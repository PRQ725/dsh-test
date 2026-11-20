// READ-ONLY Firefox WebDriver BiDi probe.
// Firefox 151's Remote Agent speaks W3C WebDriver BiDi over a websocket at
// /session. There is no CDP /json HTTP API, so we do the BiDi handshake by
// hand with Node's built-in WebSocket. Observation only: no request
// rewriting, no interception, no anti-bot circumvention.

import { writeFileSync, mkdirSync } from 'node:fs';

const PORT = process.argv[2] || '9224';
const URL_ = process.argv[3] || 'https://bambulab.jobs.feishu.cn/campus';
const OUT = process.argv[4] || '.';
const TAG = process.argv[5] || 'firefox';
const WAIT_MS = Number(process.argv[6] || '15000');

mkdirSync(OUT, { recursive: true });
const report = { tag: TAG, port: PORT, url: URL_, layers: {}, console: [], errors: [] };
const layer = (n, ok, d) => { report.layers[n] = { ok, detail: d }; console.error(`[layer] ${n}: ${ok ? 'OK' : 'FAIL'} - ${d}`); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---- Layer 1: BiDi websocket handshake ---------------------------------
const ws = new WebSocket(`ws://127.0.0.1:${PORT}/session`);
await new Promise((resolve) => {
  const t = setTimeout(() => { layer('1.bidi_handshake', false, 'timeout after 12s'); resolve(); }, 12000);
  ws.addEventListener('open', () => { clearTimeout(t); layer('1.bidi_handshake', true, 'websocket /session open (W3C BiDi endpoint)'); resolve(); });
  ws.addEventListener('error', (e) => { clearTimeout(t); layer('1.bidi_handshake', false, `error: ${e.message || 'unknown'}`); resolve(); });
});

let id = 0; const pending = new Map(); let bidiSession = null;
ws.addEventListener('message', (ev) => {
  let m; try { m = JSON.parse(ev.data); } catch { return; }
  if (m.id !== undefined && m.id !== null && pending.has(m.id)) {
    const p = pending.get(m.id); pending.delete(m.id);
    m.error ? p.rej(new Error(JSON.stringify(m.error))) : p.res(m.result);
    return;
  }
  if (m.method === 'log.entryAdded') report.console.push({ level: m.params.level, text: String(m.params.text).slice(0, 300) });
  if (m.method === 'script.exceptionThrown') report.errors.push(String(m.params.exceptionDetails?.text || '').slice(0, 300));
});
const send = (method, params = {}, timeoutMs = 25000) => new Promise((res, rej) => {
  const i = ++id; const t = setTimeout(() => { pending.delete(i); rej(new Error(`timeout: ${method}`)); }, timeoutMs);
  pending.set(i, { res: (v) => { clearTimeout(t); res(v); }, rej: (e) => { clearTimeout(t); rej(e); } });
  ws.send(JSON.stringify({ id: i, method, params }));
});

// ---- Layer 2: session.new with capabilities ----------------------------
try {
  const caps = await send('session.new', { capabilities: { alwaysMatch: { acceptInsecureCerts: false } } });
  bidiSession = caps.sessionId;
  report.sessionId = bidiSession;
  report.capabilities = caps.capabilities;
  layer('2.session_new', true, `sessionId=${bidiSession} browser=${caps.capabilities?.browserName} ${caps.capabilities?.browserVersion} webSocketUrl=${caps.capabilities?.webSocketUrl || 'n/a'}`);
} catch (e) {
  layer('2.session_new', false, `${e.message}`);
  writeFileSync(`${OUT}/${TAG}-bidi-report.json`, JSON.stringify(report, null, 2), 'utf8');
  ws.close(); process.exit(2);
}

// ---- Layer 3: script + log domains (observation) -----------------------
// Not all BiDi modules exist in every Firefox build; enable what is available.
const domainResults = {};
for (const dom of ['script.enable', 'log.enable', 'browsingContext.enable', 'session.subscribe']) {
  try {
    if (dom === 'session.subscribe') await send(dom, { events: ['log.entryAdded'] });
    else await send(dom, {});
    domainResults[dom] = 'enabled';
  } catch (e) { domainResults[dom] = `unsupported: ${e.message}`; }
}
const anyEnabled = Object.values(domainResults).some((v) => v === 'enabled');
layer('3.domains_enabled', anyEnabled, JSON.stringify(domainResults));

// ---- Layer 4: get the existing browsing context (headless still opens one)
let context = null;
try {
  const tree = await send('browsingContext.getTree', {});
  const ctxs = tree.contexts || [];
  context = ctxs[0]?.context || null;
  report.contextTree = ctxs.map((c) => ({ context: c.context, url: c.url, children: (c.children || []).length }));
  layer('4.browsing_context', !!context, context ? `context=${context}; tree=${JSON.stringify(report.contextTree)}` : 'no context found');
} catch (e) { layer('4.browsing_context', false, `${e.message}`); }

// ---- Layer 5: navigate -------------------------------------------------
if (context) {
  try {
    const nav = await send('browsingContext.navigate', { context, url: URL_, wait: 'complete' }, 40000);
    report.navigation = nav;
    layer('5.navigate', true, `reached=${nav.url} readyState via wait=complete`);
  } catch (e) { layer('5.navigate', false, `${e.message}`); }
} else { layer('5.navigate', false, 'skipped: no browsing context'); }

const READ = `(() => {
  const links = Array.from(document.querySelectorAll('a[href]'));
  const jobish = links.filter(a => /\\/campus\\/position|\\/position\\/|job|post/i.test(a.getAttribute('href')||''));
  const text = (document.body && document.body.innerText) || '';
  return { title: document.title, href: location.href, readyState: document.readyState,
    htmlLength: document.documentElement.outerHTML.length, textLength: text.length,
    textSample: text.slice(0, 700), anchorCount: links.length, jobishAnchorCount: jobish.length,
    jobishIds: jobish.map(a => ((a.getAttribute('href')||'').match(/position\\/(\\d+)/)||[])[1]).filter(Boolean),
    antiBotSignals: { slideVerifyScript: Array.from(document.scripts).some(s => /verify\\.snssdk\\.com|pc_slide/.test(s.src||'')),
      verifyContainers: document.querySelectorAll('[id*=captcha],[class*=captcha],[id*=verify],[id*=slide]').length,
      signatureRefsInHtml: (document.documentElement.outerHTML.match(/_signature/g)||[]).length },
    jsExecutionProof: 'JS_EVAL_OK' };
})()`;

// ---- Layer 6: evaluate page JavaScript ---------------------------------
// BiDi serializes JS objects as RemoteValue: {type:'object', value:[[k, RemoteValue], ...]}.
// Deserialize recursively (objects/arrays only; scalars are direct).
function deRemote(rv) {
  if (rv === null || rv === undefined) return rv;
  if (typeof rv !== 'object') return rv;
  if (Array.isArray(rv)) return rv.map(deRemote);
  const t = rv.type;
  if (t === 'object') {
    const out = {};
    for (const [k, v] of rv.value || []) out[k] = deRemote(v);
    return out;
  }
  if (t === 'array') return (rv.value || []).map(deRemote);
  if (t === 'undefined') return undefined;
  if (t === 'null') return null;
  if (['string', 'number', 'boolean', 'bigint'].includes(t)) return rv.value;
  return rv.value;
}

async function evaluate(expr) {
  const r = await send('script.evaluate', { expression: expr, target: { context }, awaitPromise: false, resultOwnership: 'none' }, 30000);
  if (r.type === 'exception') throw new Error(JSON.stringify(r.exceptionDetails).slice(0, 400));
  return deRemote(r.result);
}
if (context) {
  try {
    report.eval = await evaluate(READ);
    layer('6.js_execution', true, `proof=${report.eval.jsExecutionProof} title="${report.eval.title}"`);
  } catch (e) { layer('6.js_execution', false, `${e.message}`); }
  try {
    const dom = await evaluate('document.documentElement.outerHTML');
    writeFileSync(`${OUT}/${TAG}-rendered-dom.html`, dom, 'utf8');
    layer('7.rendered_dom', dom.length > 0, `captured ${dom.length} chars -> ${TAG}-rendered-dom.html`);
  } catch (e) { layer('7.rendered_dom', false, `${e.message}`); }
} else { layer('6.js_execution', false, 'skipped'); layer('7.rendered_dom', false, 'skipped'); }

// ---- Layer 8: screenshot via BiDi --------------------------------------
if (context) {
  try {
    const shot = await send('browsingContext.captureScreenshot', { context }, 30000);
    const buf = Buffer.from(shot.data, 'base64');
    writeFileSync(`${OUT}/${TAG}-screenshot.png`, buf);
    layer('8.screenshot', buf.length > 0, `${buf.length} bytes -> ${TAG}-screenshot.png`);
  } catch (e) { layer('8.screenshot', false, `${e.message}`); }
}

// ---- Layer 9: settle, then re-read -------------------------------------
console.error(`[info] waiting ${WAIT_MS}ms for SPA settle...`);
await sleep(WAIT_MS);
if (context) {
  try {
    report.evalAfterWait = await evaluate(READ);
    layer('9.after_settle_render', true, `textLen=${report.evalAfterWait.textLength} anchors=${report.evalAfterWait.anchorCount} jobIds=${report.evalAfterWait.jobishIds.length}`);
    const dom2 = await evaluate('document.documentElement.outerHTML');
    writeFileSync(`${OUT}/${TAG}-rendered-dom-settled.html`, dom2, 'utf8');
    const shot2 = await send('browsingContext.captureScreenshot', { context }, 30000);
    writeFileSync(`${OUT}/${TAG}-screenshot-settled.png`, Buffer.from(shot2.data, 'base64'));
  } catch (e) { layer('9.after_settle_render', false, `${e.message}`); }
}

report.summary = {
  bidiEndpoint: report.layers['1.bidi_handshake']?.ok ?? false,
  sessionCreated: !!bidiSession,
  navigated: report.layers['5.navigate']?.ok ?? false,
  jsExecuted: report.layers['6.js_execution']?.ok ?? false,
  domObtained: report.layers['7.rendered_dom']?.ok ?? false,
  renderedContent: (report.evalAfterWait?.textLength || 0) > 0,
  jobIdsFound: report.evalAfterWait?.jobishIds?.length ?? 0,
};
writeFileSync(`${OUT}/${TAG}-bidi-report.json`, JSON.stringify(report, null, 2), 'utf8');
console.error(`[done] -> ${OUT}/${TAG}-bidi-report.json`);
try { await send('session.end', {}); } catch {}
ws.close(); process.exit(0);

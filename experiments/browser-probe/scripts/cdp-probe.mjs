// READ-ONLY browser capability probe via Chrome DevTools Protocol.
// No request modification, no interception, no anti-bot circumvention,
// no script injection into the page. Observes only what the browser
// naturally renders and reports, plus the page's own console output.
//
// Usage: node cdp-probe.mjs --port 9222 --url <url> --out <dir> --tag <name>

import { writeFileSync, mkdirSync } from 'node:fs';

function arg(name, dflt) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : dflt;
}

const PORT = arg('port', '9222');
const URL_ = arg('url', 'https://bambulab.jobs.feishu.cn/campus');
const OUT = arg('out', '.');
const TAG = arg('tag', 'chrome');
const WAIT_MS = Number(arg('wait', '12000'));

mkdirSync(OUT, { recursive: true });
const report = {
  tag: TAG,
  port: PORT,
  url: URL_,
  layers: {},
  console: [],
  exceptions: [],
  requests: [],
  failedRequests: [],
  warnings: [],
};

function layer(name, ok, detail) {
  report.layers[name] = { ok, detail };
  console.error(`[layer] ${name}: ${ok ? 'OK' : 'FAIL'} - ${detail}`);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---- Layer 1: CDP HTTP endpoint reachable -------------------------------
let version = null;
try {
  const res = await fetch(`http://127.0.0.1:${PORT}/json/version`);
  version = await res.json();
  layer('1.cdp_http_endpoint', true, `Browser=${version.Browser} protocol=${version['Protocol-Version']}`);
} catch (e) {
  layer('1.cdp_http_endpoint', false, `${e.name}: ${e.message}`);
  writeFileSync(`${OUT}/${TAG}-report.json`, JSON.stringify(report, null, 2));
  process.exit(1);
}

// ---- Layer 2: find the page target --------------------------------------
let target = null;
try {
  const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
  const pages = list.filter((t) => t.type === 'page');
  target = pages.find((t) => t.url.startsWith('http')) || pages[0] || null;
  layer('2.page_target_found', !!target,
    target ? `title="${target.title}" url=${target.url}` : `no page targets; saw ${list.length} targets`);
} catch (e) {
  layer('2.page_target_found', false, `${e.name}: ${e.message}`);
}

if (!target) {
  writeFileSync(`${OUT}/${TAG}-report.json`, JSON.stringify(report, null, 2));
  process.exit(2);
}

// ---- Layer 3: WebSocket attach to the page target -----------------------
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve) => {
  const t = setTimeout(() => { layer('3.cdp_websocket_attach', false, 'timeout after 10s'); resolve(); }, 10000);
  ws.addEventListener('open', () => { clearTimeout(t); layer('3.cdp_websocket_attach', true, 'websocket open'); resolve(); });
  ws.addEventListener('error', (e) => { clearTimeout(t); layer('3.cdp_websocket_attach', false, `error event: ${e.message || 'unknown'}`); resolve(); });
});

let msgId = 0;
const pending = new Map();
const events = [];
ws.addEventListener('message', (ev) => {
  let m; try { m = JSON.parse(ev.data); } catch { return; }
  if (m.id && pending.has(m.id)) {
    const { resolve, reject } = pending.get(m.id); pending.delete(m.id);
    m.error ? reject(new Error(JSON.stringify(m.error))) : resolve(m.result);
    return;
  }
  events.push(m);
  switch (m.method) {
    case 'Runtime.consoleAPICalled':
      report.console.push({
        type: m.params.type,
        text: (m.params.args || []).map((a) => a.value ?? a.description ?? a.type).join(' ').slice(0, 500),
      });
      break;
    case 'Runtime.exceptionThrown':
      report.exceptions.push({
        text: m.params.exceptionDetails?.exception?.description
          || m.params.exceptionDetails?.text || 'unknown',
        url: m.params.exceptionDetails?.url,
        line: m.params.exceptionDetails?.lineNumber,
      });
      break;
    case 'Log.entryAdded':
      if (m.params.entry.level === 'error' || m.params.entry.level === 'warning') {
        report.warnings.push({ level: m.params.entry.level, text: m.params.entry.text?.slice(0, 500), url: m.params.entry.url });
      }
      break;
    case 'Network.responseReceived': {
      const r = m.params.response;
      if (!r.url.startsWith('data:')) report.requests.push({ status: r.status, mime: r.mimeType, url: r.url.slice(0, 300) });
      break;
    }
    case 'Network.loadingFailed':
      report.failedRequests.push({ error: m.params.errorText, type: m.params.type, canceled: !!m.params.canceled });
      break;
  }
});

function send(method, params = {}, timeoutMs = 20000) {
  const id = ++msgId;
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => { pending.delete(id); reject(new Error(`timeout: ${method}`)); }, timeoutMs);
    pending.set(id, { resolve: (v) => { clearTimeout(t); resolve(v); }, reject: (e) => { clearTimeout(t); reject(e); } });
    ws.send(JSON.stringify({ id, method, params }));
  });
}

// ---- Layer 4: enable domains (pure observation) -------------------------
try {
  await send('Runtime.enable');
  await send('Page.enable');
  await send('Log.enable');
  await send('Network.enable');
  layer('4.domains_enabled', true, 'Runtime, Page, Log, Network enabled (observation only)');
} catch (e) {
  layer('4.domains_enabled', false, `${e.message}`);
}

// ---- Layer 4b: navigate to the target URL (normal browsing, no rewriting)
try {
  await send('Page.navigate', { url: URL_ });
  const t0 = Date.now();
  let loaded = false;
  while (Date.now() - t0 < 25000) {
    await sleep(400);
    const ev = await send('Runtime.evaluate', { expression: 'document.readyState', returnByValue: true });
    if (ev.result.value === 'complete') { loaded = true; break; }
  }
  layer('4b.navigate', loaded,
    loaded ? `readyState=complete after ${Date.now() - t0}ms` : `still not complete after ${Date.now() - t0}ms`);
  const nav = await send('Runtime.evaluate', { expression: 'location.href + " | " + document.title', returnByValue: true });
  report.navigation = nav.result.value;
} catch (e) {
  layer('4b.navigate', false, `${e.message}`);
}

// ---- Layer 5: evaluate page JavaScript ----------------------------------
const READ_EXPR = `(() => {
  const q = (s) => document.querySelector(s);
  const links = Array.from(document.querySelectorAll('a[href]'));
  const jobish = links.filter(a => /\\/campus\\/position|\\/position\\/|job|post/i.test(a.getAttribute('href')||''));
  const text = (document.body && document.body.innerText) || '';
  return {
    title: document.title,
    href: location.href,
    readyState: document.readyState,
    bodyChildElementCount: document.body ? document.body.childElementCount : -1,
    htmlLength: document.documentElement.outerHTML.length,
    textLength: text.length,
    textSample: text.slice(0, 1200),
    anchorCount: links.length,
    jobishAnchorCount: jobish.length,
    jobishSamples: jobish.slice(0, 12).map(a => ({ t: (a.innerText||'').trim().slice(0,80), h: a.getAttribute('href') })),
    hasRootApp: !!q('#root, #app, [id*=root]'),
    antiBotSignals: {
      slideVerifyScript: Array.from(document.scripts).some(s => /verify\\.snssdk\\.com|pc_slide/.test(s.src||'')),
      verifyContainers: document.querySelectorAll('[id*=captcha],[class*=captcha],[id*=verify],[class*=verify],[id*=slide],[class*=slide]').length,
      visibleCaptchaText: /验证|滑块|captcha|verify/i.test(text),
      signatureRefsInHtml: (document.documentElement.outerHTML.match(/_signature/g)||[]).length,
    },
    jsExecutionProof: 'JS_EVAL_OK',
  };
})()`;

let evalResult = null;
try {
  const r = await send('Runtime.evaluate', { expression: READ_EXPR, returnByValue: true, awaitPromise: false });
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.text + ' ' + (r.exceptionDetails.exception?.description || ''));
  evalResult = r.result.value;
  report.eval = evalResult;
  layer('5.js_execution', true, `Runtime.evaluate returned object; proof=${evalResult.jsExecutionProof}`);
} catch (e) {
  layer('5.js_execution', false, `${e.message}`);
}

// ---- Layer 6: rendered DOM capture --------------------------------------
try {
  const dom = await send('Runtime.evaluate', {
    expression: 'document.documentElement.outerHTML', returnByValue: true,
  });
  const html = dom.result.value || '';
  writeFileSync(`${OUT}/${TAG}-rendered-dom.html`, html, 'utf8');
  layer('6.rendered_dom', html.length > 0, `captured ${html.length} chars -> ${TAG}-rendered-dom.html`);
} catch (e) {
  layer('6.rendered_dom', false, `${e.message}`);
}

// ---- Layer 7: screenshot -------------------------------------------------
try {
  await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
  const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true });
  const buf = Buffer.from(shot.data, 'base64');
  writeFileSync(`${OUT}/${TAG}-screenshot.png`, buf);
  layer('7.screenshot', buf.length > 0, `captured ${buf.length} bytes -> ${TAG}-screenshot.png`);
  await send('Emulation.clearDeviceMetricsOverride');
} catch (e) {
  layer('7.screenshot', false, `${e.message}`);
}

// ---- Layer 8: page performance timing -----------------------------------
try {
  const perf = await send('Runtime.evaluate', {
    expression: `JSON.stringify((() => { const n = performance.getEntriesByType('navigation')[0] || {};
      return { domContentLoaded: Math.round(n.domContentLoadedEventEnd||0), loadEvent: Math.round(n.loadEventEnd||0),
               transferSize: n.transferSize||0, resourceCount: performance.getEntriesByType('resource').length }; })())`,
    returnByValue: true,
  });
  report.performance = JSON.parse(perf.result.value);
  layer('8.performance_timing', true, JSON.stringify(report.performance));
} catch (e) {
  layer('8.performance_timing', false, `${e.message}`);
}

// ---- Layer 9: let the SPA settle, then re-read render state -------------
console.error(`[info] waiting ${WAIT_MS}ms for SPA hydration/settling...`);
await sleep(WAIT_MS);
try {
  const r = await send('Runtime.evaluate', { expression: READ_EXPR, returnByValue: true });
  report.evalAfterWait = r.result.value;
  layer('9.after_settle_render', true,
    `textLen=${r.result.value.textLength} anchors=${r.result.value.anchorCount} jobish=${r.result.value.jobishAnchorCount}`);
} catch (e) {
  layer('9.after_settle_render', false, `${e.message}`);
}

report.summary = {
  cdpReachable: report.layers['1.cdp_http_endpoint']?.ok ?? false,
  browserLaunched: !!version,
  domObtained: report.layers['6.rendered_dom']?.ok ?? false,
  jsExecuted: report.layers['5.js_execution']?.ok ?? false,
  renderedContent: report.evalAfterWait?.textLength > 0,
  requestCount: report.requests.length,
  failedRequestCount: report.failedRequests.length,
};
writeFileSync(`${OUT}/${TAG}-report.json`, JSON.stringify(report, null, 2), 'utf8');
console.error(`[done] report -> ${OUT}/${TAG}-report.json`);
ws.close();
process.exit(0);

// READ-ONLY: reset the page to a clean load, then dump the real filter DOM
// structure so the click target can be identified precisely.
import { writeFileSync } from 'node:fs';
const PORT = process.argv[2] || '9222';
const OUT = process.argv[3] || '.';
const TAG = process.argv[4] || 'chrome';
const URL_ = 'https://bambulab.jobs.feishu.cn/campus';

const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
const target = list.find((t) => t.type === 'page' && t.url.startsWith('http')) || list.find((t) => t.type === 'page');
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.addEventListener('open', res); ws.addEventListener('error', rej); });
let id = 0; const pending = new Map();
ws.addEventListener('message', (ev) => { const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { const p = pending.get(m.id); pending.delete(m.id); m.error ? p.rej(new Error(JSON.stringify(m.error))) : p.res(m.result); } });
const send = (method, params = {}) => new Promise((res, rej) => { const i = ++id; pending.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method, params })); });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const js = async (expression) => (await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: false })).result.value;

await send('Runtime.enable'); await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
await send('Page.navigate', { url: URL_ });
// Wait for the job list to actually populate rather than a fixed sleep.
let ready = false;
for (let i = 0; i < 60; i++) {
  await sleep(700);
  const n = await js(`document.querySelectorAll('a[href*="/position/"]').length`);
  if (n >= 5) { ready = true; break; }
}
console.error(`[info] job list ready=${ready}`);
await sleep(3000);

const diag = await js(`(() => {
  const out = { countText: (document.body.innerText.match(/开启新的工作[^\\n]{0,20}/)||[])[0] || null,
    jobAnchors: document.querySelectorAll('a[href*="/position/"]').length,
    checkboxInputs: document.querySelectorAll('input[type=checkbox]').length,
    inputsTotal: document.querySelectorAll('input').length };
  // Find candidate filter row containing the target text
  const hit = Array.from(document.querySelectorAll('*')).filter(el => el.children.length === 0 && (el.innerText||'').trim() === '27届秋招（制造类）')[0];
  if (hit) {
    const row = hit.closest('label') || hit.parentElement?.parentElement || hit.parentElement;
    out.hitTag = hit.tagName; out.hitClass = (hit.className||'').toString().slice(0,80);
    out.rowHtml = row ? row.outerHTML.slice(0, 900) : null;
    const inp = row ? row.querySelector('input') : null;
    out.rowHasInput = !!inp;
    if (inp) { const s = getComputedStyle(inp); const r = inp.getBoundingClientRect();
      out.inputInfo = { type: inp.type, checked: inp.checked, w: r.width, h: r.height, display: s.display, opacity: s.opacity, appearance: s.appearance }; }
  } else { out.hitTag = 'NOT FOUND'; }
  // Dump the whole filter sidebar structure skeleton
  const filterRoot = Array.from(document.querySelectorAll('*')).find(el => (el.innerText||'').trim().startsWith('筛选') && el.querySelectorAll('*').length < 400);
  out.filterSkeleton = filterRoot ? filterRoot.outerHTML.slice(0, 3000) : null;
  return out;
})()`);
console.log(JSON.stringify(diag, null, 2));
writeFileSync(`${OUT}/${TAG}-filter-dom-diag.json`, JSON.stringify(diag, null, 2), 'utf8');
ws.close(); process.exit(0);

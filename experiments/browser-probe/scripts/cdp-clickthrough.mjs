// READ-ONLY click-through test: click a job card with a real mouse event and
// confirm the SPA routes to the detail page. No form is submitted.
import { writeFileSync } from 'node:fs';
const PORT = process.argv[2] || '9222';
const OUT = process.argv[3] || '.';

const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
const t = list.find((x) => x.type === 'page' && x.url.startsWith('http')) || list.find((x) => x.type === 'page');
const ws = new WebSocket(t.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r));
let id = 0; const pend = new Map();
ws.addEventListener('message', (e) => { const m = JSON.parse(e.data);
  if (m.id && pend.has(m.id)) { const p = pend.get(m.id); pend.delete(m.id); m.error ? p.rej(new Error(JSON.stringify(m.error))) : p.res(m.result); } });
const send = (method, params = {}) => new Promise((res, rej) => { const i = ++id; pend.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method, params })); });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const js = async (expr) => (await send('Runtime.evaluate', { expression: expr, returnByValue: true })).result.value;

await send('Runtime.enable'); await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
await send('Page.navigate', { url: 'https://bambulab.jobs.feishu.cn/campus' });
for (let i = 0; i < 50; i++) { await sleep(600); if ((await js(`document.querySelectorAll('a[href*="/position/"]').length`)) >= 5) break; }
await sleep(3000);

const target = await js(`(() => {
  const a = document.querySelector('a[href*="/position/"]');
  if (!a) return null;
  // Click the job TITLE text, the element a human actually aims at.
  const inner = Array.from(a.querySelectorAll('*'))
    .filter(el => el.children.length === 0 && (el.innerText||'').trim().length > 3)
    .sort((x,y) => x.getBoundingClientRect().top - y.getBoundingClientRect().top)[0];
  const hit = inner || a;
  hit.scrollIntoView({ block: 'center' });
  const r = hit.getBoundingClientRect();
  return { x: Math.round(r.left + r.width/2), y: Math.round(r.top + r.height/2),
           w: Math.round(r.width), h: Math.round(r.height),
           hitTag: hit.tagName, hitClass: (hit.className||'').toString().slice(0,60),
           href: a.getAttribute('href'), text: (hit.innerText||'').slice(0,40),
           inViewport: r.top >= 0 && r.bottom <= innerHeight };
})()`);
console.log('job card target:', JSON.stringify(target));
await sleep(1000);

const out = { target };
if (target && target.inViewport) {
  await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: target.x, y: target.y });
  await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: target.x, y: target.y, button: 'left', clickCount: 1 });
  await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: target.x, y: target.y, button: 'left', clickCount: 1 });
  await sleep(6000);
  out.afterClick = await js(`({ url: location.href, title: document.title,
    textLen: document.body.innerText.length,
    hasApplyButton: !!Array.from(document.querySelectorAll('button,a')).find(b => /投递|申请/.test(b.innerText||'')),
    textSample: document.body.innerText.slice(0, 300) })`);
  console.log('after clicking job card:', JSON.stringify(out.afterClick, null, 2));
  const s = await send('Page.captureScreenshot', { format: 'png' });
  writeFileSync(`${OUT}/chrome-clickthrough-detail.png`, Buffer.from(s.data, 'base64'));
} else {
  out.note = 'card not in viewport; skipped click';
}
out.routedToDetail = /\/position\/\d+\/detail/.test(out.afterClick?.url || '');
console.log('routedToDetail:', out.routedToDetail);
writeFileSync(`${OUT}/chrome-clickthrough.json`, JSON.stringify(out, null, 2), 'utf8');
ws.close(); process.exit(0);

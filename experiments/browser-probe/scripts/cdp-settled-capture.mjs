// READ-ONLY: launch nothing; attach to a fresh headless Chrome we start here
// ONLY to capture the settled DOM. Kept minimal and self-cleaning.
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
await send('Page.navigate', { url: 'https://bambulab.jobs.feishu.cn/campus' });
for (let i = 0; i < 60; i++) { await sleep(700); if ((await js(`document.querySelectorAll('a[href*="/position/"]').length`)) >= 5) break; }
await sleep(6000);
const n = await js(`document.querySelectorAll('a[href*="/position/"]').length`);
const dom = await js('document.documentElement.outerHTML');
writeFileSync(`${OUT}/chrome-rendered-dom-settled.html`, dom, 'utf8');
const shot = await send('Page.captureScreenshot', { format: 'png' });
writeFileSync(`${OUT}/chrome-screenshot-settled2.png`, Buffer.from(shot.data, 'base64'));
console.log(`settled chrome: position-links=${n}, dom=${dom.length} chars`);
ws.close(); process.exit(0);

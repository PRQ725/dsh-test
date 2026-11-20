// READ-ONLY interaction capability test via CDP (real mouse events).
// Target: the Ant-Design-style tree filter checkbox in the job list sidebar.
// Sequence: clean load -> click filter -> observe change -> click again to
// restore -> open nothing, submit nothing, write nothing to the site.

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
const js = async (expression) => (await send('Runtime.evaluate', { expression, returnByValue: true })).result.value;

await send('Runtime.enable'); await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });

const result = { tag: TAG, steps: [] };
const LABEL = '27届秋招（制造类）';

await send('Page.navigate', { url: URL_ });
for (let i = 0; i < 60; i++) { await sleep(700); if ((await js(`document.querySelectorAll('a[href*="/position/"]').length`)) >= 5) break; }
await sleep(3000);

// Locate the tree checkbox span belonging to the target node.
const locate = (label) => `(() => {
  const title = Array.from(document.querySelectorAll('.atsx-tree-title, [class*=tree-title]'))
    .find(el => (el.innerText||'').trim() === ${JSON.stringify(label)});
  if (!title) return null;
  const node = title.closest('li[role=treeitem]');
  const box = node && node.querySelector('.atsx-tree-checkbox');
  if (!box) return null;
  box.scrollIntoView({ block: 'center' });
  const r = box.getBoundingClientRect();
  return { x: Math.round(r.left + r.width/2), y: Math.round(r.top + r.height/2), w: Math.round(r.width), h: Math.round(r.height),
           className: box.className, inViewport: r.top >= 0 && r.bottom <= innerHeight };
})()`;

const state = () => `(() => {
  const title = Array.from(document.querySelectorAll('.atsx-tree-title'))
    .find(el => (el.innerText||'').trim() === ${JSON.stringify(LABEL)});
  const node = title && title.closest('li[role=treeitem]');
  const box = node && node.querySelector('.atsx-tree-checkbox');
  const m = (document.body.innerText.match(/开启新的工作[（(](\\d+)/)||[]);
  return { jobCount: m[1] ? Number(m[1]) : null,
           checkboxChecked: box ? /checked/.test(box.className) : null,
           selectedTags: (document.body.innerText.match(/已选|清除/g)||[]).length };
})()`;

const click = async (box) => {
  await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: box.x, y: box.y });
  await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: box.x, y: box.y, button: 'left', clickCount: 1 });
  await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: box.x, y: box.y, button: 'left', clickCount: 1 });
};

const before = await js(state());
result.steps.push({ step: 'initial_state', ...before });

const box = await js(locate(LABEL));
result.steps.push({ step: 'locate_tree_checkbox', value: box });
await sleep(800);

if (box && box.h > 0) {
  await click(box);
  await sleep(5000);
  const after = await js(state());
  result.steps.push({ step: 'after_filter_click', ...after,
    jobCountChanged: after.jobCount !== before.jobCount,
    checkboxToggled: after.checkboxChecked !== before.checkboxChecked });

  const box2 = await js(locate(LABEL));
  if (box2 && box2.h > 0) { await click(box2); await sleep(5000); }
  const restored = await js(state());
  result.steps.push({ step: 'after_restore_click', ...restored, restoredToInitial: restored.jobCount === before.jobCount });
} else {
  result.steps.push({ step: 'locate_tree_checkbox', value: 'not found / not laid out' });
}

// Can we read a job detail page? Open the first job card link and read it, then go back.
const detailHref = await js(`(() => { const a = document.querySelector('a[href*="/position/"]'); return a ? a.getAttribute('href') : null; })()`);
if (detailHref) {
  const abs = new URL(detailHref, URL_).href;
  await send('Page.navigate', { url: abs });
  for (let i = 0; i < 40; i++) { await sleep(700); if ((await js('document.body.innerText.length')) > 400) break; }
  await sleep(4000);
  const d = await js(`(() => ({ href: location.href, title: document.title,
     textLen: document.body.innerText.length, textSample: document.body.innerText.slice(0, 500),
     applyButton: !!Array.from(document.querySelectorAll('button,a')).find(b => /投递|申请|立即投递/.test(b.innerText||'')) }))()`);
  result.steps.push({ step: 'job_detail_page', ...d });
  const shot = await send('Page.captureScreenshot', { format: 'png' });
  writeFileSync(`${OUT}/${TAG}-detail-page.png`, Buffer.from(shot.data, 'base64'));
}

result.summary = {
  interactiveClicksWork: result.steps.some((s) => s.jobCountChanged === true),
  checkboxToggled: result.steps.some((s) => s.checkboxToggled === true),
  stateRestored: result.steps.some((s) => s.restoredToInitial === true),
  detailPageReadable: result.steps.some((s) => s.step === 'job_detail_page' && s.textLen > 400),
};
console.log(JSON.stringify(result, null, 2));
writeFileSync(`${OUT}/${TAG}-interaction-test.json`, JSON.stringify(result, null, 2), 'utf8');
ws.close(); process.exit(0);

// READ-ONLY post-settle visual check + capture against already-open CDP page.
import { writeFileSync } from 'node:fs';
const PORT = process.argv[2] || '9222';
const OUT = process.argv[3] || '.';
const TAG = process.argv[4] || 'chrome';

const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
const target = list.find((t) => t.type === 'page' && t.url.startsWith('http'));
if (!target) { console.error('no page target'); process.exit(1); }

const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.addEventListener('open', res); ws.addEventListener('error', rej); });
let id = 0; const pending = new Map();
ws.addEventListener('message', (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { const p = pending.get(m.id); pending.delete(m.id); m.error ? p.rej(new Error(JSON.stringify(m.error))) : p.res(m.result); }
});
const send = (method, params = {}) => new Promise((res, rej) => { const i = ++id; pending.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method, params })); });

await send('Runtime.enable');
await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });

const probe = await send('Runtime.evaluate', {
  returnByValue: true,
  expression: `(() => {
    const vis = (el) => { if (!el) return null; const r = el.getBoundingClientRect(); const s = getComputedStyle(el);
      return { tag: el.tagName, id: el.id || null, cls: (el.className||'').toString().slice(0,120),
               w: Math.round(r.width), h: Math.round(r.height), x: Math.round(r.left), y: Math.round(r.top),
               display: s.display, visibility: s.visibility, zIndex: s.zIndex, position: s.position,
               text: (el.innerText||'').trim().slice(0,120) }; };
    // Any fixed/absolute overlay that could be a captcha or modal
    const overlays = Array.from(document.querySelectorAll('div,iframe,section'))
      .filter(el => { const s = getComputedStyle(el); const r = el.getBoundingClientRect();
        return (s.position === 'fixed' || s.position === 'absolute') && r.width > 200 && r.height > 120 && s.display !== 'none' && s.visibility !== 'hidden' && parseFloat(s.opacity||'1') > 0.1; })
      .slice(0, 15).map(vis);
    return {
      url: location.href, title: document.title,
      bodyTextLen: (document.body.innerText||'').length,
      scrollHeight: document.documentElement.scrollHeight,
      iframes: Array.from(document.querySelectorAll('iframe')).map(f => ({ src: (f.src||'').slice(0,150), w: f.getBoundingClientRect().width, h: f.getBoundingClientRect().height, display: getComputedStyle(f).display })),
      overlays,
      jobCardCount: document.querySelectorAll('a[href*="/position/"]').length,
      allCaptchaTextMatches: (document.body.innerText.match(/.{0,20}(验证|滑块|captcha).{0,20}/gi)||[]).slice(0,5),
      firstJobText: (document.querySelector('a[href*="/position/"]')?.innerText || '').slice(0,200),
    };
  })()`,
});
console.log(JSON.stringify(probe.result.value, null, 2));
writeFileSync(`${OUT}/${TAG}-postsettle-state.json`, JSON.stringify(probe.result.value, null, 2), 'utf8');

const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
writeFileSync(`${OUT}/${TAG}-screenshot-settled.png`, Buffer.from(shot.data, 'base64'));
console.error(`[ok] saved ${TAG}-screenshot-settled.png`);
ws.close();
process.exit(0);

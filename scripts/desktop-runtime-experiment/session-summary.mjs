// session-summary.mjs - READ-ONLY DSH session summary (one line of JSON).
//
// Companion to decode-session-log.mjs. Where that tool prints the decoded
// JSONL, this one prints only machine-readable facts needed by the E1
// change-classifier: event count and the LAST event type, so a delta can be
// judged as "benign one-time session/end-seed append" vs "unexpected rewrite".
//
// Usage:
//   node session-summary.mjs <session.vN.jsonl.zstd>
//
// Never writes anything.
import { readFileSync } from 'node:fs';
import { zstdDecompressSync } from 'node:zlib';

const file = process.argv[2];
if (!file) { console.error('usage: node session-summary.mjs <session.vN.jsonl.zstd>'); process.exit(2); }

let out;
try {
  const buf = readFileSync(file);
  const MAGIC = Buffer.from([0x28, 0xb5, 0x2f, 0xfd]);
  const starts = [];
  for (let i = 0; ;) { const idx = buf.indexOf(MAGIC, i); if (idx === -1) break; starts.push(idx); i = idx + 4; }
  const outs = [];
  for (let n = 0; n < starts.length; n++) {
    const s = starts[n];
    const e = n + 1 < starts.length ? starts[n + 1] : buf.length;
    try { outs.push(zstdDecompressSync(buf.subarray(s, e))); } catch { outs.push(Buffer.from('')); }
  }
  const text = Buffer.concat(outs).toString('utf8');
  const events = [];
  for (const line of text.split('\n')) {
    if (!line.trim()) continue;
    try { events.push(JSON.parse(line)); } catch { /* skip malformed */ }
  }
  const first = events[0] ?? null;
  const last = events[events.length - 1] ?? null;
  const types = {};
  for (const ev of events) types[ev.type] = (types[ev.type] || 0) + 1;
  out = {
    ok: true,
    file,
    frames: starts.length,
    decodedBytes: Buffer.byteLength(text, 'utf8'),
    events: events.length,
    sessionVersion: first?.version ?? null,
    isSeeded: first?.isSeeded ?? null,
    firstType: first?.type ?? null,
    lastType: last?.type ?? null,
    lastSeq: last?.seq ?? null,
    lastTime: last?.time ?? null,
    endSeedCount: types['session/end-seed'] ?? 0,
    endsWithEndSeed: last?.type === 'session/end-seed',
    types,
  };
} catch (error) {
  out = { ok: false, file, error: String(error && error.message ? error.message : error) };
}
console.log(JSON.stringify(out));

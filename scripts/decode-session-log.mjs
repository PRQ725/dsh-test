// decode-session-log.mjs — READ-ONLY DSH session log decoder.
//
// DSH stores session logs as CONCATENATED multi-frame zstd
// (`session.v3.jsonl.zstd`). A single `zstdDecompressSync` call decodes only
// the FIRST frame, so this tool splits on the zstd magic and decodes each
// frame independently, then concatenates.
//
// Usage:
//   node scripts/decode-session-log.mjs <session.jsonl.zstd> [--out <file>] [--summary]
//
// Writes the decoded JSONL to <file> when --out is given; otherwise prints to
// stdout. --summary prints only the event-type histogram and header line.
import { readFileSync, writeFileSync } from 'node:fs';
import { zstdDecompressSync } from 'node:zlib';

const [file, ...rest] = process.argv.slice(2);
if (!file) { console.error('usage: node decode-session-log.mjs <session.jsonl.zstd> [--out f] [--summary]'); process.exit(2); }
const outIdx = rest.indexOf('--out');
const outFile = outIdx === -1 ? undefined : rest[outIdx + 1];
const summaryOnly = rest.includes('--summary');

const buf = readFileSync(file);
const MAGIC = Buffer.from([0x28, 0xb5, 0x2f, 0xfd]);
const starts = [];
for (let i = 0; ; ) {
  const idx = buf.indexOf(MAGIC, i);
  if (idx === -1) break;
  starts.push(idx);
  i = idx + 4;
}
const outs = [];
let frameErrors = 0;
for (let n = 0; n < starts.length; n++) {
  const start = starts[n];
  const end = n + 1 < starts.length ? starts[n + 1] : buf.length;
  try { outs.push(zstdDecompressSync(buf.subarray(start, end))); }
  catch (e) { frameErrors++; outs.push(Buffer.from(`\n[FRAME ERR ${n}: ${e.message}]\n`)); }
}
const text = Buffer.concat(outs).toString('utf8');
const lines = text.split('\n').filter((l) => l.trim().length > 0);

if (outFile) writeFileSync(outFile, text, 'utf8');

const types = {};
for (const l of lines) { try { const o = JSON.parse(l); types[o.type] = (types[o.type] || 0) + 1; } catch {} }
const meta = [
  `file: ${file}`,
  `zstd frames: ${starts.length} (frameErrors=${frameErrors})`,
  `decoded bytes: ${Buffer.byteLength(text, 'utf8')}`,
  `events: ${lines.length}`,
  `header: ${lines[0] ?? '(none)'}`,
  `types: ${JSON.stringify(types)}`,
].join('\n');
if (summaryOnly || outFile) console.log(meta);
if (!outFile && !summaryOnly) console.log(text);

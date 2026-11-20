// scan-instruction-injections.mjs — READ-ONLY scanner for injected workspace-instruction messages.
//
// DSH stores session logs as CONCATENATED multi-frame zstd. This tool decodes each
// frame (same technique as decode-session-log.mjs) and reports every `user/message`
// event whose source kind is `agent-instructions`, plus the per-scope change list.
//
// It never writes to the session tree. Usage:
//   node scripts/scan-instruction-injections.mjs [--home <DSH_HOME>] [--max-bytes N] [--json]
//
// Defaults: --home $DSH_HOME or ~/.dsh, --max-bytes 64000000 (skip larger logs).
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { zstdDecompressSync } from 'node:zlib';
import { join } from 'node:path';
import { homedir } from 'node:os';

const argv = process.argv.slice(2);
const getArg = (name, dflt) => { const i = argv.indexOf(name); return i === -1 ? dflt : argv[i + 1]; };
const HOME = getArg('--home', process.env.DSH_HOME || join(homedir(), '.dsh'));
const MAX = Number(getArg('--max-bytes', 64_000_000));
const AS_JSON = argv.includes('--json');

const SESSIONS = join(HOME, 'sessions');
const MAGIC = Buffer.from([0x28, 0xb5, 0x2f, 0xfd]);

function decodeFrames(buf) {
  const starts = [];
  for (let i = 0; ;) { const idx = buf.indexOf(MAGIC, i); if (idx === -1) break; starts.push(idx); i = idx + 4; }
  const outs = [];
  for (let n = 0; n < starts.length; n++) {
    const start = starts[n];
    const end = n + 1 < starts.length ? starts[n + 1] : buf.length;
    try { outs.push(zstdDecompressSync(buf.subarray(start, end))); } catch { /* skip broken frame */ }
  }
  return Buffer.concat(outs).toString('utf8');
}

function walk(dir, out = []) {
  if (!existsSync(dir)) return out;
  for (const d of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, d.name);
    if (d.isDirectory()) walk(p, out);
    else if (/^session(\.v\d+)?\.jsonl\.zstd$/.test(d.name)) out.push(p);
  }
  return out;
}

const files = walk(SESSIONS);
const rows = [];
let scanned = 0, skipped = 0;

for (const file of files) {
  let size = 0;
  try { size = statSync(file).size; } catch { continue; }
  if (size > MAX) { skipped++; continue; }
  scanned++;
  let text;
  try { text = decodeFrames(readFileSync(file)); } catch { continue; }
  const sessionId = file.split(/[\\/]/).slice(-2, -1)[0];
  let header = null;
  for (const line of text.split('\n')) {
    const t = line.trim();
    if (!t) continue;
    let ev;
    try { ev = JSON.parse(t); } catch { continue; }
    if (ev.type === 'session') { header = ev; continue; }
    if (ev.type !== 'user/message') continue;
    const src = ev.data?.source;
    if (!src || src.kind !== 'agent-instructions') continue;
    const body = JSON.stringify(ev.data.content ?? '');
    rows.push({
      sessionId,
      file,
      size,
      cwd: header?.cwd ?? null,
      seq: ev.seq,
      form: src.form ?? null,
      baseline: src.baseline === true,
      baselineIdentity: src.baselineIdentity ?? null,
      changes: Array.isArray(src.changes)
        ? src.changes.map((c) => ({ action: c.action, scope: c.scope, path: c.path }))
        : [],
      markers: {
        additional: body.includes('Additional instructions from'),
        removed: body.includes('Instructions removed'),
        updated: body.includes('Updated instructions from'),
        budget: body.includes('Workspace instruction budget'),
      },
    });
  }
}

const summary = {
  home: HOME,
  sessionFiles: files.length,
  scanned,
  skippedTooLarge: skipped,
  instructionMessages: rows.length,
  sessionsWithInstructions: [...new Set(rows.map((r) => r.sessionId))].length,
  withAdditional: rows.filter((r) => r.markers.additional).length,
  withRemoved: rows.filter((r) => r.markers.removed).length,
  withUpdated: rows.filter((r) => r.markers.updated).length,
  withBudgetNotice: rows.filter((r) => r.markers.budget).length,
};

if (AS_JSON) {
  console.log(JSON.stringify({ summary, rows }, null, 2));
} else {
  console.log(JSON.stringify(summary, null, 2));
  console.log('\n--- instruction messages (newest session file order) ---');
  for (const r of rows) {
    const tag = r.baseline ? 'BASELINE' : (r.markers.additional ? 'ADD' : r.markers.removed ? 'REMOVE' : r.markers.updated ? 'UPDATE' : 'OTHER');
    console.log(`\n[${tag}] ${r.sessionId} seq=${r.seq} cwd=${r.cwd}`);
    console.log(`  baselineIdentity=${r.baselineIdentity ?? '-'}`);
    for (const c of r.changes) console.log(`  ${c.action.padEnd(6)} ${c.path}`);
  }
}

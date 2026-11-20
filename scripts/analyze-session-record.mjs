// READ-ONLY analyzer: extract workspace/project attribution fields from a
// DSH session project-cache record. Writes nothing; prints a summary only.
import { readFileSync } from 'node:fs';

const file = process.argv[2];
const j = JSON.parse(readFileSync(file, 'utf8'));

console.log('file:', file);
console.log('top-level keys:', Object.keys(j).join(', '));
console.log('version:', j.version);

// Recursively collect any key that looks like workspace/project/cwd attribution.
const WANT = /^(workspace.*|project.*|.*workspaceId|.*projectId|cwd|path|dir|directory|root)$/i;
const found = new Map();
const walk = (node, pathStr, depth) => {
  if (node === null || typeof node !== 'object' || depth > 12) return;
  for (const [k, v] of Object.entries(node)) {
    const p = pathStr ? `${pathStr}.${k}` : k;
    if (WANT.test(k) && (typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean')) {
      if (!found.has(`${k}`)) found.set(`${k}`, new Set());
      found.get(k).add(`${v}`);
    }
    walk(v, p, depth + 1);
  }
};
walk(j, '', 0);

console.log('\n--- attribution-ish keys (key -> distinct scalar values) ---');
if (found.size === 0) console.log('  (none found)');
for (const [k, vals] of found) {
  const arr = [...vals];
  console.log(`  ${k} (${arr.length}) -> ${arr.slice(0, 6).map((x) => JSON.stringify(String(x).slice(0, 120))).join(' | ')}`);
}

// Show the title-bearing fields specifically.
const flat = JSON.stringify(j);
console.log('\n--- literal probe ---');
for (const needle of ['browser-lab', 'dsh-test', 'Personal Job Search OS', 'D:\\Projects']) {
  const n = flat.split(needle).length - 1;
  console.log(`  "${needle}" occurrences = ${n}`);
}

// Show record-level scalar fields (the session metadata, not the event log).
const r = j.record || {};
console.log('\n--- record scalar fields ---');
for (const [k, v] of Object.entries(r)) {
  if (v === null || typeof v !== 'object') console.log(`  ${k} = ${JSON.stringify(v)}`);
}
console.log('\n--- record object fields (names only) ---');
for (const [k, v] of Object.entries(r)) {
  if (v !== null && typeof v === 'object') console.log(`  ${k} <object> keys=${Object.keys(v).slice(0, 12).join(',')}`);
}

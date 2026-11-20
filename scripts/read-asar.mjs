#!/usr/bin/env node
/**
 * Minimal read-only ASAR reader.
 *
 * Why this exists: the DeepSeek Desktop ships its bundled DSH runtime inside
 * resources/app.asar (121 MB). Extracting the whole archive to compare a handful of
 * files would write ~121 MB for no reason, so this tool parses the ASAR header and
 * reads only the requested entries, straight out of the archive. It never writes to
 * the archive and never extracts to disk.
 *
 * ASAR layout (as implemented by @electron/asar):
 *   [0..3]   UInt32LE  = 4
 *   [4..7]   UInt32LE  = size of the header pickle payload
 *   [8..11]  UInt32LE  = size of the header string payload (JSON) incl. padding
 *   [12..15] UInt32LE  = length of the JSON header string in bytes
 *   [16..]   JSON header (directory tree; files carry { offset: "<n>", size: <n> })
 *   data begins at 8 + readUInt32LE(4); a file's absolute start is that base + offset.
 *
 * Usage:
 *   node read-asar.mjs <archive> list <prefix> [--limit N]
 *   node read-asar.mjs <archive> read <entryPath> [--max-bytes N]
 *   node read-asar.mjs <archive> stat <entryPath>
 *
 * Exit codes: 0 ok, 1 usage/not-found error.
 */
import { open } from 'node:fs/promises';

function usage() {
  process.stderr.write(
    'usage: node read-asar.mjs <archive> list <prefix> [--limit N]\n' +
    '       node read-asar.mjs <archive> read <entryPath> [--max-bytes N]\n' +
    '       node read-asar.mjs <archive> stat <entryPath>\n'
  );
}

function parseArgs(argv) {
  const out = { positional: [], limit: 200, maxBytes: 2 * 1024 * 1024 };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--limit') { out.limit = Number(argv[++i]); continue; }
    if (a === '--max-bytes') { out.maxBytes = Number(argv[++i]); continue; }
    out.positional.push(a);
  }
  return out;
}

async function readHeader(handle) {
  const head = Buffer.alloc(16);
  await handle.read(head, 0, 16, 0);
  const jsonLength = head.readUInt32LE(12);
  const baseOffset = 8 + head.readUInt32LE(4);
  const jsonBuf = Buffer.alloc(jsonLength);
  await handle.read(jsonBuf, 0, jsonLength, 16);
  const json = JSON.parse(jsonBuf.toString('utf8'));
  return { header: json, baseOffset };
}

function walk(node, prefix, acc, limit) {
  if (acc.length >= limit) return;
  for (const [name, value] of Object.entries(node.files ?? {})) {
    const path = prefix === '' ? name : `${prefix}/${name}`;
    if (value.files !== undefined) {
      walk(value, path, acc, limit);
    } else {
      acc.push({ path, size: value.size, offset: value.offset, unpacked: value.unpacked === true });
      if (acc.length >= limit) return;
    }
  }
}

async function findByPath(handle, entryPath) {
  const { header, baseOffset } = await readHeader(handle);
  const parts = entryPath.split('/').filter((p) => p !== '');
  let node = header;
  for (const part of parts) {
    node = node.files?.[part];
    if (node === undefined) return undefined;
  }
  if (node.files !== undefined) return { directory: true, node, baseOffset };
  return { directory: false, node, baseOffset };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const [archive, command, target] = args.positional;
  if (archive === undefined || command === undefined || target === undefined) {
    usage();
    process.exit(1);
  }
  const handle = await open(archive, 'r');
  try {
    if (command === 'list') {
      const { header } = await readHeader(handle);
      const acc = [];
      walk(header, '', acc, args.limit);
      const needle = target.replace(/\\/g, '/').toLowerCase();
      const hits = acc.filter((e) => e.path.toLowerCase().includes(needle));
      process.stdout.write(`# entries scanned (capped at ${args.limit}): ${acc.length}\n`);
      process.stdout.write(`# matches for "${target}": ${hits.length}\n`);
      for (const h of hits) process.stdout.write(`${h.size}\t${h.path}\n`);
      return;
    }
    const found = await findByPath(handle, target);
    if (found === undefined) {
      process.stderr.write(`not found: ${target}\n`);
      process.exit(1);
    }
    if (found.directory) {
      const names = Object.keys(found.node.files ?? {});
      process.stdout.write(`directory ${target}: ${names.length} entries\n`);
      for (const n of names) process.stdout.write(`  ${n}\n`);
      return;
    }
    if (command === 'stat') {
      process.stdout.write(`path   : ${target}\n`);
      process.stdout.write(`size   : ${found.node.size}\n`);
      process.stdout.write(`offset : ${found.node.offset}\n`);
      process.stdout.write(`unpacked: ${found.node.unpacked === true}\n`);
      return;
    }
    if (command === 'read') {
      const size = found.node.size;
      const start = found.baseOffset + Number(found.node.offset);
      const take = Math.min(size, args.maxBytes);
      const buf = Buffer.alloc(take);
      await handle.read(buf, 0, take, start);
      process.stdout.write(buf.toString('utf8'));
      if (take < size) process.stdout.write(`\n# TRUNCATED at ${take} of ${size} bytes\n`);
      return;
    }
    usage();
    process.exit(1);
  } finally {
    await handle.close();
  }
}

main().catch((error) => {
  process.stderr.write(`error: ${error instanceof Error ? error.message : String(error)}\n`);
  process.exit(1);
});

// Extract selected cached package tarballs into a research directory.
// Usage: node extract-selected.mjs <inventory.json> <outRoot> <name> [<name>...]
import fs from 'node:fs'
import path from 'node:path'
import zlib from 'node:zlib'

const [invPath, outRoot, ...names] = process.argv.slice(2)
const rows = JSON.parse(fs.readFileSync(invPath, 'utf8'))

function extract(tgz, outDir) {
  const tar = zlib.gunzipSync(fs.readFileSync(tgz))
  let off = 0
  const s = (b, st, len) => b.subarray(st, st + len).toString('utf8').replace(/\0.*$/, '')
  const o = (b, st, len) => parseInt(s(b, st, len).trim() || '0', 8)
  while (off + 512 <= tar.length) {
    const h = tar.subarray(off, off + 512)
    if (h.every((b) => b === 0)) break
    const name = s(h, 0, 100)
    const prefix = s(h, 345, 155)
    const full = prefix ? `${prefix}/${name}` : name
    const size = o(h, 124, 12)
    const type = String.fromCharCode(h[156] || 48)
    const target = path.join(outDir, full)
    if (type === '5') fs.mkdirSync(target, { recursive: true })
    else if (type === '0' || type === '48' || type === '') {
      fs.mkdirSync(path.dirname(target), { recursive: true })
      fs.writeFileSync(target, tar.subarray(off + 512, off + 512 + size))
    }
    off += 512 + Math.ceil(size / 512) * 512
  }
}

for (const name of names) {
  for (const r of rows.filter((x) => x.name === name)) {
    const out = path.join(outRoot, name, r.version)
    if (!fs.existsSync(out)) extract(r.contentPath, out)
    console.log(`${name}@${r.version} -> ${out}`)
  }
}

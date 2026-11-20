// Read-only cross-version diff of cached @deepseek-ai package tarballs.
// Usage: node analyze-diff.mjs <inventory.json> <workDir> <outJson> <copyRoot> [v1] [v2]
import fs from 'node:fs'
import path from 'node:path'
import zlib from 'node:zlib'
import crypto from 'node:crypto'

const [invPath, workDir, outJson, copyRoot, argV1, argV2] = process.argv.slice(2)
const V1 = argV1 || '0.2.1-rc.2'
const V2 = argV2 || '0.2.2-rc.1'
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

function walkFiles(dir, base = dir, out = new Map()) {
  for (const d of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, d.name)
    if (d.isDirectory()) walkFiles(p, base, out)
    else if (d.isFile()) out.set(path.relative(base, p).replaceAll('\\', '/'), crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex'))
  }
  return out
}

const byName = new Map()
for (const r of rows) {
  if (!byName.has(r.name)) byName.set(r.name, {})
  byName.get(r.name)[r.version] = r
}

const result = { generatedAt: new Date().toISOString(), v1: V1, v2: V2, packages: [], addedPackages: [], removedPackages: [] }
for (const [name, versions] of byName) {
  const v1 = versions[V1]
  const v2 = versions[V2]
  if (!v1 && v2) { result.addedPackages.push(name); continue }
  if (v1 && !v2) { result.removedPackages.push(name); continue }
  if (!v1 || !v2) continue
  const d1 = path.join(workDir, name, V1)
  const d2 = path.join(workDir, name, V2)
  if (!fs.existsSync(d1)) extract(v1.contentPath, d1)
  if (!fs.existsSync(d2)) extract(v2.contentPath, d2)
  const f1 = walkFiles(d1)
  const f2 = walkFiles(d2)
  const added = [...f2.keys()].filter((k) => !f1.has(k))
  const removed = [...f1.keys()].filter((k) => !f2.has(k))
  const changed = [...f1.keys()].filter((k) => f2.has(k) && f1.get(k) !== f2.get(k))
  if (added.length || removed.length || changed.length) {
    result.packages.push({ name, added, removed, changed })
    if (copyRoot) {
      for (const ver of [V1, V2]) {
        const src = path.join(workDir, name, ver)
        const dst = path.join(copyRoot, name, ver)
        fs.mkdirSync(path.dirname(dst), { recursive: true })
        fs.cpSync(src, dst, { recursive: true })
      }
    }
  }
}
result.summary = {
  compared: [...byName.values()].filter((v) => v[V1] && v[V2]).length,
  addedPackages: result.addedPackages.length,
  removedPackages: result.removedPackages.length,
  changedPackages: result.packages.length,
  addedFiles: result.packages.reduce((a, p) => a + p.added.length, 0),
  removedFiles: result.packages.reduce((a, p) => a + p.removed.length, 0),
  changedFiles: result.packages.reduce((a, p) => a + p.changed.length, 0),
}
fs.writeFileSync(outJson, JSON.stringify(result, null, 2))
console.log(JSON.stringify(result.summary, null, 2))

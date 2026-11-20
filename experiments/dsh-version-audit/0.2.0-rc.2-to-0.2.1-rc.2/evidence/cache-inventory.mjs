// Read-only inventory of the local npm cache for @deepseek-ai packages at two versions.
// Usage: node cache-inventory.mjs <cacheDir> <outJson> <v1> <v2>
import fs from 'node:fs'
import path from 'node:path'

const [cacheDir, outJson, v1, v2] = process.argv.slice(2)
const indexDir = path.join(cacheDir, '_cacache', 'index-v5')
const entries = new Map()

function walk(dir) {
  for (const d of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, d.name)
    if (d.isDirectory()) walk(p)
    else {
      const text = fs.readFileSync(p, 'utf8')
      for (const line of text.split('\n')) {
        const i = line.indexOf('{"key"')
        if (i < 0) continue
        try {
          const o = JSON.parse(line.slice(i))
          if (!o.key || !o.integrity) continue
          entries.set(o.key, o)
        } catch {}
      }
    }
  }
}
walk(indexDir)

const re = /@deepseek-ai\/([^/]+)\/-\/\1-([^/]+)\.tgz$/
const rows = []
for (const [key, o] of entries) {
  const m = key.match(re)
  if (!m) continue
  const [, name, version] = m
  if (version !== v1 && version !== v2) continue
  const hex = Buffer.from(o.integrity.replace(/^sha512-/, ''), 'base64').toString('hex')
  const contentPath = path.join(cacheDir, '_cacache', 'content-v2', 'sha512', hex.slice(0, 2), hex.slice(2, 4), hex.slice(4))
  rows.push({ name, version, size: o.size, integrity: o.integrity, contentPath, exists: fs.existsSync(contentPath) })
}
rows.sort((a, b) => a.name.localeCompare(b.name) || a.version.localeCompare(b.version))
fs.writeFileSync(outJson, JSON.stringify(rows, null, 2))
const names = [...new Set(rows.map((r) => r.name))]
const both = names.filter((n) => rows.some((r) => r.name === n && r.version === v1) && rows.some((r) => r.name === n && r.version === v2))
const only1 = names.filter((n) => rows.some((r) => r.name === n && r.version === v1) && !both.includes(n))
const only2 = names.filter((n) => rows.some((r) => r.name === n && r.version === v2) && !both.includes(n))
console.log(JSON.stringify({ entries: rows.length, packages: names.length, both: both.length, onlyV1: only1, onlyV2: only2 }, null, 2))

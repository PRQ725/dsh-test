// Read-only decoder for DSH session.v4.jsonl.zstd (concatenated zstd frames).
// Usage: node decode-session.mjs <input.zstd> <output.jsonl.txt>
import fs from 'node:fs'
import zlib from 'node:zlib'

const [input, output] = process.argv.slice(2)
const buf = fs.readFileSync(input)
const magic = Buffer.from([0x28, 0xb5, 0x2f, 0xfd])
const offsets = []
let at = 0
while (true) {
  const i = buf.indexOf(magic, at)
  if (i < 0) break
  offsets.push(i)
  at = i + 4
}
const parts = []
let failed = 0
for (let k = 0; k < offsets.length; k++) {
  const start = offsets[k]
  const end = k + 1 < offsets.length ? offsets[k + 1] : buf.length
  try {
    parts.push(zlib.zstdDecompressSync(buf.subarray(start, end)).toString('utf8'))
  } catch (e) {
    failed++
  }
}
fs.writeFileSync(output, parts.join('\n'), 'utf8')
console.log(JSON.stringify({ frames: offsets.length, failed, chars: parts.join('\n').length }))

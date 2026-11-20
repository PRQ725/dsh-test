// Read-only extractor for npm cache tarballs (.tgz) into a research directory.
// Usage: node extract-tgz.mjs <input.tgz> <outputDir>
import fs from 'node:fs'
import path from 'node:path'
import zlib from 'node:zlib'

const [input, outDir] = process.argv.slice(2)
const tar = zlib.gunzipSync(fs.readFileSync(input))
let off = 0
let files = 0
function str(buf, start, len) {
  return buf.subarray(start, start + len).toString('utf8').replace(/\0.*$/, '')
}
function octal(buf, start, len) {
  return parseInt(str(buf, start, len).trim() || '0', 8)
}
while (off + 512 <= tar.length) {
  const header = tar.subarray(off, off + 512)
  if (header.every((b) => b === 0)) break
  const name = str(header, 0, 100)
  const prefix = str(header, 345, 155)
  const full = prefix ? `${prefix}/${name}` : name
  const size = octal(header, 124, 12)
  const type = String.fromCharCode(header[156] || 48)
  const target = path.join(outDir, full)
  if (type === '5') {
    fs.mkdirSync(target, { recursive: true })
  } else if (type === '0' || type === '48' || type === '') {
    fs.mkdirSync(path.dirname(target), { recursive: true })
    fs.writeFileSync(target, tar.subarray(off + 512, off + 512 + size))
    files++
  }
  off += 512 + Math.ceil(size / 512) * 512
}
console.log(JSON.stringify({ files, bytes: tar.length }))

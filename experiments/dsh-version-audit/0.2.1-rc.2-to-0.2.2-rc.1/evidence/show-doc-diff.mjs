// Print changed lines between two extracted README.md files (read-only).
// Usage: node show-doc-diff.mjs <workDir> <pkg1,pkg2,...> [v1] [v2] [file]
import fs from 'node:fs'
import path from 'node:path'

const [workDir, list, v1 = '0.2.1-rc.2', v2 = '0.2.2-rc.1', file = 'package/README.md'] = process.argv.slice(2)
const pkgs = list.split(',').map((s) => s.trim()).filter(Boolean)

function lcsDiff(a, b) {
  // simple LCS table for line diffs (files are small)
  const n = a.length, m = b.length
  const dp = Array.from({ length: n + 1 }, () => new Int32Array(m + 1))
  for (let i = n - 1; i >= 0; i--) for (let j = m - 1; j >= 0; j--) {
    dp[i][j] = a[i] === b[j] ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1])
  }
  const out = []
  let i = 0, j = 0
  while (i < n && j < m) {
    if (a[i] === b[j]) { i++; j++ }
    else if (dp[i + 1][j] >= dp[i][j + 1]) { out.push(['-', a[i]]); i++ }
    else { out.push(['+', b[j]]); j++ }
  }
  while (i < n) out.push(['-', a[i++]])
  while (j < m) out.push(['+', b[j++]])
  return out
}

for (const pkg of pkgs) {
  const p1 = path.join(workDir, pkg, v1, file)
  const p2 = path.join(workDir, pkg, v2, file)
  console.log(`\n===== ${pkg} :: ${file} =====`)
  if (!fs.existsSync(p1) || !fs.existsSync(p2)) { console.log('  (missing on one side)'); continue }
  const a = fs.readFileSync(p1, 'utf8').split(/\r?\n/)
  const b = fs.readFileSync(p2, 'utf8').split(/\r?\n/)
  const d = lcsDiff(a, b)
  const changed = d.filter(([s]) => s === '+' || s === '-')
  if (!changed.length) { console.log('  (identical)'); continue }
  console.log(`  changed lines: ${changed.length}`)
  let buf = []
  for (const [s, line] of d) {
    if (s === ' ') continue
    buf.push(`${s} ${line}`)
    if (buf.length >= 80) { console.log(buf.map((x) => '  ' + x).join('\n')); buf = []; console.log('  ...(truncated)'); break }
  }
  if (buf.length) console.log(buf.map((x) => '  ' + x).join('\n'))
}

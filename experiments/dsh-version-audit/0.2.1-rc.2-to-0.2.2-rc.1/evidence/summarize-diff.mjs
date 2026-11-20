// Summarize package-diff.json: separate version-bump noise from real changes.
// Usage: node summarize-diff.mjs <package-diff.json> <outJson>
import fs from 'node:fs'

const [diffPath, outPath] = process.argv.slice(2)
const diff = JSON.parse(fs.readFileSync(diffPath, 'utf8'))

const DOCISH = /(^|\/)(README|README\.zh|README\.i18n\.yaml|CHANGELOG|SKILL)\.md$|\.md$/i
const rows = []
for (const p of diff.packages) {
  const changedReal = p.changed.filter((f) => f !== 'package/package.json')
  const docs = changedReal.filter((f) => DOCISH.test(f))
  const code = changedReal.filter((f) => !DOCISH.test(f))
  if (!changedReal.length && !p.added.length && !p.removed.length) continue
  rows.push({
    name: p.name,
    added: p.added.length,
    removed: p.removed.length,
    changedReal: changedReal.length,
    docs,
    codeSample: code.slice(0, 8),
    addedSample: p.added.slice(0, 6),
    removedSample: p.removed.slice(0, 6),
  })
}
rows.sort((a, b) => b.changedReal + b.added + b.removed - (a.changedReal + a.added + a.removed))
const out = {
  generatedAt: new Date().toISOString(),
  v1: diff.v1,
  v2: diff.v2,
  summary: diff.summary,
  addedPackages: diff.addedPackages,
  removedPackages: diff.removedPackages,
  packagesWithRealChanges: rows.length,
  rows,
}
fs.writeFileSync(outPath, JSON.stringify(out, null, 2))
console.log(JSON.stringify({ packagesWithRealChanges: rows.length, top: rows.slice(0, 25).map((r) => `${r.name} (+${r.added}/-${r.removed}/~${r.changedReal})`) }, null, 2))

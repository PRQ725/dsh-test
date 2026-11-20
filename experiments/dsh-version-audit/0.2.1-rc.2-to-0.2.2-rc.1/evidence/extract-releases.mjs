// Extract official release records from a saved GitHub API page (read-only).
// Usage: node extract-releases.mjs <rawPage.txt> <outJson> <outMd>
import fs from 'node:fs'

const [src, outJson, outMd] = process.argv.slice(2)
const text = fs.readFileSync(src, 'utf8')
const start = text.indexOf('[')
const end = text.lastIndexOf(']')
if (start < 0 || end < 0) throw new Error('no JSON array found')
const releases = JSON.parse(text.slice(start, end + 1))

fs.writeFileSync(outJson, JSON.stringify(releases, null, 2))

const lines = []
lines.push('# Official release records — retrieved 2026-11-08')
lines.push('')
lines.push('Source: GitHub REST API, repository `deepseek-ai/deepseek-harness`')
lines.push('(`https://api.github.com/repos/deepseek-ai/deepseek-harness/releases?per_page=8`).')
lines.push('All entries are public, immutable, `prerelease: true`.')
lines.push('')
lines.push('> Scope note: the 0.2.2-rc.1 body explicitly says it summarizes changes **since')
lines.push('> `v0.2.1-rc.5`**. The audit baseline here is `0.2.1-rc.2`, so `rc.3`, `rc.4` and')
lines.push('> `rc.5` notes are required and are all included below.')
lines.push('')
for (const r of releases) {
  lines.push(`## ${r.tag_name}`)
  lines.push('')
  lines.push(`- published_at: \`${r.published_at}\``)
  lines.push(`- URL: ${r.html_url}`)
  lines.push(`- prerelease: ${r.prerelease} · immutable: ${r.immutable}`)
  lines.push('')
  lines.push('<details><summary>body (verbatim, English section retained)</summary>')
  lines.push('')
  lines.push('```text')
  lines.push(String(r.body || '').replace(/```/g, '~~~'))
  lines.push('```')
  lines.push('')
  lines.push('</details>')
  lines.push('')
}
fs.writeFileSync(outMd, lines.join('\n'))
console.log(JSON.stringify(releases.map((r) => ({ tag: r.tag_name, published: r.published_at, bodyChars: String(r.body || '').length })), null, 2))

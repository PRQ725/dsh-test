// Read-only extraction of runtime facts from a decoded DSH session JSONL.
// Usage: node extract-session-facts.mjs <session.jsonl.txt> <out.json>
import fs from 'node:fs'

const [input, output] = process.argv.slice(2)
const lines = fs.readFileSync(input, 'utf8').split(/\r?\n/).filter(Boolean)
const facts = { events: lines.length, types: {}, session: null, permissions: {}, goal: null, plan: null, model: null, tools: [], request: null }
for (const line of lines) {
  const o = JSON.parse(line)
  facts.types[o.type] = (facts.types[o.type] ?? 0) + 1
  if (o.type === 'session') facts.session = { id: o.id, version: o.version, cwd: o.cwd, createdAt: o.createdAt, agentPreset: o.agentPreset }
  if (o.type === 'permission/preset') facts.permissions.preset = o.data
  if (o.type === 'sandbox/mode') facts.permissions.sandbox = o.data
  if (o.type === 'approval/policy') facts.permissions.approval = o.data
  if (o.type === 'request/header') {
    facts.model = o.data.header.config
    facts.tools = o.data.header.tools.map((t) => t.name)
  }
  if (o.type === 'request/context') facts.request = { provider: o.data.provider, model: o.data.model, contextWindow: o.data.contextWindow, systemPromptUpdate: o.data.systemPromptUpdate }
  if (o.type === 'goal/change') facts.goal = o.data
}
fs.writeFileSync(output, JSON.stringify(facts, null, 2))
console.log(JSON.stringify({ events: facts.events, model: facts.model, permissions: facts.permissions, tools: facts.tools.length, goal: facts.goal }))

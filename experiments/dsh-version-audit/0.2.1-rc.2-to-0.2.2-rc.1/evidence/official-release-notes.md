# Official release records — retrieved 2026-11-08

Source: GitHub REST API, repository `deepseek-ai/deepseek-harness`
(`https://api.github.com/repos/deepseek-ai/deepseek-harness/releases?per_page=8`).
All entries are public, immutable, `prerelease: true`.

> **Scope note.** The `dsh-v0.2.2-rc.1` body says it "summarizes the major user- and
> developer-facing changes **since `v0.2.1-rc.5`**". This audit's baseline is
> **`0.2.1-rc.2`**, so `rc.3`, `rc.4` and `rc.5` are also required and are recorded below.
> Reading only the newest changelog would silently drop the rc.3–rc.5 range.

| tag | published_at | notes-affecting? |
|---|---|---|
| `dsh-v0.2.1-rc.3` | 2026-10-23T15:26:39Z | UI only |
| `dsh-v0.2.1-rc.4` | 2026-10-28T02:49:58Z | one fix |
| `dsh-v0.2.1-rc.5` | 2026-10-30T02:12:26Z | UI only |
| `dsh-v0.2.2-rc.1` | 2026-11-04T13:07:14Z | **major** |

(Alpha tags `dsh-v0.2.2-alpha.2` 2026-10-28 and `dsh-v0.2.2-alpha.3` 2026-11-03 exist and
contain the same structural changes that landed in rc.1; they are alpha-line records and are
not used as the acceptance baseline here.)

## dsh-v0.2.1-rc.3 — 2026-10-23

- Improvements: "Add More menus to the left sidebar, conversation views, and right sidebar for
  browsing and creating plugins." · "Fix New Session losing an unsent draft after switching
  sessions."
- Chores: "The DeepSeek API key adapter now updates its model list the same way as account
  sign-in."
- → No effect on this knowledge base.

## dsh-v0.2.1-rc.4 — 2026-10-28

- Bug Fixes: "Fix diagnostics leaking into stdout in ACP mode."
- → No effect on this knowledge base.

## dsh-v0.2.1-rc.5 — 2026-10-30

- Improvements: "Improve how thinking content is displayed in conversations."
- → No effect on this knowledge base.

## dsh-v0.2.2-rc.1 — 2026-11-04 (verbatim English bullets, selected)

Format: `dsh` release notes are bilingual; the English section is quoted verbatim. Bullets
marked ★ are the ones that change this knowledge base.

### Chores / breaking changes

- ★ "Raise the minimum supported Node.js version to 24.9. Upgrade older Node.js runtimes before
  upgrading DSH."
- ★ "Synchronize Cordis Core to 4.1.0, Loader to 1.1.0, and Include to 1.1.0, unifying
  configuration access, entry changes, and persistence behavior."
- ★ "Split native and PTC tool execution into Agent-scoped plugins; enable PTC through
  configuration overlays and migrate `tools.mode` and `DSH_TOOLS_MODE` usage."
- ★ "Activate tools conditionally per step with consistent model declarations, PTC bindings, and
  execution admission. Plugins must migrate `tools.resolve`/`executable` and prompt-assembly
  integration."
- ★ "Disable read-before-write and external-change checks by default while retaining sandbox
  limits and Review. Profiles requiring the previous checks can explicitly restore the
  observation policy." *(appeared in alpha.3; the rc.1 body carries the same change)*
- ★ "Add `apply_patch`, disabled by default, to create, edit, delete, and move multiple files in
  one call, with changes available in Review."
- ★ "Migrate custom plugins to asynchronous retained Session-projection handles. Legacy
  registration disposers and key-based reads retain compatibility with deprecation notices;
  approval-state recovery requires the composition to provide `sessionProjections` and await
  service activation."
- ★ "Add independent Session APIs to read snapshots and continuously subscribe to Session event
  logs, execution state, and event-projection data."
- ★ "Capture the step model before prompt assembly and pre-step and retain it through retries;
  plugins should select through `agent.model` rather than changing routes in `agent/request`."
- ★ "Official bundle lists are now exported by `@deepseek-ai/dsh-official-bundles`; custom
  integrations must update imports from app-boot."
- ★ "Allow whole-unit JSON and SQLite storage to read explicitly declared compatible older
  versions and write in the current version format."
- "Move the PTC Node control channel to birpc; upgrade self-deployed bootstraps and SSH helpers
  together, with SSH protocol increasing from 2 to 3."
- "Report caller-cancelled `run_code` calls in PTC Mode as `ABORTED` rather than
  `CODE_RUN_FAILED`."
- "Add a VM Script mode to Node PTC with top-level await, dynamic imports, and expression
  results, plus optional state retention across calls."
- "Rename Custom plugin markets to Custom plugin indexes."
- "Keep Ralph loop and Session search bundled, but no longer list them among experimental
  plugins."
- "Upgrade pi-ai to 1.3.0 ...; malformed completed tool arguments fail the response before any
  tool executes."
- "Default undeclared custom-model capacities to decimal 1M context and 128K output."

### Bug fixes relevant to long-running behaviour

- ★ "Budget global and project AGENTS.md chains separately so project instructions do not evict
  global guidance; messages containing both chains can use up to twice `maxBytes`."
- ★ "Resume blocked goals from the Web goal bar; goals that have exhausted their round limit
  still require a higher limit first."
- ★ "Approval messages explicitly state whether user approval is requested, avoiding ambiguity
  around the never policy."
- ★ "Keep skills from healthy roots available when another skill root cannot be read, and report
  incomplete discovery."
- "Reuse existing context-prefix caches for new model requests when the system prompt is
  unchanged, avoiding unnecessary cache invalidation."
- "Fix delegation tools being temporarily unavailable after preset round trips and apply the
  current Agent's tool restrictions to delegation."
- "Tell the model to continue after a skipped question without asking it again or treating the
  skip as permission."
- "Fix tool calls failing on unambiguous optional arguments by accepting an empty grep include."
- "Expand leading `~` or `~/` in local file tools to the Host home directory while preserving
  literal tildes elsewhere in paths."
- "Fix restricted sandbox commands failing to start when DSH runs as administrator or in Windows
  Sandbox, while preserving file-write and deletion restrictions."
- "Preserve saved Auto permission and approval policy during application shutdown instead of
  unintentionally switching to Full access."

### Web / UI

- ★ "Add Japanese, Spanish, French, German, Russian, and Brazilian Portuguese interface text and
  locale configuration."
- ★ "Web supports `--public-url` ...; Web supports binding to a specified IPv4/IPv6 address and
  native HTTPS listening through `--tls-cert` and `--tls-key`."
- ★ "Enable WebSocket compression for remote connections by default ...; disable it with
  `websocketCompression`."
- ★ "Allow Web Fetch to access non-public addresses for proxies and internal networks;
  deployments must restrict network access separately."
- "Insert chat text as quotes in the composer"; "Copy the complete conversation history as
  Markdown"; "Keep a directory tree in file previews"; "Unify mouse and keyboard context menus";
  "Show rich-text plugin details in the plugin manager"; "Support updating third-party plugin
  packages".

### Experimental additions (explicitly experimental)

- `subagent_oar` tool plugin — delegate independent tasks to local Codex or Claude CLIs.
- Personalized recommendations (official-plugin activation / page-creation cards).
- Developer tools — Statistics (per-turn/step context, cache, model, tool timing).
- Change requests and worktrees (run Sessions in separate Git worktrees, browse diffs).
- Auto review in Headless.
- Liveshare (share a Session through the normal browser UI; **the default Web profile excludes
  it** — `dsh-experimental-liveshare` README).

## Limits of this evidence

- Release notes are **OFFICIAL DOCUMENTED CHANGE**, not a proof of behaviour in this
  installation. Where this audit says `[FACT]` about the install, the companion
  `package-diff.json`, `diff-summary.json` and the extracted package READMEs provide
  SOURCE-CODE CONFIRMED evidence.
- The API page capture used for this file was truncated by the tool's output limit; the rc.3 /
  rc.4 / rc.5 / rc.1 bodies above were transcribed from the returned JSON before truncation.
  A full machine copy was not preserved — see `EVIDENCE-INDEX`-style note in the audit README.
- No claim here about model quality or success-rate change.

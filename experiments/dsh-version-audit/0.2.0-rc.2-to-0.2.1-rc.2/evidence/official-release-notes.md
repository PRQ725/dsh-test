# Official release records — retrieved 2026-10-19

Source: GitHub REST API, repository `deepseek-ai/deepseek-harness`
(`https://api.github.com/repos/deepseek-ai/deepseek-harness/releases?per_page=5`).
Both releases are public, immutable, prerelease: true.

## dsh-v0.2.1-rc.2

- tag: `dsh-v0.2.1-rc.2`
- published_at: `2026-10-17T08:16:33Z`
- URL: https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.1-rc.2
- Body (verbatim, English section):
  - "Add support for DeepSeek-V4.1-Flash-1017. by @LegGasai"
  - "Add support for DeepSeek Search and Fetch APIs, which can be enabled in Web Search settings.
    by @yudshj, @LegGasai"
- Body (verbatim, Chinese section):
  - "适配 DeepSeek-V4.1-Flash-1017 上线 @LegGasai"
  - "适配 DeepSeek Search 与 Fetch API，可在网页搜索设置中开启 @yudshj, @LegGasai"

This is the **entire** rc.2 delta over rc.1. Everything else in the 0.2.0→0.2.1 range came in rc.1.

## dsh-v0.2.1-rc.1

- tag: `dsh-v0.2.1-rc.1`
- published_at: `2026-10-17T05:22:10Z`
- URL: https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.1-rc.1
- Body: "summarizes the major user- and developer-facing changes since v0.2.0-rc.2".
- Change bullets relevant to this audit (verbatim English):
  - "Add the working_directory tool and TypeScript/Python SDK APIs for reading and changing a
    session's working directory."
  - "Improve subagent delegation and waiting guidance: announce delegation depth limits in advance
    and wait for running subtasks before starting another goal round."
  - "Fix new messages remaining queued after stopping, resuming, and stopping a goal-driven task
    again."
  - "End the current turn and wait for user feedback when a plan review is dismissed to request
    changes, avoiding an extra model call."
  - "Remove runtime invariant plugins and package `./invariant` exports."
  - "Remove the both mixed tool-presentation mode, leaving native and ptc."
  - "Remove the per-row dshHome setting from agent-instructions and resolve instruction directories
    from the process DSH_HOME or its default."
  - "Update third-party model support and rename the Azure provider to azure."
  - "Change API key precedence: Web and Desktop prioritize saved credentials. Headless uses
    environment variables and .env files by default, without reading saved keys."
  - "Unify subagent execution and completion notifications, with tools returning child IDs
    immediately."
  - "Add `--public-url` ...", "Allow Web to bind to a specific IPv4/IPv6 address..."
  - "Improve gateway authorization and connection management with caller-based resource access
    control..."

## Limits of this evidence

- These are **release notes**, i.e. OFFICIAL DOCUMENTED CHANGE. They do not by themselves prove a
  behaviour in this installation; the companion `package-diff.json` plus extracted package sources
  provide SOURCE-CODE CONFIRMED evidence for the items marked as such.
- The notes do not state that the DeepSeek-V4.1-Flash-1017 addition changes agent success rates,
  and no controlled experiment exists here. Any performance claim would be INFERENCE or UNKNOWN.

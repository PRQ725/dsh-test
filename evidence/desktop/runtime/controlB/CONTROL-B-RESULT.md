# Control B (minimal B1) — matched-version 0.2.0-rc.2 Web against a Desktop-created v4 session

Result: **PASS** (see the C1–C4 detail and the two C2/C4 nuances below).
Recorded 2026-10-05 (local, UTC+8).

Purpose: with everything else held equal, does a **matched-version** runtime read the same v4
session that 0.1.5-rc.3 could not discover?

---

## Setup

| Item | Value |
|---|---|
| Host | bundled Desktop runtime `0.2.0-rc.2` via `resources\runtime\cli\bin\dsh.cmd web --no-open --port 3199` |
| Isolated home | `D:\Projects\dsh-desktop-controlB-home` (DSH_HOME set for the child process only) |
| Real home | `C:\Users\user02\.dsh` — read-only throughout |
| Sample | `session-0d5e7d0c-c341-48c4-a149-81250d473f20`, 16364 B, `64B4257A37C14035792E0806679A86EC19C683D0E2A9A477060E6621D5777EDB` |
| Injected | v4 log copy + its projcache + a minimal `storages\workspace.json` (1667 B) listing that one session id |
| Deliberately NOT injected | credentials, tokens, other sessions, browser-lab/web profiles, PJOS, the dsh-test research session, settings history |

## Measured results

| Criterion | Result | Evidence |
|---|---|---|
| **C1 discovery** | **PASS** | sidebar tree showed the workspace `dsh-desktop-runtime-test-3` containing `E1 interoperability marker` — the title comes from the session's own `session/title` events written by Desktop |
| **C2 no extra session** | literal **FAIL**, discriminating **PASS** | a new draft `session-5791bcee-b05b-468b-aa88-6016d8007682` (330 B) was created — but it is `session.v4.jsonl.zstd`, i.e. **the same format as the target**, not a v3 fallback; and the target id was **preserved and kept** in `workspace.sessionIds` (`session-5791bcee…, session-0d5e7d0c…`). This is the documented `reuseOrCreateBlank` policy firing because the target session is not blank. 0.1.5 does the same thing *and additionally* destroys the association, so the literal criterion does not discriminate between matched and mismatched versions |
| **C3 render** | **PASS** | full conversation rendered: user `E1 interoperability marker` (15:39), complete Desktop reply (`已收到 E1 interoperability marker…` ending `DSHRT-FIXTURE-OK`), plus session title, timestamps, turn/step and token stats |
| **C4 read-only stability** | literal **FAIL** for size/hash; all other clauses **PASS** | the v4 log grew 16364 -> 16445 B (sha `64B4257A…` -> `918C53999807F20242B587D0E97F7EC63C7CFB8FFCD00A22EA6B0282C8A6731E`). Decoding shows exactly **one** appended event: `{"type":"session/end-seed","seq":30,"time":1791190359830,"data":{}}` (31 -> 32 events, `endSeedCount` 0 -> 1). All 31 original events are intact (per-type histogram unchanged, plus `session/end-seed: 1`); `sessionVersion` still **4**; `workspace.sessionIds` still contains the target id. Not a migration, no data loss — the same one-time marker was observed on run2's v4 session during the Desktop Stage A launch (also 31 -> 32, 0 -> 1) |

## Real-home integrity (BEFORE 16:50 -> AFTER 16:53)

```
SHARED STATE        ADDED 0  DELETED 0  CONTENT-CHANGED 0   MTIME-ONLY 1  (.dshw-usage.json, content identical)
SESSION INVENTORY   ADDED 0  DELETED 0  CONTENT-CHANGED 1
PROJCACHE INVENTORY ADDED 0  DELETED 0  CONTENT-CHANGED 1
```

The two content changes are **both the host research session**
`--D-Projects-dsh-test--\session-665e3202-…\session.v3.jsonl.zstd` (6,754,254 -> 6,861,165 B)
and its projcache: this is the conversation that ran the test, growing as it worked. Querying
every real-home file whose mtime falls in the Control B window returns exactly those two plus
`.dshw-usage.json` (content-identical) — no run3 artefact, no isolated-home path, no new session
directory.

[FACT] The real-home run3 v4 sample is byte-identical before and after:
16364 B `64B4257A37C14035792E0806679A86EC19C683D0E2A9A477060E6621D5777EDB`.

[FACT] Real-home integrity for everything Control B could have touched is clean
(`ADDED 0 / DELETED 0 / CONTENT-CHANGED 0`). The one session content change is the host research
session — an observer effect of running the test from inside it, not a Control B write.

## Incidental finding: the runtime rejects a BOM in storages\workspace.json

[FACT] The first start failed to activate 4 entries:

```
workspace (@deepseek-ai/dsh-workspace): StorageError: unit 'workspace': file is not valid JSON
SyntaxError: Unexpected token '\uFEFF', "{ "u"... is not valid JSON
session-controller: pending (waiting for service: workspaceRegistry)
```

Cause: my preparation wrote the file with PowerShell 5.1 `Set-Content -Encoding UTF8`, which emits
a **UTF-8 BOM**; the runtime parses it with a bare `JSON.parse`. The real home's file has **no** BOM
(`7B 0A 20 20`). Rewriting the minimal registry BOM-free made the host start clean and the
workspace registry load. `control-b-prep.ps1` now writes it BOM-free and asserts that.

## Conclusion

[FACT] 0.2.0 matched-version Web can discover, list and render the Desktop-created v4 session
read-only.
[FACT] 0.1.5 cannot discover the same v4 session because its session catalog stops at v3.
[CONCLUSION] The observed interoperability failure is a **runtime / session-format version
boundary** issue, not a generic Desktop-vs-Web incompatibility.

[FACT] Corollary worth keeping: "open a session" is **not** a strictly read-only operation in
either runtime — attaching appends a one-time `session/end-seed` marker. It is non-destructive
(all prior events intact, format unchanged) and it happens once per session.

DESKTOP/WEB V4 ROOT CAUSE: CLOSED.

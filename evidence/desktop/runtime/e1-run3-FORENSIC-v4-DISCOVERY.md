# E1 run3 forensic: why the old Web 0.1.5 does not discover the Desktop-created v4 session

Read-only source archaeology. Recorded 2026-10-05 (local, UTC+8).
Subjects: global `dsh 0.1.5-rc.3` and the bundled Desktop runtime `0.2.0-rc.2`.
Tool used to read the bundled runtime without extracting it: `scripts\read-asar.mjs`
(parses the ASAR header and reads individual entries out of
`...\Programs\DeepSeek Harness\resources\app.asar`).

Evidence grades: [FACT] source or captured evidence proves it; [INFERENCE] reasoned from
source/timeline; [UNKNOWN] not proven.

---

## 0. The observation to explain

[FACT] run3 Stage A: Desktop 0.2.0-rc.2 created `session-0d5e7d0c-c341-48c4-a149-81250d473f20`,
`session.v4.jsonl.zstd`, 16364 B, 31 events, last event `turn/end`, in workspace
`D:\Projects\dsh-desktop-runtime-test-3`.
[FACT] run3 Stage B: the human opened the same workspace in the old Web 0.1.5-rc.3. The
workspace was visible, **the v4 session was not**, so it could not be opened, rendered or
continued. No continuation message was sent; Stage C did not run.
[FACT] Stage B also produced a new `session-f2bc40b9-0196-4d85-b573-2468122f5ead`,
`session.v3.jsonl.zstd`, 333 B, 4 events (`session`, `permission/preset`, `sandbox/mode`,
`approval/policy`), no `turn/start`.
[FACT] The v4 session was **not** modified by 0.1.5: 16364 B / `64B4257A37C1…` at capture A
and 16364 B at capture B, absent from both compare diffs, `endSeedCount 0`,
`endsWithEndSeed false`, `isSeeded false`.
[FACT] The v4 session is still present on disk and is still found by the E1 evidence tooling,
whose matcher is version-agnostic: `^session\.v\d+\.jsonl\.zstd$`
(`capture-shared-state.ps1:151`, `detect-runtime-test-session.ps1:80`).

## A. 0.1.5 session discovery entry point

The chain, host-side, top to bottom:

| Layer | File | Symbol |
|---|---|---|
| UI | `@deepseek-ai/dsh-client-ui-workspace/lib/client.js` | `openWorkspace()` -> `connectWorkspace()` |
| host API | `@deepseek-ai/dsh-api-session-controller/lib/types/list.js` | `ApiSessionList.list()` -> `this.ctx.sessionQuery.listSessions(signal)` |
| query | `@deepseek-ai/dsh-session-query/lib/index.js` | `SessionCorpus.listSessions()` -> `listPersisted(persistence)` (line 282) |
| persistence contract | `@deepseek-ai/dsh-session-persistence` | `SessionPersistence.list` |
| **JSONL backend** | `@deepseek-ai/dsh-session-persistence-jsonl/lib/index.js` | `JsonlSessionPersistence.list()` (line 2454) -> **`listArtifacts()`** (line 2858) |

`listArtifacts()` walks: `listProjectDirs()` (`readdir(root)`) -> `listSessionDirs(project)`
(`readdir(project)`) -> `resolveGenerationInDirectory(dir)` (`readdir(sessionDir)`) ->
`readGenerationHeader(selected)`.

`ApiSessionList.list()` additionally drops any record whose `header.cwd` is `undefined`
(`if (record.header.cwd === undefined) continue;`). That filter is not what matters here —
the v4 record never reaches it — but it is a second silent-omission point worth knowing.

## B. Session filename / version matching rules

[FACT] Canonical basename (`dsh-session-format/lib/index.js:464`):

```js
const CANONICAL_LOG_FILENAME = /^session(?:\.v([1-9][0-9]*))?\.jsonl$/u;
function sessionFormatLogFilename(version) {
    const generation = sessionFormatVersion(version, "Session log generation version");
    return generation === 0 ? "session.jsonl" : `session.v${generation}.jsonl`;
}
```

[FACT] The JSONL backend appends the compression suffix and strips it before parsing
(`dsh-session-persistence-jsonl/lib/index.js:746-775`): `.jsonl.zstd` for zstd,
`.jsonl` for plaintext. `parseGenerationLogFilename(name, compression)` removes the suffix
and delegates to `parseSessionFormatLogFilename`.

**Therefore the matcher is version-AGNOSTIC.** `session.v4.jsonl.zstd` is a canonical v4
generation name and parses to `4`. There is no allow-list and no upper bound in the
filename layer: `v1` … `v999` all parse. `session.v0.jsonl` is deliberately non-canonical
(v0 keeps the bare `session.jsonl` name).

[FACT] `resolveGenerationInDirectory()` (line 3161) collects **every** canonical generation
present and selects the numerically **highest**:

```js
const latest = generations.sort((left, right) => right.version - left.version)[0];
```

`listSessionDirs()` (line 3268) rejects only the obsolete **flat-file** layout (a
`*.jsonl` / `*.jsonl.zstd` file sitting directly in the project directory); it does not
inspect versions.

## C. Can 0.1.5 scan the v4 file? — YES (filesystem level)

[FACT by source] `resolveGenerationInDirectory()` returns
`{ sourcePath: "...\session-0d5e7d0c-...\session.v4.jsonl.zstd", sourceVersion: 4, currentPath: "...\session.v3.jsonl.zstd" }`.
Nothing before this point filters on version.

[FACT] This is corroborated by the E1 tooling, which lists the v4 file with a plain
`^session\.v\d+\.jsonl\.zstd$` match and produced a full 31-event decode of it
(`session-summaries.jsonl`: `"sessionVersion":4`).

So proposition **A (filesystem existence)** and the *first half* of proposition **B (host
discovery)** hold: the host's enumerator does reach the file.

## D. Does 0.1.5 have a v4 codec/parser? — NO

[FACT] `@deepseek-ai/dsh-session/lib/types/types.js:54` and `lib/index.js:56`:
`export const SESSION_FORMAT_VERSION = 3;`

[FACT] `dsh-session-format-catalog/lib/index.js` (0.1.5) constructs:

```js
const sessionFormatCatalog = createSessionFormatCatalog({
    currentVersion: 3,
    codecs: [releasedV0..., releasedV1..., releasedV2..., releasedV3...],
    currentEncoder: releasedV3SessionFormatCodec,
    migrations: [sessionFormatV0ToV1, sessionFormatV1ToV2, sessionFormatV2ToV3],
    ...
});
```

[FACT] `createSessionFormatCatalog()` (`dsh-session-format/lib/index.js:284-293`) requires a
codec for **every** version `0..currentVersion` and **rejects any codec above it**. A v4
codec cannot even be registered in this build.

[FACT] `readHeader()` (line 294) refuses anything newer:

```js
if (storedVersion > chain.currentVersion) return Object.freeze({
    status: "unsupported",
    storedVersion,
    targetVersion: chain.currentVersion,
    reason: `stored Session uses newer format v${storedVersion}; this build writes v${chain.currentVersion}`
});
```

[FACT] `@deepseek-ai/dsh-session-format-v3-to-v4` is **not installed** in the global
0.1.5 tree (only `...-v0-to-v1`, `...-v1-to-v2`, `...-v2-to-v3` are present).

[FACT] The user-facing refusal text is prepared in
`dsh-session-persistence/lib/index.js:137`:

```
session "<id>" uses log format v4, but this harness reads only v3: the log was written by a
newer harness — upgrade the harness to open it
```

## E. Which layer fails

**FAILURE LAYER: HOST INDEX (persistence session listing).**

[FACT] `listArtifacts()` (0.1.5, line 2858):

```js
for (const dir of await this.listSessionDirs(project, signal)) {
    const selected = await this.resolveGenerationInDirectory(dir, signal);   // finds v4
    if (selected === void 0) continue;
    let header;
    try {
        header = await this.readGenerationHeader(selected, void 0, signal);  // throws for v4
    } catch (error) {
        if (error instanceof SessionFormatUnsupportedError) continue;         // <== SILENTLY DROPPED
        throw error;
    }
    if (header === void 0) continue;
    ...
    artifacts.push({ header, path: selected.sourcePath });
}
```

and `readGenerationHeader()` (line 2890) throws `SessionFormatUnsupportedError` when
`result.status === "unsupported"` — i.e. for the v4 header, and the loop swallows it.

So the sequence is:
1. **filesystem discovery: SUCCEEDS** — the v4 file is enumerated and parsed as a generation.
2. **host index: DROPS IT** — the header read is refused by the v3-only catalog and the
   listing loop `continue`s. The session never appears in `persistence.list()`, hence never in
   `sessionQuery.listSessions()`, hence never in the Web client's session list.
3. **UI surfacing: faithfully renders an already-filtered list.** The sidebar is not the
   cause; it never receives the row. [FACT] `dsh-client-ui-workspace` groups rows by
   `workspace.sessionIds`, and the v4 id is not among them (see J).
4. **loader: also refuses, but is never reached through the UI.** A direct by-id open would
   take `requireStoredLog()` (line 2483), which explicitly branches on
   `selected.sourceVersion > SESSION_FORMAT_VERSION` and throws
   `SessionFormatUnsupportedError` with the "upgrade the harness" text. So there is a second,
   independent refusal gate behind the listing — it simply never fires from the UI because the
   row is not offered.

[FACT] On question 6 ("does projcache take part in listing?"): **no, not in enumeration.**
The listing comes only from persistence; the projection cache is consulted afterwards to
*decorate* rows already present — `ApiSessionList.projectionsFor()` calls
`sessionProjectionCache.cachedSnapshot(header, …)` / `cachedPredecessorTitle(…)` for a header
that is already in the list, and a cache failure is caught and logged
(`api-session.list: projection column for "<id>" failed; serving the row without it`).
The trial agrees: 0.1.5 did not touch the v4 session's projcache
(A->B PROJCACHE INVENTORY added only `session-f2bc40b9.json`, changed only
`session-665e3202.json`).

[FACT] On question 7 ("does the workspace registry record sessions?"): it records
**workspace -> sessionIds** (see J). It is a second place where ids live, and it is not where
the v4 session is filtered, but it is affected by the outcome.

## F. Why a new blank v3 session appears

[FACT] `dsh-client-ui-workspace/lib/client.js` (0.1.5, lines 44-72):

```js
async connectWorkspace(workspaceId) {
    const workspace = ...find(item => item.workspaceId === workspaceId);
    const inflight = this.connecting.get(workspaceId);
    if (inflight !== undefined) return inflight;
    const archived = this.workspaces.list.getSnapshot().archivedSessionIds;
    const sessions = this.sessions.list.getSnapshot();
    for (const id of sessions.ids) {
        const summary = sessions.byId[id];
        if (summary !== undefined && summary.blank && summary.cwd === workspace.path
            && workspace.sessionIds.includes(summary.id) && !archived.includes(summary.id)) return summary.id;
    }
    const attempt = this.sessions.create({ workspaceId }).finally(...);   // <== CREATE
    this.connecting.set(workspaceId, attempt);
    return attempt;
}

async openWorkspace(workspaceId, beforeOpen) {
    ...
    const sessionId = await this.connectWorkspace(workspaceId);   // called on workspace open
    ...
    this.openSession(sessionId);
}
```

Causal chain, each link source-proven:

1. Opening a workspace calls `connectWorkspace`.
2. It looks for an existing **blank** session in that workspace, iterating the **client's
   session list** — which is the host listing from §A.
3. The v4 session is absent from that list (§E), and it is not blank anyway (§A/F note).
4. No blank session satisfies the predicate -> it calls `sessions.create({ workspaceId })`.
5. The host materialises the new session **in its own current format**: a synthesized header
   is stamped `version: SESSION_FORMAT_VERSION` (`dsh-session/lib/types/index.js:80`, `= 3`),
   and the `Session` constructor refuses any header whose version is not 3
   (`session header version must be 3, got …`, line 31). The catalog's `currentEncoder` is
   `releasedV3SessionFormatCodec`, so the bytes written are v3.
6. Observed result matches exactly: 4 bootstrap events, no `turn/start`.

[FACT] Why the new session is displayed as "New Session": `ApiSessionList` registers a
`sessionListMetadata` projection whose `init` is `{ blank: true, … }` and whose `apply` is
`blank = state.blank && event.type !== 'turn/start'`. With no `turn/start` the session stays
`blank`, and the client renders blank rows with the localized `session.new` label.

**Two reasons the v4 session is not reused** (both must be stated; the second is independent
of the first): (i) it is not in the visible session list at all; (ii) even if it were, the
reuse predicate requires `summary.blank === true`, and a session with a completed turn is not
blank. So "reuse the existing session as the draft" was never a possibility for a v4 session
with real content, even under a matched runtime.

[INFERENCE] The 16:00:07 timestamp of the blank session is the moment the human opened the
workspace in the Web UI; the client gesture is not independently logged.

## G. Matched archaeology: 0.2.0-rc.2 bundled runtime

[FACT] `dsh-session/lib/types/types.js` in the bundle: `export const SESSION_FORMAT_VERSION = 4;`

[FACT] Bundled `dsh-session-format-catalog/lib/index.js`:

```js
const sessionFormatCatalogOptions = {
    currentVersion: 4,
    codecs: [releasedV0…, releasedV1…, releasedV2…, releasedV3…, releasedV4SessionFormatCodec],
    currentEncoder: releasedV4SessionFormatCodec,
    migrations: [sessionFormatV0ToV1, sessionFormatV1ToV2, sessionFormatV2ToV3, sessionFormatV3ToV4],
    ...
};
```

[FACT] `@deepseek-ai/dsh-session-format-v3-to-v4/lib/index.js` **is present** in the bundle
(73014 B). It exports `createSessionFormatV3ToV4`, `releasedV4SessionFormatCodec`,
`assertReleasedV4Header`, `restoreReleasedV4Artifact`.

[FACT] The bundle also ships a **v3-only** catalog for historical child identity:

```js
const historicalSessionFormatCatalog = createSessionFormatCatalog({
    currentVersion: 3,
    codecs: [v0, v1, v2, v3],
    currentEncoder: releasedV3SessionFormatCodec,
    migrations: [v0ToV1, v1ToV2, v2ToV3],
    restoreCurrent: artifact => restoreReleasedV3Artifact(artifact, RELEASED_V3_EVENT_TYPES),
    ...
});
```

i.e. 0.1.5's main capability survives inside 0.2.0 as a sub-capability used when reading
historical children without recursively opening current sessions.

[FACT] Bundled `dsh-session-persistence-jsonl` `listArtifacts()` has the **same shape and the
same silent-skip design**, now over `listGenerations(signal)`:

```js
try { header = await this.readGenerationHeader(selected, void 0, signal); }
catch (error) {
    if (error instanceof SessionFormatUnsupportedError || error instanceof SessionPersistenceCorruptionError) continue;
    throw error;
}
```

With `SESSION_FORMAT_VERSION = 4`, a v4 header is `status: "current"` and is **not** refused.

[FACT] Bundled `dsh-client-ui-workspace` keeps the same reuse-or-create policy, refactored:

```js
reuseOrCreateBlank(workspace) {
    ...
    for (const id of sessions.ids) {
        const summary = sessions.byId[id];
        if (summary === undefined || !summary.blank || summary.cwd !== workspace.path
            || !workspace.sessionIds.includes(id) || archived.includes(id)) continue;
        return this.reuseBlank(workspace.workspaceId, id);
    }
    return this.sessions.create({ workspaceId: workspace.workspaceId });
}
async reuseBlank(workspaceId, sessionId) {
    try { return await this.sessions.create({ workspaceId, sessionId }); }
    catch (error) {
        if (sessionCreateErrorFrom(error)?.rpcError.code !== "session/writer-held") throw error;
        return this.sessions.create({ workspaceId });
    }
}
```

## H. Minimal 0.1.5 vs 0.2.0 session-compatibility diff

| Aspect | 0.1.5-rc.3 (global) | 0.2.0-rc.2 (Desktop bundle) |
|---|---|---|
| `SESSION_FORMAT_VERSION` | **3** | **4** |
| catalog `currentVersion` | 3 | 4 |
| codecs registered | v0–v3 | v0–v4 |
| `currentEncoder` | `releasedV3SessionFormatCodec` | `releasedV4SessionFormatCodec` |
| migration chain | v0->v1, v1->v2, v2->v3 | … , v2->v3, **v3->v4** |
| `dsh-session-format-v3-to-v4` | **absent** | present (73014 B) |
| reads v3 | yes (`status: "current"`) | yes (codec + v3->v4 migration) |
| reads v4 | **no** (`status: "unsupported"`) | yes (`status: "current"`) |
| writes | **v3 only** | **v4 only** |
| dual-read (v3+v4) | no | **yes** |
| discovery filename matcher | `^session(?:\.v([1-9][0-9]*))?\.jsonl$` + `.zstd` — version-agnostic | identical |
| listing on an unsupported header | `continue` (silent omission) | `continue` (same design, but v4 is supported) |
| by-id open of an unsupported version | throws `SessionFormatUnsupportedError` | n/a |
| extra capability | — | `createSessionFormatCatalogWithChildren`, `historicalSessionFormatCatalog` (v3-only) |

[FACT] The v4 format boundary is introduced **between 0.1.5-rc.3 and 0.2.0-rc.2**, by adding
the `dsh-session-format-v3-to-v4` package and bumping `SESSION_FORMAT_VERSION` 3 -> 4.

## I. E1 run3 final classification

DISCOVERY: **FAIL** (by 0.1.5's own host listing / UI).
OPEN, RENDER, CONTINUE: **NOT REACHED**.
DESTRUCTIVE MIGRATION: **NO** — the v4 session was neither migrated, rewritten, moved nor
deleted; 0.1.5 simply refused to read it.

**E1 run3 final: NOT DISCOVERABLE** (asymmetric read-only incompatibility at the host index
layer, caused by a v4 format the 0.1.5 catalog cannot decode).

Note the precise wording: the v4 **session directory and file remain intact and are plainly
visible to any version-agnostic filesystem reader** (including the E1 tooling). "Not
discoverable" describes the 0.1.5 host/UI, not the disk.

## J. Destructive side effects

[FACT] No session data was destroyed or rewritten:

* the v4 log is byte-identical at capture A and still 16364 B at capture B;
* the experiment-session listing diff A->B reported `added files: (none)` /
  `removed files: (none)`;
* no `.bak`, `.imported`, `.orig`, `.old` or second `session.v*.jsonl.zstd` appeared in that
  session directory (the capture script tests for all of these);
* the v4 session's `endSeedCount` stayed 0 and `endsWithEndSeed` stayed false — 0.1.5 never
  appended a single event to it.

[FACT] No shared configuration was destroyed: `browser-lab` and `web` profile files
unchanged, home `cordis.patch.yml` still ABSENT, global `AGENTS.md` unchanged.
[FACT] `settings.yaml` **re-appeared** at 16:00:15 (52 B, only `ui-onboarding`) — the known
0.1.5 client re-bootstrap; classified class A. The R3 baseline and Stage A both recorded it
ABSENT, so run3 Stage A settings churn was **0**, exactly as the approved Option A predicted.

**[INFERENCE — high confidence] The workspace registry lost the v4 session association.**

`C:\Users\user02\.dsh\storages\workspace.json` (unit `workspace`, `version: 2`) maps each
workspace to a `sessionIds` array. The run3 entry is:

```json
"ef6f489c-c00b-46ac-94ce-1581a8137b3f": {
  "path": "D:\\Projects\\dsh-desktop-runtime-test-3",
  "title": "dsh-desktop-runtime-test-3",
  "sessionIds": ["session-f2bc40b9-0196-4d85-b573-2468122f5ead"],
  "createdAt": "2026-10-05T07:39:39.165Z",
  "updatedAt": "2026-10-05T08:00:07.169Z"
}
```

`session-0d5e7d0c-…` is **absent**. Numeric basis for the inference:

| stage | size of `storages\workspace.json` | utc |
|---|---|---|
| R3 baseline (no run3 entry yet) | 3282 B | 2026-10-05T06:50:43.095Z |
| run3 Stage A | **3681 B** | 2026-10-05T07:39:39.198Z |
| run3 Stage B | **3681 B** | 2026-10-05T08:00:07.171Z |

A and B are the **same size with different hashes**. Both candidate ids are 44 characters
(`session-` + UUID; `session-0d5e7d0c-c341-48c4-a149-81250d473f20` and
`session-f2bc40b9-0196-4d85-b573-2468122f5ead`), and the v3 session did not exist until
16:00:07. At Stage A the only session in that workspace was the v4 one. So A's array held one
44-char id (the v4 id) and B's holds the v3 id: a **replacement**, not an append — an append
would have grown the file by roughly 46 bytes. `createdAt` still carries Desktop's timestamp
(15:39:39) while `updatedAt` moved to the blank-session moment, i.e. the writer merged into the
existing entry while rewriting `sessionIds`.

[INFERENCE] Consequence: 0.1.5 overwrote the workspace's session association with its own
(version-filtered) view. This is a **metadata association loss**, not session-data
destruction. No `.bak` of `workspace.json` exists (`dsh-atomic-write` writes and renames; no
temporary artefact was left behind).
[UNKNOWN] Whether Desktop 0.2 re-adds the v4 id to `sessionIds` on its next launch — that
would confirm both the loss and its reversibility. Not tested this round.
[UNKNOWN] Whether the same replacement happens for workspaces whose sessions are all v3.

[FACT] Two `session/end-seed` appends occurred during run3 and were classified class A
(non-destructive, one-time, outside the run3 workspace): run2's v4 session
`session-944c61ce` (events 31->32, `endSeedCount` 0->1) between the R3 baseline and Stage A
(a Desktop-launch effect), and the research session `session-665e3202` (5524->5525,
14->15) between Stage A and Stage B (a research-host effect). Neither is an E1 finding.

## K. Are more Web 0.1.5 experiments needed?

**No, for the discovery question.** The mechanism is settled at source level: filename matcher
(version-agnostic) -> generation selection (highest) -> header read (refused by a v3-only
catalog) -> silent `continue` in the listing. Additional 0.1.5 UI probing would only re-observe
the same absence.

Optional, cheap, and NOT required:

* open the v4 session by id in 0.1.5 and capture the refusal text; the expected text is known
  from source (`… uses log format v4, but this harness reads only v3 … upgrade the harness to
  open it`), so this would confirm D at runtime rather than at source level;
* re-launch Desktop 0.2 to see whether it re-adds the v4 id to `workspace.sessionIds`
  (this is the one genuinely open question raised in J, and it is a Desktop experiment, not a
  Web one).

Recommendation: spend the next slot on Control B (§L), not on more 0.1.5 probing.

## L. Impact on Control B

[INFERENCE] The finding makes Control B the decisive matched-version control. If the sole
difference is the format-version boundary, then a Web **0.2.0-rc.2** host must (a) list the
v4 session (its catalog returns `status: "current"` for v4) and (b) open/read it without
migration. A failure there would falsify the "version boundary is the whole story" model and
point at something else — a second variable — which would be the more important result.

**Design gap to fix before running Control B.** The existing design runs Control B under an
isolated `$DSH_HOME`, and the whole point of that isolation is that it must not touch the real
home. But an isolated home contains **no run3 v4 session**, so under the current design
Control B cannot observe the artefact it exists to test. Two options:

| Option | How | Assessment |
|---|---|---|
| **B1. Seed the isolated home with a copy** | copy the run3 v4 session directory + its projcache file into the isolated home, add the workspace + session ids to the isolated `storages\workspace.json`, then run the bundled 0.2.0 Web against the isolated home | **Recommended.** Real home untouched; the v4 bytes are identical; the registry can be authored explicitly so the test also exercises `workspace.sessionIds` |
| B2. Run Control B against the real home | point `$DSH_HOME` at the real home with Desktop stopped | Rejected as the default: it violates the isolation invariant and a single stray write would contaminate the real home. Only acceptable if the task is read-only *and* a real-home BEFORE/AFTER diff is required and reviewed |

[FACT] For B1 the probe inputs already exist: the session directory
`...\sessions\--D-Projects-dsh-desktop-runtime-test-3--\session-0d5e7d0c-…\session.v4.jsonl.zstd`
(16364 B, `64B4257A37C14035792E0806679A86EC19C683D0E2A9A477060E6621D5777EDB`) and its
projcache `session-0d5e7d0c-….json` (6099 B), plus the observed
`storages\workspace.json` shape to reproduce. The copy is additive; the source stays untouched.

Additional Control B assertions that follow from this report:

1. after the workspace is opened in 0.2.0 Web, assert **no new `session.v*.jsonl.zstd`
   appears** in the seeded workspace (if one does, the reuse-or-create path also failed under
   matched versions, which is a different and equally interesting defect);
2. assert `workspace.sessionIds` still contains the v4 id after the run (registry
   non-destruction check);
3. assert the v4 log's size and SHA-256 are unchanged unless a message is deliberately sent;
4. assert the session appears in the session list before opening it (listing is separable from
   reuse-or-create).

CONTROL B: **NEEDS REDESIGN** (objective updated + isolation strategy B1), not ready to run
as previously written.

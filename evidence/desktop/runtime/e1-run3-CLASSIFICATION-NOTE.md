# E1 run3 — RUN NOTE AND FINAL CLASSIFICATION

Status: **STOPPED AT STAGE B. Stage C NOT executed and NOT planned.**
Recorded: 2026-10-05 (local, UTC+8).
Run: `run3` — desktop-runtime session interoperability, baseline -> A -> B.

---

## 1. Provenance

| Field | Value |
|---|---|
| Run metadata | `evidence\desktop\runtime\e1-run3.metadata.json` (`BaselineVerified=true`, sealed 2026-10-05 15:38:03) |
| Sealed baseline | `e1-BASE-QUIESCENT-R3` (+ `-VERIFY`, `-compare`, `-VERDICT.txt`) |
| Workspace | `D:\Projects\dsh-desktop-runtime-test-3` (created by `new-e1-run.ps1`, 0 sessions at creation) |
| Fixture | `AGENTS.md` 122 B `0FF8FA597BA8DCCEFF7BB46AA59A77B938822FDD98E63A8502B239DF6E0FAC01` |
| Stage A capture | `e1-run3-A` (2026-10-05 15:41:17) |
| Stage B capture | `e1-run3-B` (2026-10-05 16:00:48) |
| Compares | `e1-run3-BASELINE-A-compare`, `e1-run3-A-B-compare` |
| Session lock | `e1-run3.session.lock.json` -> `session-0d5e7d0c-c341-48c4-a149-81250d473f20` |
| Approved settings decision | Option A (do not restore `settings.yaml`) — see `e1-run3-BASELINE-PRECONDITIONS.md` §4.1 |

## 2. Stage A (Desktop 0.2.0-rc.2 created the v4 session)

| Check | Result |
|---|---|
| baseline binding | PASS — previous stage resolved to the sealed `e1-BASE-QUIESCENT-R3`, never `e1-run3-BASE` |
| capture pipeline valid | True (`sessions=58 shared-state=30`) |
| diff valid | True (`detailRows=8 expectedDetailRows=8 warnings=0`) |
| destructive change | **0** |
| settings churn | **0** — `settings.yaml` ABSENT at baseline and ABSENT at A, exactly as Option A predicted |
| profile / home invariants | all PASS (browser-lab, web, home `cordis.patch.yml` ABSENT, global `AGENTS.md`) |
| exact session lock | PASS |

[FACT] Desktop created exactly one session, in v4:

```
session-0d5e7d0c-c341-48c4-a149-81250d473f20
session.v4.jsonl.zstd   16364 B
sha256 64B4257A37C14035792E0806679A86EC19C683D0E2A9A477060E6621D5777EDB
31 events, last = turn/end, seq 29, isSeeded false, endSeedCount 0
contains: session, permission/preset x2, sandbox/mode x2, approval/policy x2,
          command/run, command/done, agent/inbox/spliced x4, turn/start, step/start,
          system/message, user/message x5, request/header, request/context,
          session/title x2, session/title-llm-request,
          session-log-deepseek/delivery-accepted x2, assistant/message, step/end, turn/end
```

[FACT] One class-A item was recorded at Stage A, outside the run3 workspace: run2's v4 session
`session-944c61ce` received a one-time, non-destructive `session/end-seed` append
(31 -> 32 events, `endSeedCount` 0 -> 1) as a consequence of the Desktop launch.

**Stage A verdict: successful.** Desktop 0.2.0-rc.2 created a v4 session in an isolated
workspace, imported nothing destructively, and left every profile untouched.

## 3. Stage B (old Web 0.1.5-rc.3 opened the same workspace)

Human observation (as reported): the workspace was visible; **the Desktop-created v4 session
was not**; therefore it could not be opened, rendered or continued. No continuation message was
sent. Stage C was not attempted.

| Check | Result |
|---|---|
| capture pipeline valid | True (`sessions=59 shared-state=30`) |
| diff valid | True (`detailRows=10 expectedDetailRows=10 warnings=0`) |
| destructive change | **0** |
| profile / home invariants | all PASS |
| exact session lock | PASS — the locked v4 session was still located by the tooling at 16364 B |

[FACT] Auto-created during Stage B, in the same workspace:

```
session-f2bc40b9-0196-4d85-b573-2468122f5ead
session.v3.jsonl.zstd   333 B
sha256 90A6B839D408E5974FB56FDA3C6645A760FACDC5C72FC97E364279AAC7355818
4 events: session, permission/preset, sandbox/mode, approval/policy  (no turn/start)
sessionVersion 3, isSeeded false
```

[FACT] A->B diff (10 rows): `settings.yaml` APPEARED (52 B, `ui-onboarding`, 16:00:15);
`storages\workspace.json` CONTENT-CHANGED; `.dshw-usage.json` CONTENT-CHANGED;
the workflow's blank v3 session ADDED; the research session `session-665e3202`
CONTENT-CHANGED (+1 event, end-seed, outside the run3 workspace);
`profiles\browser-lab\cordis.yml` MTIME-ONLY.

[FACT] The v4 session does **not** appear in any part of the A->B diff. It was not modified.

Human classification of the interoperability question:

| Aspect | Result |
|---|---|
| DISCOVERY | **FAIL** |
| OPEN | NOT REACHED |
| RENDER | NOT REACHED |
| CONTINUE | NOT REACHED |
| DESTRUCTIVE MIGRATION | NO |

## 4. Root cause (source-level, see the forensic report)

`e1-run3-FORENSIC-v4-DISCOVERY.md` establishes, at source level:

* 0.1.5's filename matcher is **version-agnostic** (`^session(?:\.v([1-9][0-9]*))?\.jsonl$`
  plus the `.zstd` suffix) and its generation selector takes the **highest** version — so the
  v4 file **is** enumerated;
* 0.1.5's format catalog is built with `currentVersion: 3`, codecs v0–v3 and migrations only up
  to v2->v3; `@deepseek-ai/dsh-session-format-v3-to-v4` is not installed;
* `readHeader()` refuses v4 as `status: "unsupported"`
  (`stored Session uses newer format v4; this build writes v3`);
* `JsonlSessionPersistence.listArtifacts()` **catches `SessionFormatUnsupportedError` and
  `continue`s**, so the session is silently dropped from the host's listing;
* the Web sidebar therefore never receives the row, and opening the workspace falls through to
  `connectWorkspace()` -> `sessions.create({ workspaceId })`, which the host materialises in its
  own current format, **v3** — producing the blank v3 session;
* a direct by-id open would have failed too, with
  `session "<id>" uses log format v4, but this harness reads only v3: the log was written by a
  newer harness — upgrade the harness to open it`.

**Failure layer: HOST INDEX (persistence session listing).** Filesystem discovery succeeds;
UI surfacing is not the cause; the loader also refuses but is never reached via the UI.

## 5. Final classification

**E1 RUN3 FINAL: `NOT DISCOVERABLE`.**

Precise meaning: the Desktop-created v4 session is **not discoverable by DSH 0.1.5-rc.3's host
listing / Web UI**. It remains present, intact and readable by any version-agnostic reader on
disk, and the E1 tooling located and decoded it throughout (`sessionVersion: 4`).

Supporting statements, kept separate on purpose:

* [FACT] filesystem existence: the v4 file exists in the shared `$DSH_HOME\sessions`.
* [FACT] host-side discovery: 0.1.5's enumerator finds the file but the host listing drops it.
* [FACT] UI surfacing: the sidebar is not offered the row.
* [FACT] load support: 0.1.5 has no v4 codec/parser and refuses v4 by design.
* [FACT] the incompatibility is **asymmetric and read-only**: 0.2.0 reads v3 (codec + v3->v4
  migration) and writes v4; 0.1.5 reads and writes v3 only and cannot read v4 at all.
* [UNKNOWN] whether a v4 file's *content* would survive an attempted 0.1.5 read — 0.1.5 refuses
  before decoding any version-dependent structure, so this was never exercised.

This must NOT be written as "0.1.5 cannot parse v4 files in general": it cannot read the v4
*format*, and it deliberately refuses rather than mis-parsing. The refusal, not a parse failure,
is the mechanism.

## 6. Destructive side effects

[FACT] **None on session data.** The v4 log was byte-identical at A and unchanged at B; no
event was appended to it (`endSeedCount` 0, no end-seed); the experiment session directory had
`added files: (none)` / `removed files: (none)`; no `.bak` / `.imported` / `.orig` / `.old` and
no second `session.v*.jsonl.zstd` appeared in it; no format downgrade occurred.

[FACT] **None on configuration.** `browser-lab` / `web` profiles unchanged, home
`cordis.patch.yml` still ABSENT, global `AGENTS.md` unchanged. `settings.yaml` was *created*
(not overwritten) by the known 0.1.5 client re-bootstrap, and the pre-existing
`settings.yaml.imported` was left untouched (still 52 B `EA141B86…`, mtime 12:29:50).

[INFERENCE — high confidence] **One metadata association loss.** The run3 entry in
`C:\Users\user02\.dsh\storages\workspace.json` now lists only the blank v3 session in
`sessionIds`; `session-0d5e7d0c-…` is absent. The size evidence (3282 B at baseline with no
run3 entry -> 3681 B at A -> 3681 B at B, different hashes, both candidate ids 44 characters,
the v3 session not existing until 16:00:07) shows the array was **replaced**, not appended, and
that `createdAt` (Desktop's 15:39:39) was preserved while `updatedAt` moved to 16:00:07.
Interpretation: the 0.1.5 host rewrote the workspace's session list from its own
version-filtered view. This is reversible in principle and did not touch the session log.
[UNKNOWN] Whether a subsequent Desktop 0.2 launch re-adds the id.

## 7. What run3 did and did not establish

Established (FACT):
1. Desktop 0.2.0-rc.2 creates a v4 session in an isolated workspace with zero destructive effect
   and zero settings churn when no legacy `settings.yaml` is present (Option A confirmed).
2. DSH 0.1.5-rc.3 **cannot discover** a v4 session: the host listing silently omits it.
3. The cause is a format-version boundary (`SESSION_FORMAT_VERSION` 3 -> 4), not a filename
   pattern, not the sidebar, and not the projcache.
4. Opening a workspace whose only session is v4 makes 0.1.5 create a fresh blank **v3** session
   as the draft, by design of `connectWorkspace`'s reuse-or-create policy.
5. 0.1.5's incompatibility with v4 is **fail-closed and non-destructive**.

Not established:
1. whether Web 0.2.0 can discover/open/render/continue the v4 session — **that is Control B**;
2. whether v3 -> v4 is transparent for a *reader* that does support v4 (implied by the codec set
   and the migration edge, but not observed on this artefact);
3. whether the registry association loss in §6 is repaired by Desktop.

## 8. Interaction history (for the record)

| Attempt | Outcome | Disposition |
|---|---|---|
| E1 run1 (`e1-BASE`, `e1-A`) | baseline CONTAMINATED (captured while browser-lab ran) | superseded; kept |
| STEP 1 R1 (`e1-BASE-QUIESCENT*`) | FALSE PASS — fail-open capture pipeline | INVALID; kept, see `e1-BASE-QUIESCENT-INVALID-NOTE.md` |
| STEP 1 R2 (`e1-BASE-QUIESCENT-R2*`) | environment quiescent; validator FALSE FAIL on a legal zero-row diff | revalidated PASS, kept |
| E1 run2 Stage A | Desktop action succeeded; baseline binding broken; baseline->A interval contained research activity | OPERATIONALLY SUCCESSFUL, ATTRIBUTION-CONTAMINATED; Stage B/C must not proceed, see `e1-run2-A\RUN2-CONTAMINATION-NOTE.md` |
| **E1 run3 A -> B** | **Desktop created v4; 0.1.5 could not discover it; blank v3 created; nothing destroyed** | **this note — final classification NOT DISCOVERABLE; Stage C not executed** |

## 9. Next steps (not this round)

1. Run the (redesigned) **Control B**: matched-version Web 0.2.0 against a **seeded copy** of the
   run3 v4 session in an isolated home. See the updated `control-b-runbook.md`.
2. Optionally re-launch Desktop 0.2 once against the real home to observe whether it re-adds the
   v4 id to `workspace.sessionIds` (closes the §6 UNKNOWN).
3. Stage C remains unexecuted and should stay unexecuted: it would require 0.1.5 to continue a
   session it cannot even open, and a v3 session was never the subject of the experiment.

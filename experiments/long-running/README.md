# experiments/long-running - Long-running Toolkit line

Assets for building and evaluating DSH long-running loops, and for developing the portable
toolkit that a project adopts. Registered here (and not under `docs/` or `scripts/`) so it does
not fork the existing IA.

**v0.2 was released on 2026-10-09.** The published artifact is
`toolkit/long-running/v0.2/` (exactly eight files); the release record is
`toolkit/long-running/RELEASES.md`, and the closing record for the development line is
`v0.2-work/RELEASE-REPORT.md`. The v0.2 research line is **CLOSED / RELEASED**: the release is
immutable and new findings belong to a future version. Nothing else in this directory is a
published product; the paths below are the release source, the research record and the frozen v0.1
pilot.

| Bucket | What it is | Where | State |
|---|---|---|---|
| **v0.1 research line** | design spec, runbook, evaluator v0, its selftest and fixture | this directory (below) | long-term, frozen where marked |
| **v0.1 frozen pilot artifact** | the pilot's six-file output | `D:\Projects\dsh-longloop-pilot\out\toolkit-v0.1\` (**outside this repo**) | frozen; never released, HUMAN ACCEPTANCE never granted |
| **v0.1 pilot evidence** | per-round evidence, acceptance record, final report | `D:\Projects\dsh-longloop-pilot\evidence\` (**outside this repo**) | frozen |
| **v0.2 release source** | the eight-file candidate that was published, kept for traceability | `v0.2-work/candidate/long-running/` | frozen; identical to the release |
| **v0.2 accepted portable release** | the published eight files | `toolkit/long-running/v0.2/` | **RELEASED 2026-10-09** |

## v0.1 research line

| File | Role | Lifetime |
|---|---|---|
| `PILOT-SPEC-v0.1.md` | design: contracts S1-S12, three-bucket separation, portable delivery contract, safety reality | long-term |
| `RUNBOOK.md` | the exact human steps that started and supervised the first pilot | long-term |
| `check.ps1` | **Evaluator v0** - read-only mechanical acceptance (presence, fields, vocabulary, references, portability, version awareness), exit 0/1/2 | frozen before arming |
| `check.selftest.ps1` | Evaluator v0 regression harness: 9 cases | long-term |
| `fixtures/complete/` | the one compliant fixture used by that selftest | test data |

`check.ps1` is the judge for the **v0.1 six-file artifact only**. It is not an admissible judge
for the v0.2 eight-file structure, and the v0.2 candidate is allowed to fail it.

Related: `D:\Projects\dsh-longloop-pilot\` is the disposable **pilot instance** (read-only now);
the DSH `0.2.0-rc.2` package READMEs are the official mechanism reference. The v0.1 pilot's
outcome, budget and lessons are recorded in that workspace's `evidence/FINAL-REPORT.md`.

## v0.2 line - `v0.2-work/` (**CLOSED / RELEASED**)

Development of the Long-running Toolkit v0.2, through revisions `v0.2-rc.1`, `v0.2-rc.2` and
`v0.2-rc.3`, without touching the frozen v0.1 artifacts. The line **closed on 2026-10-09** when
rc.3 was published as **v0.2** to `toolkit/long-running/v0.2/`. Start at
**`v0.2-work/README.md`**, which is the index for everything below it, and read
`v0.2-work/RELEASE-REPORT.md` for the publication and closure record.

| Item | Role |
|---|---|
| `v0.2-work/README.md` | navigation index for the v0.2 development area |
| `v0.2-work/RELEASE-REPORT.md` | **release and closure record**: manifest, acceptance, archive inventory, cleanup, Known Limitations L1-L7 |
| `v0.2-work/V0.2-ACCEPTANCE-SPEC.md` | acceptance rules V1-V16 + R1-R3, with dated amendments A1-A5 |
| `v0.2-work/candidate/long-running/` | the 8-file candidate that was published; kept as the traceable release source |
| `v0.2-work/evaluator/check-v0.2.ps1` | the v0.2 mechanical evaluator: `-Mode Candidate|Hygiene|Adoption|Readiness` |
| `v0.2-work/evaluator/check-v0.2.selftest.ps1` | 44-case regression harness over real candidate copies, with a fail-closed scratch guard |
| `v0.2-work/evidence/` | mechanical results, raw run logs, selftest copies, dry-run records, invocation note |
| `v0.2-work/adoption/` | the bounded adoption dry-runs: the historical `dryrun-project/` and the rc.1/rc.2 scenario projects |
| `v0.2-work/CHANGE-LIST.md` | every v0.2-baseline change traced to a v0.1 section, a pilot finding, or a verified official contract |
| `v0.2-work/RC1`, `RC2`, `RC3` change reports | the three revision records: baseline, change, verification, residual risk |

## Release gates - all three were met for v0.2

1. `MECHANICAL PASS` - the frozen v0.2 evaluator exits 0 on the candidate (`CANDIDATE VALIDATION PASS`).
2. `ADOPTION DRY-RUN PASS` - fresh projects adopted the toolkit and were verified through their
   declared instance roots (`ADOPTION PASS (contract-verified)`), with refusals proven in both
   directions.
3. `HUMAN CONTENT ACCEPTANCE` - **APPROVED** by the user's direct authorization on 2026-10-09.

Promotion copied the eight verified files into `toolkit/long-running/v0.2/` without editing them,
verified 8/8 against the rc.3 freeze record, and left the source candidate in place. **The v0.2
line is now closed**: the release is immutable, the rc.1/rc.2/rc.3 records are retained as recorded,
and any further work belongs to a future version.

## Post-release compatibility audit (2026-10-19)

The published v0.2 was re-audited read-only against DSH `0.2.1-rc.2`. Result:
**COMPATIBLE WITH CAVEAT** — none of the ten contracts is `INCOMPATIBLE`; the eight release files are
byte-identical (8/8 SHA-256), and no live goal execution was performed (`GOAL LIVE TEST: NOT RUN`).

The audit found behaviours that need a version note rather than a toolkit edit: the goal driver now
waits for running subagent descendants before starting a round and removes a queued round prompt at
idle; plan-review dismissal ends the turn; `working_directory` changes the Session cwd without
re-scoping existing sandbox grants; and the `{{cwd}}` prompt variable was removed. Details, per-item
evidence and the K01–K24 delta: [`../dsh-version-audit/0.2.0-rc.2-to-0.2.1-rc.2/`](../dsh-version-audit/0.2.0-rc.2-to-0.2.1-rc.2/).

## Post-release compatibility audit (2026-11-08)

The published v0.2 was re-audited read-only against DSH **`0.2.2-rc.1`**. Result:
**COMPATIBLE WITH CAVEAT** (unchanged verdict) — none of the ten contracts is `INCOMPATIBLE`,
the eight release files are untouched, and **no live goal execution was performed**
(`GOAL LIVE TEST: NOT RUN`). No toolkit edit is made by this audit.

New caveats that a v0.3 (or a reader) must know — all source-confirmed, none is a toolkit defect:

1. **`exit_plan_mode` is now progressively disclosed.** It is admitted only from the first step
   whose plan state is active, and an earlier call returns `UNKNOWN_TOOL`. The old statement
   "entering or leaving plan mode changes only the prompt section, never the tool catalog" is
   therefore **no longer exactly true** for that one tool. The plan contract itself (human review
   gate, `{approved:false}` on dismiss, guidance-not-enforcement) is unchanged.
2. **The driver gained a `disposed` cause.** Agent disposal (graceful shutdown, or reloading the
   plugin that owns the Agent) aborts the round with `disposed` and **only disarms** continuation,
   so the goal stays `active` — same as plugin unload. User / parent / hook cancellations still
   **pause**. Do not read "the round ended" as "the goal was paused".
3. **`update_goal` now ignores stray fields instead of rejecting them.** `objective` and
   `max_goal_rounds` apply only to `edit`; `blocked_reason` is required only for `blocked`. The
   previous `GOAL_TOOL_INVALID_UPDATE` error is gone, so any script that relied on that error as
   a validator will now pass silently.
4. **More resume entry points.** The Web goal bar can now resume a **blocked** goal directly;
   a goal that has **exhausted its round limit still requires raising the limit first**. The
   "manual rearm" discipline is unchanged — but `blocked` is no longer a dead end from the UI.
5. **`create` / `edit` / `pause` / `resume` still require a direct human turn** (host-enforced,
   `requireDirectHuman`), and a durably paused goal still fails `resume` with
   `GOAL_TOOL_RESUME_PAUSED`. The "the loop cannot re-arm itself" guarantee **holds**.

Details: [`../dsh-version-audit/0.2.1-rc.2-to-0.2.2-rc.1/`](../dsh-version-audit/0.2.1-rc.2-to-0.2.2-rc.1/)
(`FINAL-REPORT.md` §4, `KNOWLEDGE-DELTA.md` K29–K36).

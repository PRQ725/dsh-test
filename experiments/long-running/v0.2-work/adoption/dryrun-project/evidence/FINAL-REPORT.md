# FINAL REPORT - adoption dry-run (initialization only)

Post-exercise record, written at the report path fixed before any goal existed. This report
describes an **initialization exercise**, not a completed long-running run: no goal was
created and no automatic round ran.

## 1. Executive summary

The objective of the exercise was to find out whether a fresh project, following only the
toolkit candidate's own README, can reach a complete long-running *initialization*. It could.
Every step that does not require creating a goal produced a project-owned artifact carrying a
real value, and the project's own evaluator discriminates correctly between pass, fail and
error. The steps that do require a goal (creation, rounds, post-run reporting after a real
loop) were deliberately not performed, because creating a goal would start an autonomous loop
and turn an adoption test into a pilot.

Terminal state: no goal exists; there is no phase, no round count and no activation to report.
The exercise's own verdict is **ADOPTION DRY-RUN PASS**, which is a statement about the
toolkit's adoptability, not about its content quality.

## 2. Goal and frozen baseline

| Item | Value |
|---|---|
| Objective | copied verbatim from `docs/long-running/GOAL.md` when the contract was written |
| Round cap chosen | 4, to be passed explicitly if a goal is ever created (**HARD**) |
| Frozen goal contract | `docs/long-running/GOAL.md` |
| Approved plan | `docs/long-running/PLAN.md`, STATUS: APPROVED, revision r1 |
| Frozen evaluator | `evaluator/check-project.ps1`, SHA256 `421C75B6C4B142404CA13ECC02362684670E043323EFD3973919EAD8D3AC4CC5` (5863 bytes) |
| Toolkit candidate adopted | the v0.2 candidate copy under `toolkit/long-running/`, 8 files |
| Version assumed | DSH `0.2.0-rc.2` for the toolkit's mechanism claims; not re-probed here |

The frozen artifacts were re-hashed at report time and were unchanged.

## 3. Execution timeline

There were no goal rounds. The exercise had two movements.

| Movement | Nature | Outcome |
|---|---|---|
| Initialization (steps 1-10 of the adoption procedure) | content work | project conventions collected; goal, plan and state written; evaluator authored, tested and frozen |
| Reporting (step 13, out of order) | record-keeping | this report, written from the round-0 evidence at the path fixed in the goal contract |

## 4. Deliverable inventory

| Path | Role | Frozen? |
|---|---|---|
| `toolkit/long-running/**` | the adopted toolkit copy, unmodified | yes |
| `docs/long-running/GOAL.md` | frozen objective contract | yes |
| `docs/long-running/PLAN.md` | approved plan | yes |
| `docs/long-running/STATE.md` | durable position | append-only |
| `evaluator/check-project.ps1` | project evaluator | yes, hash recorded |
| `docs/onboarding/GUIDE.md` | the synthetic deliverable | not yet reviewed by a human |
| `evidence/round-0.md` | initialization evidence | append-only |
| `.dsh/skills/long-running/SKILL.md` | the skill bundle placement | no |

## 5. Evaluation and acceptance

Command: `pwsh -NoProfile -ExecutionPolicy Bypass -File evaluator/check-project.ps1 -Project <project root>`
with `DRYRUN_CANDIDATE_ROOT` naming the candidate. Exit code **0** on the final state; the
`FAIL` (1) and `ERROR` (2) runs are recorded in `evidence/round-0.md`, including the first run
that failed because an input had not been declared.

States, kept separate:

| State | Value |
|---|---|
| `MECHANICAL PASS` (this project's evaluator) | yes |
| `READY FOR HUMAN REVIEW` | not applicable - no goal exists |
| `HUMAN ACCEPTANCE` | **not given** |
| `GOAL COMPLETE` | **not applicable** - no goal was created |

What this establishes: the adoption procedure is followable end to end for everything short of
arming a loop, and the toolkit's own evaluator contract can be re-implemented by an adopter
without copying the toolkit author's script.

## 6. Budget and efficiency

| Quantity | Value | Grade |
|---|---|---|
| rounds started | 0 of a chosen cap of 4 | `FACT` |
| rounds that changed a deliverable | 0 | `FACT` |
| wall clock | not measured with a meter; file timestamps available on request | `UNKNOWN` |
| token use | no meter exists | `UNKNOWN` |
| monetary cost | no meter exists | `UNKNOWN` |
| network calls | 0 | `FACT` |

Efficiency reading: the exercise cost one initialization pass and no rounds, which is the
intended shape for an adoption test. It also shows the honest limit of the budget table: with
no goal, the only enforced budget has nothing to enforce, and everything else is unmeasured.

## 7. Deviations and incidents

1. The first evaluator run failed because it required `DRYRUN_CANDIDATE_ROOT` and the variable
   was not set. Handled by declaring the input; the failing run is preserved in the evidence.
2. The evaluator was edited after its first execution (to require the candidate root rather
   than skip the comparison), and was then frozen. This is recorded because an evaluator that
   changes after being used invalidates any earlier pass; the freeze hash above is the
   post-change one and no earlier pass is claimed.
3. There is no version-control marker in this project, so the toolkit's documented project-root
   rule falls back to the current working directory. Recorded in `AGENTS.md` and here.
4. Report generation happened before any goal existed, in reverse order relative to a real run.
   It is a deviation and is recorded as one.

## 8. Lessons learned

- `FACT` A copied toolkit survives an adoption pass unchanged, and a project-level evaluator can
  prove it byte for byte. This is a cheap and effective check against in-place editing of a
  reusable asset.
- `FACT` Separating the portable copy from the filled instances (`toolkit/` versus
  `docs/long-running/`) kept the blank forms reusable, but the toolkit's README does not
  currently prescribe where filled instances belong. An adopter has to invent it.
- `FACT` The evaluator contract is re-implementable by an adopter: this project's evaluator is
  a different program from the toolkit's, with different checks, and it implements the same
  exit-code and read-only discipline.
- `INFERENCE` The most likely adoption failure is not a missing step but a missing *input*: the
  first run failed because the evaluator needed a path nobody had declared. Requiring inputs
  explicitly is what turned a silent skip into a visible failure.
- `UNKNOWN` Whether the locally placed skill would actually be discovered and loaded by a live
  session. Placement and frontmatter were verified as files; discovery was not observed.

## 9. Next actions

| # | Action | Owner |
|---|---|---|
| 1 | Decide whether the toolkit should prescribe where a project keeps its filled instances | human (toolkit owner) |
| 2 | Decide whether the toolkit should carry a starter project-evaluator skeleton, or keep evaluator authorship entirely with the adopter | human (toolkit owner) |
| 3 | If a deeper test is wanted, run a real 2-round goal in a similarly disposable project and observe pause, cap and reporting | human |
| 4 | Accept or reject the toolkit candidate's content | human |

What this exercise did **not** test: goal creation, automatic rounds, the round cap, pause and
resume, recovery after a restart, and the behaviour of any `SOFT` stop condition. All of those
require a goal, which this exercise deliberately never created.

## Appendix A - per-round quantitative capture

No goal round ran, so the per-round table has no rows. The quantities this project committed
to capture per round, had a goal been created, were: round number, whether the round changed a
deliverable, whether it produced a new verified fact, rounds started against the cap, the
evaluator exit code, and the evidence file. Token use, cost and wall clock were accepted as
`UNKNOWN` because no meter exists.

# RC2 DRY-RUN AND REGRESSION EVIDENCE - v0.2-rc.2

Records the targeted regression for the three rc.2 contract repairs (F1 round semantics,
F2 instance-root consistency, F3 hygiene vs readiness). Every number below is from a run in this
round; logs are in `rc2/`. The rc1 scenarios and logs are left where they were.

- Candidate under test: `../candidate/long-running/` (digests in `RC2-CHANGE-REPORT.md` §6)
- Judge: `../evaluator/check-v0.2.ps1` (digest in §6)
- Harness: `../evaluator/check-v0.2.selftest.ps1`, 35 cases
- Scenario projects: `../adoption/rc2-scenarios/{S1..S6}/`
- All test data is under `v0.2-work/`; the scratch root is `evidence/rc2/selftest-scratch`,
  inside the approved base `evidence/`
- No goal was created, no automatic round ran, nothing outside the workspace was written

## 1. Scenario inventory

| Scenario | Layout | Declaration | Instance documents | Purpose |
|---|---|---|---|---|
| `S1-ready-custom` | `planning/` | `planning/` | GOAL, PLAN, STATE, EVALUATION, FINAL-REPORT | consistent declared custom root, approval recorded |
| `S2-conflict` | both `planning/` and `docs/long-running/` | `planning/` | both sets | the argument points at the other directory: a conflict |
| `S3-equivalent-forms` | `planning/` | `.\planning\` | full set | the same directory, spelled differently |
| `S4-blank-declaration` | `planning/` | `UNFILLED — not decided` | full set | a blank declaration is not a path |
| `S5-goal-only` | `docs/long-running/` | *absent* | GOAL only | hygiene passes, readiness does not |
| `S6-no-approval` | `planning/` | `planning/` | full set, `Approval record: NOT RECORDED` | an unperformed human gate |

Every scenario's `toolkit/long-running/` is a fresh copy of the candidate; the harness asserts
the candidate tree hash before and after, so no case can have passed by editing the artifact.

## 2. R2 regression matrix - 11/11 as expected

| Case | What it exercises | Command shape | Exit | Log |
|---|---|---|---|---|
| R2-T10 | the candidate still passes | `-Mode Candidate` | **0** | `final-r2-R2-T10-candidate.log` |
| R2-T11 | default layout adoption still passes and reports the path | `-Mode Adoption` (no declaration) | **0** | `final-r2-R2-T11-default-layout.log` |
| R2-T12 | declared custom layout passes and prints the declaration | `-Mode Adoption -InstanceRoot <planning> -GoalContract <GOAL.md>` | **0** | `final-r2-R2-T12-declared-custom.log` |
| R2-T4 | declaration, argument and directory all agree | same as T12 | **0** | `final-r2-R2-T4-custom-pass.log` |
| R2-T3 | `.\planning\` declared vs `planning` inspected | equivalent forms | **0** | `final-r2-R2-T3-equivalent-forms.log` |
| R2-T2 | declaration `planning/` vs inspected `docs/long-running/` | conflict | **1** | `final-r2-R2-T2-conflict.log` |
| R2-T5 | `Instance root:` unfilled | blank declaration | **1** | `final-r2-R2-T5-blank-declaration.log` |
| R2-T9 | all checkable prerequisites pass, human gates open | `-Mode Readiness` | **3** | `final-r2-R2-T9-readiness-pending.log` |
| R2-T6 | only `GOAL.md` present | `-Mode Readiness` | **3** | `final-r2-R2-T6-goal-only-not-ready.log` |
| R2-T7 | plan not approved | `-Mode Readiness` | **3** | `final-r2-R2-T7-no-approval.log` |
| R2-T8 | no evaluator test evidence | `-Mode Readiness` | **3** | `final-r2-R2-T8-no-evaluator-evidence.log` |

The two error paths and the refusals are covered by the harness (T9 `ERROR` on a missing root,
T32-T34 refusals); this matrix is about the contract semantics.

## 3. What each verdict actually means

**R2-T9 is the case that matters.** It is the most complete synthetic project that can be built
without a human: every checkable prerequisite passes, and the mode still returns **exit 3** with
`NOT READY PENDING HUMAN GATE (2 items)`, naming `R09 workspace and permission boundary verified`
and `R11 human approval records`. It does **not** print READY, and it states in its own output
that it is not acceptance and arms nothing. A green run of the adoption mode cannot be mistaken
for this: adoption (R2-T4) says `INSTANCE HYGIENE`, while readiness (R2-T9) reports twelve
per-item verdicts and refuses to collapse them.

**R2-T2 is the fail-closed case.** The declaration says `planning/`, the argument says
`docs/long-running/`, and both directories exist with plausible documents. The evaluator refuses
to choose:

```
V13 instance-root conflict: the Instance root: field of ... declares 'planning/' ... but the
inspected directory is '...docs\long-running'. Fail-closed: the frozen declaration is not
overridden by the filesystem, and the evaluator will not switch to another directory. A human
decides which side is corrected.
```

It does not pass, does not silently inspect the declared directory instead, and does not edit the
contract.

**R2-T3 is the false-positive guard.** `.\planning\` and `planning` name one directory. The
comparison normalizes first, so the run reports `instance-root consistency: PASS` rather than
inventing a conflict out of spelling.

## 4. Harness result

```
SELFTEST PASS
  35 cases, 0 failures.
```

Log: `final-selftest.log`. The 35 cases cover: nine evaluator-discrimination cases (T1-T9), two
mode/baseline cases (T10-T11), five instance-root contract cases (T12-T16), six rc.2 cases
(T31-T36: round-semantics wording, conflict, equivalent forms, blank declaration, hygiene-passes,
readiness-fails), eleven scratch-guard cases (T17-T27), and two immutability cases for the
candidate tree and the whole scratch base (T28-T29).

Two cases failed on the way and are kept in the record rather than erased:

1. **T15** first reused another case's copy after that case had filled a template; the copy
   integrity check then failed for a reason unrelated to the case. Fixed by giving T15 its own
   fresh copy. This is a harness defect, not an evaluator defect.
2. **A first run of the whole harness** failed because T12-T16 shared one copy that an earlier
   case edited. Fixed the same way. Both failures were caused by cases sharing mutable state, and
   the fix is visible in the source (each adoption case takes a fresh `New-RealCopy`).

## 5. Incidents

1. **One rc1 log was rewritten.** `evidence/rc1/baseline-adoption.log` and
   `baseline-candidate.log` were re-generated when the rc.2 baseline was captured, instead of
   writing to `rc2/`. Both outputs are byte-identical to the rc1 records (424 B and 325 B, same
   PASS text, same command, unchanged candidate), so no information was lost - but the rc1
   directory should not have been written at all, and the mtime change is recorded here rather
   than hidden. Every other rc1 artifact is untouched, including `RC1-CHANGE-REPORT.md`, the
   rc1 scenario logs and `evidence/rc1/selftest-scratch/` (28 entries).
2. **The rc.2 baseline capture initially omitted `-Proposal`**, so the adoption run failed
   copy-integrity for a missing input rather than for a real reason. The matrix was corrected and
   re-run; the superseded logs remain in `rc2/` with their `r2-` prefix.
3. **Exit-code capture bug in the throwaway matrix script** (`| Out-Null` swallowed the return
   value, so every row reported an empty code). Fixed by capturing the function's return value
   directly. The harness itself was never affected.

## 6. Not tested

Goal creation, automatic rounds, the round cap, pause/resume, restart recovery, and any `SOFT`
stop condition - all require a goal, which this round never created. Independent adoption is also
not tested: the toolkit, the scenarios and the judge share one author.

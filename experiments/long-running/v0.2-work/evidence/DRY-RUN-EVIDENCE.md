# ADOPTION DRY-RUN - evidence and verdict

Purpose: verify that a **brand-new project** can reach a complete long-running
*initialization* using only the v0.2 candidate and its own README, before anything is published.
This is a bounded exercise: it does not start an autonomous loop and it touches no real
business project.

- Candidate adopted: `../candidate/long-running/` (8 files)
- Dry-run project: `../adoption/dryrun-project/` (synthetic, no business data)
- Toolkit copy in the project: `../adoption/dryrun-project/toolkit/long-running/` (8 files,
  byte-identical to the candidate for all eight)
- Project evaluator: `../adoption/dryrun-project/evaluator/check-project.ps1`

---

## 1. What was performed

| Procedure step | Performed? | Evidence |
|---|---|---|
| 1 decide the shape | yes | `../adoption/dryrun-project/AGENTS.md` states the project's constraints, including "no goal" |
| 2 project discovery | yes | `AGENTS.md` "Project-specific facts an adopter must discover" table |
| 3 choose where working documents live | yes | `toolkit/` for the portable copy, `docs/long-running/` for filled instances |
| 4 write and freeze `GOAL.md` | yes | `docs/long-running/GOAL.md`, no blank-form markers remaining |
| 5 write and approve `PLAN.md` | yes | `docs/long-running/PLAN.md`, `STATUS: APPROVED` |
| 6 initialize `STATE.md` | yes | `docs/long-running/STATE.md`, round 0 |
| 7 write the evaluation contract | yes | `evidence/EVALUATION.md` |
| 8 author, test and freeze an evaluator | yes | `evaluator/check-project.ps1`; PASS/FAIL/ERROR all exercised against real artifacts |
| 9 review budget and safety | yes | budget table in `GOAL.md`; scope in `AGENTS.md` |
| 10 confirm version compatibility and permissions | partial | version recorded as an assumption; no live mechanism probe was performed |
| 11 create the goal with an explicit cap | **no, deliberately** | creating a goal would start an autonomous loop |
| 12 monitor, pause, resume | **no** | requires a live goal |
| 13 generate the Final Report | yes, out of order | `evidence/FINAL-REPORT.md`, written from evidence at the pre-agreed path |
| 14 human acceptance and knowledge deposition | partial | states recorded; acceptance deliberately left pending |

## 2. The adopter's own evaluator really was tested

The toolkit's step 8 asks the adopter to exercise PASS, FAIL and ERROR. Four real runs were
made, and one of them failed on the first attempt:

| Run | Result |
|---|---|
| untouched project | exit 0 `PASS` |
| one portable file edited in place in the project's toolkit copy | exit 1, naming that file |
| nonexistent project root | exit 2 `ERROR` |
| candidate root not supplied | exit 1, fail-closed |

The failing first attempt is preserved in `../adoption/dryrun-project/evidence/round-0.md`.
It is the most transferable finding of the exercise: the evaluator did not silently skip an
unverifiable comparison, it refused to claim a result it could not establish.

## 3. v0.2 evaluator run against the dry-run project

```
check-v0.2.ps1 - Long-running Toolkit v0.2 evaluator
mode: Adoption
root: <dry-run project>/toolkit/long-running
candidate: <candidate>

PASS
```

Exit code 0. Raw output in `adoption-run.log`.

## 4. Gaps found, and what was done about them

1. **The toolkit does not say where a project keeps its filled instances.** The exercise had to
   invent the `toolkit/` plus `docs/long-running/` split, and only that split makes it possible
   to fill a form without destroying the reusable template.
   *Action taken:* recorded as a human review item rather than silently patched into the
   candidate, because prescribing a layout is a content decision, not a mechanical defect.

2. **The adoption check V12 was checking the wrong object.** The first adoption run failed with
   five `UNFILLED` findings — in the **toolkit copy**, whose blank forms are supposed to stay
   blank. The rule could never pass in a correct adoption.
   *Action taken:* spec amendment A1, applied and recorded in `V0.2-ACCEPTANCE-SPEC.md` and in
   `CHECK-REPORT.md` section 4; the corrected rule is proven by selftest cases T10 and T10b.

3. **Nothing told the adopter that the toolkit's own mechanism claims were unverified here.**
   The toolkit's README does say so, and the dry-run honoured it by marking step 10 partial and
   the discovery question `UNKNOWN`.

No gap was found that made initialization impossible.

## 5. Verdict

**ADOPTION DRY-RUN: PASS**, with three qualifications that a human should weigh:

- the exercise was performed by the same party that wrote the toolkit, so it is not an
  independent adoption;
- the project was created for the exercise, so it did not have to reconcile pre-existing
  conventions it disagreed with;
- the parts that need a live goal (creation, rounds, cap, pause, resume, recovery) were not
  exercised at all, so this says nothing about them.

What it does establish is narrower and still worth having: the procedure is followable end to
end for everything short of arming a loop, the evaluator contract can be re-implemented by an
adopter as a different program, and a copied toolkit can be mechanically proven intact.

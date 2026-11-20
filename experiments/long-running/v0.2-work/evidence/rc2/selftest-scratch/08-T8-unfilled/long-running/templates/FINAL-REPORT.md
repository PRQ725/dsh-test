# FINAL-REPORT - blank post-run report contract

Copy this file into the target project. The `filled in` marker means the field is still blank.

**This contract is fixed before the goal is armed**, together with the report path, the report
owner and the quantities each round will capture. It is filled in **after** automatic
continuation has stopped, from the evidence already on disk. Deciding the report's shape at
the end is how a run's most useful output - budget, efficiency, deviation history - ends up
reconstructed from memory and lost.

Rules that apply to every section below:

- Write from evidence, not recollection. Cite the evidence file for each claim.
- Never rewrite an earlier evidence file to make the result look cleaner.
- Report a quantity that was never captured as `UNKNOWN`. Inventing a plausible value is a
  report defect, not a rounding choice.
- Keep the run's terminal state and the human acceptance status separate. A run that ended at
  its round cap has not been accepted, and a clean mechanical check does not change that.
- Reporting does not consume a round: it happens after automatic continuation has stopped.

Report path:
filled in. The exact path, agreed before arming. This file, filled in at that path, is the
report.

Report owner:
filled in. Who generates the report and in which turn or mode, and who reviews it before it is
treated as final.

Instance root:
filled in. The directory holding this project's filled documents, matching the `Instance root:`
field of the frozen objective contract. This report is written inside it, so an implicit
location here would make the report the one artifact nobody declared.

## 1. Executive summary

filled in. What the objective was, what actually happened, the terminal goal state (phase,
rounds started against the cap, activation, any blocker and its stable code), the current
acceptance status, and one honest bottom line about whether the run demonstrated what it set
out to demonstrate.

## 2. Goal and frozen baseline

filled in. The objective verbatim; the round cap; the frozen acceptance baseline and its hash;
the evaluator and its hash; the approved plan and its revision; the version and packages the
run assumed. State whether each frozen artifact was re-verified as unchanged at report time.

## 3. Execution timeline

filled in. One row per round: when it ran, what kind of round it was (content, review, or
blocked), whether it changed a deliverable, whether it produced a new verified fact, and its
outcome. Derive times from artifact timestamps and say so when that is the only timing
evidence retained.

## 4. Deliverable inventory

filled in. Every produced artifact with its path, size and hash, and whether it is frozen. State
whether the bytes a reviewer sees now are the same bytes that received the mechanical pass.

## 5. Evaluation and acceptance

filled in. The exact evaluator command, its exit code and raw output; any failed run and the fix,
preserved rather than erased; the evidence chain's completeness; what the evaluation
establishes; and what it does **not** establish. Keep the four states distinct:
`MECHANICAL PASS`, `READY FOR HUMAN REVIEW`, `HUMAN ACCEPTANCE`, `GOAL COMPLETE`.

## 6. Budget and efficiency

filled in. Report as observed numbers: rounds started against the cap; rounds that changed a
deliverable; review-only rounds; rounds with no information gain; wall clock and how it was
derived. Report token use, cost and any other unmetered quantity as `UNKNOWN` rather than
estimated. Add a short reading of whether the round allowance was used efficiently, including
the case where the work finished long before the cap.

## 7. Deviations and incidents

filled in. Every deviation from the plan, every failed attempt, every boundary refusal, every
interrupted call whose effect could not be proven, and every place the sandbox, the approval
policy or the authority rules changed the outcome - each with how it was handled and what it
cost. Record these when they happen and carry them forward unedited.

## 8. Lessons learned

filled in. What is now known that was not known before, graded `FACT`, `INFERENCE` or `UNKNOWN`,
and separated into what generalizes beyond this project and what does not. Include the negative
findings; they are usually the most transferable part.

## 9. Next actions

filled in. The concrete follow-ups, each with an owner and a trigger, separating what a human
must decide from what a future run could do. State explicitly what this run did **not** test.

---

## Appendix A - per-round quantitative capture (complete during the run)

The contract's real value is here. Each round appends its own row; the report then cites these
rows instead of reconstructing them.

| Round | Date/time | Kind | Changed a deliverable? | New verified fact? | Rounds started / cap | Evaluator exit | Evidence file |
|---|---|---|---|---|---|---|---|
| filled in | filled in | filled in | filled in | filled in | filled in | filled in | filled in |

Quantities decided before arming as measured, and quantities accepted as `UNKNOWN`:

filled in. List which numbers this run promised to capture each round, and which it accepted it
could not capture. Only the round cap and the round count are host-enforced; everything else is
self-reported and must be labelled that way.

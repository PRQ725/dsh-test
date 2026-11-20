# PLAN - adoption dry-run

STATUS: APPROVED
Approved by: the adopter (human), in the dry-run review step
Approval date: recorded in the dry-run evidence file
Authority: this file is the authoritative execution plan for this project.
Relationship: goal = `docs/long-running/GOAL.md` (frozen); evaluator =
`evaluator/check-project.ps1` (frozen before the goal exists).
On conflict: the goal contract and the frozen evaluator win; this plan may only shrink or
re-order work already inside the frozen success criteria.

Plan status:
APPROVED, revision r1.

Goal reference:
`docs/long-running/GOAL.md` - produce one internal onboarding guide for a fictional internal
tooling change, in at most 4 goal rounds. On conflict the goal contract and the frozen
evaluator win over this plan.

Work stages:
1. Stage A - outline and one sample chapter exist and pass the project evaluator.
2. Stage B - the remaining chapters exist, each cited, evaluator still passing.
3. Stage C - evidence chain complete for every round that ran, evaluator frozen result
   recorded, report generated at the agreed path.

Deliverables:
`docs/onboarding/GUIDE.md` (the guide), `evidence/round-<n>.md` (one per round that runs),
`evidence/EVALUATION.md` (acceptance record), `evidence/FINAL-REPORT.md` (post-run report).
The guide freezes at the acceptance gate; the evidence files stay append-only.

Verification per stage:
`pwsh -NoProfile -ExecutionPolicy Bypass -File evaluator/check-project.ps1 -Project <this
project root>` must exit 0, and each stage additionally requires its named artifact to exist
with its required sections. A stage that is only asserted complete is not verified.

Replanning triggers:
the evaluator failing for the same reason in two consecutive rounds; a round producing no new
verified fact; a source that turns out to be unavailable; or any need to widen the write
scope.

Budget:
round cap `maxGoalRounds = 4`, passed explicitly at goal creation (**HARD**). Network calls 0
(**SOFT**). Wall clock per round at most 10 minutes (**SOFT**). Token and cost: **UNKNOWN**,
because this environment exposes no meter.

Human approval:
The adopter reviewed and approved this plan. Recorded here deliberately: **approving this plan
does not create or arm the goal.** Planning and goals are independent mechanisms; the goal
will be created later, by a direct human request, with the cap above.

Amendments:
None yet. Amendment entries are append-only, dated, reasoned, and may only shrink or re-order
work inside the frozen success criteria.

Recovery reference:
`docs/long-running/STATE.md` holds the durable position. A recovery also reads the frozen goal
contract, the most recent `evidence/round-<n>.md`, the live goal runtime state, and the actual
files on disk. Automatic continuation does not survive a restart and must be re-armed by a
person.

# PLAN - blank approved plan

Copy this file into the target project, fill every field, and have it approved by a human
before execution begins. The `UNFILLED` marker means the field is still blank.

Two things this file exists to make impossible to forget:

- **The PLAN is the route inside one Goal for the complete objective.** Plan approval is a
  phase gate, not a Goal creation event. Do not create a planning-only Goal and then a second
  execution Goal for the same objective. If the Goal already exists, continue it; if not,
  create it once for the complete objective.
- **A plan is a route, not a contract.** It may only shrink or re-order work that is already
  inside the frozen success criteria. Adding scope is a proposal for the next revision.

Authorization mode:
Planning complete / Execution pending (PENDING_HUMAN) or GRANTED. After GRANTED, execute all approved stages without per-stage approval; record Human Decision Gates.

Plan status:
UNFILLED. One of `DRAFT`, `APPROVED`, `AMENDED`, `SUPERSEDED`, plus the revision number and
date. Only a human moves this to `APPROVED`.

Goal reference:
UNFILLED. The frozen objective contract this plan serves, by path, plus the one-sentence
objective so a reader does not have to open two files. State what wins on conflict.

Work stages:
UNFILLED. The ordered stages of the run. For each stage give its goal, its entry condition and
its done condition. Keep the stages small enough that one autonomous round can complete one
increment and still have time to verify it.

Deliverables:
UNFILLED. The artifacts this plan will produce, each with its exact path and its role. Name
which of them are frozen at the acceptance gate and which are evidence.

Verification per stage:
UNFILLED. The exact command that decides each stage, the artifact it inspects, and the
expected result. A stage whose verification is only "the model says it is done" is not
verified.

Replanning triggers:
UNFILLED. The concrete observations that force an amendment: the evaluator failing for the
same reason twice, a stage producing no new verified fact, evidence contradicting a stated
assumption, or a required approval that cannot be obtained.

Budget:
UNFILLED. Native `maxGoalRounds` (explicit, `HARD`); logical PLAN budget as
`SOFT logical: N` if used; every other limit `SOFT` and self-reported. State what is
measured, estimated, and what will be `UNKNOWN` because no meter exists. Never label a logical
round count as `HARD`.

Human approval:
UNFILLED. Who approved this plan, when, through which review path, and what exactly they
approved. Record it here rather than in a conversation, and repeat that approval does not arm
the goal.

Approval record:
UNFILLED. The single line a readiness check reads: who approved, the date, and the review path.
Until a person has actually approved the plan, write `NOT RECORDED` here and leave it at that.
Presence of this field proves only that a record was written; it is never proof of intent, and
no automated check may treat it as authorization.

Amendments:
UNFILLED. Append-only. Each entry carries a date, the reason, the shrinking or re-ordering
performed, and who authorized it. Never edit an earlier entry.

Recovery reference:
UNFILLED. Where the durable position lives, what a recovery must read in addition to it, and
which operation a human must perform to resume automatic continuation. Interrupted effects are
verified before being repeated.

# PLAN - blank approved plan

Copy this file into the target project, fill every field, and have it approved by a human
**before** any goal is created. The `rc.2 blank-declaration value` marker means the field is still blank.

Two things this file exists to make impossible to forget:

- **Approving this plan does not create or arm a goal.** Planning and goals are independent
  mechanisms; the toolkit only composes them by convention, plan first.
- **A plan is a route, not a contract.** It may only shrink or re-order work that is already
  inside the frozen success criteria. Adding scope is a proposal for the next revision.

Plan status:
rc.2 blank-declaration value. One of `DRAFT`, `APPROVED`, `AMENDED`, `SUPERSEDED`, plus the revision number and
date. Only a human moves this to `APPROVED`.

Goal reference:
rc.2 blank-declaration value. The frozen objective contract this plan serves, by path, plus the one-sentence
objective so a reader does not have to open two files. State what wins on conflict.

Work stages:
rc.2 blank-declaration value. The ordered stages of the run. For each stage give its goal, its entry condition and
its done condition. Keep the stages small enough that one autonomous round can complete one
increment and still have time to verify it.

Deliverables:
rc.2 blank-declaration value. The artifacts this plan will produce, each with its exact path and its role. Name
which of them are frozen at the acceptance gate and which are evidence.

Verification per stage:
rc.2 blank-declaration value. The exact command that decides each stage, the artifact it inspects, and the
expected result. A stage whose verification is only "the model says it is done" is not
verified.

Replanning triggers:
rc.2 blank-declaration value. The concrete observations that force an amendment: the evaluator failing for the
same reason twice, a stage producing no new verified fact, evidence contradicting a stated
assumption, or a required approval that cannot be obtained.

Budget:
rc.2 blank-declaration value. The round cap (explicit, `HARD`) and every other limit (`SOFT`, self-reported).
State what is measured, what is estimated and what will be reported `UNKNOWN` because no meter
exists.

Human approval:
rc.2 blank-declaration value. Who approved this plan, when, through which review path, and what exactly they
approved. Record it here rather than in a conversation, and repeat that approval does not arm
the goal.

Approval record:
rc.2 blank-declaration value. The single line a readiness check reads: who approved, the date, and the review path.
Until a person has actually approved the plan, write `NOT RECORDED` here and leave it at that.
Presence of this field proves only that a record was written; it is never proof of intent, and
no automated check may treat it as authorization.

Amendments:
rc.2 blank-declaration value. Append-only. Each entry carries a date, the reason, the shrinking or re-ordering
performed, and who authorized it. Never edit an earlier entry.

Recovery reference:
rc.2 blank-declaration value. Where the durable position lives, what a recovery must read in addition to it, and
which operation a human must perform to resume automatic continuation. Interrupted effects are
verified before being repeated.

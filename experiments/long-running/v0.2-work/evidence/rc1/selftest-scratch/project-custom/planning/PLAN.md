# PLAN - blank approved plan

Copy this file into the target project, fill every field, and have it approved by a human
**before** any goal is created. The `a declared project value` marker means the field is still blank.

Two things this file exists to make impossible to forget:

- **Approving this plan does not create or arm a goal.** Planning and goals are independent
  mechanisms; the toolkit only composes them by convention, plan first.
- **A plan is a route, not a contract.** It may only shrink or re-order work that is already
  inside the frozen success criteria. Adding scope is a proposal for the next revision.

Plan status:
a declared project value. One of `DRAFT`, `APPROVED`, `AMENDED`, `SUPERSEDED`, plus the revision number and
date. Only a human moves this to `APPROVED`.

Goal reference:
a declared project value. The frozen objective contract this plan serves, by path, plus the one-sentence
objective so a reader does not have to open two files. State what wins on conflict.

Work stages:
a declared project value. The ordered stages of the run. For each stage give its goal, its entry condition and
its done condition. Keep the stages small enough that one autonomous round can complete one
increment and still have time to verify it.

Deliverables:
a declared project value. The artifacts this plan will produce, each with its exact path and its role. Name
which of them are frozen at the acceptance gate and which are evidence.

Verification per stage:
a declared project value. The exact command that decides each stage, the artifact it inspects, and the
expected result. A stage whose verification is only "the model says it is done" is not
verified.

Replanning triggers:
a declared project value. The concrete observations that force an amendment: the evaluator failing for the
same reason twice, a stage producing no new verified fact, evidence contradicting a stated
assumption, or a required approval that cannot be obtained.

Budget:
a declared project value. The round cap (explicit, `HARD`) and every other limit (`SOFT`, self-reported).
State what is measured, what is estimated and what will be reported `UNKNOWN` because no meter
exists.

Human approval:
a declared project value. Who approved this plan, when, through which review path, and what exactly they
approved. Record it here rather than in a conversation, and repeat that approval does not arm
the goal.

Amendments:
a declared project value. Append-only. Each entry carries a date, the reason, the shrinking or re-ordering
performed, and who authorized it. Never edit an earlier entry.

Recovery reference:
a declared project value. Where the durable position lives, what a recovery must read in addition to it, and
which operation a human must perform to resume automatic continuation. Interrupted effects are
verified before being repeated.

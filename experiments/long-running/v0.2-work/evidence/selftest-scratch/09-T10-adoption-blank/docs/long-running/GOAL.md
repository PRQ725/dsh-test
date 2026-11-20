# GOAL - blank objective contract

Copy this file into the target project, fill **every** field with that project's real values,
and freeze it **before** any goal is created. The `a real project value` marker tells a reader (and any
checker) that this is still a blank form; remove it only when the field carries a real value.

While the run is active, the running loop may **not** edit this file. Improvements belong in a
proposal document for the next revision of the project's own contract.

Relationship to the other contracts: the frozen evaluator and this file outrank the plan. On
conflict, the plan loses.

Objective:
a real project value. One measurable end state for this project, stated as the result that will exist when
the work is finished. Keep it to a single objective: one goal holds one current objective per
session, so a second objective belongs in a second goal, not in this one. The text you later
pass to goal creation must be this objective, quoted verbatim.

Success criteria:
a real project value. The numbered criteria a mechanical check can verify, and separately any criterion
that only a human can judge, labelled as such. If a criterion cannot be checked by machine,
say so here rather than substituting a check that would pass trivially.

Scope boundaries:
a real project value. What the work may touch, and the roots it may write to. Name anything read-only, and
anything frozen that must not be modified even if modifying it would make a check pass.

Non-goals:
a real project value. The neighbouring problems, refactors or improvements this objective deliberately
excludes, so a helpful loop does not wander into them.

Evidence requirements:
a real project value. What each round must leave behind: one evidence file per round with the attempted
work, the verified claims, the exact command run and its raw result, whether the round changed
a deliverable, whether it produced a new verified fact, and the grade (`FACT`, `INFERENCE` or
`UNKNOWN`) of every substantive claim. State the evidence location.

Budget:
a real project value. The round cap, passed explicitly when the goal is created, marked as the only
`HARD` enforced budget. Every other limit - tokens, cost, wall clock, tool calls, information
gain - must be recorded here and labelled `SOFT`, because it is self-reported only.

Stop conditions:
a real project value. When the loop must stop: success with a recorded human-review request; the round cap
being reached; repeated rounds that yield no new verified fact; and any step that would
require a destructive action, a write outside the permitted scope, or an edit to a frozen
artifact. State for each condition whether it is `HARD` or `SOFT`, and what a `SOFT` condition
actually does (it asks a human; it does not halt the run).

Human escalation:
a real project value. The situations handed to a person immediately: writes outside the permitted scope,
any change to a frozen artifact, a destructive or irreversible action, a need for credentials
or additional infrastructure, and any conclusion that the agreed budget is insufficient.

Report path:
a real project value. The exact location of the final report, fixed here **before** the loop is armed.
Deciding this at the end is how a run's most useful output gets lost.

Report owner:
a real project value. Who generates the report, and in which turn or mode. Reporting happens after
automatic continuation has stopped, so it never consumes a round.

Acceptance authority:
a real project value. The person or role who may declare `HUMAN ACCEPTANCE`, and who may confirm the goal
complete. A model never declares either.

Evaluator location:
a real project value. Where the frozen mechanical evaluator lives, its exact invocation, its exit-code
convention, and its recorded hash. It is read-only during the run and may not be edited to make
a round pass.

Version assumptions:
a real project value. The DSH version and the packages whose behaviour this contract assumes, how that
contract was re-confirmed in this environment, and what to do if the documented behaviour
differs. Version-bound behaviour must be named as such.

Recovery expectations:
a real project value. What a person must re-arm after a resume, fork or host restart; which state is
durable and which is not; and where the durable position is written down.

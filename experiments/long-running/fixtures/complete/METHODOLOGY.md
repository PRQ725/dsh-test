# METHODOLOGY - Long-running Toolkit (FIXTURE)

FIXTURE CONTENT - this is an evaluator test fixture, not the pilot deliverable.

## 1 Objective
Objective, success criteria, scope boundaries, non-goals, evidence requirements.

## 2 Plan
Plan precedes the goal. Replan when evidence contradicts the plan.
The plan template is templates/GOAL.md.

## 3 State
Keep a small durable state file across rounds rather than regenerating a full
report every round. The state shape is templates/STATE.md.

## 4 Evaluation
Three acceptance layers must stay separate.
Machine checks are mechanical and produce an exit code.
Evidence quality is graded as FACT, INFERENCE or UNKNOWN.
Human review decides whether the methodology is actually good.

## 5 Budget
maxGoalRounds is the only hard enforced budget. Token, wall-clock and cost
limits are advisory only and must be labelled SOFT wherever they appear.

## 6 Stop
Stop on success, on the round limit, on repeated failure, or when a round
produces no new information.

## 7 Recovery
Automatic continuation is provided by @deepseek-ai/dsh-goal-round-driver. After
a host restart the durable state survives but continuation is disarmed and must
be re-armed by a human.

## 8 Knowledge deposition
Write durable notes when a conclusion is verified, not while it is still a
hypothesis. The acceptance record uses templates/EVALUATION.md.
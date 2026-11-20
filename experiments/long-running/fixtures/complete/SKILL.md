# SKILL - Long-running goal loop (FIXTURE)

FIXTURE CONTENT - this is an evaluator test fixture, not the pilot deliverable.

## When to use
Use this skill when one completion objective should continue across several
autonomous rounds and a human is available to review the result.

## Contracts
The objective contract, plan contract, state contract, evaluation contract,
budget contract and recovery contract are defined in the methodology file.
The round state template is templates/STATE.md and the acceptance template is
templates/EVALUATION.md.

## Round loop
Each round reads the current state, makes one concrete increment of progress,
verifies it, and updates the state file before the round ends.

## Stop and escalate
Stop on completion, on a round limit, or on two consecutive rounds without new
information. Escalate to a human when a destructive action would be required.
# README - Long-running Toolkit (FIXTURE)

FIXTURE CONTENT - this is an evaluator test fixture, not the pilot deliverable.

## What this is
A portable policy layer that helps an AI set up a supervised long-running loop in
a new project. It deliberately contains no project-specific goal, path or budget.

## How to use it in a new project
Copy this directory into the target project root, read that project's own
conventions and constraints first, then fill the templates in templates/ and
decide whether a long-running loop is appropriate at all.

## Compatibility
Verified against DSH 0.2.0, using the official packages @deepseek-ai/dsh-goal,
@deepseek-ai/dsh-plan-mode and @deepseek-ai/dsh-goal-round-driver. Behaviour is
version-bound. Re-confirm the mechanism contract in the target environment before
arming anything; do not assume an older or newer DSH behaves identically.
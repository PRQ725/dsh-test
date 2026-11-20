# STATE - adoption dry-run

Round:
Round 0 of a cap of 4. No goal has been created; this file records initialization position.

Completed:
- The toolkit candidate was copied into `toolkit/long-running/` unchanged (8 files).
- The project's own conventions were inventoried into `AGENTS.md`.
- The goal contract was written and frozen at `docs/long-running/GOAL.md`.
- The plan was approved and persisted at `docs/long-running/PLAN.md`.
- The project evaluator `evaluator/check-project.ps1` was written, tested and frozen.
- The report path `evidence/FINAL-REPORT.md` was fixed before arming.
- This state file was initialized.

Verified facts:
- [FACT] The toolkit copy under `toolkit/long-running/` contains exactly 8 Markdown files and
  no other file; verified with `Get-ChildItem -Recurse -File`.
- [FACT] `pwsh -NoProfile -ExecutionPolicy Bypass -File evaluator/check-project.ps1 -Project <root>`
  exits 0 on this project, and exits 1 after a deliberate mutation of a portable file, and
  exits 2 for a nonexistent project root. Raw runs in `evidence/round-0.md`.
- [FACT] Approving `docs/long-running/PLAN.md` did not create a goal. Plan approval and goal
  creation are independent, and this project deliberately has no goal.
- [INFERENCE] The toolkit's adoption steps 1-10 completed without needing any value that the
  project could not supply. The one step that could not be exercised is goal creation
  (steps 11-13), because it would start an autonomous loop.
- [UNKNOWN] Whether a locally discovered DSH skill would load `SKILL.md` in this environment:
  the file was placed at the documented discovery location with the required frontmatter, but
  no live catalog observation was made in this dry-run.

Open questions:
- Whether the adopted layout (`toolkit/` for the portable copy, `docs/long-running/` for the
  filled instances) is the best convention, or whether the toolkit should say where filled
  instances belong. It worked here; the toolkit's README does not currently prescribe it.
- What an actual first content round would reveal that initialization cannot.

Next step:
None in this dry-run: the exercise stops at initialization readiness, deliberately, and no
goal may be created here. If this were a live project, the next step would be a direct human
request to create the goal with `max_goal_rounds = 4`, followed by round 1 producing the
outline and one sample chapter.

Artifacts:
- `toolkit/long-running/**` - the portable toolkit copy; frozen, unmodified.
- `docs/long-running/GOAL.md` - frozen objective contract.
- `docs/long-running/PLAN.md` - approved plan.
- `evaluator/check-project.ps1` - frozen project evaluator.
- `evidence/FINAL-REPORT.md` - report generated at the pre-agreed path for this exercise.

Evidence:
- `evidence/round-0.md` - initialization record, commands and raw results.
- `evidence/EVALUATION.md` - evaluation contract and what it does not prove.
- `evidence/FINAL-REPORT.md` - post-exercise report.

Budget used:
Rounds consumed: 0 of 4 (**HARD**, no goal exists). Network calls: 0 (**SOFT**, reported).
Wall clock: recorded in `evidence/round-0.md` from file timestamps (**SOFT**). Token and cost:
**UNKNOWN** - no meter exists here.

Recovery also needs:
This file is not sufficient on its own. A recovery also reads `docs/long-running/GOAL.md`,
`docs/long-running/PLAN.md`, the most recent `evidence/round-<n>.md`, the live goal runtime
state, and the actual files on disk. The goal and its phase survive a restart; whether
automatic continuation is *armed* does not, and a person must re-arm it. Interrupted effects
are inspected before they are repeated.

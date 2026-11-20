# Round 0 evidence - adoption dry-run initialization

This is the record of the *initialization* exercise, not of a goal round. The dry-run
deliberately stops at initialization readiness: no goal was created, so there is no round 1.

## attempted

Follow the toolkit candidate's own README adoption procedure against a brand-new, synthetic
project with no business data, and find out whether a fresh adopter can reach a complete
long-running initialization. Steps 1-10 and 14 of the procedure were exercised. Steps 11-13
(create the goal, run rounds, generate the report after the loop stops) were **not** exercised
as intended, because step 11 would start an autonomous loop; the report contract from step 13
was exercised out of order, as a filled deliverable, so that the contract's shape could be
checked.

Steps 7 and 8 were exercised as written: the project's own evaluation contract and its own
read-only evaluator were authored, run against a real artifact, run against a real mutation,
and frozen.

## verified

| # | Claim | Grade | Source |
|---|---|---|---|
| 1 | The copied toolkit is complete: exactly 8 Markdown files, the 8 expected names, no non-Markdown file | `FACT` | `Get-ChildItem -Recurse -File` over `toolkit/long-running/` |
| 2 | The project evaluator exits 0 on the untouched project | `FACT` | raw run below |
| 3 | The project evaluator exits 1, naming the file, after one portable file is edited in place | `FACT` | raw run below |
| 4 | The project evaluator exits 2 for a nonexistent project root | `FACT` | raw run below |
| 5 | Without the candidate root supplied, the evaluator fails closed rather than skipping the comparison | `FACT` | raw run below |
| 6 | Approving the persisted plan created no goal | `FACT` | no goal-creation call was made; the project has no goal |
| 7 | Every adoption step that needs no goal produced a project-owned artifact with a real value | `FACT` | `AGENTS.md`, `docs/long-running/{GOAL,PLAN,STATE}.md`, `evaluator/check-project.ps1` |
| 8 | `SKILL.md` was placed at the documented discovery path as a directory bundle with required frontmatter | `FACT` | `.dsh/skills/long-running/SKILL.md`, first three lines |
| 9 | Whether DSH would actually load that skill in a live session | `UNKNOWN` | not observed: no session catalog was inspected, and no skill tool call was made |
| 10 | The adoption steps are complete enough that no step required a value the project could not supply | `INFERENCE` | the steps that were exercised all reached a written output |

## exact command

```powershell
$env:DRYRUN_CANDIDATE_ROOT = '<candidate root>'
& '<project>\evaluator\check-project.ps1' -Project '<project>'
```

## raw result

Untouched project - **exit 0**:

```text
check-project.ps1 - adoption dry-run project evaluator
project: <project>

PASS
  portable copy intact, filled instances carry no blank-form marker, guide complete.
  NOTE: this proves structure only; usability is a human judgement.
```

One portable file edited in place in the copied toolkit - **exit 1**:

```text
FAIL
  - P2 the copied toolkit file was edited in place: README.md

failure reasons: 1
```

Nonexistent project root - **exit 2**:

```text
ERROR: project root does not exist: <missing path>
```

Candidate root not supplied - **exit 1**, which is the fail-closed behaviour:

```text
FAIL
  - P2 no candidate root supplied; run with DRYRUN_CANDIDATE_ROOT set so the copy can be compared

failure reasons: 1
```

The last case is recorded because it was the first run actually performed, and it failed. It
is kept rather than erased: a check that silently skipped an unverifiable comparison would be
worthless, and the fix (declare the input) is part of the evidence that the evaluator was
really tested.

## progress delta

- Artifacts created in the adoption project: `AGENTS.md`, `docs/long-running/GOAL.md`,
  `docs/long-running/PLAN.md`, `docs/long-running/STATE.md`,
  `evaluator/check-project.ps1`, `docs/onboarding/GUIDE.md`,
  `evidence/{round-0,EVALUATION,FINAL-REPORT}.md`, `toolkit/long-running/**`,
  `.dsh/skills/long-running/SKILL.md`.
- Changed a deliverable: yes (initialization).
- New verified fact: yes (claims 1-8 above).

## completion gate

Not applicable: this project has no goal and no acceptance gate. The exercise's own gate is
"initialization reachable", and `ADOPTION DRY-RUN` is reported separately from the toolkit's
`MECHANICAL PASS`.

## stop status

Stopped deliberately at initialization readiness. No goal exists. A `SOFT` policy in the
toolkit has nothing to enforce here because nothing is running.

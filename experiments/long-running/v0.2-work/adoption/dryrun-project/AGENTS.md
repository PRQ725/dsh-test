# AGENTS.md - adoption dry-run project

This is a **synthetic, no-business-data** project. It exists only to exercise the adoption
procedure of the Long-running Toolkit v0.2 candidate: whether a fresh project, following the
toolkit's own README, can reach a complete long-running *initialization*. It contains no
resume data, no personal data, and no integration with any real system.

## What this project's own conventions require

These rules come first; the toolkit never overrides them.

1. **No real data.** Every artifact is synthetic. Nothing here may be copied into a real
   project as content; only the *procedure* is meant to be reusable.
2. **No goal is created in this project.** The dry-run verifies initialization readiness
   only. Creating a goal would start an autonomous loop, which this exercise deliberately
   does not do.
3. **No writes outside this project directory.** The project root is this folder.
4. **There is no version-control marker here.** This project is not a repository, so the
   toolkit's "nearest ancestor containing the version-control marker" rule falls back to the
   current working directory. Recorded as a known deviation.
5. **Frozen artifacts are read-only once recorded:** the project evaluator and the goal
   contract, once frozen, are not edited by the work they govern.
6. **Layout convention.** The portable toolkit lives under `toolkit/long-running/` and keeps
   its blank forms untouched. The project's own filled instances live under
   `docs/long-running/`, so that filling a form never destroys the reusable template.

## Project-specific facts an adopter must discover

| Item | Value in this project |
|---|---|
| Green command | `pwsh -NoProfile -ExecutionPolicy Bypass -File evaluator/check-project.ps1 -Project <project-root>` |
| Required input | `DRYRUN_CANDIDATE_ROOT` must name the candidate the toolkit copy came from; without it the evaluator fails closed rather than skipping the comparison |
| Writable scope | this project directory only |
| Read-only / frozen | `toolkit/long-running/**`, `evaluator/check-project.ps1` once frozen |
| Review owner | the adopter (a person) |
| Acceptance authority | the adopter (a person) |
| Report path | `evidence/FINAL-REPORT.md` |

# Onboarding guide - fictional internal tooling change

> Synthetic artifact. This guide describes a fictional internal tooling change so that the
> adoption dry-run has a real deliverable to verify. It contains no business data and is not
> intended to be followed anywhere.

## Purpose

Give a new team member a single end-to-end path for the fictional change: what it is, what it
needs, how to walk through it, how to confirm it worked, and how to undo it.

## Prerequisites

- Access to the fictional internal tool, granted by the team's access owner.
- The project checked out locally, with the green command available:
  `pwsh -NoProfile -ExecutionPolicy Bypass -File evaluator/check-project.ps1 -Project <root>`.
- No production credentials. The walkthrough is read-only against the fictional tool.

## Walkthrough

1. Run the green command and confirm it exits 0 before changing anything. This is the
   ground-truth step: it tells you whether the failure you are about to investigate is yours.
2. Open `docs/long-running/GOAL.md` and read the success criteria. They are the definition of
   done; nothing else is.
3. Perform the fictional change in the tool's staging area only.
4. Re-run the green command and record the raw output.
5. Write one evidence file for the round, with what you attempted, what you verified, the
   exact command and its raw result.

## Verification

- The green command exits 0.
- Every judged claim in the evidence file carries a grade: `FACT`, `INFERENCE` or `UNKNOWN`.
- A quantity nobody measured is recorded as `UNKNOWN`, not estimated.
- The guide still carries all five sections; if a section was removed, the check fails.

## Rollback

- Revert the staging change in the fictional tool.
- The toolkit copy is never edited in place, so no rollback is needed for it; if a filled
  instance was wrong, correct it in `docs/long-running/`, not in `toolkit/long-running/`.
- If the evaluator itself was touched, stop: re-verify its hash before trusting any PASS.

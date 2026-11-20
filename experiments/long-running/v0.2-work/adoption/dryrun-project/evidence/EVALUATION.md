# EVALUATION - adoption dry-run

This project has no goal, so this is an initialization record rather than an acceptance record
for a completed run. It follows the toolkit's `templates/EVALUATION.md` shape: contract first,
implementation second, and the two kept apart.

## A. Evaluation contract

Evaluation contract:
Mechanically decidable criteria, restated from `docs/long-running/GOAL.md`:
(P1) the portable toolkit copy contains exactly the 8 expected files and nothing else;
(P2) every portable file in the copy is byte-identical to the candidate it came from;
(P3) the project's filled instances exist and carry no blank-form marker;
(P4) `docs/onboarding/GUIDE.md` exists and carries its five required sections.
Human-review item: whether the guide would actually be usable by a new team member. No proxy
check is substituted for it.

Machine checks:
Command: `pwsh -NoProfile -ExecutionPolicy Bypass -File evaluator/check-project.ps1 -Project <project root>`
with `DRYRUN_CANDIDATE_ROOT` naming the candidate.
Result: **exit 0** on the final state. Raw output and the failure/error runs are in
`evidence/round-0.md`.
What it proves: structure and copy integrity only. It is a necessary condition, never a
sufficient one.

Evidence quality:
`evidence/round-0.md` is the only round evidence file, because this exercise ran zero goal
rounds. Every substantive claim there is graded `FACT`, `INFERENCE` or `UNKNOWN` with a
source. One claim is explicitly `UNKNOWN`: whether DSH would load the installed skill in a
live session.

Human review:
Questions for a person: is the adoption procedure actually followable without the author
present; is the `toolkit/` plus `docs/long-running/` layout a convention the toolkit should
prescribe; and does the toolkit earn its overhead for a project this small?
What the reviewer should distrust: the loop graded its own evidence, and the same person
authored the toolkit, the project documents and the evaluator. That is not independence.
What was not promised: no goal was created, no automatic continuation was exercised, and no
claim is made about runtime behaviour of the goal mechanisms.

## B. Evaluator implementation

Evaluator implementation:
`evaluator/check-project.ps1`, run with PowerShell 5.1+ or `pwsh`. Exit codes: 0 pass, 1 fail
with printed reasons, 2 error. Read-only: it opens no artifact for writing.

How the evaluator is authored:
Written against the frozen criteria in `docs/long-running/GOAL.md`, deliberately limited to
structure, copy integrity and required sections. It does not judge guide quality.

Frozen:
Frozen at project initialization, before any goal existed. SHA256 of
`evaluator/check-project.ps1`: `421C75B6C4B142404CA13ECC02362684670E043323EFD3973919EAD8D3AC4CC5`
(5863 bytes). Recorded from the file on disk at freeze time; the hash was read, not assumed.

Test cases:
Executed against real artifacts, not fixtures: untouched project -> exit 0; one portable file
edited in place -> exit 1 naming that file; nonexistent project root -> exit 2; candidate root
not supplied -> exit 1 (fail-closed). Raw outputs in `evidence/round-0.md`.

Tamper check:
Recompute the evaluator's SHA256 and compare with the value recorded above; re-run the four
cases. If the digest differs, no earlier PASS from this evaluator may be trusted.

Independence:
Not achieved. The same person wrote the toolkit, the project documents and this evaluator, and
ran it. Recorded here rather than implied away: a mechanically clean result from a
self-authored gate is weak evidence, and the human content acceptance is what compensates.

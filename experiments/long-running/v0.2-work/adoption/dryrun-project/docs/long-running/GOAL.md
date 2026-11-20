# GOAL - adoption dry-run

This is the project's own filled instance of the toolkit's blank objective contract. It was
frozen before any goal existed, and no goal was created. It is synthetic and governs a
fictional internal documentation objective, because the point of this project is to exercise
adoption, not to produce real content.

Objective:
Produce one internal onboarding guide for a fictional internal tooling change - a single
Markdown guide, complete enough that a new team member can follow it end to end - inside this
project, in at most 4 goal rounds, working only from sources inside this project.

Success criteria:
1. (machine) `docs/onboarding/GUIDE.md` exists and carries the sections: purpose, prerequisites,
   walkthrough, verification, rollback.
2. (machine) `pwsh -NoProfile -ExecutionPolicy Bypass -File evaluator/check-project.ps1 -Project <root>`
   exits 0, which also proves the portable toolkit copy is byte-identical to the candidate.
3. (machine) One `evidence/round-<n>.md` exists for every round that ran, each carrying
   attempted / verified / exact command / raw result.
4. (human) The guide is judged actually usable by a new team member. This is a human-review
   item and no proxy check is substituted for it.

Scope boundaries:
Writable: this project directory only (`docs/`, `evidence/`, `evaluator/`).
Read-only: `toolkit/long-running/**` (the portable copy is never edited in place), and
`evaluator/check-project.ps1` once frozen. Frozen artifacts must not be modified even if doing
so would make a check pass.

Non-goals:
No real data or real system content; no new goal; no plugin installation; no changes to any
other project; no reformatting or "improving" the toolkit copy; no attempt to make the guide
longer than it needs to be.

Evidence requirements:
One `evidence/round-<n>.md` per round that runs, with attempted work, verified claims, the
exact command, its raw result, whether the round changed a deliverable, whether it produced a
new verified fact, and a grade (`FACT`, `INFERENCE`, `UNKNOWN`) with a source for every
substantive claim.

Budget:
`max_goal_rounds = 4`, passed explicitly at goal creation: the only **HARD** budget. Network
calls 0 (**SOFT**). Wall clock at most 10 minutes per round (**SOFT**). Token use and cost:
**UNKNOWN**, because no meter exists in this environment.

Stop conditions:
1. The evaluator exits 0 and the acceptance record plus the report exist - report
   `READY FOR HUMAN REVIEW` and freeze the guide (**HARD** effect on content work; the
   reporting itself is **SOFT**).
2. Two consecutive rounds with no new verified fact - stop content work and ask a person.
   This is **SOFT**: it does not stop automatic continuation.
3. `roundsStarted` reaches 4 - the continuation driver records a round-limit blocker and stops
   (**HARD**).
4. Any step would need a destructive action, a write outside the scope above, or an edit to a
   frozen artifact - stop immediately and escalate.

Human escalation:
Writes outside this project; any change to a frozen artifact; credentials or an external host;
a conclusion that 4 rounds are insufficient; and any request to create the goal, which is
reserved to a direct human request.

Report path:
`evidence/FINAL-REPORT.md`, fixed here before any goal exists.

Report owner:
The adopter, in a human-authorized turn after automatic continuation has stopped. In this
dry-run, the same person generated it at the fixed path from the evidence files.

Acceptance authority:
The adopter (a person). A model never declares human acceptance and never confirms the goal
complete.

Evaluator location:
`evaluator/check-project.ps1`, invoked as
`pwsh -NoProfile -ExecutionPolicy Bypass -File evaluator/check-project.ps1 -Project <project root>`.
Exit codes: 0 pass, 1 fail with printed reasons, 2 error. Read-only, artifact-based, never
reads a model-declared completion claim. Frozen before the goal exists; SHA256 recorded in
`evidence/EVALUATION.md`.

Version assumptions:
DSH `0.2.0-rc.2` was the version the toolkit candidate was verified against; the goal-related
mechanism claims are version-bound to the `0.2.0` line and were not re-confirmed by a live
probe in this project. If the installed version differs, the mechanism contract must be
re-confirmed from the installed package documentation before anything is armed.

Recovery expectations:
The goal (objective, phase, revision, admitted-round count) and the plan survive a restart;
whether automatic continuation is armed does not, and a person must re-arm it. Durable
position lives in `docs/long-running/STATE.md`, which is read first and is not sufficient on
its own.

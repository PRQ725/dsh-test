# v0.2 CHANGE LIST - what changed, why, and on what evidence

> **Superseded for the current candidate by `RC1-CHANGE-REPORT.md`.** This file records the
> change inventory of the **v0.2 baseline** round. The `v0.2-rc.1` release-readiness revision
> that followed changed four candidate files (`README.md`, `SKILL.md`, `templates/GOAL.md`,
> `templates/FINAL-REPORT.md`), the evaluator, the selftest and the acceptance spec; those deltas
> and the current digests are in `RC1-CHANGE-REPORT.md` sections 3 and 6. Nothing here was
> rewritten: this remains the record of the baseline change set.

Every change is traced to (a) a specific v0.1 file and section, (b) a finding in the first
pilot's final report, or (c) an authoritative contract that was actually read in this
environment. Nothing was added to inflate the file count, and no new file was added without a
stated reason it cannot be merged into an existing one.

Paths below are repository-relative where possible. The v0.1 sources are the six frozen files
in the pilot's output directory and the pilot's own evidence; the official contracts are the
installed DSH `0.2.0-rc.2` package READMEs.

---

## 0. Two changes the audit produced that were not on the original list

**C0.1 - `SKILL.md` needs YAML frontmatter.** Not raised in the brief, found during the audit.
[FACT] The installed `@deepseek-ai/dsh-skill-filesystem` documentation states that a skill file
is parsed for frontmatter with a required kebab-case `name` and a `description`, and that a
file whose frontmatter is missing or malformed is dropped **with a warning that never reaches
the model catalog**. The v0.1 `SKILL.md` has no frontmatter, so the file could not be a loadable
skill in any deployment that scans its directory. The v0.2 candidate adds the frontmatter.
Trace: `SKILL.md` (v0.1) first line; `@deepseek-ai/dsh-skill-filesystem` README, "Skill format"
and "Observable success and failures".

**C0.2 - the "copy it and DSH loads it" claim had to be split in two.** Also not in the brief.
[FACT] Discovery is **depth one** only (`<root>/<name>/SKILL.md` or `<root>/<name>.md`), the
project root is the nearest ancestor containing the version-control marker (falling back to the
current working directory), and the documented roots are the project's `.dsh/skills`, the
project's `.agents/skills`, configured custom directories, then the user-level roots. [FACT] The
shipped profile bundle mounts the registry, the filesystem provider and the model-facing tool.
[UNKNOWN] Whether this toolkit's own `SKILL.md` would actually be loaded: no live session
catalog was observed. v0.2 documents both the explicit-read path and the discovery path, and
marks the second as unverified here.
Trace: `@deepseek-ai/dsh-skill-filesystem` README, "Roots and priority" and "Known
limitations"; `@deepseek-ai/dsh-tool-skill` README; `@deepseek-ai/dsh-base` `cordis.patch.yml`
lines 294-305.

---

## 1. P0 - new-project adoption procedure was incomplete

**Source.** v0.1 `README.md` "How to use it in a new project": eight numbered items, each one or
two sentences, none of them naming a concrete input, output or approval gate. It explained the
shape of adoption without making adoption executable.

**Change.** `README.md` rewritten around a 14-step adoption procedure, each step naming what it
consumes and what it produces, with `[HUMAN]` marks on the steps that require a person, plus
explicit sections for "when to use it" and "when not to use it" and an unambiguous statement
that a plan can be approved without arming a goal.

**Trace.** v0.1 `README.md` §"How to use it in a new project" items 1-8; brief section 四 items
1-15; first pilot final report §9 item 3 (promotion deliberately outside the pilot's scope, so
the adoption path was never exercised by a real second project).

**Verification.** Evaluator V10 (14 steps present, both approval gates stated); exercised for
real in the adoption dry-run (see `evidence/DRY-RUN-EVIDENCE.md`).

---

## 2. P0 - no Final Report contract

**Source.** [FACT] the first pilot's report says it plainly: "neither `GOAL.md`, `PLAN.md` nor
the toolkit specified a post-run report: no path, no owner, no required sections, no timing",
and the report had to be specified in a post-run human turn and reconstructed from artifacts.
The pilot's own "REPORTING CONTRACT PROPOSAL v0.2" (P1-P9) is the direct antecedent.

**Change.** New `templates/FINAL-REPORT.md`; `templates/GOAL.md` gains `Report path`,
`Report owner`, `Acceptance authority`, `Evaluator location` and `Version assumptions`; the
report contract is fixed before arming, the report itself is generated after the run from the
evidence, an appendix fixes the per-round quantitative capture, and terminal run state is kept
separate from human acceptance.

**Trace.** first pilot `evidence/FINAL-REPORT.md` §8 "Missing Final Report specification" and
"Reporting discipline observation"; its REPORTING CONTRACT PROPOSAL v0.2 P1-P9; v0.1
`templates/GOAL.md` (which had no report field at all).

**Why a new file rather than folding it into `EVALUATION.md`.** The two contracts answer
different questions at different times: `EVALUATION.md` is written at the acceptance gate about
*this* artifact, while the report contract must exist **before** the goal is armed and governs
data collection *during* the run. Merging them would put a pre-run contract inside a post-run
record.

**Verification.** Evaluator V7; dry-run `evidence/FINAL-REPORT.md` was generated from the
pre-agreed path to prove the contract is fillable.

---

## 3. P1 - the plan was not persisted

**Source.** [FACT] the pilot's plan existed only in the session event stream until a human
approved it and it was written to `PLAN.md` (pilot `PLAN.md` §0.D records the rule being added
in revision r3, after the gap had already been felt). v0.1 `METHODOLOGY.md` §2 tells the reader
to plan first and never says where the approved plan lives.

**Change.** New `templates/PLAN.md` covering plan status, goal reference, work stages,
deliverables, per-stage verification, replanning triggers, budget, human approval, append-only
amendments and the recovery reference. `METHODOLOGY.md` gains section F on persistence and
versioning; `SKILL.md` gains a "Plan approval" step stating that approval does not arm the goal.

**Trace.** pilot `PLAN.md` §0.D; v0.1 `METHODOLOGY.md` §2; first pilot final report §8
"Missing Final Report specification" (the same class of gap: a contract that no artifact held).

**Why a new file.** A plan has a lifecycle of its own — draft, approved, amended — and must be
read by both the loop and the human without opening the objective contract. Putting it inside
`GOAL.md` would make the frozen objective mutable by every replan.

**Verification.** Evaluator V1/V10 on the new template; dry-run wrote and approved a real plan
before any goal existed.

---

## 4. P1 - no general evaluator design procedure

**Source.** [FACT] v0.1 `templates/EVALUATION.md` is a three-field acceptance record
(`Machine checks:`, `Evidence quality:`, `Human review:`). It records that a check was run; it
says nothing about how to author one, test it, freeze it or keep it independent — and the
toolkit's only evaluator was one the toolkit's author had already written by hand. The pilot
report notes the consequence: "the loop graded its own evidence, with no independent judge of
claim quality".

**Change.** `templates/EVALUATION.md` restructured into two halves — evaluation **contract** and
evaluator **implementation** — with authoring, freeze, PASS/FAIL/ERROR test cases, tamper check
and independence. `METHODOLOGY.md` gains section C (the evaluator's own lifecycle) and section B
(the three acceptance layers as three different questions). `SKILL.md` gains an "Evaluator
design and freeze" step.

**Trace.** v0.1 `templates/EVALUATION.md` (all three fields); v0.1 `METHODOLOGY.md` §4; first
pilot final report §5 "What the evaluation does NOT establish", §8 "Limits of a SOFT stop
policy".

**Verification.** Evaluator V6; the dry-run project authored, tested and froze a *different*
evaluator of its own (`adoption/dryrun-project/evaluator/check-project.ps1`), which is the real
test of whether the procedure is followable.

---

## 5. P1 - no stop capability after early completion

**Source.** [FACT] first pilot final report §7 item 4: "`READY FOR HUMAN REVIEW` cannot stop the
driver ... the goal remained `armed` until the cap", and §8: "A stop condition that the
executing agent cannot enforce is a *request to a human*". The pilot's own plan had already
established the mechanism facts behind it.

**Change.** No new mechanism, and no new plugin. `METHODOLOGY.md` section D states the real
execution semantics in a HARD/SOFT table; `SKILL.md` "Stop and escalation" says plainly that
`READY FOR HUMAN REVIEW` stops nothing, that the model cannot pause or re-arm its own goal, and
that manufacturing a terminal goal state to end a run is a false claim. It also records the one
real capability honestly: a terminal lifecycle action *is* accepted inside an autonomous round
and does end it — which is exactly why the rule against using it as a brake is a rule.

**Trace.** first pilot final report §7 item 4, §8 "Limits of a SOFT stop policy"; v0.1
`SKILL.md` §"Stop and escalate"; `@deepseek-ai/dsh-tool-goal` README "Authority rules";
`@deepseek-ai/dsh-goal-round-driver` README "When continuation stops" and "After resume, fork,
or unload"; `@deepseek-ai/dsh-goal` README "Drive the lifecycle".

**Deliberate non-change.** No stop controller was built. The brief forbids it this round, and
the audit found no way to enforce an early stop from inside a round: the only real levers are a
human pause and the cap. Claiming otherwise in a prompt would be the exact defect section D
documents.

**Verification.** Evaluator V8.

---

## 6. P2 - internal consistency

**Source.** v0.1 `METHODOLOGY.md` §3 states "**The state file is the only thing the next round
must read**" — an over-claim: the next round also needs the frozen objective, the approved plan,
the most recent evidence and the actual filesystem state. v0.1 `README.md` §"What this is"
described "the four documents a project fills in" without naming them.

**Change.** `METHODOLOGY.md` §3 now carries an explicit correction and states that the state
file is the *first* thing read and **not** sufficient on its own; `templates/STATE.md` adds a
`Recovery also needs:` field and an opening paragraph listing the other sources, with the rule
that the filesystem wins on disagreement. `README.md` carries an explicit eight-file table and
states the count so a stale count is detectable.

**Trace.** v0.1 `METHODOLOGY.md` §3; v0.1 `templates/STATE.md`; v0.1 `README.md` §"What this
is"; `@deepseek-ai/dsh-goal` README "What survives and what does not".

**Verification.** Evaluator V4 (count consistency) and V5 (responsibility boundaries, no
"only file" claim).

---

## 7. P2 - Skill discovery and installation

Covered by C0.2 above. Summary of the change: `README.md` gains a section that separates a
`SKILL.md` document from a loadable skill, gives the two honest installation paths, states the
frontmatter, depth and root facts as `FACT`, and marks the unexecuted part `UNKNOWN`.
`SKILL.md` gains a "Skill installation and discovery" section saying the same thing
operationally, plus the frontmatter C0.1 requires.

---

## 8. Structural changes to the eight files

| File | v0.1 | v0.2 | Nature |
|---|---|---|---|
| `README.md` | 4837 B, 3 sections | 16201 B, 6 sections | rewritten: adoption procedure, when/when not to use, skill installation, compatibility |
| `SKILL.md` | 6113 B, 4 sections | 18738 B, frontmatter + 15 sections | rewritten: 14 named steps with inputs, outputs and human gates; new discovery section |
| `METHODOLOGY.md` | 11394 B, 8 sections | 22930 B, part 1 (8 sections) + part 2 (A-J) | extended: part 1 kept, part 2 adds the ten required distinctions |
| `templates/GOAL.md` | 2253 B, 8 fields | 4151 B, 14 fields | extended: report path/owner, acceptance authority, evaluator location, version assumptions, recovery |
| `templates/PLAN.md` | - | 2669 B, 10 fields | **new** (see change 3) |
| `templates/STATE.md` | 1547 B, 8 fields | 2327 B, 9 fields | extended: `Recovery also needs:`; over-claim removed |
| `templates/EVALUATION.md` | 1273 B, 3 fields | 3832 B, 2 halves / 15 fields | restructured: contract versus implementation |
| `templates/FINAL-REPORT.md` | - | 5032 B, 9 sections + appendix | **new** (see change 2) |
| `PROPOSALS.md` | did not exist in v0.1 | still does not exist | deliberately not added; see below |

Files that were deliberately **not** added: a `PROPOSALS.md` (the pilot's own next-actions list
mentions it, but it is pilot-workspace governance, not portable toolkit content, and the
toolkit already tells the reader to keep improvements outside the frozen contract), a
changelog, and a separate skill-install document (the content fits in `README.md` and
`SKILL.md` without duplication).

---

## 9. What was explicitly not changed

- The v0.1 six-file artifact: **unchanged**. Its digests were re-read and match the freeze
  record exactly, and `Evaluator v0` still exits 0 on it.
- `experiments/long-running/check.ps1` (Evaluator v0): **unchanged**, digest
  `F3D22F99A59C4316A7DD0764FE7B83E441B91DD40148A53B2022E82A33C7BDA7`. It is not used to judge
  the v0.2 candidate, and the candidate is allowed to fail it.
- `PILOT-SPEC-v0.1.md`, `RUNBOOK.md`, `check.selftest.ps1`, `fixtures/`: **unchanged**.
- The pilot workspace, its evidence, its `GOAL.md`, its `PLAN.md` and its final report:
  **unchanged**; nothing outside `D:\Projects\dsh-test` was written.
- No goal was created, no automatic loop was started, no plugin was installed, no profile or
  global DSH configuration was touched, no network research was performed, and no real business
  project was modified.

## 10. Files created this round (all additions)

```
experiments/long-running/v0.2-work/
    V0.2-ACCEPTANCE-SPEC.md            frozen acceptance rules (V1-V12, R1-R3) + amendments A1, A2
    CHANGE-LIST.md                     this document
    candidate/long-running/            the 8-file candidate (bucket B)
        README.md  SKILL.md  METHODOLOGY.md
        templates/{GOAL,PLAN,STATE,EVALUATION,FINAL-REPORT}.md
    evaluator/
        check-v0.2.ps1                 v0.2 evaluator (frozen; digest in CHECK-REPORT)
        check-v0.2.selftest.ps1        12-case regression harness over real candidate copies
    evidence/
        CHECK-REPORT.md                mechanical result, selftest matrix, deviations, digests
        DRY-RUN-EVIDENCE.md            adoption exercise record and verdict
        INVOCATION.md                  how to run the evaluator on this host, and why
        candidate-run.log              raw candidate-mode output
        adoption-run.log               raw adoption-mode output
        selftest-scratch/              the 10 real mutated copies and their raw logs
    adoption/dryrun-project/           the synthetic adopting project (bucket: test data)
        AGENTS.md
        .dsh/skills/long-running/SKILL.md
        toolkit/long-running/**        byte-identical copy of the candidate
        docs/long-running/{GOAL,PLAN,STATE}.md
        docs/onboarding/GUIDE.md
        evaluator/check-project.ps1
        evidence/{round-0,EVALUATION,FINAL-REPORT}.md
```

One existing file was edited: `experiments/long-running/README.md` (registers the v0.2
development line so the experiment index does not go stale). No existing file was deleted.

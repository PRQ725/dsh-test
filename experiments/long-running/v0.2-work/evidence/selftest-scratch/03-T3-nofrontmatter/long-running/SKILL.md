# SKILL - operating procedure for one supervised long-running goal loop

This is the procedure. `METHODOLOGY.md` explains why the contracts relate the way they do;
`README.md` explains what the toolkit is and contains the adoption procedure a human follows.

Every step below states its **Input** and **Output**. Steps marked **[HUMAN GATE]** cannot be
completed by the model: they need a direct human decision, and the model's job is to stop and
ask. Steps marked **[HARD]** rest on host-enforced behaviour; **[SOFT]** marks a policy the
loop follows but nothing enforces.

Do not start at step 8. The order is the method.

---

## Applicability

**Input:** a candidate objective, plus the adopter's answers to the "when not to use" list in
`README.md`.
**Output:** a go / no-go decision with the deciding reason written down.

Go only when all five applicability conditions hold: one objective too large for one turn; an
end state describable in advance with mechanically checkable criteria (or an explicit human
review item); naturally incremental progress; a reachable human; and work that is safe to
repeat. Otherwise stop here and do the work directly. A loop armed on subjective or
unbounded work produces rounds with no verifiable progress and no honest stopping point.

**[SOFT]** This check is a judgement; nothing enforces it. Its value depends on the human
actually applying it before arming anything.

## Skill installation and discovery

**Input:** this toolkit's `SKILL.md`, and the target environment's skill configuration.
**Output:** either an explicitly-read procedure, or a locally discovered skill that was
confirmed in the session catalog.

Two different objects are routinely confused, so separate them first:

- a **`SKILL.md` document**: a file an AI or a person reads;
- a **skill DSH can discover and load**: an entry in the session skill catalog, produced by a
  mounted skill provider.

**Copying a file into a project root does not create a loadable skill.** [FACT] In the shipped
profile bundle of the verified version, the local Skill provider scans, at a **depth** of one
level, either a directory bundle named like the skill with `SKILL.md` inside it, or a flat
skill file at the top level of a scanned root; nested trees are deliberately not discovered.
[FACT] It requires YAML **frontmatter** with a kebab-case name and a description, and a file
whose frontmatter is missing or malformed is dropped with a warning - the model-side catalog
receives no per-skill diagnostic, so an invalid skill is indistinguishable from an absent one.
[FACT] The documented roots are the project's own skill directory, the project's shared agents
directory, configured custom directories, then the user-level roots, with the project root
resolved as the nearest ancestor carrying the version-control marker and the current working
directory used when there is none.

Consequently there are two honest installation paths:

1. **Explicit read (always available).** Keep the toolkit as a folder and instruct the agent to
   read this file, or reference its path from the goal document. Nothing is discovered, so
   nothing can silently fail.
2. **Local discovery (verify before relying on it).** Place the file where the provider scans,
   as a directory bundle with frontmatter as its first line, then confirm the skill appears in
   the session catalog. Adding the frontmatter is a prerequisite, not a formality.

[UNKNOWN] Whether discovery in the target environment actually loads this toolkit was **not**
executed while producing it: no skill was installed and observed in a live catalog. Treat path
2 as a documented, plausible procedure to be confirmed locally - never as "copy it and DSH
picks it up automatically", and never as a promise this toolkit can make on another version's
behalf.

## Project discovery

**Input:** read access to the target project.
**Output:** a written inventory of the project's own conventions and constraints.

Before writing any contract, find out how the target project already works: its instruction
files and what they forbid; the exact command that decides "green"; the paths writable by the
work and the paths that are frozen or read-only; whether it is under version control and what
the rollback is; who reviews and who accepts. The toolkit never overrides local rules, and
every value you later write into `templates/GOAL.md` must come from this inventory rather
than from assumption.

**[HARD]** the file sandbox: writes outside the permitted scope are refused by the host.
Discover the actual scope instead of asserting it.

## Goal design

**Input:** the inventory from project discovery, and `templates/GOAL.md`.
**Output:** a filled, frozen goal document, ready to be quoted verbatim at goal creation.

Fill every field, including report path, report owner, acceptance authority, evaluator
location and version assumptions. State success criteria so a mechanical check can decide
them; where a criterion cannot be checked mechanically, label it a human-review item rather
than substituting a proxy check that always passes. Name the write scope and everything that
is frozen. **[HUMAN GATE]** the goal document is approved and frozen before anything is
armed; the running loop may never edit it.

Why the insistence: an autonomous round has no memory of your intent beyond what is written
down. A durable goal carries an objective string, not your reasoning, your quality bar, or
the things you assumed nobody would do.

## Plan approval

**Input:** the frozen goal document, plus `templates/PLAN.md`.
**Output:** an approved plan persisted at a stable path in the project, marked with its
approval record.

Write the stages, the deliverable and the verification for each stage, the replanning
triggers, the budget, and the amendment rule. **[HUMAN GATE]** a human approves it, and the
approval is recorded in the file itself.

Two facts the plan must not pretend otherwise about. First, approving a plan **does not**
create or arm a goal: the two are independent mechanisms and this procedure only composes
them by convention, in this order. Second, plan mode is guidance, not enforcement — the tool
surface is not reduced while planning, so plan approval is a design review, not a safety
boundary.

Amendments are append-only and may only shrink or re-order work already inside the frozen
success criteria. Adding scope is a proposal for the next revision, never something a running
round awards itself.

## Evaluator design and freeze

**Input:** the success criteria in the goal document.
**Output:** a read-only evaluator program, its test record, its hash, and a frozen evaluation
contract in `templates/EVALUATION.md`.

Separate the two objects the whole time:

- the **evaluation contract** — what must be checked, the pass criteria, who decides;
- the **evaluator implementation** — the script that performs the checks.

A Markdown acceptance record is a contract. It is not an evaluator. Never call a checklist a
mechanical check.

Then: author the evaluator; exercise **PASS**, **FAIL** and **ERROR** with real artifacts,
including real mutated copies for the failures, so a passing run is distinguishable from a
run that never executed; record its hash; and freeze it before arming. **[HUMAN GATE]** the
freeze and the PASS/FAIL/ERROR evidence are reviewed, and the evaluator may not be edited
afterwards by anyone participating in the run.

**[HARD]** rule for the whole run: never edit the acceptance baseline or the evaluator to make
a round pass. A failure list is not an obstacle to be removed; it is the to-do list.

## State and evidence initialization

**Input:** `templates/STATE.md` and the choice of evidence location.
**Output:** an initialized state file and an empty per-round evidence series.

Record round 0, the verified facts that already hold (the green command, the write scope, the
frozen artifacts and their hashes) and the single next step. Then commit to one evidence file
per round.

Be accurate about what state is: it is the *first* thing a recovery reads, not the only one.
A recovery may also need the frozen goal document, the approved plan, the most recent
evidence, the live goal runtime state, and the actual state of the files on disk. Where a
state file and the filesystem disagree, the filesystem wins.

## Budget and safety review

**Input:** the requested round cap, the sandbox mode and approval policy actually in effect.
**Output:** a budget table in which every line is labelled `HARD` or `SOFT`, and a recorded
safety boundary.

**[HARD]** the only enforced budget is the goal's round cap `maxGoalRounds`: the continuation
driver stops at the cap and records a stable `round-limit` blocker. Everything else — token,
cost, wall clock, tool calls, information gain — is **[SOFT]**: reported by the loop, verified
by a human from evidence, enforced by nothing. A limit written into a prompt, a plan or this
document is not a budget; label it `SOFT` wherever it appears.

If the environment has no meter for a quantity, write `UNKNOWN`. Do not estimate a number to
fill a table.

**[HUMAN GATE]** the adopter confirms the sandbox mode and approval policy in force, and
confirms that the write scope in the goal document matches reality. Also confirm the version
contract before arming: locate the installed package documentation in the target environment
and re-confirm the goal authority rules, activation semantics and round-cap behaviour.

## Goal activation

**Input:** the frozen goal document and the plan approval record.
**Output:** one live goal with an explicit round cap.

**[HUMAN GATE]** goal creation requires a direct human request. Pass the cap explicitly;
omitting it selects the deployment default. Verify in the creation result that the cap is the
one you intended and that continuation is armed. **[HARD]** creating a goal starts the loop:
there is no safe "create then immediately pause" step to hide behind, because pausing is
itself a human operation. Everything before this step is the safety gate.

Note what planning permission does and does not give you: exiting plan mode does not create a
goal, and creating a goal does not require a plan. Do not describe them as one mechanism.

## Round execution

**Input:** the live goal, the state file, the approved plan, and the latest evidence.
**Output:** one concrete increment, a fresh mechanical result, one evidence file, and an
updated state file.

Each round runs the same six steps:

1. **Read durable state** — the state file, the most recent evidence, and the approved plan.
   Re-derive the position from what was written down; do not trust a narration of the
   previous round.
2. **Re-verify ground truth** — run the frozen evaluator and record its raw result before
   changing anything.
3. **Make one increment** — produce the next piece of the deliverable. One round, one
   increment; a round that tries to finish everything verifies nothing.
4. **Verify mechanically** — run the evaluator again and record the exact command and raw
   output.
5. **Write one evidence file** — attempted, verified, exact command, raw result, whether the
   round changed a deliverable, whether it produced a new verified fact, and the grade
   (`FACT` / `INFERENCE` / `UNKNOWN`) of every substantive claim.
6. **Update state** — so the next round, or a fresh process, can start from it.

Round discipline: never write outside the permitted scope; never perform a destructive
action; never edit the frozen baseline or the evaluator; never pad an empty round. A round
that produced no new verified fact must say so explicitly — an honest empty round is
information.

## Stop and escalation

**Input:** the live goal state and the evidence series.
**Output:** a reported end state, an escalation, or a stop request — never a self-granted
acceptance.

Ranked by what actually enforces them:

1. **Success** — the evaluator passes and the acceptance gate is satisfied. Report
   `READY FOR HUMAN REVIEW`, persist the marker in the state file and the evidence, and
   **freeze the deliverables**: from then on only read-only re-verification and record-keeping,
   so what the human reviews cannot change while they review it.
2. **Round cap** **[HARD]** — the driver stops at the cap and records `round-limit`. This is
   the only backstop that cannot be ignored.
3. **Repeated failure** **[SOFT]** — two consecutive rounds with no new verified fact means
   stop content work and ask a human. This is a request, not a halt.
4. **Unsafe step required** — a write outside scope, an edit to a frozen artifact, a
   destructive or irreversible action, or a need for credentials or a second host. Stop and
   escalate immediately instead of negotiating with the boundary.

Be exact about stopping, because this is where a loop misleads its operator:

- `READY FOR HUMAN REVIEW` is a **status report**. It stops nothing. While the goal is active,
  armed and idle with allowance remaining, the next round will be queued regardless of what
  the state file says.
- **[HARD]** the model cannot pause, resume or re-arm a goal: those operations require a
  direct human turn. The human-facing pause path is the only immediate early stop.
- Do not manufacture a terminal goal state to stop the loop. Declaring the goal complete or
  blocked in order to end the run is a false claim about the work, and it corrupts the record
  a human needs. Awaiting a human is not a blocker and not a completion.
- **[INFERENCE]** the practical consequence for a supervised run: if nobody is watching, the
  loop consumes its remaining rounds. Choose a small cap, and treat "the human will notice"
  as an assumption to record, not a mechanism.

Escalate rather than improvise whenever a step would need an approval the loop cannot obtain,
a scope it does not have, or a judgement reserved to a human.

## Recovery

**Input:** the durable state, the evidence series, and the live runtime state.
**Output:** a re-derived position and an explicit statement of what must be re-armed by a
human.

Recovery rests on knowing what survives what. Durable: the goal (objective, phase, revisions,
admitted-round count), the approved plan, the state file, the evidence files, the artifacts.
**[HARD]** not durable: whether continuation is currently armed. After a resume, a fork or a
process restart the goal is disarmed and will not revive itself; a human re-arms it.

Interrupted work is handled by checking, not by assuming:

- **Interrupted tool calls.** A call recorded without a result recovers with an *unknown*
  outcome, because the runtime cannot prove whether the side effect landed. Inspect actual
  state before repeating anything that had side effects. No result is not evidence of no
  effect.
- **Interrupted rounds.** Re-derive position from the state file, the plan and the evidence —
  never from what the previous round "was about to do".
- **Partial artifacts.** A partially written deliverable simply fails the evaluator. That
  failure is the signal and needs no special machinery.
- **Stale plans.** If evidence contradicts the approved plan, amend the plan (append-only,
  shrink-or-reorder only) rather than silently departing from it.

**[HUMAN GATE]** re-arming continuation after any of these events.

## Final reporting

**Input:** the frozen goal document's report path and owner, and the accumulated per-round
evidence.
**Output:** one report at the pre-agreed path, generated from evidence rather than memory.

The report contract (see `templates/FINAL-REPORT.md`) is fixed **before** arming, together
with the path, the owner and the quantities that will be captured each round. During the run,
each round appends its own quantitative evidence; after the run, the report cites those files.
A quantity that was never captured is `UNKNOWN` — inventing a plausible value is a report
defect, not a rounding choice.

Reporting happens **after** automatic continuation has stopped, so reporting can never consume
a round or extend the run. In DSH `0.2.0-rc.2` the practical mode is a post-run,
human-authorized reporting turn; that is one implementation of the contract, not part of the
method.

Report the run's terminal state and the human acceptance status as separate facts. A run that
ended at its round cap has not been accepted, and a clean evaluator does not change that.

## Human acceptance

**Input:** the frozen artifacts, the evidence chain, and the report.
**Output:** a recorded human verdict, with the four states kept distinct.

| State | Meaning | Who may declare it |
|---|---|---|
| `MECHANICAL PASS` | the frozen evaluator exited 0 | the evaluator only |
| `READY FOR HUMAN REVIEW` | mechanical pass and a complete evidence chain | the loop may *report* this |
| `HUMAN ACCEPTANCE` | a person judges the result genuinely usable and portable | the human only |
| `GOAL COMPLETE` | human acceptance recorded, then the goal confirmed | the human only |

**[HARD]** The model never accepts its own work and never declares the goal complete. A
self-declared completion is a proposal for a human to accept or reject. Say plainly in the
acceptance record what the loop could not promise, what the reviewer should distrust, and
which claims are still `UNKNOWN` — including the fact that a loop grading its own evidence has
no independent judge.

## Knowledge deposition

**Input:** the accepted result plus the full run record.
**Output:** conclusions written down at the level where they will be reused.

Deposit at three levels: per round (the evidence file, exact command and raw result), per
project (the state file and the final report), and per acceptance (the evaluation record with
the human verdict). Write conclusions when they are verified, not while they are still
hypotheses, and keep failed approaches: a dead end that is written down saves the next attempt
from repeating it.

Finally, separate the buckets one last time. A development candidate is not a release.
Promotion to the release location is a separate, human-authorized step that copies the
accepted bytes and re-runs the frozen evaluator there; the copy is never edited. Anything
that needs changing becomes the next version, and the previous one keeps its record.

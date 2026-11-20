# METHODOLOGY - why the long-running contracts relate the way they do

This file is the reasoning behind the contracts. `SKILL.md` is the procedure; `README.md` is
what the toolkit is and how a project adopts it.

Version note: every mechanism claim below was derived from locally installed documentation
for one DSH release (**version-bound**, see `README.md` Compatibility) and must be
re-confirmed in the target environment before it is relied on. Claims are graded with the
convention in section 4.

Part 1 keeps the eight contracts of v0.1. Part 2 adds the distinctions that the first pilot
showed were missing: responsibility boundaries, the double meaning of "evaluation", the
evaluator's own lifecycle, the real semantics of stopping, `UNKNOWN` discipline, plan
persistence, the report contract, idempotent recovery, portability, and release hygiene.

---

# Part 1 - the eight contracts

## 1 Objective

A long-running loop is worth starting only when the end state can be described before the
work begins, so the objective contract forces its statements to be written down first: the
objective itself, success criteria, scope boundaries, non-goals, evidence requirements,
budget, stop conditions, human escalation, and the report path, owner, acceptance authority,
evaluator location and version assumptions.

The reason for the insistence is that an autonomous round has no memory of your intent beyond
what is written down. A durable goal carries an objective string; it does not carry your
reasoning, your quality bar, or the things you assumed nobody would do. Anything not written
into the contract is, from the loop's point of view, undefined.

Success criteria must be **mechanically checkable wherever possible**, because a machine check
is the only progress signal a round can produce without human judgement. Where a criterion
genuinely cannot be checked mechanically, the contract must say so and route it to human
review. Inventing a proxy check that always passes is worse than no check: it converts an
unknown into a false fact.

## 2 Plan

The plan precedes the goal. Planning and goals are **independent official mechanisms**:
approving a plan does not create or arm a goal, and arming a goal does not require a plan.
This toolkit composes them by convention, in that order, because a reviewed plan is the
cheapest place to discover that an objective was never achievable.

Planning mode is **guidance, not enforcement**. The tool surface is not reduced while
planning, so "no mutations during planning" is a policy the model follows, not a boundary the
host imposes. Do not describe a plan as a safety gate; the real gates are the file sandbox,
the approval policy, and the authority rules on goal mutation.

Two rules keep the plan honest. **Replan trigger:** if evidence contradicts the plan, or a
round cannot make progress, revise the plan before continuing — repeating an approach that has
already failed is not persistence, it is waste. **Drift control:** a plan may only shrink or
re-order work already inside the frozen success criteria; adding scope is a proposal for the
next revision, never something a running round awards itself.

## 3 State

Each round keeps one small durable state file, not a full report: the shape is fixed by
`templates/STATE.md`. Two design choices follow from how long loops actually fail. A small
state file is cheap to read and survives condensation, truncation and resumption, where a
transcript does not. And evidence is **one file per round**, not a growing log, because a
per-round record stays auditable by a human who was not present, while an append-only log
becomes unreadable exactly when it matters.

Durable state and *continuation permission* are different things. Goal state is durable;
whether the loop is currently allowed to continue automatically is not. After a session
resume or fork the state is still there but continuation comes back disarmed, and only a human
can re-arm it. A round must therefore never conclude from "the goal still exists" that "the
loop will keep running".

**Correction to v0.1.** The earlier text claimed the state file is "the only thing the next
round must read". It is not. Reading it first is a rule; treating it as sufficient is a
mistake. Recovery may also need the frozen goal document, the approved plan, the most recent
evidence, the live goal runtime state, and the actual filesystem state. Where the state file
and the filesystem disagree, the filesystem is the better witness.

So the honest formulation is: `templates/STATE.md` is the *first* file a round or a recovery
reads, and it is **not** the only required one. A state file that has drifted from the
filesystem, or that omits the plan and the latest evidence, will send the next round to the
wrong place faster than no state file at all.

## 4 Evaluation

Three acceptance layers, never collapsed into one:

| Layer | Who decides | Mechanism |
|---|---|---|
| **Machine** acceptance | the evaluator | a read-only, artifact-based program that exits 0 on pass and non-zero on failure; it never reads a model's completion claim |
| **Evidence** quality | the loop, graded | every substantive claim labelled `FACT`, `INFERENCE`, or `UNKNOWN`, with a source |
| **Human** review | a human | whether the result is genuinely usable, and whether the method is honest |

The grade vocabulary is deliberately small:

- **FACT** - observed directly in this environment, or stated by an authoritative local source
  that was actually read; reproducible from the recorded command.
- **INFERENCE** - a conclusion drawn from facts, where the reasoning step could be wrong.
  Record what it rests on.
- **UNKNOWN** - not established. Say so instead of guessing. A recorded `UNKNOWN` is a useful
  artifact; a confident guess is a liability.

**A green mechanical check is a necessary condition, never a sufficient one.** A structural
evaluator can prove that artifacts exist, that required fields are present and that internal
references resolve. It cannot tell whether the method is any good. A model's self-declared
completion is likewise a proposal, not an acceptance.

Keep four states distinct:

| State | Meaning | Who may declare it |
|---|---|---|
| `MECHANICAL PASS` | the evaluator exited 0 | the evaluator only |
| `READY FOR HUMAN REVIEW` | mechanical pass and a complete evidence chain | the loop may *report* this |
| `HUMAN ACCEPTANCE` | a human judges the result usable and portable | the human only |
| `GOAL COMPLETE` | human acceptance recorded, then the goal confirmed | the human only |

## 5 Budget

Budgets split into exactly two kinds, and confusing them is the most common way a long loop
misleads its operator:

| Budget | Enforcement |
|---|---|
| the goal's round cap `maxGoalRounds` | **HARD** - the continuation driver stops the loop at the cap and records a stable round-limit blocker |
| token, currency, wall-clock, tool-call and information-gain limits | **SOFT** - self-reported by the loop and verified by a human reading the evidence |

A limit written into a prompt, a plan, or a methodology is **not** an enforced budget and must
be labelled `SOFT` wherever it appears. The only budget a long loop cannot simply ignore is
the round cap, because a separate mechanism enforces it rather than the model.

Practical consequences: pass the cap explicitly when creating the goal, because omitting it
selects the deployment default; do not promise cost or time ceilings you cannot meter; and
treat "no new verified fact in two consecutive rounds" as a `SOFT` stop condition that stops
content work and asks for a human without halting the loop.

## 6 Halting

Stop conditions are ranked by what actually enforces them:

1. **Success** - the evaluator passes and the acceptance gate is satisfied. Report it; do not
   self-accept, and freeze the deliverables at that moment.
2. **Round cap** - the driver records a round-limit blocker and stops. This is the hard
   backstop and the reason a supervised loop cannot run forever.
3. **Repeated failure** - successive rounds that produce no new verified fact mean the
   approach is wrong, not that more rounds will help.
4. **Unsafe step required** - a destructive action, a write outside the permitted scope, or a
   change to the frozen baseline. Stop and escalate instead of negotiating with the boundary.

A stop condition the model cannot enforce is still useful, but it must be described as a
*request for human action*, not as a capability. `SKILL.md` states the same conditions
operationally.

## 7 Recovery

Recovery rests on knowing what survives what. **Durable:** the goal (objective, phase,
revisions, admitted-round count), the approved plan, the state and evidence files, the
artifacts. **Not durable:** whether automatic continuation is currently *armed* - a fresh
process, a resumed session or a forked session starts disarmed, and only a human re-arms it.

Automatic continuation is supplied by an official driver package (named in `README.md`),
which schedules one round at a time while the goal is active, continuation is armed and round
allowance remains. It carries no independent evaluator and no resource meter: it enforces the
round allowance and nothing else, which is precisely why the round cap is the only budget
labelled `HARD`. Read that package's installed documentation rather than any summary, since
its contract is version-bound.

**Interrupted rounds.** A round that is cancelled or crashes leaves a partial record. The next
round re-derives its position from durable state and evidence, never from a narration of what
the previous round "was about to do".

**Interrupted tool calls.** A call recorded without a result recovers with an *unknown*
outcome rather than an automatic retry, because the runtime cannot prove whether the external
effect landed. Verify actual state before repeating anything with side effects.

**Partial artifacts.** A partially written deliverable is simply a deliverable that fails the
evaluator. That failure is the signal; it needs no special machinery.

Isolating a DSH configuration home is a different concern from restricting where a process may
write files: one scopes configuration and session state, the other scopes file effects, and
neither substitutes for the other.

## 8 Knowledge deposition

Write conclusions down when they are **verified**, not while they are still hypotheses. The
value of a long run is the durable knowledge it leaves behind, and that value is destroyed if
the record mixes established facts with plausible guesses.

Deposit at three levels: **per round** (the evidence file - what was attempted, what was
verified, the exact command, the raw result), **per project** (the state file and the final
report - current position, verified facts, open questions, next step), and **per acceptance**
(the evaluation record - which checks ran, what they returned, what remains a human
judgement).

Two habits keep the record trustworthy. Record the **exact command and its raw output**; a
conclusion whose command is unknown cannot be re-verified. And record failures and dead ends:
a dead end written down saves the next attempt from repeating it, which is the same benefit as
a positive fact at a fraction of the cost.

---

# Part 2 - the distinctions v0.2 adds

## A Goal, Plan and State: three different jobs

They are three different objects with three different lifetimes, and confusing them is how a
run loses its position.

| Object | Job | Lifetime | Who may change it |
|---|---|---|---|
| **Goal** | one durable completion objective plus its phase, revision, admitted-round count and cap | survives resume, fork and restart; ends only through a lifecycle transition | created, edited, paused, resumed and cleared by a human; completed or blocked under the rules in section D |
| **Plan** | how the rounds are expected to get there, with per-stage verification | lives in the project as a versioned file; amended append-only | approved by a human; amended by the loop only to shrink or re-order |
| **State** | where the work actually stands right now, for the next reader | rewritten every round; small by design | the loop |

The goal is the **contract**, the plan is the **route**, the state is the **position**. A
route change is not a contract change; a position update is not progress. And the plan is not
a gate: approval fixes intent, it does not restrict tools.

## B Mechanical acceptance, evidence review, human acceptance

Three different questions, three different judges:

- **Mechanical acceptance** asks: *do the required artifacts exist and satisfy the stated
  structural criteria?* Judge: the frozen evaluator. Binary, reproducible, blind to meaning.
- **Evidence review** asks: *is the claim-by-claim record complete, sourced and honestly
  graded?* Judge: a reader working from the evidence files. This is what catches a `FACT` that
  rests on nothing, or a round that quietly disappeared.
- **Human acceptance** asks: *is this actually usable, and should it be trusted?* Judge: a
  person. No amount of the first two answers this question.

The failure mode to avoid is collapsing them: treating a green evaluator as acceptance, or
treating the loop's own summary as evidence review. A loop that grades its own evidence has no
independent judge; that limitation must be stated in the acceptance record rather than hidden.

A second distinction runs inside the machine layer, and v0.1 missed it:

| Object | What it is | Where it lives |
|---|---|---|
| **the evaluation contract** | what must be checked, the pass criteria, and who decides | the project's evaluation record, written before the run |
| **the evaluator implementation** | the program that actually performs the checks and returns an exit code | a read-only script or program, frozen before the run |

A filled-in Markdown acceptance record is a **contract**. It is **not** an evaluator
implementation, and calling it one is how a project ends up believing it has mechanical
acceptance when all it has is a document that a model asserts is satisfied. If nothing names
an executable check, there is no machine layer at all.

## C The evaluator has its own lifecycle

An evaluator is a program, and it needs the same treatment as any other acceptance-critical
artifact. Four phases:

1. **Author.** Written against the frozen success criteria, read-only, inspecting artifacts
   only, with a fixed exit-code convention (for example 0 pass, 1 fail with printed reasons,
   2 error).
2. **Test.** Exercised against a **real** compliant artifact *and* against real mutated copies
   for each failure class, so that PASS, FAIL and ERROR are each demonstrably reachable. A
   validator tested only against hand-written near-misses proves nothing about the real
   producer's output.
3. **Freeze.** Hash recorded and the freeze noted in the evaluation record, before the goal is
   armed.
4. **Re-verify.** After any doubt about tampering, verify the hash and re-run the tests before
   trusting a PASS.

**Independence** is a property, not a claim. The evaluator must not read a completion claim,
must not be editable by the party being judged, and must be runnable by someone who took no
part in the work. **Regression** is the price of change: if the evaluator changes, its test
cases must be re-run and the change must be visible in the evaluation record - a silently
edited evaluator invalidates every earlier PASS.

## D HARD and SOFT stopping: what actually executes

Stopping is where honest documentation matters most, because a stop condition that does not
execute will be read as if it did.

| Condition | Class | What actually happens |
|---|---|---|
| round cap reached | **HARD** | the continuation driver stops and records a stable round-limit blocker; no model cooperation is required |
| goal completed through its lifecycle | **HARD** | continuation is disarmed; the run ends |
| a human pauses | **HARD** | continuation stops immediately; the human-facing path is the early-stop mechanism |
| "report READY FOR HUMAN REVIEW" | **SOFT** | nothing. It is a status report. Automatic rounds continue while the goal is active, armed and has allowance |
| "two rounds with no new verified fact" | **SOFT** | content work stops; the loop says so and asks for a human. Continuation continues |
| token / cost / wall-clock ceiling | **SOFT** | reported if measured, enforced by nothing |
| "the model decides to finish early" | not a mechanism | only a human pause, a lifecycle end, or the cap actually stops the run |

Two consequences worth stating plainly. First, **a model cannot pause, resume or re-arm its
own goal**: those operations require a direct human turn, so no prompt-level instruction can
create a native waiting state. Second, ending the run by declaring the goal complete or
blocked when neither is true would be a false claim about the work; "awaiting a human" is
neither. When a run genuinely needs a real autonomous early stop, that requires a separately
evaluated mechanism - not a rewritten prompt, and not a claim.

A third consequence follows from the same authority rules and is worth spelling out, because
it is easy to over-read: a terminal lifecycle action *is* accepted inside an autonomous round
and does end the current turn and the continuation. That is a real capability, and it is
precisely why the rule above is a rule: the only honest use of it is when the goal really is
achieved or really is blocked for the stated reason. Using it as a brake substitutes a false
terminal claim for a stopping mechanism, and every later reader inherits the lie.

## E UNKNOWN discipline when the meter does not exist

An honest budget record has three possible values per quantity: a measured number, a clearly
labelled estimate, or `UNKNOWN`. Most long-loop environments can measure rounds and file
timestamps and little else.

Rules that keep the record usable:

- Decide **before** the run which quantities will be captured, because most cannot be
  recovered afterwards.
- Report an uncaptured quantity as `UNKNOWN`. Never fill the gap with a plausible number; a
  fabricated metric is a defect, not a rounding choice.
- Prefer an artifact-derived number with its derivation stated (for example wall clock from
  file modification times) over a remembered one.
- Keep `UNKNOWN` visible in the final report and in the acceptance record. An open unknown is
  a finding; a closed fake is a liability.

## F Approved plans are persisted and versioned

A plan that lives only in a conversation is not a plan; it cannot be reviewed, cited, or
amended. So: the approved plan is written to a stable path in the project, states its status,
its approval record and its authority, and is amended only by appending dated, reasoned
sections. Amendments may shrink or re-order work inside the frozen criteria; anything that
adds scope is a proposal for the next version.

The plan also records how it relates to the other contracts, and what wins on conflict: the
frozen objective and the frozen evaluator outrank the plan. Approval is a human act and is
recorded as one; and, as section A and `SKILL.md` both state, approving a plan neither creates
nor arms a goal.

## G The Final Report is a contract, not an afterthought

A report written after the fact, from memory, with a path chosen at the end, is the weakest
artifact in a long run. So the report contract is fixed **before** arming, in the objective
document, with four things decided up front: the exact path, the owner, the required sections,
and the quantities each round will capture.

Then: evidence accumulates per round, the report is generated from those files after the run
has stopped, and it reports terminal state and human acceptance separately. It never rewrites
an earlier evidence file, and it marks uncaptured quantities `UNKNOWN`.

Who writes the report is an implementation choice. One deployment may require a post-run,
human-authorized reporting turn (which has the useful property that reporting can never
consume a round); another may generate it automatically at the stop edge. The contract is the
same either way, and a version-specific implementation must not be presented as the method.

## H Idempotent recovery: inspect effects, do not assume

A long run is interrupted eventually. The governing rule is that **absence of a result is not
evidence of absence of an effect**: a tool call can land and still return nothing observable
to the caller.

So recovery is an inspection procedure, not a retry procedure:

1. Read the durable state, the approved plan and the latest evidence.
2. Inspect the **actual** artifacts and their hashes on disk.
3. Reconcile: state, evidence and filesystem may disagree; the filesystem wins, and the
   disagreement is itself a finding to record.
4. Only then decide what to repeat, and repeat only operations proven not to have landed.

Actions that are naturally idempotent (re-running a read-only evaluator, re-writing a file
from its source of truth) can be repeated freely. Actions with external or destructive effects
must be verified first. Marking a step's outcome `UNKNOWN` and proceeding is correct;
retrying blindly is not.

## I Portability: no project state in a portable toolkit

A reusable toolkit carries policy, contracts and blank forms. It carries **no** objective, no
budget value, no path, no session or goal identifier, no version-specific finding presented as
universal, and no local username or project name. The moment one project's state is baked into
it, every later adopter inherits a false assumption.

Practice: refer to locations by role rather than by literal path; keep the adopter's filled
copies outside the toolkit; keep the toolkit's own development records outside it too; and
treat "this worked in my environment" as a claim that needs its environment recorded next to
it.

## J Candidate, release, and the knowledge they leave behind

Three buckets exist and must never be merged:

| Bucket | What it is | What may happen to it |
|---|---|---|
| **frozen pilot artifact** | an experiment's output, kept exactly as it was produced | nothing. It is evidence, not a product |
| **development candidate** | work in progress under verification | edited freely, verified, re-verified |
| **accepted release** | the accepted bytes, promoted | copied once, re-verified in place, never edited |

Promotion is a separate human-authorized step, and it **copies**; editing the promoted copy
destroys the link between what was verified and what is published. Anything that needs a
change becomes the next version, and the previous version keeps its record.

A release is gated on three separate facts, and none of them implies another: a mechanical
pass on the frozen evaluator, a successful adoption exercise by a real adopter, and a human
content acceptance. Promotion without all three publishes something nobody has actually
judged.

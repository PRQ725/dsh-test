# Long-running Toolkit v0.2

A portable policy layer for running **one supervised long-running goal loop** inside a
project: a single completion objective that keeps advancing across autonomous rounds under
an enforced round cap, written-down contracts, per-round evidence, and a human acceptance
gate.

This is not a scheduler, an agent framework, or a replacement for any DSH package. It adds
*policy, contracts and blank forms* on top of mechanisms the installed DSH already provides.

---

## What this is

Three separable parts:

| Part | Role | Where |
|---|---|---|
| **Policy** | when a long loop is appropriate, what must be fixed in writing before arming it, and what actually stops it | `SKILL.md`, `METHODOLOGY.md` |
| **Blank forms** | the five documents a project fills in for its own objective, plan, state, evaluation and final report | `templates/` |
| **Contract references** | the official mechanisms this policy leans on, named by package rather than reimplemented | `README.md` (this file), `METHODOLOGY.md` |

Two properties are deliberate:

- **Project-agnostic.** No objective, budget, path, session id or version pin belonging to
  any particular project is baked in. You copy it, then you fill in your own values.
- **Version-bound.** Every mechanism claim here was derived from locally installed
  documentation for one DSH release. It is not a statement about DSH in general.

**Three buckets, never merged** (this distinction is the main thing v0.1 lacked):

| Bucket | What it is | Where it lives |
|---|---|---|
| **A. Frozen pilot artifact** | the v0.1 six-file candidate produced by the first pilot. Immutable. Not a release. | the pilot's own output directory |
| **B. Development candidate** | this toolkit, while it is still being built and verified | the developer's own staging area |
| **C. Accepted portable release** | the same bytes, promoted after all three release gates pass | the research repository's `toolkit/long-running/v0.2/` |

A candidate is not a release. Promotion is a separate human step that **copies** bytes and
never edits them; any needed change makes the copy a new candidate version.

One expectation to set before anything else, because it decides whether this toolkit helps or
wastes a run: **a round allowance is a ceiling, not a work plan.** A single round may complete a
bounded set of related increments, and a single round **may complete the whole objective** — the
first pilot did exactly that, verifying and recording as it went. What a round may not do is
leave its own output unverified, pad itself to look busy, or split one job across rounds to
consume the allowance. If the work finishes early, that is a normal outcome: finish honestly,
freeze what exists, and hand it to a human. Because the remaining allowance is consumed by the
continuation driver whether or not there is work, stretching the job to "use" the rounds buys
nothing.

---

## When to use it

Use a long-running loop only when **all** of these hold:

1. There is exactly **one** completion objective, and it is genuinely larger than one turn.
2. The end state can be described **before** work starts, with success criteria a mechanical
   check can verify — and anything a machine cannot check is written down as an explicit
   human-review item instead of a proxy check.
3. Progress is naturally incremental: each round can produce one concrete, verifiable
   advance rather than redoing the whole job.
4. A **human is reachable** to re-arm, pause, and eventually accept. The loop cannot stop
   itself on request and cannot accept its own result.
5. The work is safe to attempt repeatedly: no destructive step, no irreversible publish, no
   credential the loop cannot reach safely.

## When not to use it

Do **not** create a goal for:

- routine single-turn work — a goal adds ceremony and consumes rounds for nothing;
- several parallel objectives — one goal holds one current objective per session;
- work whose success is entirely subjective — you would be arming a loop with no stop signal
  and no acceptance criterion;
- work needing approvals, credentials or infrastructure the loop would have to improvise;
- anything that must not be read by a person before it is trusted;
- anything whose "completion" you would be tempted to declare yourself. If the honest end
  state is "waiting for a human", a long loop will keep consuming rounds until its cap.

---

## Authorization model — same Goal, planning then execution phases

**One complete objective is carried by one Native Goal.** Planning and execution are phases
inside that Goal, not separate Goals. Do not create a planning-only Goal and then an
execution-only Goal for the same objective.

Two authorizations, never conflated:

| Authorization | Grants | Does **not** grant |
|---|---|---|
| **Planning Authorization** | investigation, audit, architecture analysis, GOAL/PLAN drafting, budget estimate, acceptance design, risk/dependency analysis | production-code changes, data migration, authoritative FACT/CLM/SRC writes |
| **Execution Authorization** | one-time approval of the agreed complete implementation scope (all stages in the frozen PLAN) | scope changes, budget expansion, authoritative fact changes, irreversible operations outside the approved migration |

- The Goal is created for the **complete objective**, including its planning phase. A planning
  phase may consume rounds from the same Goal's logical budget; it must not be moved into a
  second "planning Goal".
- GOAL and PLAN must be confirmed by a Human before execution rounds begin; approval is a
  phase gate, not a new Goal.
- After Execution Authorization, do not ask for per-stage approval: execute the frozen PLAN
  continuously, updating STATE, evidence and FINAL-REPORT each round, fixing ordinary
  implementation problems autonomously.
- Scope, core objective, acceptance criteria or budget changes require a new Human decision;
  they do not require a new Goal.
- Completion is judged against the complete objective. Finishing planning, or finishing one
  stage, is not Goal completion.

### Human Decision Gate

Only these require a human stop:

1. authoritative FACT/CLM/SRC change not already authorized;
2. irreversible operation or migration beyond approved scope;
3. major architectural conflict affecting the core design;
4. changing the Goal's core objective or acceptance criteria;
5. budget insufficiency/expansion;
6. factual ambiguity requiring human confirmation;
7. any item explicitly listed in the GOAL as human-decided.

Non-blocking gaps are recorded and work continues on unaffected parts. A local issue must not be escalated into a project-wide `BLOCKED`.

---

## Adoption procedure

Fourteen steps, in order. Steps marked **[HUMAN]** require a person; `[HARD]` marks a
host-enforced fact rather than a promise.

### Step 1 — Decide the shape **[HUMAN]**
Answer the two lists above honestly. If any "when not to use" item applies, stop here and do
the work directly instead. This step has no artifact; its output is a decision.

### Step 2 — Identify the target project's own conventions before touching anything

Read the target project first; this toolkit never overrides local rules. Collect, as a short
written inventory (put it in your goal document or a scratch note):

- the project root, and the instruction files it already carries (for example `AGENTS.md` or
  `CLAUDE.md`) and what they forbid;
- how the project is built, tested and reviewed, and the exact command that decides "green";
- the paths the work may write to, and the paths that are read-only or frozen;
- whether the project is under version control, and what the rollback story is;
- who reviews, and who is allowed to accept the result.

Do not skip this because the toolkit "looks generic". The goal document is written against
*this* project's constraints.

### Step 3 — Choose where the working documents live
Keep two things apart, and put each one somewhere named:

```
<project-root>/
    toolkit/
        long-running/          the portable toolkit, copied in and left UNFILLED
            README.md  SKILL.md  METHODOLOGY.md  templates/
    docs/
        long-running/          this project's filled instances (the default "instance root")
            GOAL.md  PLAN.md  STATE.md  EVALUATION.md  FINAL-REPORT.md
    evidence/                  one evidence file per round
```

The **instance root** is the directory holding this project's *filled* documents. Its default
is `docs/long-running/`, and the toolkit's own `templates/` is never an instance root: filling a
template in place destroys the reusable form. Keep the portable toolkit and the project's
working state separate in both directions.

A project may keep its instances somewhere else — a `planning/` directory, or a governance
directory it already has — but it must then **declare** it, rather than leaving an AI or a
reviewer to guess:

- record the directory in the `Instance root:` field of `GOAL.md`, which is the declaration of
  record;
- pass that same directory to your evaluator explicitly, e.g.
  `check-v0.2.ps1 -Mode Adoption -InstanceRoot <project>/planning`;
- an evaluator that is not told otherwise will use the default `docs/long-running/`, and it must
  report which path it inspected so a stale convention cannot pass unnoticed.

**The declaration is authoritative.** Three different things can disagree here, and only one of
them wins:

| Object | What it says |
|---|---|
| the frozen `GOAL.md` declaration | where the instances are *authorized* to live |
| the evaluator's instance-root argument | which directory *this run* inspects |
| the filesystem | which directories *currently exist* |

If the argument names a different directory than the declaration, that is a **conflict**, not a
correction. Do not re-point the declaration, do not edit the frozen contract to match the
layout, and do not quietly inspect whichever directory happens to exist: stop, record the
conflict, and let a human decide which side is wrong. Compare the two paths mechanically, on
normalized paths — a trailing separator, `/` versus `\`, letter case, or a relative versus an
absolute spelling of the same directory is not a conflict.

What a green adoption check buys you: **INSTANCE HYGIENE**, meaning the instance directory is
sound. What it does not buy you: **INITIALIZATION READINESS**, the stronger question of whether
the project may arm a goal. Step 10.5 below is where those are separated.

### Step 4 — Write the project's `GOAL.md` **[HUMAN]**
Copy `templates/GOAL.md` into the instance root (by default `docs/long-running/`) and fill every
field with that project's real values: objective, success criteria, scope boundaries, non-goals,
evidence requirements, budget, stop conditions, human escalation, **instance root**, **report
path**, **report owner**, **acceptance authority**, **evaluator location**, and **version
assumptions**. Then freeze it. The running loop may not edit it; improvements go to a proposals
file for the next revision.

The objective text you will later pass to goal creation comes from this file, verbatim.

### Step 5 — Write `PLAN.md` and get it approved **[HUMAN]**
Copy `templates/PLAN.md` and fill it: stages, deliverables per stage, verification per stage,
replanning triggers, budget, approval record, amendments, recovery reference.

The PLAN is the route for the **same Goal** that carries the complete objective. Plan approval
is a phase gate, not a Goal creation event: it does not create a second Goal, and it does not
permit splitting the objective into a planning Goal plus an execution Goal. Plan mode is
guidance, not enforcement: the tool surface is not restricted while planning, so treat plan
approval as a design review, not as a safety boundary. The real boundaries are the file
sandbox, the approval policy and the goal authority rules.

If the Goal has not been created yet, create it **once** for the complete objective after the
plan is approved; do not create a separate execution Goal later. If it already exists (for
example, the planning phase is the Goal's first phase), continue the same Goal.

### Step 6 — Initialize `STATE.md`
Copy `templates/STATE.md` into the project. Record round 0, the empty completed list, the
already-verified facts (the project's test command, the write scope, the frozen artifacts),
and the single next step. This is the durable position a fresh process reads first.

### Step 7 — Write the evaluation contract **[HUMAN]**
Copy `templates/EVALUATION.md`. Separate two things that v0.1 conflated:

- the **evaluation contract** — what must be checked, the pass criteria, and who decides;
- the **evaluator implementation** — the script or program that actually performs the
  mechanical checks.

A Markdown acceptance record is a contract, not an evaluator. If your only "evaluator" is a
checklist a model fills in, you have no mechanical check at all.

### Step 8 — Author, test and freeze the evaluator **[HUMAN]**
Write the evaluator as a read-only program that inspects artifacts and exits with a fixed
code convention (for example 0 pass, 1 fail with printed reasons, 2 error). Then:

1. test it against a **real** compliant artifact and against **real** mutated copies —
   deleting a required file, stripping a required field, injecting a forbidden path — and
   confirm it fails for the right reason (PASS / FAIL / ERROR each exercised);
2. record its hash and its contract in the evaluation record;
3. freeze it *before* the goal is armed.

During the run the evaluator is read-only evidence. The loop must never edit it, and any
check that would be relaxed to make a round pass is out of bounds by definition. A model
grading its own work is not an independent judge; where that matters, have a second party or
a separate session run the frozen evaluator.

### Step 9 — Review budget and safety **[HUMAN]**
Write down which limits are actually enforced and which are self-reported. In DSH
`0.2.0-rc.2` exactly one budget is host-enforced: the goal's round cap `maxGoalRounds`,
enforced by the continuation driver, which records a stable `round-limit` blocker at the cap.
Token, cost, wall-clock, tool-call and information-gain limits are **SOFT**: the loop reports
them and a human verifies from evidence. If your environment has no meter for a quantity,
write `UNKNOWN` rather than an estimate.

Also confirm the file-sandbox mode and approval policy you are actually running under, and
confirm the write scope you wrote into `GOAL.md` matches it.

Remember that a **round allowance is a ceiling, not a work plan**. The cap bounds the run; it
does not divide the work into that many pieces. If the objective can be completed in two rounds,
complete it in two rounds and hand it over — the unspent allowance is consumed by the driver
either way, so stretching the job to "use" the rounds buys nothing and costs review attention.

### Step 10 — Confirm version compatibility and real permissions **[HUMAN]**
Record the DSH version you verified against (see Compatibility below), locate the installed
package documentation in your own environment, and re-confirm the mechanism contract — goal
authority rules, activation semantics, round cap — before arming anything. Do not assume a
different version behaves as this toolkit describes.

### Step 10.5 — Confirm initialization readiness — not just instance hygiene

Two verdicts, deliberately separate:

- **INSTANCE HYGIENE PASS**: the instance directory is sound — it exists, holds real instance
  documents, holds no blank-form marker, and is not the toolkit's own `templates/`. This is what
  a plain adoption check establishes, and it is **not** permission to arm a goal.
- **INITIALIZATION READINESS**: every prerequisite for arming a goal has been verified or
  explicitly authorized.

Twelve items make up the readiness contract. Check each one and record its verdict: `PASS` for a
mechanically checked item, `POLICY` for a policy record that exists but proves nothing about
intent, `PENDING` for a human gate nobody has performed yet, `FAIL` for a missing prerequisite.

| # | Item |
|---|---|
| 1 | `GOAL.md` exists and is filled |
| 2 | `PLAN.md` exists with an approval record (the approval itself is a human gate) |
| 3 | `STATE.md` is initialized |
| 4 | `EVALUATION.md` exists and is filled |
| 5 | a project-specific evaluator exists |
| 6 | the evaluator has PASS/FAIL/ERROR test evidence (adequacy is a human judgement) |
| 7 | the evaluator's freeze baseline (hash) is recorded |
| 8 | budget and stop conditions are stated |
| 9 | the workspace and permission boundary were verified — **human gate** |
| 10 | instance-root consistency passes (the normalized comparison above) |
| 11 | the required human approvals are recorded — **human gate** |
| 12 | the final report's path and owner are determined |

If your evaluator has a readiness mode, use it and read its per-item output; if it does not, do
the twelve checks by hand. Either way, **do not merge them into one word**. A readiness report is
not acceptance, and it arms nothing: the goal is created in the next step, by a person.

### Step 10.6 — Know which verdict you are holding

Four different checks, four different claims. Confusing them is how a run ends up "green" and
unprepared, so name the verdict out loud before acting on it.

| Check | How it is run | A green result may claim | A green result does **not** prove |
|---|---|---|---|
| **Candidate Validation** | `-Mode Candidate`, against the toolkit copy | `CANDIDATE VALIDATION PASS` | anything about a target project |
| **Instance Hygiene** | `-Mode Hygiene`, against an instance directory | `HYGIENE PASS` and `CONTRACT NOT CHECKED` | that the directory is the **declared** one, that initialization is complete, that anyone approved anything, or that a goal may be armed |
| **Contract-verified Adoption** | `-Mode Adoption -GoalContract <project>/…/GOAL.md` | `ADOPTION PASS` | initialization readiness, human approval, or permission to arm |
| **Initialization Readiness** | `-Mode Readiness -GoalContract <project>/…/GOAL.md` | per-item `PASS` / `POLICY` / `PENDING` / `FAIL` | acceptance; it arms nothing and its human gates stay `PENDING` |

**Instance Hygiene must never be reported as an adoption result.** A hygiene run reads no goal
contract, so it cannot know whether the directory it inspected is the one the project declared;
its output says `CONTRACT NOT CHECKED` for exactly that reason. `ADOPTION PASS` is reserved for a
run that also read the frozen declaration and found the paths equal.

The refusal is deliberate: `-Mode Adoption` and `-Mode Readiness` **require** `-GoalContract`, and
the evaluator exits with an error if it is missing rather than quietly downgrading to hygiene.
Reading a directory and reading a frozen, human-approved declaration are different acts, and only
the second one can support a claim about the project.

Machine approval is never human approval. No output of any mode proves that a person approved a
plan, accepted a permission boundary, or authorized arming a goal — those remain human gates, and
Step 11 is where a person acts on them. Put plainly: a green result does not prove readiness, does
not prove that anyone approved anything, and does not prove that a goal may be armed.

### Step 11 — Create the goal with an explicit round cap **[HUMAN]**
Creating the goal is a step that **requires a direct human request**; a model or a subagent
cannot do it on its own initiative.

Create **one Goal for the complete objective**, not one for planning and another for execution.
The objective text comes verbatim from `GOAL.md`; the PLAN is the route inside that same Goal.

Pass `max_goal_rounds` explicitly. Omitting it selects the deployment default, which is far
larger than any supervised run should use.

Verify the creation result shows the cap you intended and that continuation is armed. If the
cap is wrong, stop and correct it before letting the loop run. Creating a goal **starts** the
loop; there is no "create then immediately pause" safety step to rely on.

### Step 12 — Monitor, pause and resume **[HUMAN]**
While a goal is active and armed, automatic rounds continue until the goal ends or the cap is
exhausted. Read the live goal state (phase, rounds started against the cap, activation) and
read the state plus evidence files each round. The human-facing pause/resume path is the only
early-stop mechanism that acts immediately. Record in the plan who is watching and at what
cadence; if nobody is watching, expect the loop to consume its cap.

### Step 13 — Generate the Final Report
The report's path and owner were fixed in `GOAL.md` before arming, so this step fills a
contract rather than inventing one. Generate it **after** automatic continuation has stopped,
from the per-round evidence already on disk — never from recollection, and never by rewriting
an earlier evidence file. Quantities that were not captured are reported as `UNKNOWN`.

Whether the loop or a human writes the report is an implementation choice. In DSH
`0.2.0-rc.2` the practical mode is a post-run, human-authorized reporting turn; do not
generalize that into a requirement of the method.

### Step 14 — Human acceptance, terminal state and knowledge deposition **[HUMAN]**
Keep these four states separate and never infer one from another:

| State | Meaning | Who may declare it |
|---|---|---|
| `MECHANICAL PASS` | the frozen evaluator exited 0 | the evaluator only |
| `READY FOR HUMAN REVIEW` | mechanical pass **and** the evidence chain is complete | the loop may *report* this |
| `HUMAN ACCEPTANCE` | a person judges the result genuinely usable | the human only |
| `GOAL COMPLETE` | complete objective met, terminal FINAL-REPORT published, Native phase complete; **acceptance may still be pending** | the runtime/agent on evidence, not a substitute for acceptance |

**Terminal states are a separate axis from acceptance.** A run must end in exactly one of:

| Terminal state | Meaning |
|---|---|
| `COMPLETE` | complete objective and success criteria met, necessary verification passed; `acceptance=pending` is allowed when only independent Human Acceptance remains |
| `COMPLETE_WITH_EXCEPTIONS` | approved scope done; remaining items explicitly deferred/waived/handed over by a human |
| `BLOCKED` | required work remains and a concrete condition cannot be bypassed |
| `PAUSED_FOR_HUMAN` | waiting for a human decision; **not** a failure |
| `FAILED` | core objective cannot be met and no acceptable alternative exists |

`STOP FOR HUMAN REVIEW` is **not** `BLOCKED`. If all engineering work is done and only human
acceptance remains, end as `COMPLETE` with `acceptance=pending`. If required work remains, do
not claim `COMPLETE`.

`DRAFT` is not a valid terminal report state: a goal that ends must publish a terminal
`FINAL-REPORT` (see `templates/FINAL-REPORT.md`), or explicitly state `PARTIAL` plus what is
unfinished.

Only after acceptance does promotion happen: copy the candidate into the release location,
re-run the frozen evaluator there, and record the result. Do not edit the copied content — if
it needs a change, that is the next version. Then deposit knowledge: what was verified, what
failed, what remains `UNKNOWN`, and which next actions are worth doing.

---

## Installing `SKILL.md` so DSH can actually load it

`SKILL.md` in this toolkit, and a *loadable DSH skill*, are two different objects. [FACT]
Copying a single file to a project root does **not** create a loadable skill. Two honest
options:

**Option 1 — human/AI-read document (always works).** Keep the toolkit folder as-is, and
tell your agent to read `SKILL.md` explicitly, or paste its path into the goal document's
evaluator/instruction references. No discovery mechanism is involved, so nothing can silently
fail.

**Option 2 — make it a locally discovered DSH skill, if your environment mounts the local
skill provider.** [FACT, from the installed `@deepseek-ai/dsh-skill-filesystem`
documentation] The provider scans, at discovery depth one, either `<root>/<name>/SKILL.md`
or `<root>/<name>.md`, parses each file's YAML frontmatter, and requires a kebab-case `name`
plus a `description`. A file without valid frontmatter is **dropped with a warning**; there is
no per-skill error surfaced to the model. [FACT] The shipped profile bundle mounts
`@deepseek-ai/dsh-skill`, `@deepseek-ai/dsh-skill-filesystem` and `@deepseek-ai/dsh-tool-skill`,
so the mechanism exists in this deployment family. [FACT] The documented roots are
`<projectRoot>/.dsh/skills`, `<projectRoot>/.agents/skills`, configured custom directories,
then the user-level roots `<DSH_HOME>/skills` and the shared agents home; nested skill trees
are deliberately not discovered, and the project root is the nearest ancestor containing
`.git`, falling back to the current working directory.

So a plausible installation is to move `SKILL.md` to something like
`<projectRoot>/.dsh/skills/long-running/SKILL.md` with frontmatter as the first line, then
confirm it appears in the session's skill catalog before relying on it.

[UNKNOWN] This toolkit's own round did **not** execute that discovery: no skill was installed
and observed in a live catalog. Treat Option 2 as a documented, plausible procedure to be
confirmed in your environment, not as a verified behaviour of this toolkit — and never
describe it as "copy it and DSH picks it up automatically."

---

## Compatibility

**Verified against DSH `0.2.0-rc.2`**, using these official packages, all at the same
version in the verified installation: `@deepseek-ai/dsh-goal`,
`@deepseek-ai/dsh-goal-round-driver`, `@deepseek-ai/dsh-tool-goal`,
`@deepseek-ai/dsh-command-goal`, `@deepseek-ai/dsh-plan-mode`, and — for the skill-install
section above — `@deepseek-ai/dsh-skill`, `@deepseek-ai/dsh-skill-filesystem`,
`@deepseek-ai/dsh-tool-skill`.

Verified at package level only: the version strings and the documentation shipped inside the
installed packages. No runtime probe of activation, pause, or the round cap was performed in
this development round.

Everything this toolkit says about goals, plans, activation, round caps and stopping is
**version-bound** to the `0.2.0` line. Treat it as `0.2.0` behaviour, never as universal DSH
behaviour:

- Locate the DSH installation tree in your environment and read the installed package
  documentation for the packages named above; do not rely on this file as a substitute.
- **Re-confirm** the mechanism contract in the target environment before arming anything.
- If a package is absent, or the documented contract differs, adapt the policy instead of
  assuming the toolkit still applies.
- Record the version you actually verified in your own copy of this file, so a later reader
  can tell which contract your forms were written against.

---

## Files in this toolkit

Exactly eight files. Count them before you copy.

| File | Role |
|---|---|
| `README.md` | this file: what the toolkit is, when to use it, and the adoption procedure |
| `SKILL.md` | the operating procedure an agent follows, step by step, with human gates |
| `METHODOLOGY.md` | why the contracts relate the way they do, and where their limits are |
| `templates/GOAL.md` | blank objective contract, frozen before arming |
| `templates/PLAN.md` | blank approved plan, persisted and versioned in the project |
| `templates/STATE.md` | blank durable cross-round state |
| `templates/EVALUATION.md` | blank evaluation contract and acceptance record |
| `templates/FINAL-REPORT.md` | blank post-run report contract |

Read next: `SKILL.md` for the procedure, `METHODOLOGY.md` for the reasoning, and
`templates/` for the forms.

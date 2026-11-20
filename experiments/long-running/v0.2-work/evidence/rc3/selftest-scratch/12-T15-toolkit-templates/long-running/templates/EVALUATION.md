# EVALUATION - blank evaluation contract and acceptance record

Two objects live here and must never be confused. The `UNFILLED` marker means a field is
still blank.

- **The evaluation contract** (first half): what must be checked, the pass criteria, and who
  decides.
- **The evaluator implementation** (second half): the program that actually performs the
  mechanical checks, and the evidence that it works.

A Markdown record is a contract. It is not an evaluator. If nothing in this file names an
executable check, then this project has no mechanical acceptance at all - only a self-report,
which is exactly what the machine layer exists to avoid.

## A. Evaluation contract

Evaluation contract:
UNFILLED. The criteria, restated so each one is either mechanically decidable or explicitly a
human-review item. For each mechanically decidable criterion, name the artifact inspected and
the observable that decides it. For each human-review item, name who decides it.

Machine checks:
UNFILLED. The exact command, the root it is run against, the date and time, the exit code and
the raw output. State plainly that a passing mechanical check proves structure, required
fields and internal reference soundness only - it is a necessary condition, never a
sufficient one.

Evidence quality:
UNFILLED. The list of round evidence files that exist, one per round that actually ran, with a
statement of how each substantive claim is graded (`FACT`, `INFERENCE`, `UNKNOWN`) and whether
every claim carries a source. Note every round that produced no new verified fact, and every
claim still `UNKNOWN`.

Human review:
UNFILLED. The questions a person must answer, and the states only a person may declare.
Record that a mechanical pass means `READY FOR HUMAN REVIEW`, that `HUMAN ACCEPTANCE` has not
been given, and that the goal must not be reported complete until a human confirms it. Note
anything the reviewer should distrust - in particular any evidence the loop graded itself -
and any promise the loop could not actually keep.

## B. Evaluator implementation

Evaluator implementation:
UNFILLED. The path of the program that performs the checks, the interpreter or runner it needs,
its full invocation, and its exit-code convention (for example 0 pass, 1 fail with printed
reasons, 2 error). State that it is read-only and never reads a model-declared completion
claim.

How the evaluator is authored:
UNFILLED. Who wrote it, against which frozen version of the success criteria, and what it
deliberately cannot decide. An evaluator that tries to judge quality rather than structure will
either pass everything or encode one person's taste as a gate.

Frozen:
UNFILLED. The date of the freeze, the SHA256 of the evaluator at freeze time, and the rule that
it may not be edited after the goal is armed. If the evaluator is ever changed, say so here,
re-run the test cases, and record the new hash - a silently edited evaluator invalidates every
earlier pass.

Test cases:
UNFILLED. The cases that were actually executed, each with its artifact and its observed
outcome. At minimum: a real compliant artifact must pass (exit 0); a real mutated copy for each
failure class must fail for the expected printed reason (exit 1); and an unusable invocation or
missing root must error (exit 2). Hand-written near-miss fixtures do not substitute for the
real producer's output.

Tamper check:
UNFILLED. How a reader confirms that the evaluator that produced this record is the frozen one:
the hash comparison, the command that reproduces it, and the re-verification performed after
any doubt.

Independence:
UNFILLED. Who ran the evaluator relative to who produced the artifacts, and whether any party
that graded the work is also the party that could edit the gate. Where independence was not
achieved, say so here instead of implying it.

## C. Initialization readiness

Guarantee scope of this project's checks:
UNFILLED. Record which verdicts this project will actually run, and what each one is allowed to
claim. The four are deliberately distinct; conflating them is how a project reports success it
did not establish.

| Verdict | Proves | Does not prove |
|---|---|---|
| **CANDIDATE VALIDATION** | the portable toolkit artifact satisfies its own structural checks | anything about this project |
| **HYGIENE PASS** | the instance directory is sound: reachable, holds instance documents, no blank-form marker, not the toolkit's own templates | that it is the **declared** directory, that initialization is complete, that anyone approved anything, that a goal may be armed |
| **ADOPTION PASS** | hygiene, plus a readable frozen contract whose `Instance root:` declaration matches the inspected directory after normalization | initialization readiness, human approval, or permission to arm |
| **INITIALIZATION READINESS** | the twelve items below, item by item | acceptance; it arms nothing |

Run the strongest check available and report it by its own name. Report a directory-only run as
`HYGIENE PASS` together with `CONTRACT NOT CHECKED`; never report it as an adoption. The
contract-verified modes require the contract and refuse to run without it - do not work around
that refusal by describing a weaker run as a stronger one.

Initialization readiness:
UNFILLED. INSTANCE HYGIENE is the weaker verdict: the instance directory exists, holds real
instance documents, holds no blank-form marker, and is not the toolkit's own `templates/`. It is
not permission to arm a goal. INITIALIZATION READINESS is the stronger question, and it is
answered item by item with `PASS` (mechanically checked), `POLICY` (a record, not proof of
intent), `PENDING` (a human gate nobody has performed), or `FAIL` (a checkable prerequisite is
absent).

Record the twelve items here, one verdict each:

1. `GOAL.md` exists and is filled - `PASS` / `FAIL`
2. `PLAN.md` exists with an approval record - `PASS` / `PENDING` (the approval is a **human gate**)
3. `STATE.md` is initialized - `PASS` / `FAIL`
4. `EVALUATION.md` exists and is filled - `PASS` / `FAIL`
5. a project-specific evaluator exists - `PASS` / `FAIL`
6. the evaluator has PASS/FAIL/ERROR test evidence - `POLICY`; adequacy is a **human gate**
7. the evaluator's freeze baseline (hash) is recorded - `PASS` / `FAIL`
8. budget and stop conditions are stated - `PASS` / `FAIL`
9. the workspace and permission boundary were verified - **human gate**, `PENDING`
10. instance-root consistency - `PASS` / `FAIL` / `PENDING`
11. the required human approvals are recorded - **human gate**, `PENDING`
12. the final report's path and owner are determined - `PASS` / `FAIL`

Three rules. A recorded approval is `POLICY`, never `PASS`: the words prove a record, not an
intent. An unperformed human gate is `PENDING`, never inferred away. And a readiness report is
**not acceptance and arms nothing** - it exists so the person who does arm the goal can see which
prerequisites are verified and which are still theirs to decide.

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

# STATE - blank durable cross-round state

Copy this file into the target project and update it before every round ends. The `filled in`
marker means the field is still blank. Keep it short: this is a position report, not a report
of the work.

**Read this first, not only this.** This file is the cheapest place to recover the current
position, but it is not sufficient on its own. A recovery may also need the frozen objective
contract, the approved plan, the most recent evidence file, the live goal runtime state
(phase, rounds started against the cap, activation) and the actual files on disk. Where this
file and the filesystem disagree, the filesystem wins and the disagreement is itself a finding
to record.

Round:
filled in. The round number and the cap it runs against, written as rounds started over the
maximum.

Completed:
filled in. What has actually been finished, expressed as artifacts that exist and checks that
now pass - not as effort spent.

Verified facts:
filled in. The claims established so far, each graded `FACT`, `INFERENCE` or `UNKNOWN`, each
with the source or the exact command that established it. Keep failed approaches here too: a
dead end written down saves the next round from repeating it.

Open questions:
filled in. What is still unresolved and what would settle it, including anything that would
invalidate the current plan if the answer turns out badly.

Next step:
filled in. The single concrete increment the next round should attempt, specific enough that a
fresh process with no memory of this conversation could start it.

Artifacts:
filled in. The paths produced so far, by role, marking which are frozen pending review. Record
hashes for anything whose integrity matters later.

Evidence:
filled in. One entry per round that has run, naming its evidence file, so a reviewer can
enumerate the rounds without searching.

Budget used:
filled in. Rounds consumed against the cap (`HARD`), plus the self-reported `SOFT` budgets -
token, cost, wall clock, tool calls - each clearly marked as reported rather than enforced, or
`UNKNOWN` where nothing measured them.

Recovery also needs:
filled in. What a resuming reader must consult in addition to this file, which durable items
survive a restart, what does not, and which operation a human must perform before automatic
continuation resumes.

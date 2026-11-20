# PILOT START RUNBOOK - Long-running Bootstrapping Pilot (v0.1)

Do **not** run this until the frozen baseline has been accepted. Nothing here has been
executed yet. Steps marked **[H]** are human-only; the host refuses them from an
autonomous round anyway.

## 0. Facts you need

| Item | Value |
|---|---|
| Pilot workspace | `D:\Projects\dsh-longloop-pilot` |
| Profile | `browser-lab` (the only profile currently serving a Web UI) |
| Session | a **new** session created **in the pilot workspace** - never the `dsh-test` session |
| Evaluator (frozen at arm) | `D:\Projects\dsh-test\experiments\long-running\check.ps1` - Evaluator v0 (9 regression cases) |
| Evaluator selftest | `D:\Projects\dsh-test\experiments\long-running\check.selftest.ps1` |
| Goal tool | `create_goal` with `max_goal_rounds: 5` - **not** the `/goal` command |
| Round cap default if omitted | 256 |

## 1. Pre-flight (before any goal exists)

1. **[H]** Confirm the baseline is frozen: `check.ps1` unchanged, `GOAL.md` criteria read
   and agreed.
2. **[H]** Re-run the evaluator regression; it must print `SELFTEST PASS` (exit 0):
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File D:\Projects\dsh-test\experiments\long-running\check.selftest.ps1
   ```
3. **[H]** Confirm `D:\Projects\dsh-longloop-pilot\out\` is **empty** (no pre-generated
   deliverable).
4. **[H] Set the sandbox mode, then verify by OBSERVATION ONLY - no write probe.**
   - Environment variable `DSH_PERMISSION_MODE` only sets the *approval* policy
     (`danger-full-access` -> `never`, anything else -> `ask`). It is **not** the filesystem fence.
   - The fence is the session's `SandboxMode`
     (`read-only` | `workspace-write` | `danger-full-access`), and its effective values are
     visible in the session itself - a recorded `[FACT]` of this knowledge base:
     `sandbox/mode`, `approval/policy`, `permission/preset`
     (see [00-dsh-local-filesystem.md](../../docs/00-dsh-local-filesystem.md) §7.5.3).
   - **[H]** Before creating the goal, switch this session's permission preset to
     **`workspace-write`** in the Web UI.
   - **[H] Pre-start check - read only, in this order:**
     1. effective `sandbox/mode = workspace-write` and `permission/preset = workspace-write`
        (i.e. **not** `danger-full-access`);
     2. `approval/policy = ask`;
     3. the session workspace root is the pilot workspace, and the session was started in
        that directory - `workspaceRoot` defaults to `process.cwd()` via the
        `@deepseek-ai/dsh-base` entry `sandbox-policy`.
   - **No scratch file is created. Write probes are deliberately not part of this runbook.**
   - Known limit, stated plainly: this knowledge base contains **no** experiment that ever
     demonstrated an out-of-workspace write being *denied*. The migration plan listed that
     verification as a to-do
     ([13-migration-plan.md](../../docs/migration/13-migration-plan.md) L288, L357) and the
     phase-3.2 verification record states it was still pending
     ([14-phase32-execution-verification.md](../../docs/migration/14-phase32-execution-verification.md) L211);
     the session analysed there contained no filesystem or shell tool events at all (L171).
     This step therefore verifies **configuration, not behaviour**. `HARD SAFETY BOUNDARY`
     remains `NOT VERIFIED` until someone demonstrates an actual denial.
   - Never probe inside `dsh-test`, `PJOS` or the resume project.
5. **[H]** Clean up any leftover experimental workspace groups in the Web UI sidebar
   (optional; unrelated to this pilot).

## 2. Create the pilot session

1. **[H]** In the Web UI add the workspace `D:\Projects\dsh-longloop-pilot`.
2. **[H]** Create a new session in it. Confirm the sidebar shows that workspace and that
   `AGENTS.md` is in scope (the session's working directory is the pilot workspace).
3. **[H]** Confirm no goal is currently set: `/goal` prints "No goal is currently set."

## 3. Plan first (no goal yet)

1. **[H]** Send `/plan` to enter plan mode.
2. Send a short planning request, e.g.
   `Read GOAL.md and PILOT-SPEC-v0.1.md and propose the round-by-round plan for producing out\toolkit-v0.1, within 5 rounds.`
3. The model explores read-only and calls `exit_plan_mode` with the plan; a **Plan review**
   question appears.
4. **[H]** Approve, or keep planning. Approval exits plan mode; it does **not** create or
   arm a goal.

## 4. Create and arm the goal (the arming step)

This is the point of no return: `create_goal` arms the goal immediately, and the first
automatic round starts as soon as this turn ends and the agent goes idle.

1. **[H]** In a **direct human turn**, instruct:
   `Create the goal exactly as specified in D:\Projects\dsh-longloop-pilot\GOAL.md, including max_goal_rounds 5.`
2. The model calls `create_goal` with the verbatim `objective` from `GOAL.md` and
   `max_goal_rounds: 5`.
3. **[H] Verify before ending the turn** - the tool result must show
   `maxGoalRounds: 5` and `activation: armed`. If it shows 256, the cap was omitted:
   `/goal clear` and redo step 1.
4. End the turn. Round 1 begins automatically.

> **The real start barrier is preparation, not `/goal pause`.**
> `create_goal` arms immediately, and after this turn ends the driver starts round 1 on its
> own. Do **not** treat "create the goal then immediately pause" as a safety step - the
> first round can already be admitted before a pause lands. Everything that must be true
> before the loop runs must be true **before** step 4.1 is sent.
>
> If you deliberately want the goal created but not running, the only safe way is to create
> it in a session whose workspace you are not ready for, or to accept round 1 starting and
> `/goal pause` at the first checkpoint you can see. Prefer not creating it at all.

## 5. Monitoring during automatic execution

- **[H]** `/goal` shows phase, `Rounds: n/5`, revision and activation.
- **[H]** Watch `D:\Projects\dsh-longloop-pilot\STATE.md` and `evidence\round-<n>.md`.
- **[H]** After every round, run the frozen evaluator to see the remaining gap:
  ```
  powershell -NoProfile -ExecutionPolicy Bypass -File D:\Projects\dsh-test\experiments\long-running\check.ps1 -Root D:\Projects\dsh-longloop-pilot\out\toolkit-v0.1
  ```
  Early rounds are expected to FAIL; the failure list is the to-do list.
- **[H]** Intervene if a round writes outside the pilot workspace, touches the frozen
  baseline, or reports no new verified fact twice in a row.

## 6. Pause / stop commands **[H]**

| Intent | Command |
|---|---|
| pause the loop | `/goal pause` |
| resume after pause (or after a host restart) | `/goal resume` |
| abandon and start over | `/goal clear` |
| change the objective | `/goal edit <objective>` |
| inspect state | `/goal` |

The autonomous loop itself cannot run any of these: `pause`, `resume` and `edit` require a
direct human turn. During a round it can only report `complete` or `blocked`.

## 7. Success verification

1. **[H]** `check.ps1` exits 0 on `out\toolkit-v0.1\`.
2. **[H]** `evidence\round-<n>.md` exists for every round that ran, and every claim in them
   is graded.
3. **[H]** Write `evidence\ACCEPTANCE.md`: evaluator command, exit code, timestamp, and
   your own verdict on methodology quality.
4. **[H]** Then, and only then, confirm the goal:
   `/goal` -> read `goal_id` + `revision` -> `update_goal action=complete`.
   A model-proposed `complete` is a proposal, not acceptance.
5. **[H] Promote the accepted deliverable into the research repo** (this is what makes it
   the reusable Toolkit, and it happens only after step 4):
   copy `D:\Projects\dsh-longloop-pilot\out\toolkit-v0.1\` to
   `D:\Projects\dsh-test\toolkit\long-running\v0.1\`, then re-run the frozen evaluator
   against the promoted copy and record the result in `evidence\ACCEPTANCE.md`.
   Do not edit the copied content during promotion - if it needs changes, that is v0.2.

## 8. Failure paths

| Situation | Action |
|---|---|
| round cap reached (`blocked`, code `round-limit`) | read the evidence, decide: raise the cap in v0.2, or accept a smaller deliverable |
| 2 rounds without new information | stop, review, revise the plan - do not simply resume |
| host restart mid-loop | durable state survives; continuation does **not**. Verify `STATE.md`, then **[H]** `/goal resume` |
| evaluator cannot pass within 5 rounds | treat as a pilot finding: record it, then decide whether the criteria were wrong (v0.2) or the loop was (also v0.2) |
| baseline tampering suspected | stop; re-verify `check.ps1` via the selftest before trusting any PASS |

## 9. What this runbook deliberately does not do

No host-restart drill, no `blocked` drill, no fork, no Ralph, no second pilot, no
multi-session coordination. Those are later experiments.

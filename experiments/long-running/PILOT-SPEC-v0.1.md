# Long-running Pilot Specification v0.1

Status: **prepared, not executed.** Frozen 2026-10-08. No goal has been created.
Version anchors: DSH `0.2.0-rc.2` (global npm anchor), evaluator `Evaluator v0`.

This document is the design of the first **Bootstrapping Pilot**: a restricted
long-running loop is used to build the next generation of the long-running toolkit.

```
Long-running v0   (official DSH mechanisms + this minimal human policy)
      |
      +-- executes one real Goal (maxGoalRounds = 5)
      |
      +-- produces Long-running Toolkit v0.1  ->  <pilot>\out\toolkit-v0.1\
      |
      +-- accepted by frozen Evaluator v0 + human review
      |
      +-- lessons feed v0.2
```

## S0 - Three separate things (do not mix them)

| Bucket | Where it lives | Lifetime |
|---|---|---|
| **A. Reusable toolkit** | this directory (`experiments\long-running\`): spec, evaluator, fixtures, runbook. After a PASS + human review, the *deliverable* is promoted into the research repo (planned: `docs\11-long-running-toolkit.md` + a `toolkit\long-running\` asset tree). | long-term |
| **B. One-off pilot instance** | `D:\Projects\dsh-longloop-pilot\` (workspace, `AGENTS.md`, `GOAL.md`, `STATE.md`, `out\`, `evidence\`) | disposable |
| **C. Official mechanism reference** | DSH `0.2.0-rc.2` package READMEs (local) - `dsh-goal`, `dsh-goal-round-driver`, `dsh-command-goal`, `dsh-tool-goal`, `dsh-plan-mode`, `dsh-session-checkpoint-policy`, `dsh-compaction`, `dsh-repeat-tool-reminder` | upstream |

Principle **OFFICIAL FIRST**: none of the above is reimplemented. We add policy and
templates only; no scheduler, no agent loop, no goal plugin.

## S1 - Objective contract

A goal is admissible only if all eight are written down before arming:

`Objective` / `Success criteria` / `Scope boundaries` / `Non-goals` /
`Evidence requirements` / `Budget` / `Stop conditions` / `Human escalation`.

Success criteria must be **mechanically checkable** wherever possible; anything that is
not gets an explicit "human review" marker rather than a fake check.
Template: `templates` of the produced toolkit; instance: `<pilot>\GOAL.md`.

## S2 - Plan contract

- Plan **precedes** the goal. Planning happens in official Plan Mode (`/plan`), whose exit
  is a human review.
- Plan mode is **guidance, not enforcement**: the tool catalog is unchanged, so the
  contract is that no mutation tool is called while in plan mode.
- Plan and Goal are **independent official mechanisms** - approving a plan does not arm a
  goal, and a goal does not require a plan. We compose them by convention, in this order.
- **Replan trigger**: evidence contradicts the plan, or a round cannot make progress.
- **Drift control**: the plan may only shrink or re-order the work already inside the
  frozen success criteria. Adding scope is a v0.2 proposal, not a round action.

## S3 - State contract

Every round keeps one small durable state file, not a full report:

`Round` / `Completed` / `Verified facts` / `Open questions` / `Next step` /
`Artifacts` / `Evidence` / `Budget used`.

Round evidence is one file per round (`evidence\round-<n>.md`, four fields:
attempted / verified / exact command / raw result). The state file is the only thing the
next round must read.

## S4 - Evaluation contract

Three layers, never collapsed:

| Layer | Who decides | Mechanism |
|---|---|---|
| **Machine acceptance** | Evaluator v0 | `check.ps1 -Root <dir>`, exit 0 = PASS, 1 = FAIL, 2 = ERROR. Read-only, artifact-based, never reads a model completion claim. |
| **Evidence quality** | the loop, graded | every claim labelled `FACT` / `INFERENCE` / `UNKNOWN` |
| **Human review** | the human | methodology quality, scope discipline, whether the result is actually reusable |

> `check.ps1` cannot tell whether the methodology is any good. A green evaluator is a
> necessary condition, never a sufficient one. **Model self-declared COMPLETE is not
> acceptance.**

Evaluator v0 rules (frozen): C1 artifact presence + minimum size + required
sections/fields + no leftover placeholders; C2 evidence-grade vocabulary and the three
acceptance layers; C3 every `templates/*.md` reference resolves; C4 the budget contract
names `maxGoalRounds` and marks everything else `SOFT`.

## S5 - Budget contract

| Budget | Value | Enforcement |
|---|---|---|
| `maxGoalRounds` | 5 | **HARD** - `goal-round-driver` blocks with `round-limit` at the cap |
| token / cost | soft | **SOFT** - DSH has no meter |
| wall clock | soft, <= 6 min/round | **SOFT** |
| tool/experiment calls | soft | **SOFT** |
| no-information-gain | 2 consecutive rounds without a new verified fact -> stop | **SOFT**, human-verifiable from `evidence/` |

A limit written into a prompt is **not** an enforced budget and must be labelled `SOFT`.
Only `maxGoalRounds` is real.

## S6 - Recovery contract

| Situation | Official behaviour | Our policy |
|---|---|---|
| `pause` | `/goal pause` or `update_goal action=pause`; a running turn is cancelled with inbox retained | pause before any risky step |
| `resume` | re-arms; allowed from `active` / `paused` / `blocked` only while `roundsStarted < maxGoalRounds` | human only |
| **host restart** | durable goal/plan state survives; **activation is process-local and comes back `disarmed`**, and the driver disarms every agent at load | loop does **not** auto-resume; a human must `/goal resume` |
| interrupted round | event log keeps the partial record | the next round must re-derive state from `STATE.md` + `evidence/`, not from narration |
| partial artifact | ordinary files | a partial `out\toolkit-v0.1\` simply fails `check.ps1`; that is the signal |
| stale plan | plan mode state is durable | if the plan no longer matches the criteria, replan before continuing |
| human rearm | `resume` requires a direct human turn (host-enforced) | the loop can never re-arm itself |

## S7 - Bootstrapping pilot goal (v0)

Full instance text, budget and stop conditions: `D:\Projects\dsh-longloop-pilot\GOAL.md`.
Summary: produce `out\toolkit-v0.1\` (SKILL.md, METHODOLOGY.md, templates/GOAL.md,
templates/STATE.md, templates/EVALUATION.md) until Evaluator v0 exits 0, within 5 rounds,
using only already-verified facts and the locally installed official READMEs.

The goal may **propose** better rules in `PROPOSALS.md`; it may **not** change its own
acceptance baseline.

## S8 - Verification plan (first pilot only)

In scope: P1 goal created with cap 5; P2 automatic continuation really happens;
P3 successive rounds make distinguishable progress; P4 state and artifacts persist;
P5 the evaluator separates PASS from FAIL; P6 pause/resume works; P7 the loop stops when
success is reached; P8 the round cap prevents an unbounded loop.

Deliberately deferred: host-restart recovery (second experiment), `blocked` drill, fork,
Ralph, multi-session coordination, advanced scheduling.

## S9 - Safety reality

Current runtime: file policy `danger-full-access`, `approval.policy = never`.
Therefore `AGENTS.md` prohibitions are **policy, not isolation**.

Genuine host-enforced guards:

- `create_goal` / `update_goal action=edit|pause|resume` are refused unless the call happens
  in a **direct human turn on a runtime-root agent** (`requireDirectHuman`). An autonomous
  round can therefore only ever report `complete` or `blocked`; it cannot re-arm, rename or
  re-budget itself.
- `maxGoalRounds` is enforced by the driver.
- `exit_plan_mode` requires a human answer on the plan-review question.

Not guarded: file writes outside the pilot directory, network use, `git` operations, any
tool call an approval prompt would otherwise have gated.

Consequence: this pilot is **supervised**, not unattended. For a smaller blast radius the
host would have to run with `DSH_PERMISSION_MODE=workspace-write` (which switches
`approval.policy` from `never` to `ask`) or under a workspace-write file sandbox. That is a
human decision and is **not** part of this round.

### S9.1 - Measured status of the boundary (2026-10-08)

[FACT] Under the policy in force during preparation (`danger-full-access`), a write to a
scratch path outside every session workspace root **succeeded**. There is therefore no
filesystem enforcement in the current configuration.

[FACT] `SandboxMode = 'read-only' | 'workspace-write' | 'danger-full-access'` is a real
mode, and the two knobs are orthogonal:

| Knob | Set by | Effect |
|---|---|---|
| approval policy | `DSH_PERMISSION_MODE` env -> the `approval` entry (`danger-full-access` -> `never`, else `ask`) | interactive gate only |
| sandbox mode | session permission preset (`read-only` / `workspace-write` / `danger-full-access`) | **real filesystem fence** (`dsh-fs-sandbox`, `dsh-sandbox-local`, and on Windows an ACL write-SID backend) |

`workspace-write` allows writes to the session workspace root plus designated temp
directories and denies the rest; it is a genuine fence, not merely `approval.policy=ask`.
An isolated `$DSH_HOME` is **not** required to get filesystem scoping; it is only required
to isolate DSH config and session state.

=> `HARD SAFETY BOUNDARY = NOT VERIFIED` **as currently configured**. The earlier plan was to
flip it by switching the pilot session's preset to `workspace-write` and re-running a scratch
write probe. That probe has since been **removed from the runbook** - see S9.2.

### S9.2 - Historical evidence audit (2026-10-08): reuse instead of re-testing

Search of this knowledge base for `workspace-write` / `sandbox` / `filesystem isolation` /
`workspaceRoot` / `DSH_PERMISSION_MODE` / Windows ACL / out-of-workspace write /
permission preset:

| Question | Verdict |
|---|---|
| Is there a past experiment that demonstrated an out-of-workspace write being **denied**? | **NO** |
| Is there past evidence about the **Windows** environment? | **YES** - the whole line is Windows; `dsh-sandbox-windows-acl` / `dsh-win32-process` are present in both eras - but **no denial was ever observed** |
| Does 0.2.0-rc.2 still use the **same enforcement shape**? | **PARTIAL** - same packages at `0.2.0-rc.2` (`dsh-sandbox`, `dsh-sandbox-policy`, `dsh-sandbox-local`, `dsh-fs-sandbox`, `dsh-pwsh-sandbox`, `dsh-bash-sandbox`, `dsh-sandbox-windows-acl`, `dsh-permission-presets`) and the same `dsh-base` entries (`sandbox-policy` with `mode: DSH_PERMISSION_MODE ?? 'workspace-write'` and `workspaceRoot: process.cwd()`; the three presets; `fs-sandbox`). Identical **configuration shape**, unverified **behaviour** |
| Important version change that could invalidate a past conclusion? | Nothing to invalidate - there is no past behavioural conclusion. The gap is a **never-performed test**, not a stale result |

What the history *does* establish:

- `[FACT]` the sandbox / permission / approval **boundary values are observable in session
  events** (`sandbox/mode`, `approval/policy`, `permission/preset`) and are runtime values,
  not project files - `docs/00-dsh-local-filesystem.md` §7.5.3.
- `[FACT]` a phase-3.2 session was observed running with
  `permission/preset = workspace-write`, `sandbox/mode = workspace-write`,
  `approval/policy = ask` - `docs/migration/14-phase32-execution-verification.md` L173.
- `[FACT]` that same session contained **no** `tool/*`, `read`, `edit`, `write` or `pwsh`
  events (L171), so it exercised no filesystem write at all.
- `[FACT]` write-scope verification was planned and left open:
  `docs/migration/13-migration-plan.md` L288 ("验证写入被限制在允许的 workspace 范围、
  sandbox 生效") and L357 (marked `NON-BLOCKING`, "验证时确定"); and
  `14-phase32-execution-verification.md` L211 lists "真实项目数据上的 write 安全验证" as
  still not executed.

Conclusion and decision:

- **[UNKNOWN]** whether `workspace-write` actually denies an out-of-workspace write in this
  environment, in any version.
- Repeating the scratch write probe is **not required for the pilot to proceed**; it is
  replaced by an observation-only pre-start check (preset is `workspace-write`, approval is
  `ask`, workspace root is the pilot workspace, mode is not `danger-full-access`).
- The residual risk is accepted **explicitly and consciously**: the runbook now verifies
  configuration, not behaviour, and `HARD SAFETY BOUNDARY` stays `NOT VERIFIED`.
  Compensating controls: the run is supervised; the autonomous loop cannot re-arm, rename or
  re-budget itself; the pilot's non-goals exclude destructive actions and any write outside
  the pilot workspace; the evaluator is read-only.
- No new sandbox experiment is started by this round.

## S10 - Portable toolkit delivery contract

The final artefact is a **reusable, project-agnostic guidance system**, not a filled-in goal.
It lives in the research repo at:

```
D:\Projects\dsh-test\toolkit\long-running\v0.1\
    README.md          how a user/AI adopts the toolkit in a NEW project
    SKILL.md           procedural guidance: design, start, maintain a long-running loop
    METHODOLOGY.md     why the contracts relate the way they do
    templates/         empty forms to copy and fill per project
        GOAL.md  STATE.md  EVALUATION.md
```

| Requirement | Meaning |
|---|---|
| **PORTABLE** | copyable into any project root; no absolute filesystem path, no local identifier |
| **PROJECT-AGNOSTIC** | contains no goal, budget, path or session id of any particular project |
| **VERSION-AWARE** | records the verified DSH version; marks 0.2.0-specific behaviour as such and tells the reader to re-confirm in the target environment |
| **REUSABLE** | the templates are blank forms; the prose is guidance, not a script |

Rules:

- The toolkit must **not** hard-depend on `C:\Users\...` or `D:\Projects\dsh-test\...`; it
  names official packages and tells the reader to locate the install tree in their own
  environment.
- Official READMEs are **referenced, not copied**. Bulk duplication is forbidden.
- 0.2.0-specific findings may not be presented as universal.

**Delivery path** (three buckets, never merged):

```
pilot workspace (disposable)                research repo (durable)
  out\toolkit-v0.1\   --human accept-->      toolkit\long-running\v0.1\
```

The pilot's `AGENTS.md` forbids writing into the research repo, so promotion is a separate
human step performed **after** human acceptance. Until then the artefact is a **candidate**,
not a release.

## S11 - Evaluator v0 changes for the portable contract (still pre-arm)

Because the portable contract in S10 adds requirements the first evaluator did not cover,
Evaluator v0 was extended **before arming** (this is the last permitted change; it freezes
when the goal is created):

- **C1** now also requires `README.md` with `## What this is`,
  `## How to use it in a new project`, `## Compatibility`.
- **C5** portability: no absolute filesystem path (`X:\`), no local identifier
  (`dsh-longloop-pilot`, `dsh-test`, `Personal Job Search OS`, `user02`).
- **C6** version awareness: `README.md` records the verified version and names the official
  packages; `METHODOLOGY.md` names `@deepseek-ai/dsh-goal-round-driver`.
- **C7** re-confirmation duty stated in `README.md`.

Regression: 9 cases (empty / missing README / missing EVALUATION.md / missing field /
absolute path / dropped version / compliant / read-only audit / fixture immutability),
`check.selftest.ps1` -> `SELFTEST PASS` (exit 0).

## S12 - Acceptance-state separation

`MECHANICAL PASS` (evaluator) -> `READY FOR HUMAN REVIEW` (the loop may report this) ->
`HUMAN ACCEPTANCE` (human only) -> `GOAL COMPLETE` (human only). A model-declared `complete`
and a green evaluator are both insufficient; see the pilot's `GOAL.md`.

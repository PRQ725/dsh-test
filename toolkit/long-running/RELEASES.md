# Long-running Toolkit - releases

Published releases of the Long-running Toolkit. A release is an immutable set of files; a defect
found after publication is registered and planned for a future version rather than patched in place.

## v0.2 - 2026-10-09

| Field | Value |
|---|---|
| Version | **v0.2** |
| Source revision | **v0.2-rc.3** |
| Release date | 2026-10-09 |
| Human content acceptance | **APPROVED** - direct authorization by the user |
| Publication authorization | **APPROVED** - direct authorization by the user |
| Release path | `toolkit/long-running/v0.2/` |
| Source path (kept, traceable) | `experiments/long-running/v0.2-work/candidate/long-running/` |
| Development archive | `experiments/long-running/v0.2-work/` |
| Release report | `experiments/long-running/v0.2-work/RELEASE-REPORT.md` |
| Verification | release 8/8 files match the rc.3 freeze record in `RC3-CHANGE-REPORT.md` section G |
| Research line status | **CLOSED / RELEASED** |

### Contents - exactly eight files

| File | Bytes | SHA256 |
|---|---|---|
| `README.md` | 23744 | `F02C536C85BB9421A4381DF098BE9E52F4EF43AB28ACBD5A7FE92638C7CF2134` |
| `SKILL.md` | 27405 | `95FF1D9097580A9B5A9FBE334D456DF53B8A1E7841EC6D83391D587A8AD5A1AB` |
| `METHODOLOGY.md` | 29942 | `49B6290715D479923033BCBB6CB0020B3439C61071CF626DE94A235040EC41DC` |
| `templates/GOAL.md` | 5169 | `FD19D55CC6AFE13132CA3A4BB8271A45ABB25472FA393E17B9E69B8D941FFEC1` |
| `templates/PLAN.md` | 3023 | `54CC75C48F2688489ABFDA1E5E6979E71146AA64017FC979BCADA21882A49E30` |
| `templates/STATE.md` | 2327 | `8895BA4EA4364F8F4F4D0C2AE5B0E5BDB6C19FC715EA310864ACCDDACB0306AC` |
| `templates/EVALUATION.md` | 6962 | `B576C5A444D13D7B18AED0A672F57E9CEA3E5869895F393B9A96A6204BB88A26` |
| `templates/FINAL-REPORT.md` | 5302 | `4F6F252D0DE32E7F838343C46AEF51336B584B2D7B0FD62BB9CD00E6ABBA8AB5` |

### What was verified, and what was not

**Verified:** structural validation of the eight files; instance-hygiene checking; contract-verified
adoption against a frozen objective contract; a twelve-item initialization-readiness contract that
reports human gates as `PENDING`; and a 44-case regression harness. See the release report for the
raw results.

**Not verified:** live DSH Skill discovery; real multi-round goal execution; pause/resume;
host-restart recovery; adoption by a complex real project. The release report lists these and four
further limitations (L1-L7) in full, and they are published as recorded rather than patched into
the released files.

**How to adopt it:** read `v0.2/README.md` and follow its adoption procedure. The procedural
guidance for an agent is `v0.2/SKILL.md`; the reasoning is `v0.2/METHODOLOGY.md`; the blank forms
are in `v0.2/templates/`.

### How to use this release

1. Copy `v0.2/` into the target project (for example as `toolkit/long-running/`) and keep its
   `templates/` blank.
2. Fill the project's own instances from those blank forms, outside the copied toolkit.
3. Declare the instance root in the project's `GOAL.md` and pass that directory explicitly to your
   evaluator.
4. Treat this release as **immutable**. If something is wrong with it, register the issue; the fix
   belongs to the next version.

### Integrity

Verify a copy by comparing digests against the table above. This repository is **not** a git
repository and no verified OS-level read-only protection is applied to these paths, so the digests
- not the directory's existence - are the integrity check. Do not describe the release as
OS-protected unless such a mechanism has actually been verified.

---

## No earlier release

v0.1 was a pilot artifact and was **never released**: HUMAN ACCEPTANCE was never granted for it.
Its frozen six files and their evidence live in the pilot workspace
`D:\Projects\dsh-longloop-pilot\` and are recorded in
`experiments/long-running/README.md`.

---

## v0.2.1 — 实战回灌（2026-11-20）

来源：在 Personal Job Search OS 的生产式使用中沉淀的 Long-running 改进，去项目化后回灌本 toolkit。

### 方法论文档（`v0.2/`）

- **One Goal，规划/执行同属一个 Goal**：新增 `METHODOLOGY.md` Part 3「Authorization」与 `README.md` 授权模型章节；
  - Planning Authorization：调查、审计、架构、GOAL/PLAN 起草、预算与验收设计均属同一 Goal 的逻辑预算；
  - Execution Authorization：人类一次性批准**冻结的完整 PLAN 范围**；批准执行**不得**新开第二个 Goal；
  - Scope/objective/budget 变化 ⇒ 重新人类裁决，而不是新建 Goal。
- **Human Decision Gate**：明确只有 7 类事件可停下（事实变更、不可逆/越界、重大架构冲突、目标/验收变化、预算扩张、事实歧义、GOAL 明确列出的项目）；非阻塞缺口记录后继续，局部问题不得升级为项目级 BLOCKED。
- **Step 14 扩展**：从「人类验收与知识沉淀」扩为「人类验收、终态与知识沉淀」，并要求 FINAL-REPORT 始终为终态（不得 DRAFT）。
- **预算语义**：Native `maxGoalRounds` 是唯一 `HARD` 预算；逻辑 PLAN 预算只能写 `SOFT logical: N`，**禁止** `HARD N logical`。

### 模板（`v0.2/templates/`）

- `GOAL.md`：新增 Planning/Execution Authorization、Budget（HARD vs SOFT）；
- `PLAN.md`：新增 Authorization mode、冻结范围与执行阶段说明；
- `STATE.md`：新增逻辑轮次 vs Native 运行时（phase / roundsStarted / maxGoalRounds / armed）；
- `FINAL-REPORT.md`：新增 Owner goal、Terminal status、Acceptance status（pending/accepted/rejected，仅人类可定）。

### 工具（`tools/`）

- 新增 `tools/check-longrunning.mjs`（T1 只读结构检查器，`--instance-root` / `--goal-contract` / `--instance-hygiene` / `--self-test`），
  与 `tools/check-longrunning.selftest.mjs`（30 项自测，当前全部通过）。
- 本 toolkit 内路径根 = `toolkit/long-running`（`REPO_ROOT` 指向此处）；接入其它项目时按该项目根调整一行即可。


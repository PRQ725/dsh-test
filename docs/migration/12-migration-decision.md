# Phase 2 — Migration Decision Record

> 本文件是 Phase 2 收尾的 **Migration Decision Record**：把 DSH archaeology + Claude Code archaeology + Concept Mapping 得到的结果「封账」，形成可靠迁移决策基线。它不是 migration plan / 操作步骤。
> 证据等级：`[FACT]` / `[INFERENCE]` / `[UNKNOWN]`；分类：DIRECT-COPY / RE-HOST / RECREATE / ARCHIVE-ONLY / DO-NOT-MIGRATE / UNKNOWN。
> 依赖文档：`10-claude-code-project-inventory.md`（CC Step 1）、`11-claude-code-dsh-concept-mapping.md`（CC↔DSH mapping）。
> 建立：2026-09。

---

## 1. Research Status

| 研究线 | 状态 |
|---|---|
| DSH archaeology（Phase 1：filesystem / bundle / profile / host / root-include / patch / session） | **基本完成**（`00`/`01`/`02`/`03`）[FACT] |
| Claude Code Step 1（Project Inventory & Boundary） | **完成**（`10-…inventory.md`）[FACT] |
| Claude Code Step 2（Concept Mapping） | **完成**（`11-…concept-mapping.md`）[FACT] |

**阻塞分类**（不把一切 UNKNOWN 当 blocker）：
- **migration-blocking UNKNOWN**：当前**没有**经评估会阻止「文件层迁移 + 基础 re-host」的 UNKNOWN。存在若干影响「*多深度* / *还原度*」的未决点，但不构成硬 blocker。[INFERENCE]
- **non-blocking UNKNOWN**：CC 高级机制 runtime 语义（scope/Skill/session）、DSH agent preset→model-visible context 完整组装链细节等——只影响「做到多像」，不影响「可迁、迁什么、边界为何」。[INFERENCE]
- **future research**：未使用的 CC mechanisms、specimen representativeness 等，留待后续（非 Phase 3 起点必需）。[INFERENCE]

---

## 2. What Is the Actual Project Asset?

> 关键纪律：以下类别**不能混为一谈**。它们是不同 persistence/scope 层。

### Project-persistent assets（可迁移、可人工检查、跨会话）
[FACT] Personal Job Search OS 的项目资产 = 项目目录内文件：
- `CLAUDE.md`（根指令/导航/状态文件）
- `README.md`（总览）
- `docs/`（16 份设计/模型/隐私文档）
- 各模块 `README.md` / `_templates/`（schema 契约）/ `_index.md`
- 结构化 Markdown 数据实例（candidate 结构化知识、jobs、match、resumes、discovery、applications…）
- `.gitignore`（隐私/版本边界声明）
- Git 仓库（本地版控历史；属于项目持久化边界）

### Agent instruction（注入模型的行为/约束/导航指令）
[FACT/INFERENCE] CLAUDE.md 中真正属于 Agent 行为规则/约束/导航的部分（16 条核心边界、Privacy Rule、事实与派生规则、修改规则、模块导航）。它是「project-persistent 文件里的 instruction 职能」，但按「它给 Agent 看的规则」单独分类。

### Runtime/session state（运行态，非项目资产）
[FACT] Claude Code session/conversation context、会话日志——CC 平台侧运行态，specimen 项目目录内**无**其文件。

### Machine/environment state（机器/环境级，非项目资产）
[FACT] DSH `$DSH_HOME`、credentials、DSH installation、npm global node_modules、profile node_modules、cache、runtime Fiber state、旧机环境。

> **边界结论**：[FACT/INFERENCE] Project-persistent assets 是唯一「直迁内容」；Agent instruction 是「作为文件迁入后需在目标重承载/确认加载」的一层；Runtime/session state 与 Machine/environment state **都不应作为迁移内容**。三者不可混。

---

## 3. Migration Classification

> 迁移决策分类，非操作步骤。分类含 DIRECT-COPY / RE-HOST / RECREATE / ARCHIVE-ONLY / DO-NOT-MIGRATE / UNKNOWN。

| Asset / Concept | Current Claude Code role | DSH destination / mechanism | Classification | Confidence |
|---|---|---|---|---|
| Project filesystem / workspace | CC 项目根目录 | DSH **workspace**（注册目录 + workspace.json） | **DIRECT-COPY / RE-HOST**（目录内容直迁；在 DSH 侧作为 workspace 注册） | HIGH |
| README.md | 项目总览 | workspace 内 markdown（DSH 无专用 README 机制，仅作文件读取） | **DIRECT-COPY** | HIGH |
| docs/ | project knowledge / schema | workspace 内 markdown | **DIRECT-COPY** | HIGH |
| CLAUDE.md | root instruction / constraint / navigation / state / knowledge | workspace 内文件 + **`dsh-agent-instructions`**（按项目根读 AGENTS.md/CLAUDE.md）；部分职责无法由单一 DSH 机制承载 | **RE-HOST**（指令职能重承载；文件本身 DIRECT-COPY） | HIGH(机制存在)/MEDIUM(全职责还原) |
| `.claude/skills/job-search/` | CC Skill 声明（骨架） | DSH skill 机制 / agent preset skill 层 | **RECREATE / UNKNOWN**（文件可参考，但 CC Skill 骨架需在 DSH skill 语义下重做；骨架未实现故可低成本重建） | MEDIUM |
| Git repository | 项目持久化边界 + 隐私边界 | 无 DSH 对应（正交）；项目自留 | **DO-NOT-MIGRATE（作为 DSH 机制）**；git 历史作为项目资产保留 | HIGH |
| project data（结构化 Markdown） | 项目数据 | workspace 内 markdown（同载体） | **DIRECT-COPY** | HIGH |
| Claude Code session/context | CC 平台运行态 | DSH session + session event log | **DO-NOT-MIGRATE（不迁内容）**；如需仅 ARCHIVE-ONLY | HIGH |
| Agent instruction | CLAUDE.md 的指令/约束/导航 | `dsh-agent-instructions`（AGENTS.md/CLAUDE.md 项目 baseline）+ agent preset(persona/system) 候选 | **RE-HOST** | MEDIUM |
| Runtime state | CC 会话/运行态 | DSH session log + Fiber state | **DO-NOT-MIGRATE** | HIGH |
| Machine/environment state | ~/.claude 用户级、CC 安装 | `$DSH_HOME`、DSH install、credentials、node_modules、cache | **DO-NOT-MIGRATE** | HIGH |
| `.gitignore` | 隐私/版本边界声明 | workspace 内文件（沿用其语义） | **DIRECT-COPY** | HIGH |

---

## 4. CLAUDE.md Decision

> 最重要结论：**CLAUDE.md ≠ 某个 DSH .yml**；它是 one-to-many。

```
CLAUDE.md
  ├── instruction   （Agent 行为/工作流规则）
  ├── constraint    （16 条边界 + Privacy Rule 等硬约束）
  ├── navigation    （指向 docs/ 各模块该读哪份）
  ├── current-state pointer（项目当前推进状态表）
  └── limited knowledge（模块表/对象清单/数据流摘要，非完整知识）
```

决策：
- **`dsh-agent-instructions` 已确认可读取项目根 CLAUDE.md / AGENTS.md**（默认候选 `['AGENTS.md','CLAUDE.md']`，root marker `.git`，root→cwd 逐目录加载，system-reminder 注入）。[FACT：DSH 源码]
- ⇒ **CLAUDE.md 的 Agent-instruction 职责存在一个非常直接的 DSH 承载机制**。[FACT/INFERENCE] 这是最有价值的单点。
- 但 **CLAUDE.md 的全部职责不是由该机制单独等价承载**：[INFERENCE]
  - constraint：DSH 把规则当 instruction 文本注入；无「声明式 rule schema」硬执行。若需硬执行（如 privacy 边界）要落到 host sandbox/approval，性质不同。
  - navigation / current-state / limited knowledge：DSH 把 CLAUDE.md 当**被读的 workspace 文件**，不解析其导航；这些本就是「内容」。
- **docs/ 与项目数据**仍属 workspace/project knowledge（DSH 按需读取，不升级为结构机制）。[FACT]
- **current-state pointer 是持久化项目文件，不是 session runtime state**。[FACT/INFERENCE] 勿把它当 DSH session log / Fiber state。
- **Confidence**：CLAUDE.md「文件可迁 + 指令可由 dsh-agent-instructions 承载」= **HIGH**；「CLAUDE.md 全职责可由单一 DSH 机制等价还原」= **MEDIUM**（navigation/state 无专门机制，按内容承载）。

---

## 5. Session / Runtime Decision

结合 Phase 1 的 DSH 研究结论（`03`、session log 研究）：
- **session log ≠ project**。[FACT] CC session/context、DSH session event log 都不是项目文件。
- **runtime Fiber state ≠ project**。[FACT] DSH 运行态在内存 + `$DSH_HOME/sessions`，非项目资产。
- **session archive ≠ migration prerequisite**。[FACT/INFERENCE] 迁项目文件即可续研；session 只是研究/会话档案，不是续研前提（呼应 `03` §5）。
- **`$DSH_HOME` ≠ Personal Job Search OS project asset**。[FACT] `$DSH_HOME` 是本机 DSH 状态（`C:\Users\user02\.dsh`），与 Personal Job Search OS 是不同目录/不同系统。

> Decision：Session/runtime 内容不进入 Personal Job Search OS → DSH 的项目迁移。

---

## 6. Git / Privacy Decision

- Personal Job Search OS 的 Git repository 是**项目持久化边界的一部分**（本地历史 + 灾难恢复）。[FACT]
- `candidate/raw` 等私人原始资料有 **Git ignore / privacy boundary**。[FACT]
- migration **不应破坏**这个边界；项目内容作为文件迁入目标 workspace 时，应**保留** privacy/ignore 语义（`candidate/raw` 等私人资料不进入公开/研究文档层）。[INFERENCE]
- **不要因 DSH migration 而把原始 PII 引入 DSH archaeology docs**。[RECOMMENDATION/FACT] 遵守项目自身 Privacy Rule + DSH 侧保密纪律。
- **不迁移旧机器的 DSH credentials / identity / `$DSH_HOME`**。[FACT/RECOMMENDATION] 旧机 `C:\Users\12699` 与新机 `C:\Users\user02` 不同；credentials/identity 不跨机复制（呼应 `03` §6）。

---

## 7. What We Do NOT Need to Reproduce

[FACT/RECOMMENDATION] 不需要为「兼容 Claude Code」而创造不存在的机制。列出不重现项：
- Claude Code 的所有高级机制——settings / commands / agents / hooks / MCP（**当前 specimen 未使用**）。
- 旧 DSH runtime（`$DSH_HOME`、安装、profile node_modules、node_modules、cache）。
- 旧 DSH session runtime state（session log、Fiber state）。
- 旧机器安装环境（install、credentials、identity、`C:\Users\12699` 相关）。
- `.claude/skills/job-search/` 作为「CC Skill」——只承载其「未来 Job Search 工作流编排」意图，不复制未实现的 CC 骨架。

> 理由：specimen 只用 CLAUDE.md + skill 骨架；为 CC 未使用机制造对应物既无 specimen 证据、也违反「不做无证据设计」。[INFERENCE]

---

## 8. Remaining UNKNOWNs（仅保留重要项）

| UNKNOWN | 是否阻塞迁移 |
|---|---|
| DSH agent preset → 最终 model-visible context 的**字节级**组装链（persona/instruction/tool schema 注入顺序与预算）；注入到 step 1 durable message 已实证，仅**末跳**未直接观察 | **NON-BLOCKING**（`14` §C/D） |
| Claude Code 完整 session persistence semantics（格式/位置） | **NON-BLOCKING**（session 不迁） |
| 未使用的 Claude Code mechanisms（settings/commands/agents/hooks/MCP）的 runtime 关系 | **NON-BLOCKING**（specimen 未用，不重现） |
| specimen representativeness（只用 CLAUDE.md+skill 骨架，是否代表典型 CC 项目） | **NON-BLOCKING**（不影响本项目迁移，只影响 CC 通用模型完备性） |
| CC 原生 CLAUDE.md 精确加载/继承机制（import/user 叠加等） | **NON-BLOCKING**（DSH 侧承载已 runtime 实证，见 `14` §D） |

> 结论：**以上均为 non-blocking / future research**；没有经评估会阻止当前项目「内容直迁 + CLAUDE.md 指令 re-host」的硬 blocker。[INFERENCE]
> **[UPDATED 2026-09]** 与 `13-migration-plan.md` §15 口径已统一：**不存在 BLOCKING UNKNOWN**；原 `13` 中两个 BLOCKING 均已 RESOLVED（workspace adopt 实测、agent-instructions 实测加载）。[FACT]

---

## 9. Migration Readiness Verdict

## READY WITH CAVEATS

Phase 2 的研究已足以支撑进入 Phase 3 的 migration design。文件层资产（CLAUDE.md/README/docs/templates/数据实例/gitignore）DIRECT-COPY 路径清晰、边界明确。**并且（[UPDATED 2026-09]）Phase 3.2 已进一步实测完成**：workspace adopt 成功、CLAUDE.md 被 `dsh-agent-instructions` 真实注入（`14` §A–D，全部 PASS）。给出 caveats：

**Caveats：**
1. **CLAUDE.md 是 one-to-many**：不能机械 `CLAUDE.md → 某 .yml`；其**指令职能**已由 `dsh-agent-instructions` 实证承载，但 constraint/navigation/state 无声明式 schema，仍按 workspace 文本承载。
2. ~~**指令承载方式待定**~~ → **[RESOLVED 2026-09]**：第一版采用 `dsh-agent-instructions`（项目 CLAUDE/AGENTS 自动加载）而非拆进 agent preset；已 runtime 实证（`14` §C/D）。是否**额外**把部分 persona/behavior 放进 agent preset 仍属 Phase 3.5 优化项。
3. **隐私/版本边界必须保留**：迁入后 `candidate/raw` 私人资料与 PII 不得进入研究/文档层，Git ignore 语义延续。
4. **session/runtime 不迁**：不要让「历史 session 没恢复」成为续研或迁移的障碍。
5. **skill 骨架需重做**：`.claude/skills/job-search/` 作为 DSH skill 的目标定义需在 Phase 3.5 确定（skill 语义不等价）。
6. **README/旧 docs 状态滞后**：Phase 3 应以 CLAUDE.md 状态表 + git 实际为准，勿以过时 README 为迁移清单基线。

---

## 10. Recommended Migration Principle

只写原则，不写操作步骤：
1. **migrate project assets, not machine state** —— 只迁 Personal Job Search OS 项目文件，不迁 `$DSH_HOME`/credentials/install/session runtime。
2. **preserve project filesystem structure unless DSH requires otherwise** —— 默认保留模块/对象/版本目录结构；仅在 DSH 确有要求时才改动。
3. **preserve Git/privacy boundary** —— 迁入后延续 `candidate/raw` ignore 与隐私语义；不把 PII 带进研究层。
4. **re-host Agent instruction rather than mechanically translating file formats** —— CLAUDE.md 指令按「DSH 如何承载 agent instruction」重承载，不做逐格式硬译。
5. **validate behavior after migration** —— 迁后验证 CLAUDE.md 能被 DSH 读取、数据可读、边界生效。
6. **do not attempt to reproduce unused Claude Code mechanisms** —— 不因「兼容 Claude Code」复刻未使用的 settings/commands/agents/hooks/MCP。
7. **keep knowledge in workspace files, not in chat/session** —— 知识/决策沉淀进 workspace docs（延续项目与 DSH 双方纪律）。
8. **make decisions reversible / versioned** —— 迁移改动应可回滚、可追溯（对齐项目「不可变版本」与 Git 纪律）。

---

## 11. Next Phase

## Phase 3 — Personal Job Search OS → DSH Migration（**已启动**）

- ~~migration design~~ → **完成**（`13`，Phase 3.1）
- ~~instruction loading strategy~~ → **已决策并实证**：走 `dsh-agent-instructions`（`14` §C/D）
- ~~target workspace 采用方式~~ → **已实证**：直接 adopt 既有目录（`14` §A/B）
- **仍待做**：Phase 3.3 file/工作流 minimal migration（真实数据使用、写入安全、privacy 运行期验证、rollback 实测）；Phase 3.4 全量 validation；Phase 3.5 skill / automation RECREATE。
- **rollback strategy**：机制已确认（adopt 只写注册，`delete` 不动源目录，`14` §A.2）；实测待 Phase 3.3。

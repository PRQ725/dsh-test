# Phase 2 — Claude Code Project Archaeology
## Step 1: Project Inventory & Boundary Analysis

> 本文把 Step 1（Claude Code Project Inventory & Boundary Analysis）的研究结果**正式落盘**。调查最初以会话报告形式完成；本文为可检索、可引用、可供 Step 2/Phase 3 依赖的持久记录。
> 证据等级贯穿：`[FACT]`=源码/文件直接证明；`[INFERENCE]`=多事实推导；`[UNKNOWN]`=证据不足。
> 研究对象：`D:\Projects\Personal Job Search OS`（用户真实 Claude Code 项目）。建立：2026-09。
> 相关：`11-claude-code-dsh-concept-mapping.md`（Step 2 Concept Mapping）。

> ### ⚠️ 前置说明
> 本文 Step 1 研究只做 READ-ONLY。因 Personal Job Search OS 含用户私人资料，对 `candidate/raw|fact-base|evidence/decisions`、真实 resume/match/job 实例**只检查结构/metadata，不读取 PII 正文**。本轮同样只做最小 READ-ONLY 核实，未做大范围新调查。

---

## 1. Research Scope

- 目标：先理解这个真实 Claude Code Project 本身，**不立即映射到 DSH**、不做 migration design。
- 检查范围：`D:\Projects\Personal Job Search OS` 根目录 + Claude Code 相关位置（CLAUDE.md、.claude、commands/skills/agents/hooks/settings/MCP）+ 各模块结构与数据对象。
- 允许：列目录、读文本、查 metadata、读 Claude Code 配置、搜索定位。
- 禁止：修改/创建/删除/重命名、安装 package、改 git、改 Claude Code 配置、执行改变项目状态的命令。
- **Step 1 不回答**：「CLAUDE.md 对应 DSH 什么」等映射问题；只回答「这个真实项目到底是什么」。

---

## 2. Project Identity

[FACT] 项目 **Personal Job Search OS** 是一个真实、长期维护的个人求职操作系统，目标是把「整理经历 → 分析 JD → 匹配 → 写简历 → 投递 → 面试 → 复盘」统一到一套**可追溯、可复用、可迭代**的分层体系，并以 **Candidate Repository（`candidate/`）作为候选人事实源（Candidate Fact Source）**。

- **它不是传统软件代码项目**：[FACT] 根目录无 `package.json`、无 `src/`、无构建系统；内容几乎全为 **Markdown 文件**。
- 它是 **Markdown / file-system based 的知识 / 数据系统**：[FACT/INFERENCE] 文件既是「schema 说明」(docs/README/模板) 也是「数据记录」(各模块真实实例)。
- Git 定位：[FACT] 本地版本控制 + 灾难恢复，**刻意不配置 remote**（`git remote -v` 为空），GitHub 不是系统组成部分。
- CLAUDE.md 反复声明「**不实现** Resume Generator / 自动匹配算法 / LLM Prompt / Interview Engine / Analytics」——即这些**不以程序**实现，而以规则 + 结构化文档 + 人工/AI 工作流承载。[FACT]

---

## 3. Project Inventory

### 3.1 根目录
| 条目 | 状态 | 说明 |
|---|---|---|
| `CLAUDE.md` | ✅ | 约 11 KB，项目长期工作上下文入口 |
| `README.md` | ✅ | 约 2.8 KB，项目总览 |
| `.gitignore` | ✅ | Git 范围管理 + 隐私边界 |
| `.git/` | ✅ | 本地仓库，`main` 分支 |
| `.claude/` | ✅ | 仅 `skills/job-search/` 骨架 |
| 顶层模块目录 | ✅ | candidate / discovery / jobs / resumes / applications / match / interviews / analytics / docs |

### 3.2 顶层模块结构与实例
- **candidate/**（1155 文件，多数在 raw）— `raw/`(只读原始资料) `fact-base/` `evidence/` `decisions/` + `preferences.md` + `manifest.md` + `README.md`
- **jobs/** — 4 个真实岗位实例（`tencent-ai-algo-eng / game-client / hpc-research / chip-design`，各含 `job.md/jd.md/requirements.md/analysis.md`）+ `_templates/`
- **discovery/tencent/** — 35 个 Discovered Job（disc-tencent-001..038）+ 1 个 Run
- **resumes/** — 2 个真实实例（`RES-20260815-001__master`{v1,v2}、`RES-20260815-002__tencent-game-client`{v1}）+ `_templates/`
- **match/** — 4 个真实分析（MAT-20260814-001..004，各含 match.md + 不可变 v1/v2）
- **applications/** — 仅 `_templates/` + README + `_index.md`（无真实投递）
- **interviews/、analytics/** — 仅 README 占位
- **docs/** — 16 份设计文档（ARCHITECTURE / DATA-MODEL / 各 *-MODEL / CAREER-DIRECTION-MATRIX / RESUME-STRATEGY / WORKFLOWS / NAMING-CONVENTIONS / PRIVACY-POLICY / GIT-PRIVACY-AUDIT / DISCOVERY-LESSONS / WEB-JOB-DISCOVERY / README）

> 注意：以上真实实例数量为 [FACT]（文件系统统计），各实例**正文 PII 未读取**。

### 3.3 Git 追踪范围（read-only）
- tracked：candidate 结构化知识（fact-base 21 文件、decisions、evidence、manifest、preferences）、jobs 真实 4 岗、match 真实 4 分析、discovery/tencent 真实扫描、docs 全 16、CLAUDE/README/.gitignore、各模块 README/模板/索引。[FACT]
- 未提交改动：`M CLAUDE.md` + `?? resumes/RES-.../`（2 个实例目录 untracked）。[FACT]
- gitignored：`candidate/raw/`（私人原始资料）、generated exports/attachments、缓存、临时文件、备份归档等。[FACT]
- `git remote`：空（无 origin/任何 remote）。[FACT]

---

## 4. Claude Code Related Files

[FACT] 项目「Claude Code 特有痕迹」极少：
- `CLAUDE.md`（根）— 存在
- `.claude/skills/job-search/{SKILL.md, README.md}` — 存在（骨架）

[FACT] 以下在项目 scope **不存在**：`.claude/settings.json`、`settings.local.json`、`.claude/commands/`、`.claude/agents/`、`.claude/hooks/`、MCP 配置、`.claude-version`。

[FACT] 附带说明：全树搜到的 `candidate/raw/projects/*/CLAUDE.md` 与一处 `.vscode/settings.json`，是**被当作候选原始资料**的其他项目/他人项目文件（位于 gitignored 的 `candidate/raw/` 内），**不属于本项目自身的 Claude Code 配置**。

---

## 5. File Classification

| 类别 | 文件 |
|---|---|
| **A. Project Documentation** | `README.md`、`docs/` 全部（ARCHITECTURE、各 *-MODEL、WORKFLOWS、NAMING-CONVENTIONS、CAREER-DIRECTION-MATRIX、RESUME-STRATEGY、PRIVACY-POLICY、GIT-PRIVACY-AUDIT、DISCOVERY-LESSONS、WEB-JOB-DISCOVERY、docs/README）、各模块 `README.md` |
| **B. AI / Agent Instructions** | `CLAUDE.md`（根；项目唯一 AI 指令入口）、`.claude/skills/job-search/SKILL.md`（骨架，含 frontmatter `name`/`description`，未实现） |
| **C. Claude Code Configuration** | 仅 `.claude/skills/job-search/`（Skill 声明目录）。**不存在**：settings.json / commands / agents / hooks / MCP |
| **D. Application / Project Files**（本项目的「数据/应用」等价物 = 结构化 Markdown 数据对象） | 数据实例：`candidate/fact-base/*`、`candidate/evidence/*`、`candidate/decisions/*`、`jobs/<job-id>/*.md`、`match/MAT-*/vN.md`、`resumes/RES-*/{vN,resume-meta}.md`、`discovery/tencent/**`；模板：各模块 `_templates/*.md`；索引：各模块 `_index.md`；元数据/清单：`candidate/manifest.md`、`candidate/preferences.md`、各 `*-meta.md` |
| **E. Other** | `candidate/raw/**`（私人原始资料输入层：PDF/XLSX/图片/他人项目文件）——归为原始素材/输入，非本项目运行文件但为事实源输入 |

> 核心认知：这是一个**以 Markdown 为「schema+记录」、以 README/docs 为「schema 说明」、以 CLAUDE.md 为「约束/导航引擎」的文件系统数据系统**。[INFERENCE]

---

## 6. Project Data / Object Structure

[FACT] CLAUDE.md 列出 **16 个核心对象**：Candidate · Fact · Evidence · Claim · Job · Original JD · Requirement · JD Analysis · Match Analysis · Application · Resume · Cover Letter · Export Artifact · Interview · Discovered Job · Discovery Run（Outcome 属 Application；Export Artifact 是导出文件）。

三层数据模型（来自 CLAUDE.md/ARCHITECTURE，[FACT]）：
- **事实层 Fact Layer**：Candidate Fact Source（`candidate/`）+ Original JD Source of Truth（`jobs/<id>/jd.md`）。规则：可追溯、不编造、raw 原样保留。
- **分析层 Analysis Layer**：JD 分析、Match Analysis、Discovery 初筛、Analytics。规则：派生、可重算、标注来源。
- **产出层 Output Layer**：Resume、Cover Letter、Export、Application、Interview。规则：选择性/包装性表达，不反写事实层。

强约束（不可违反，来自 CLAUDE.md「核心边界」16 条）：Claim≠Evidence、Job≠Application、Resume≠Fact Source、Match Analysis 可重算不改事实、Facts≠Preferences≠Self-Assessment、「无证据证明≠不满足」(DATA_GAP 不自动升 SKILL_GAP)、AI Experience 能力边界、Development & Documentation Privacy Rule 等。

对象组织约定：[FACT]「一个对象一目录」+「不可变版本 vN」（resume-meta/match/job 模板均体现：meta 可改、vN 不可变；Application 引用具体 `RES-…-vN`、`MAT-…-vN`）。命名：稳定 ID `前缀-YYYYMMDD-NNN` + slug 目录（见 `docs/NAMING-CONVENTIONS.md`）。

---

## 7. Git / Privacy Boundary

[FACT] 三条隐私防线（CLAUDE.md「Git 定位」明写）：
1. `candidate/` 等私人目录 + 真实实例数据，默认不进入 Git tracked。
2. `.gitignore` 显式 ignore：`candidate/raw/`、generated exports/attachments、缓存、临时文件、备份归档。
3. **不配置远程仓库**（无 origin / 不 push）——GitHub 不再是系统组成部分。
- 设计意图：**Git 历史本身不是隐私机制**；真正边界 = 私人目录 + .gitignore + 无 remote。[FACT]
- 实际状态：candidate 结构化知识(fact-base/evidence/decisions/preferences/manifest) 已 tracked；`candidate/raw/` 原始资料被 ignore（仅其 README 占位 tracked）。[FACT]

> ⚠️ **文档-实际漂移（客观观察，非本次制造）**：多个模块 README / ARCHITECTURE 仍写「真实实例数据不进入 Git / 无真实岗位」，但实际 git 已 tracked 真实 job/match/discovery 实例。即 **README/旧 docs 滞后于实际推进**；CLAUDE.md 状态表与实际 git 更接近。[FACT]

---

## 8. CLAUDE.md Analysis

### 8.1 包含什么类型的信息（内容分类）
自述为「**项目导航 + 最高优先级工作规则**」，不重复 docs。实际包含：[FACT]
1. Project Identity（背景/目标/方式）
2. 核心模块表（导航）
3. 核心对象 16 个（数据模型导航）
4. 核心边界 16 条不可违反规则（最强约束）
5. Git 定位（本地/不配 remote/隐私防线）
6. Development & Documentation Privacy Rule（6 条）
7. 事实与派生规则（Fact 来源限制；JD 来源仅 STATED/INFERRED）
8. 核心数据流（ASCII 图）
9. 修改规则（改架构先查 docs；改动需同步 DATA-MODEL/ARCHITECTURE/WORKFLOWS/README/模板）
10. Skill 原则（骨架勿塞整个系统；分层）
11. 当前项目状态表（各模块 ✅/🔨/⬜ + 版本进展）
12. 结尾：改架构先读 docs，勿依赖历史聊天 Session

不包含：coding conventions（无代码）、构建命令、task-specific 对话脚本。[FACT]

### 8.2 角色判断（多角色并存）
[INFERENCE] CLAUDE.md 同时承担：
- **Agent instruction**（顶层指令：每次进项目该守的规则）
- **constraint**（16 条边界 + Privacy Rule，恒生效 hard must/must-not）
- **navigation / router**（指向 docs/ 该读哪份）
- **current-state pointer**（项目状态表，让不记得历史的新 session 接续）
- **少量 project knowledge**（模块表/对象清单/数据流本身）
它**不是** documentation（那属 README/docs）；是「给 Agent 的运行时指令 + 项目自描述」的混合体。

### 8.3 CLAUDE.md 是 project knowledge 还是 runtime instruction？
[FACT/INFERENCE] **两者都有，且刻意分层**：
- Runtime instruction 面：核心边界、Privacy Rule、事实/修改规则——「行为约束/工作流规则」。
- Project knowledge / 导航面：模块表、对象清单、数据流、文档路由、当前状态——是**指向 docs 已有知识的「导航/索引 + 增量状态」**，本身非完整知识体。
- 关键证据：CLAUDE.md 自述只做「导航与规则固化，不重复全部文档内容」；把详细设计委托给 docs/。⇒ **CLAUDE.md = 瘦的、规则/导航优先入口；docs/ = 厚的、schema/说明知识体**；非冗余而是分层。[FACT→INFERENCE]

---

## 9. README.md Analysis

[FACT/INFERENCE]
- **受众**：广义/项目门面（人也看、后续 session 也做第一眼导航），偏说明性。
- **解决**：说明「这是什么系统」+ 目标 + 模块/状态 + 当前已完成 + 下一步，指向 `docs/ARCHITECTURE.md`。
- **是否含 AI-specific instructions**：基本没有——它是说明，不是约束。
- **与 CLAUDE.md 重叠**：模块目录表、职责、当前状态、下一步——**两处都有**（有意的导航冗余）。
- **职责差异**：README = 稳定、偏静态、「系统是什么」；CLAUDE.md = 高动态、约束/规则、「Agent 该怎么干活、有什么不许违反、推进到哪」。二者分工不同层，非真正重复。
- **漂移**：README 明显滞后（写「无真实岗位/简历」「Phase 2 骨架中」）；CLAUDE.md 与 git 实际已推进到「4 真实岗位 + 4 真实 match + 2 真实简历」。README 已过时，CLAUDE.md 为最新事实源。[FACT]

---

## 10. Claude Code Project Boundary

三层边界结构 [FACT/INFERENCE]：
```
① Claude Code 平台注入层（非项目文件、用户级/全局）：CLI 自身 settings/全局 context/MCP 服务/内置 Agent+Tools/认证 — 仓库内无痕迹，属平台侧
② 本项目显式「Claude Code 边界面」（仓库内）：CLAUDE.md（root 指令+规则+状态）+ .claude/skills/job-search/（未实现骨架）；（settings/commands/agents/hooks/MCP 存在性均空）
③ 项目自身内容系统（绝大多数文件）：docs/ + 各模块 README/_templates/_index + 数据实例 + .gitignore/git 边界
```

边界观察：
- 项目「Claude Code 特有痕迹」极少，只有 1 个 CLAUDE.md + 1 个未实现 skill 骨架。[FACT]
- 绝大多数体量是项目自己的领域数据系统，与 Claude Code 机制无关——Claude Code 在此更像「遵循文件规则的执行器」，而非「被深度编排的对象」。[INFERENCE]
- 项目把领域逻辑以「规则/数据」外置进 Markdown，不依赖 CC 的 settings/agents/hooks 承载业务逻辑。[INFERENCE]

---

## 11. Current Claude Code Mechanism Usage

| 机制 | specimen 内使用 |
|---|---|
| CLAUDE.md（root memory/instruction） | ✅ 使用（唯一真正的 CC 指令入口） |
| .claude/skills/ | ✅ 仅 1 个占位骨架（job-search），未实现逻辑 |
| settings.json / commands / agents / hooks / MCP | ❌ 均未使用（项目 scope 不存在） |

[FACT] 该 specimen 是「纯」Claude Code 项目：只用了 CLAUDE.md + 一个未实现 Skill 骨架；settings/commands/agents/hooks/MCP 全为**未实例化的平台通用槽位**。

---

## 12. UNKNOWNs

1. Claude Code 平台对 CLAUDE.md 的**精确加载/继承机制**（哪些算 project CLAUDE、是否支持 `@`import、user CLAUDE 叠加、优先级）——specimen 无源码/运行证据。[UNKNOWN]
2. Claude Code **project/user/session scope** 的精确 runtime 边界。[UNKNOWN]
3. **Skill runtime loading**（frontmatter 如何被发现/何时注入）——specimen 只有未实现骨架。[UNKNOWN]
4. **CC session 持久化**的确切位置与格式（推断平台侧 `~/.claude`）。[UNKNOWN]
5. specimen 是否代表典型 CC 项目——它只用 CLAUDE.md+skill 骨架，未用多数 CC 机制。[UNKNOWN]
6. 未使用机制的 runtime 关系（settings/commands/agents/hooks/MCP）需其它 specimen/官方文档。[UNKNOWN]

---

## 13. Step 1 Conclusions

1. Personal Job Search OS 是 **Markdown/file-system based 的知识/数据系统**，不是传统代码项目。[FACT]
2. root 有 `CLAUDE.md` 与 `README.md`。[FACT]
3. `.claude/` 只有一个**尚未实现**的 `job-search` Skill 骨架。[FACT]
4. 无 settings.json / settings.local.json / commands / agents / hooks / MCP 配置（项目 scope）。[FACT]
5. Git 是本地版控 + 灾难恢复，**不配 remote**。[FACT]
6. `candidate/raw` 是私人原始资料输入层，有 Git ignore/privacy boundary。[FACT]
7. docs / templates / structured data 构成项目自身知识/数据系统。[FACT]
8. CLAUDE.md 同时承担 instruction / constraint / navigation / current-state pointer 等职责。[FACT/INFERENCE]
9. README 与 CLAUDE.md 有**有意的导航重叠**，但职责不同（README=静态门面，CLAUDE.md=动态约束+状态）。[FACT/INFERENCE]
10. README 状态明显滞后；CLAUDE.md 与实际 Git 状态更接近。[FACT]
11. Claude Code 特有的项目内机制**非常少**。[FACT]
12. 项目是「规则/数据外置 + 模型照章执行」型，未深度使用 Claude Code 高级机制。[INFERENCE]

> 下一研究动作（Step 2）已做：见 `11-claude-code-dsh-concept-mapping.md`。

# Phase 2 — Claude Code ↔ DSH Concept Mapping

> 本文是 Phase 2 的 Concept Mapping 产出（Step 2）。目标不是设计 migration，而是回答：**Claude Code Project 中已识别的概念，在 DSH 中有没有对应物？若有，对应关系是什么性质？若无，缺口在哪？**
> 证据等级：`[FACT]`=源码/文件直接证明；`[INFERENCE]`=多事实推导；`[UNKNOWN]`=证据不足；`[RECOMMENDATION]`=后续设计建议。
> 建立：2026-09。
> 研究对象：`D:\Projects\Personal Job Search OS`（Claude Code specimen）；DSH 本机安装（`@deepseek-ai/dsh@0.1.1-rc.2`）+ Phase 1 archaeology 文档。

> ### ⚠️ 前置事实 / 文档状态
> - 上一轮 Step 1 的 inventory 最初以会话报告形式给出，后已落盘为 `10-claude-code-project-inventory.md`。本文的 Claude Code 侧事实与该文件一致。
> - **[UPDATED 2026-09]** specimen `Personal Job Search OS` **现已注册为 DSH workspace**（`92030ae8-62db-4114-bf99-5ccdcb4c1449`）——本文写作时它还不是。当前状态见 `14-phase32-execution-verification.md` §B。本文的 mapping 结论不受影响，但其中「尚未 adopt / 尚未实测」的前瞻性表述**已由 Phase 3.2 的结果取代**。[FACT]

---

## 1. Research Scope

- **Claude Code 侧**：仅研究 `Personal Job Search OS` 中**实际存在**的项目概念；Claude Code 通用但本项目未实例化的机制单独标记 `Platform-level concept, not instantiated in this specimen`，不强塞进「实际项目模型」。
- **DSH 侧**：使用 Phase 1 已确认的模型 + 本轮回源码复核；覆盖 workspace / profile / bundle / host / agent / session / sandbox 等。
- **对照维度**：Responsibility、Scope、Lifecycle、Runtime semantics、Persistence、Authority、Mutability、User/Agent visibility。
- 本轮**不做 migration design**，只记录 research 层面的 migration implications。

---

## 2. Claude Code Concept Model

> 基于 specimen 实际文件（本轮重新核实）建立。区分「标本中实例化」与「平台通用未实例化」。

### 2.1 实际实例化（specimen 证据）
| 概念 | 标本证据 | 它是什么 |
|---|---|---|
| **Project filesystem / workspace** | 整个 `D:\Projects\Personal Job Search OS` 目录树 | 一个含 `.git`、`CLAUDE.md`、模块子目录的项目根。数据以 Markdown 文件承载。 |
| **CLAUDE.md** | 根目录 `CLAUDE.md`（11 KB） | 项目长期工作上下文入口：导航 + 最高优先级规则 + 项目状态。 |
| **Project knowledge / docs** | `docs/`（16 份设计文档：ARCHITECTURE / 各 *-MODEL / PRIVACY / GIT-PRIVACY-AUDIT 等） | schema / 架构 / 工作流说明，是「厚知识体」。CLAUDE.md 只导航不重复。 |
| **Module structure + schemas + data** | 各模块 `README.md`、`_templates/*.md`、`_index.md`、真实数据实例（`candidate/`、`jobs/<id>/`、`match/MAT-*`、`resumes/RES-*`） | 模块边界说明 + 数据契约(schema) + 实际记录。以「一个对象一目录 + 不可变版本 vN」组织。 |
| **`.claude/skills/`** | `.claude/skills/job-search/{SKILL.md, README.md}`（**骨架**，SKILL.md 有 frontmatter `name`/`description`） | Claude Code Skill 声明目录；本项目仅占位，未实现任何逻辑。 |
| **Git / project persistence** | `.git/`（本地，无 remote）+ `.gitignore` | 本地版控 + 灾难恢复；`.gitignore` 划定隐私边界（`candidate/raw/` 私人资料不跟踪，结构化知识可跟踪）。 |
| **Session / conversation context** | 无标本内文件（Claude Code 会话日志在平台侧 `~/.claude/...`，不属于项目） | 平台运行态。specimen 只能推断其存在，无法从项目文件证明其格式。 |
| **Agent / runtime** | 无项目内证据 | Claude Code 的 CLI/模型运行进程，平台侧。 |

### 2.2 本项目**未**使用的 Claude Code 机制
- `.claude/settings.json`、`commands/`、`agents/`、`hooks/`、MCP 配置、`.claude-version`：**全项目 scope 不存在**。
- 全树搜到的 `candidate/raw/projects/*/CLAUDE.md` 与一处 `.vscode/settings.json` 是**被当作候选原始资料**的其他项目文件（在 gitignored 的 `candidate/raw/` 内），非本项目自身配置。
- 分类：以下为 **Platform-level concepts, not instantiated in this specimen**：CC `commands`、`agents`、`hooks`、`settings`、MCP、内置 tools 目录；以及本项目对 README/CLAUDE.md 之外的 agent-visible config 均未用。

---

## 3. DSH Concept Model

> 引用 Phase 1 文档（`00/01/02/03`，已按当前机器语义规范化）+ 本轮源码复核。列出与 CC 映射直接相关的机制。

| 概念 | 是什么 | Scope/Plane | Persistence | Runtime 如何进入 | Knowledge? Instruction? State? |
|---|---|---|---|---|---|
| **Workspace** | 一个已注册的项目目录（`workspace.json` 记录 path/title/sessionIds） | DSH 运行期注册对象 | `$DSH_HOME/storages/workspace.json` | DSH 启动会话时按 workspace 关联 cwd | Project knowledge 所在层 |
| **Profile** | `$DSH_HOME/profiles/<name>/` 目录：`package.json`(manifest, `dsh.profile.bundles`)、`cordis.yml`(空 root)、`cordis.patch.yml`(用户层)、`pnpm-workspace.yaml` | Host plane | `$DSH_HOME/profiles/<name>/` | boot 时 `loadProfile` + `initProfile`（首用自动 init，`web` 是 shipped 模板） | 机器级 host 组合，非 project knowledge |
| **Bundle** | 含 `dsh.bundle.patch` 的 npm package（base / web-app）；提供 bundle patch | Host plane | dsh 安装 `node_modules` + profiles 扁平 fallback | profile 的 `dsh.profile.bundles` 顺序解析 | host 组合来源，非 project |
| **Host composition** | 空 root ← base bundle patch ← web-app bundle patch ← profile patch ← home patch ← `--patch`；单次 `applyEntryPatches` | Host plane | profile/bundle patch 文件 + 内存 Entry tree | boot 时 `composeProfile`/`boot` 装配 | host 基础设施（注册表/sandbox/persistence/model route） |
| **Host Entry / EntryGroup / Fiber** | 组合后的 entry 树；`Include.root = EntryGroup`；Entry → `registry.plugin` → `new Fiber` | Host plane | 内存（root `cordis.yml` 仅作 baseUrl 锚点） | `root.update` 按 id reconcile | 运行态 |
| **Agent scope / composition** | 每个会话把所选 preset 挂进 agent scope；`agent→preset→global` 作用域链 | Agent plane | preset 文件 + 会话运行 | `agentPresets.mount(agentCtx, id)` | agent 构成 |
| **Agent preset** | 目录含 `agent.cordis.yml`（**[UPDATED 2026-09]** 0.1.5-rc.1 shipped roster = standard/cordis/ptc/minimal；旧版含 code；user 可 copy 到 user root） | Agent plane | **[UPDATED]** `<DSH>\node_modules\@deepseek-ai\dsh-agent-presets\presets\`（system）+ `$DSH_HOME\.agent-presets\`（user）；旧版为 `config/agent-presets/` | roster 扫描 roots；每进程单 mount 于 standing scope，会话加入 | **agent instruction 的主要载体之一** |
| **Agent preset cordis patch** | `agent.cordis.yml` 中逐行 = agent-plane plugin 行（persona / agent-instructions / tool-fs / tool-pwsh / tool-skill …） | Agent plane | preset 文件 | 随 preset mount 逐行激活 | 定义 agent 的 model-facing tools + prompt 段 |
| **Model-facing tools** | tool-fs / tool-fs-search / tool-bash/tool-pwsh / tool-jobs / tool-skill 等，注册进 host tools registry 但 schema 随 scope 可见 | Agent plane（模型可见） | plugin 包 + preset 行 | preset mount 时注册 | agent 工具 |
| **AGENTS.md / CLAUDE.md instruction loading** | `dsh-agent-instructions`：加载 `$DSH_HOME/AGENTS.md`(user-global) 后按 root→cwd 逐目录加载候选；默认候选 `['AGENTS.md','CLAUDE.md']`，overlay `['AGENTS.local.md','CLAUDE.local.md']`，root marker `['.git']` | Agent plane（注入历史） | 项目/workspace markdown 文件 + `$DSH_HOME/AGENTS.md` | 首步 agent/pre-step 组合 baseline → 注入 step1；fs 触碰后动态增/改/删 | **project/workspace instruction 的直接消费机制** |
| **Session** | 一个 workspace 下一次会话（header 带 cwd、agentPreset、title 等） | Agent/session | `workspace.json` + `session_projcache.json` | `session.create` | — |
| **Session event log** | append-only JSONL（.zstd）事件日志 | session | `$DSH_HOME/sessions/<workspace-key>/<id>/session.jsonl(.zstd)` | 事件持久化 | runtime/session state 的持久面 |
| **$DSH_HOME** | harness home（本机 `C:\Users\user02\.dsh`） | 机器/用户级 | — | env `$DSH_HOME` | 机器/环境级 |
| **Sandbox / permission boundary** | host plane 的 sandbox + approval stack（fs 策略、approval） | Host plane | config/运行 | boot | host 基础设施 |

---

## 4. Core Mapping Table

> 关系类型：`Direct equivalent` / `Functional analogue` / `Split across multiple mechanisms` / `Contained within another mechanism` / `No direct equivalent` / `Unknown`。证据见 confidence §9。

| # | Claude Code 概念（specimen） | DSH 对应 | 关系类型 | 理由 |
|---|---|---|---|---|
| 1 | Project filesystem / workspace | DSH **workspace**（已注册目录 + 关联 session） | **Functional analogue** | CC「项目」= 任意含 `.git`/`CLAUDE.md` 的目录；DSH「workspace」= 显式注册（`workspace.json`）+ 关联 session。文件树相同载体，但 DSH 多一层显式注册。 |
| 2 | CLAUDE.md（整体） | **多个 DSH 机制**（见 §5） | **Split across multiple mechanisms / one-to-many** | CC 一个文件承载 instruction+constraint+navigation+state+knowledge；DSH 无单一对应，需拆分。 |
| 3 | Project knowledge / docs/ | DSH **workspace 内 markdown 文件**（由 tool-fs/read 读取，非结构机制） | **Functional analogue** | 两端都把「知识」作为项目内文件由模型读取；DSH 没有把 docs 提升为受管 registry 的机制。 |
| 4 | `.claude/skills/` | DSH **skills registry + skill 文件系统发现 + tool-skill**（`dsh-agent-presets` standard 已注册 skill-filesystem/tool-skill） | **Functional analogue** | 两端都有「Skill」目录；但 CC 侧 specimen 仅骨架未实现，DSH 侧 skill 机制真实存在。二者语义是否等价仍待证（见 §11）。 |
| 5 | Git / project persistence | DSH 无独立「项目 git」机制；但 workspace 内文件可自行 git（DSH 不介入） | **No direct equivalent（正交）** | Git 是项目/内容层事实，非 DSH 运行时机制；DSH 自己的持久化是 `$DSH_HOME`（机器级）+ session log，与项目 git 不同层。 |
| 6 | CC session / conversation context | DSH **session + session event log** | **Functional analogue** | 两端都是「某项目/workspace 下一次与模型的会话」。但 CC session 日志在平台侧（specimen 无项目内证据）；DSH session log 结构已确认。精确格式/继承仍 [UNKNOWN]。 |
| 7 | Agent / runtime | DSH **agent（session 内）+ agent preset + host 基础设施** | **Split / Functional analogue** | CC 单个「Agent」概念在 DSH 拆成 host(共享基础设施) + agent(preset 构成的模型面)。CC 侧本项目无项目内 agent 证据。 |
| 8 | CC tools（内置 Read/Edit/Bash/Grep…） | DSH **model-facing tools**（tool-fs / tool-fs-search / tool-pwsh / tool-skill…） | **Functional analogue** | 两端都以「模型可见工具」形式出现；CC 内置、DSH 由 preset 行注册。名称不可一一对应（见 §10）。 |
| 9 | Project-level instruction（CLAUDE.md 内容作指令） | DSH **`dsh-agent-instructions`**（AGENTS.md/CLAUDE.md 项目 baseline）+ **agent preset persona/instruction** | **Direct-equivalent-leaning** | DSH 有原生机制按项目根→cwd 加载 CLAUDE.md/AGENTS.md 作 instruction（默认候选即含 `CLAUDE.md`）。这是全部映射中最接近的对应。 |
| 10 | Project knowledge（持续、项目内） | DSH workspace markdown（读取得） | **Functional analogue** | 两端知识都持久在项目文件，模型按需读。 |
| 11 | Runtime / session state | DSH session event log + 内存 Fiber/plugin state | **Functional analogue** | 两端「运行态」都不是 project files；CC 侧仅推断存在，DSH 侧机制已确认。 |
| — | CC user/global scope（~/.claude） | DSH `$DSH_HOME/AGENTS.md`(user-global instruction) + `$DSH_HOME`(machine state) | **Functional analogue** | 两者都有「用户/机器级」层，但具体文件集不同。CC 侧本项目未用。 |
| — | CC `.claude/settings` / commands / agents / hooks / MCP | DSH 无逐一对等；部分可能对应 host/agent 机制 | **Unknown**（specimen 无实例） | 标本未实例化，无法从 specimen 判对应；需其他 specimen 或 CC 官方文档。 |

> 注意：#9 的「Direct-equivalent-leaning」仅指 **DSH 存在按项目加载 CLAUDE.md 作 instruction 的机制**（源码可证）。不等于「CC 的 CLAUDE.md 注入语义 = DSH 的 AGENTS.md 注入语义」——CC 侧精确加载/继承机制仍未从 runtime/source 验证（见 §11）。

---

## 5. CLAUDE.md One-to-Many Analysis

> 不回答「CLAUDE.md = 某 .yml」，而是把 CLAUDE.md 的职责切片分别落到 DSH。

| CLAUDE.md 职责切片（Step 1 已识别） | DSH 中落在哪 | 关系 | 说明 |
|---|---|---|---|
| **A. instruction**（工作流/事实规则/修改规则等「该怎么做」） | `dsh-agent-instructions` 的项目 instruction baseline（它按 root 读 CLAUDE.md/AGENTS.md 注入）＋ **agent preset 的 persona / 系统提示行** | **直接对应为主（机制存在）** | DSH 的原生 instruction 加载机制会把 CLAUDE.md 内容作为项目级 instruction 注入模型历史（system-reminder 帧）。同时 agent preset persona 定义「你是谁」，可承载通用 coding 指令。[FACT：dsh-agent-instructions 默认候选含 CLAUDE.md] |
| **B. constraint**（核心边界 16 条、Privacy Rule、事实规则） | 同 instruction baseline（作为文本被加载）+ **DSH host 的 sandbox/approval**（若约束要硬性执行而非仅提示） | **Split** | DSH 没有「声明式 rule schema」；CC 的规则是给模型看的指令文本。硬约束（能否写某目录）在 DSH 由 host sandbox/approval 表达，与 CC 的文本规则性质不同。 |
| **C. navigation / router**（指向 docs/ 各模块该读哪份） | **无 DSH 独立「router」机制**；作为 instruction 文本被加载后，模型据此去 tool-fs/read 读 workspace 文件 | **Contained within instruction mechanism** | DSH 不解析 CLAUDE.md 的「导航」，只把它整段当 instruction 注入；导航结果是模型执行读文件的产物。 |
| **D. project-state pointer**（「当前项目状态」表格） | **无 DSH 声明式「项目状态」机制**；状态若写成文件 = workspace markdown，每次作为候选 instruction 被读 | **No direct equivalent as mechanism（内容落在 workspace 文件 + 被当作 instruction 文本）** | CC 靠 CLAUDE.md 里的状态文本接续；DSH 没有「把某文件当项目状态」的内建物，状态文件与知识文件在 DSH 里同是「可被 AGENTS 机制读的 markdown」。注意：DSH 的 session/title/state 是**会话运行态**，与「项目当前推进状态」不是一回事。 |
| **E. knowledge / reference**（对象清单、数据流、模块表） | **workspace 内 markdown**（docs + CLAUDE.md 作为可读文件）+ 由模型 tool 读取 | **Functional analogue** | DSH 把这些当项目文件，不升级为结构机制；与「直接迁移资产」一致。 |

**结论**：CLAUDE.md 在 DSH 中是 **one-to-many**：其**指令职责**可由 `dsh-agent-instructions`（AGENTS.md/CLAUDE.md 加载）最直接承接；其**导航/状态/知识**部分是「作为 workspace markdown 被模型读取」的内容，DSH 没有也不需要有单独的「CLAUDE.md 等价物」——它们本应落在 workspace 文件层。若要把某些规则变成**对该 agent 恒生效**（不分项目），则要落入 **agent preset**（persona / 系统提示）。**没有「CLAUDE.md = 某一个 .yml」的单点对应。**

---

## 6. Project Knowledge vs Agent Instruction vs Runtime State

### 6.1 三分法在两系统内是否成立

**Claude Code specimen 侧**（基于项目内文件）
1. **Project knowledge**：`docs/`、模块 README、模板、数据实例 → 持久、项目内、可人工检查、跨会话可迁移。[FACT]
2. **Agent instruction**：`CLAUDE.md` 的规则/导航内容 → 是知识的一部分，但承担「给模型的行为指令」职能；是 CC 自动加载的 project-level context。[FACT/INFERENCE]
3. **Runtime/session state**：CC 会话日志与运行态 → **不在项目文件内**（specimen 项目目录中无 CC session 文件），属平台侧。[INFERENCE]

**DSH 侧**（源码确认）
1. **Project-persistent knowledge**：workspace 内 markdown（docs、模板、数据）→ 由 tool 读取；不依赖 profile/session。[FACT]
2. **Agent instruction**：agent preset（persona/instruction 行）+ `dsh-agent-instructions` 从 workspace/AGENTS 加载的 instruction baseline → 注入模型历史。[FACT]
3. **Runtime/session state**：session event log（`session.jsonl`）+ 内存 Fiber state → 不是 project files，随会话持久在 `$DSH_HOME/sessions`。[FACT]

### 6.2 三分法验证结论
> 两套系统都成立**三个不同 persistence/scope 层级**：[INFERENCE]（由上面 FACT 推导）
> - **Project-persistent knowledge**：两端都在「项目/workspace 目录」内的文件，可直迁、可人工检查。
> - **Agent instruction**：两端都是「注入到模型上下文的行为/导航指令」，但**载体与激活时机不同**（CC=CLAUDE.md 项目自动加载；DSH=agent preset 定义 + 按项目加载 AGENTS/CLAUDE）。这是**迁移最需要对齐的层**。
> - **Runtime/session state**：两端都不是项目资产，是机器/运行态，**不可作为直迁资产**。

- Personal Job Search OS：`docs/`、模板、数据实例 = **Project knowledge**；CLAUDE.md 规则/导航 = **instruction 兼 knowledge-pointer**；项目内**无** runtime state（在平台侧）。[FACT]
- CLAUDE.md 中：instruction(§A/B) + navigation(§C) + state-pointer(§D) + knowledge(§E)。其中真正的「instruction/constraint」才是 agent instruction；state 表是「knowledge/state pointer」而非运行时状态。项目状态 ≠ 会话运行时状态。[FACT/INFERENCE]
- DSH：workspace markdown = project knowledge；agent preset + agent-instructions 输出 = agent instruction；session log / Fiber = runtime state。[FACT]

---

## 7. Scope Mapping

> 「同名≠同 scope 语义」。specimen 无法证明 CC 侧精确 runtime scope 行为之处标 UNKNOWN。

| Claude Code scope | DSH scope | 关系 | 说明 |
|---|---|---|---|
| **project scope**（当前目录 + CLAUDE.md/.claude） | DSH **workspace + workspace 内 AGENTS/CLAUDE 加载（root→cwd）** | **Functional analogue** | 两端都有「某项目目录为作用域」。DSH 的 instruction discovery 用 projectRootMarker(`.git`) 向上找根再 root→cwd 读文件——与 CC「项目级 CLAUDE.md」概念一致。CC 精确匹配（哪些文件算 project CLAUDE）[UNKNOWN]。 |
| **user/global scope**（`~/.claude`，含 user CLAUDE.md/settings） | DSH `$DSH_HOME` 级（`$DSH_HOME/AGENTS.md` user-global + 机器级 profile/bundle） | **Functional analogue** | 都有「用户/机器级」层先于项目层。但 DSH 的 user-global instruction 固定为 `AGENTS.md`；CC 的 user scope 文件集与加载语义需 CC 侧证据，[UNKNOWN]。 |
| **session/runtime scope**（本次对话、会话日志） | DSH **session（agent scope 内）+ session event log** | **Functional analogue** | 两端都「一次会话」为界。DSH 会话有自己的 cwd/agentPreset/scope parent chain（agent→preset→global）。CC 会话与项目/scope 绑定方式待证。[UNKNOWN]。 |
| — | DSH **host scope**（无 CC 直接同名物） | **No direct equivalent（DSH 特有）** | CC 没有「进程级共享基础设施」的显式等价；CC 的能力多在 CLI/运行时内建。DSH 的 host plane（sandbox/registry/model route/web）是 CC 没有的一层。 |

> 关键提醒：CC 的「project/user/session」与 DSH 的「workspace/host/agent/session」**不是四组一一对应**。CC 是「project + user/global + session」三维；DSH 是「workspace + host(process) + agent + session + $DSH_HOME」五维。二者都含「项目」「会话」字样，但 scope 划分不同：DSH 多了**host(进程/机器基础设施)** 与 **agent(preset 构成)** 两个显式层。[FACT/INFERENCE]

---

## 8. Persistence Boundary

| Concept | Claude Code persistence | DSH persistence | Mapping |
|---|---|---|---|
| CLAUDE.md | 项目根文件（git-tracked） | workspace markdown（可被 dsh-agent-instructions 读作 project instruction） | **直迁资产（文件）** |
| docs/ + 模块 README + 模板 | 项目文件（git） | workspace markdown | **直迁资产（文件）** |
| project data（数据实例） | 项目文件（结构化 markdown；部分 gitignored） | workspace markdown（同一载体） | **直迁资产（文件），内容自洽** |
| `.claude/skills/` | 项目内 skill 声明 | DSH skill 机制（preset/registry） | **需重建模（文件可迁但激活机制不同）** |
| `.git` | 项目本地版本历史 | 无 DSH 对应（正交） | 项目自留，不属 DSH |
| session/conversation | CC 平台侧（`~/.claude/...`，非项目文件） | DSH `$DSH_HOME/sessions/...` jsonl | 两端都非项目资产；**运行态，非直迁** |
| DSH workspace（注册） | — | `$DSH_HOME/storages/workspace.json` | DSH 运行期注册，非内容资产 |
| agent preset | — | **[UPDATED 2026-09]** `<DSH>\node_modules\@deepseek-ai\dsh-agent-presets\presets\`（system）+ `$DSH_HOME\.agent-presets\`（user）；旧版为 `config/agent-presets/` | DSH 特有；CC 无直接「preset」文件，需从 CC agent-visible 行为归纳 |
| session log | CC 平台 | `$DSH_HOME/sessions/<ws>/<id>/session.jsonl(.zstd)` | 两端运行态档案；不当作直迁知识 |
| $DSH_HOME | —（CC 用户目录 `~/.claude`） | `C:\Users\user02\.dsh` | 机器/环境级，不迁移内容 |
| runtime Fiber state | — | 内存 | 运行态，不迁移 |

**目标问题回答**：
- **可直接迁移的持久化项目资产**：CLAUDE.md、docs/、模块 README/模板/索引、真实数据实例、`.gitignore`（文件本身）——它们都是项目内文件。[FACT]
- **运行时产生的状态**：CC session 日志、DSH session log、内存 Fiber/plugin state、workspace 注册、DSH 运行期索引。[FACT]
- **机器/环境级状态**：`$DSH_HOME`（profile/bundle 安装、AGENTS.md user-global、session 存储、credentials/cache）、CC 用户目录 `~/.claude`。[FACT]
- > 本表只描述 persistence 边界，**不构成 migration procedure**。

---

## 9. Mapping Confidence

| Mapping | Confidence | 证据来源 |
|---|---|---|
| #9 CLAUDE.md 项目指令 → DSH `dsh-agent-instructions`（存在按项目读 CLAUDE.md 的机制） | **HIGH** | DSH 源码：默认 `instructionFileCandidates=['AGENTS.md','CLAUDE.md']`、root marker `.git`、root→cwd 加载、system-reminder 注入。机制存在性无可疑。 |
| #9 **该机制在真实 session 中确实注入 PJOS CLAUDE.md** | **HIGH（已升级）** | **[UPDATED 2026-09]** Phase 3.2 Step 2B runtime 取证：session `session-1c4f609d-…` seq=8 durable user/message，`source.kind=agent-instructions`、`baseline=true`、`changes.path=CLAUDE.md`，text 含 CLAUDE.md 全文，位于 step 1、首次 request 前，零 tool 调用。详见 `14-phase32-execution-verification.md` §D。[FACT] |
| #9「CC 原生 CLAUDE.md 注入语义 == DSH 的 AGENTS/CLAUDE 注入语义」 | **MEDIUM**（未升级） | CC 侧精确加载/继承/scope 仍未从 CC runtime/source 验证；只能确认「DSH 侧确实注入」，不能确认两端语义完全等价。 |
| #2/#5 CLAUDE.md one-to-many、CLAUDE.md≠单一 .yml | **HIGH** | CLAUDE.md 内容切片（instr/constraint/nav/state/knowledge）均已逐段定位，DSH 无单一承载物（多处 `No direct equivalent`）。 |
| #1 workspace ↔ workspace | **HIGH（已升级）** | **[UPDATED 2026-09]** `workspace.create` adopt 语义 + PJOS 真实注册 + 项目零副作用已实测（`14` §A/B）。 |
| #6 session ↔ session | **MEDIUM** | 两端概念存在且同向，但 CC 侧 session 归属/持久化 specimen 无法证明；DSH 侧 session/log 结构已 FACT（`00` §7.5.2）。 |
| #8 CC tools ↔ DSH model-facing tools | **MEDIUM** | 两端都以工具目录形式存在，但 CC 内置工具集本项目文件无法枚举，名称/语义一一对应未验证。 |
| #4 skills ↔ DSH skills | **MEDIUM** | 标本 skill 仅骨架，无法验证 CC skill 的真实 runtime 加载；DSH skill 机制真实。等价性 [UNKNOWN] 但类比成立。 |
| #7 Agent/runtime；#11 runtime state | **LOW-MEDIUM** | CC 侧无项目内证据，主要靠概念推断；DSH 侧机制已确认。 |
| scope 映射（project/user/session ↔ workspace/host/agent/session） | **MEDIUM**（DSH 侧 HIGH，CC 侧 scope 精确行为 LOW） | 分层已由源码确认，但 CC 侧 scope runtime 行为 [UNKNOWN]。 |

> 不制造虚假 HIGH：CC 侧凡是依赖平台内部、specimen 无法证明的，最高只给 MEDIUM。
> **[UPDATED 2026-09] 升级说明**：#9（DSH 侧实际注入）与 #1（workspace adopt）已由 Phase 3.2 的 runtime/实测证据从 MEDIUM 升为 HIGH；**未**把任何 CC 侧未验证项升级。

---

## 10. Key Findings

1. **CLAUDE.md 是 one-to-many，不是单点对应**。[FACT→INFERENCE] 它同时是 instruction(A/B)、navigation(C)、state-pointer(D)、knowledge(E)。DSH 无一个「CLAUDE.md 等价物」；其**指令职责**最接近 DSH 的 `dsh-agent-instructions`（DSH 原生就按项目根读 `CLAUDE.md`/`AGENTS.md`），其**导航/状态/知识**职责则落在「workspace markdown + 模型读取」层，**没有**对应 DSH 的声明式状态/规则 schema。
2. **DSH 已内建「读 CLAUDE.md 作项目指令」的机制**（HIGH），并已在真实 session 中**实测注入成功**（`14` §D）。这意味着 CLAUDE.md 作为文件**可以原样成为 DSH workspace 的 project instruction**——这是最有价值的单点发现。
3. **三分法（project knowledge / agent instruction / runtime state）在两系统都成立**。[INFERENCE] 两端的 knowledge 都是项目文件；instruction 都是「注入模型上下文的行为指令」但**载体/激活不同**；runtime state 都是非项目、机器/运行态。migration 最大对齐点在第一层（文件直迁），需设计的是第二层（instruction 重新承载）。
4. **DSH 有 CC 没有的显式层次：host(进程/基础设施) 与 agent preset**。[FACT] CC 的单「Agent」/单「项目」在 DSH 中是多 plane 的。CC 的「能力如何在项目内组合」没有 CC 侧的显式等价文件可解剖（specimen 全走 CLAUDE.md 文本 + 平台内建）。
5. **CC 的 user/project/session scope ≠ DSH 的 workspace/host/agent/session scope**。[FACT/INFERENCE] 二者都有「项目」「会话」，但 DSH 多了 host + agent(preset) 两层，scope 划分不同。不能因同名而对等。
6. **CLAUDE.md 的「项目状态」不是会话运行时状态**。[FACT/INFERENCE] 它是「项目推进情况的知识/文件」，DSH 对应的是 workspace 文件内容，**不是** session log / Fiber state。DSH 的会话运行态与 CC 会话运行态才是同一类（均不可直迁）。
7. **DSH 内没有把「constraint 规则」变成声明式 schema 的机制**；CC 的规则是给模型读的文本。[INFERENCE] 若要硬执行（如 privacy 边界），需落到 host sandbox/approval，性质不同。
8. **多份 module README 滞后于实际推进**（README、jobs/README、ARCHITECTURE.md 仍写「无真实岗位/数据」而 git 已 tracked 真实实例）——这是 specimen 自身的文档-状态漂移，不影响 mapping 但提醒：以 CLAUDE.md 状态表 + git 为准，勿信旧 README。[FACT]

---

## 11. UNKNOWNs

1. **CC CLAUDE.md 的精确加载/继承机制**（哪些文件算 project CLAUDE、是否支持 `@`import、user CLAUDE.md 如何叠加、优先级）——specimen 无源码/运行证据，需 CC 官方文档或其他 specimen。
2. **CC user/project/session scope 的精确 runtime 边界**——同上。
3. **CC Skill 的 runtime loading**（SKILL.md frontmatter 如何被发现/挂载/何时注入）——specimen 只有未实现骨架。
4. **CC session persistence 的确切位置与格式**（仅推断在平台侧 `~/.claude`）——specimen 项目文件内无证据。
5. **DSH agent preset → model context 的完整链路**（persona/instruction 段如何精确拼进 model-visible 上下文、与 tool schema 顺序/预算）——部分源码可见；**注入到 step 1 durable user/message 已实证**（`14` §C/D），但**最终请求 payload 的字节级组装未被直接观察** → 仍 [UNKNOWN]/[INFERENCE]。
6. **CC tools ↔ DSH tools 的精确一一对应**（CC 内置工具集本项目无法枚举；名称相似≠语义等价）。
7. **CC `.claude/settings`/commands/agents/hooks/MCP ↔ DSH 的对应**——specimen 未实例化，无法从标本判对应，需其他 specimen + CC 文档。
8. **specimen 是否代表「典型」Claude Code 项目**——它只用 CLAUDE.md + 一个 skill 骨架，未用多数 CC 机制，是「文件/知识系统型」项目；对用满 settings/agents/hooks/MCP 的项目，本 mapping 不完备。

---

## 12. Implications for Migration（研究发现的影响，非迁移方案）

- 若未来要把 CC 项目迁到 DSH，**文件层（docs/、CLAUDE.md、数据实例、模板）本身可直接成为 DSH workspace 内容**，无需换格式；且 DSH 原生会读 CLAUDE.md 作 project instruction——意味着 CLAUDE.md 的「指令」职能可能几乎零成本保留。[INFERENCE]
- **难点在设计层，不是文件层**：CLAUDE.md 里的「约束/导航/状态」在 DSH 没有对应 schema，需决定它们是「继续作为 workspace 文件文本」（近似现状）还是「提炼进 agent preset / 某种声明式物」。此决定属 migration design，本轮不做。[RECOMMENDATION]
- **CC「无硬性约束机制」→ DSH「有 host sandbox/approval」** 是一个能力增益点：CC 的文本规则若迁到 DSH，可选择性升级为硬性 sandbox/approval（例如 privacy 边界）。这是「加能力」而非「平移」。[INFERENCE]
- **运行态/会话态不可作为迁移内容**（两端都是机器/会话级）——呼应 Phase 1 的「session 是档案非迁移主机制」。[FACT]
- 由于本 specimen 是「知识系统型」CC 项目，它只揭示 CC 模型的一个子集；对 CC 的完整 project model（含 hooks/agents/MCP/settings）仍需其它 specimen 补全后才能谈完整 mapping。[RECOMMENDATION]

---

## 13. Next Research Questions

1. 用 CC 官方文档 / 一个含 settings·agents·hooks·MCP 的 specimen，验证 CC project/user/session scope 与 CLAUDE.md/Skill 的**精确 runtime 语义**（解 §11 第 1–4 项）。
2. 追踪 **DSH agent preset 到最终 model-visible 上下文**的完整组装链（persona / agent-instructions / tool schema 的注入顺序与预算），以确定 CLAUDE.md 指令迁到 DSH 后「落在 preset 还是 workspace-AGENTS 加载」的语义差异（解 §11 第 5 项）。
3. 比较 **CC Skill frontmatter 语义**与 **DSH skill 机制**（目录发现、何时注入、权限/trust）——是 true skill 等价还是仅命名相似。
4. 厘清 CC「项目状态文本」能否 / 应否映射到 DSH 任一机制，或两者都只当 workspace 内容（CLAUDE.md state table 的 DSH 落点）。
5. 收集第 2 个 CC specimen（用到 settings/agents/hooks/MCP），检验本 mapping 在「非纯文件型」项目上的完备性。
6. （届时）把 CLAUDE.md 的 instruction 职责拆到 DSH preset 与 workspace-AGENTS 加载之间的**归属标准**（何时放哪边）——属 migration design 前置研究。

# 研究上下文固化 · 阶段一 → 阶段二衔接

> 本文是**研究状态 + 阶段衔接文档**，不是聊天记录 / transcript，也不是 DSH 底层事实的主要来源。
> 底层事实以 `00` / `01` / `02` 为准；本文记录**阶段性研究状态、已做出的研究决策、下一阶段入口**。
> 证据等级贯穿：`[FACT]`=源码/文件/实际行为直接证明；`[INFERENCE]`=多事实推导；`[UNKNOWN]`=未验证。
> 建立：2026-09（阶段一收束）

> ### 环境状态更新（迁移后必读，避免把旧路径当当前环境）
> 第一阶段源码考古在原机器进行，其绝对路径历史事实为：`$DSH_HOME = C:\Users\12699\.dsh`；workspace = `D:\dsh-test`。[FACT]
> 本文档及其 workspace 现已在**当前机器**：`$DSH_HOME = C:\Users\user02\.dsh`；workspace = `D:\Projects\dsh-test`。[FACT]
> 下面正文中凡指「第一阶段当时」的 `D:\dsh-test`，均指**原机器历史事实**；「当前」一律指 `D:\Projects\dsh-test`。本文技术结论（bundle/profile/host/agent composition、patch 语义等）不受迁移影响。

---

## 1. 文档定位

- 本文是**研究上下文固化文件**（Context Consolidation）。
- 目标：若未来在另一台电脑重启一个不记得本次对话的新 DSH session，读本文后应能明白——研究到哪、为何这样设计、下一步做什么。
- 它不是 transcript；不逐条复述对话。
- 相关文档：`00`（文件事实）、`01`（composition 架构/归属）、`02`（运行机制）、`README`（导航索引）。

---

## 2. 第一阶段已完成的重要架构结论（接续用）

- Host composition 与 Agent composition 是**不同 scope / plane**。[FACT]
- bundle / profile / home / CLI `--patch` 组合机制：按序摊平后单次应用。[FACT]（细节见 `01`）
- Root Include：`cordis.yml` → `Include.read()` → `EntryOptions[]` → `applyEntryPatches` → `EntryGroup.update`。[FACT]
- Entry → `Entry.update`/`init` → `tree.import(name)` → `Entry._start` → `ctx.registry.plugin` → `new Fiber`。[FACT]（`Include.root = EntryGroup`；`root.update = EntryGroup.update`）
- `cordis.yml` 是 Root Include 的**磁盘数据源**；当前 Web Profile 由 DSH 策略将其保持为 `[]`（每次 boot 重写）。[FACT]
- patch 是 **ordered patch operations**，不是普通 config object merge；`config` 为整键替换。[FACT]
- 第一阶段考古时的 workspace `D:\dsh-test`（原机器）是 **research workspace**，不是 self-contained DSH profile/project（其根目录无 `cordis.yml`/`package.json`）。[FACT] 迁移后同一 research workspace 位于当前机器的 `D:\Projects\dsh-test`。
- 仍 [UNKNOWN]：Cordis `Fiber` 启动后的完整 effect/依赖注入时序；`ModuleLoader` 动态导入细节（阶段一决定暂不深入）。

---

## 3. 当前研究项目的知识载体

核心可迁移资产 = 本 `docs\` 下的 Markdown：[FACT]
- `docs/00-dsh-local-filesystem.md` — 概念 ↔ 本机路径
- `docs/01-host-composition.md` — composition 架构/归属（Host/Agent 层级）
- `docs/02-root-include-and-patch-composition.md` — Root Include / patch 算子 / 运行链
- `docs/04-agent-composition-and-instructions.md` — agent composition 与 instruction system
- `docs/05-browser-mcp.md` — Browser MCP 集成与 E2E
- `docs/06-dsh-runtime-and-multiprocess.md` — runtime 与多进程行为
- `docs/browser-mcp/` — Browser MCP 研究线知识
- `docs/migration/` — Claude Code → DSH 迁移研究
- `docs/README.md` — 导航索引
- 本文 `03-…`

[FACT] 这些 Markdown 是当前研究知识的主要可迁移载体。
- 原 `docs/dsh-write-test.md`（已不存在于该路径）已于 2026-09 归档至 `archive/temp/dsh-write-test.md`（早期实验产物）。[FACT]
- `web-config.txt` / `web-default.txt`（原 workspace 根）= 0.1.1 时代的 diagnostic dump，非核心知识；**2026-09 已归档**至 `archive/0.1.1-era/` 与 `archive/superseded-dumps/`。[FACT]
- 不要把 `$DSH_HOME` 整体当作 project knowledge。[FACT]

---

## 4. Session 与长期研究知识的边界

### Knowledge（已入 Markdown）
可迁移 ✅；可人工检查 ✅；不依赖 session ✅；是未来研究的主要上下文载体。[FACT]

### Conversation Context（仅当前对话）
不应成为唯一研究知识载体；session log 可存档，但后续研究不应依赖它才能继续。[INFERENCE]

### Runtime / Session State（活 Fiber、Plugin instance 等）
属运行态，不作为跨机迁移资产。[FACT]

**明确区分**（不要混为一谈）：
- session log = 持久化事件日志
- session history = 由 log 重放的对话/历史
- session state = 某会话可重放/重建的层面（部分在 log）
- runtime state = 活进程/内存态（不在 log）
- project knowledge = Markdown 知识文件

---

## 5. Session Log 研究结论（无敏感内容）

- session persistence 使用 `$DSH_HOME\sessions\<workspace>\<id>\session.jsonl(.zstd)`。[FACT]
- 格式：JSONL，默认 zstd 压缩（`@deepseek-ai/dsh-session-persistence-jsonl`）。[FACT]
- 是 **append-only event log**。[FACT]
- 记录 user/assistant/tool（含 tool 调用与结果）等事件。[FACT]
- 存在 replay / restore / resume 机制（`dsh-session`；dsh CLI `--resume`）。[FACT]
- session runtime ≠ log：运行态不在 log。[FACT]
- session export/download 是 **ZIP**（`dsh-session-<id>.zip`）。[FACT]
- ZIP 含原始 log，并可能含 descendant/subagent logs 与引用附件。[FACT]
- **无已确认的“把 download ZIP 直接 import 到另一台机器继续 session”的一等公民机制**：[INFERENCE]（基于目前源码——export 是面向人工查看/分享的 ZIP，未发现 DSH 侧 ZIP re-import 会话路径）。

> 结论：session log 更适合作为**研究档案/参考**，而非跨机迁移研究上下文的主要机制。

---

## 6. 迁移策略（阶段一收束时所写；已在当前机器完成 workspace 迁移）

> 本节描述的迁移策略在当时面向「目标机器」；**该迁移现已完成**：research workspace（含本 `docs\`）已到当前机器 `D:\Projects\dsh-test`，session archive 归入 `archive\`。以下为当时策略的事实记录，保留原样。

不迁移整个 `$DSH_HOME`。
**不直接复制**：DSH installation、npm global node_modules、`$DSH_HOME` 整体、profile node_modules、credentials、runtime cache、live runtime state。[FACT]
**核心迁移资产**：原机器 `D:\dsh-test\docs\`（迁移后位于当前机器 `D:\Projects\dsh-test\docs\`）。[FACT]
**可选**：session export ZIP 作为研究档案（迁移后已归入 `archive\`）。[INFERENCE]

---

## 7. 关于 Profile 的决策

- [FACT] 使用 `$DSH_HOME\profiles\web`（该 profile 是 DSH 的 shipped 模板 profile，见 `00`/`02`）。
- [FACT] research workspace 根目录本身没有 `cordis.yml` / `package.json` 等 self-contained profile 文件（原机器 `D:\dsh-test` 与迁移后当前机器 `D:\Projects\dsh-test` 均如此）。
- [INFERENCE] 新机器的 profile / bundle / installation 应在该机器上**重新研究并建立**（不直接复制原 `$DSH_HOME`）。
- ~~[UNKNOWN] 特定机器最终是否需要名为 `web` 的 profile~~ → **已解决**：`web` 是 DSH **shipped 模板 profile**（`PROFILE_TEMPLATES.web`），首次 boot `web` 时自动初始化（见 `00`）。[FACT]

> Profile 是「所在机器上的研究对象」，不随 workspace 跨机复制；当前机器（`C:\Users\user02`）的 profile 已在 DSH 首次 boot `web` 时自动初始化为 shipped 模板。

---

## 8. 第二阶段研究目标（**已完成** —— 见 §11 阶段状态）

下一阶段不是马上"改造项目"。第一步是：

> **研究一个真实 Claude Code Project 本身**。

研究 specimen：`D:\Projects\Personal Job Search OS`
目标：建立 **Claude Code Project Model**。
重点调查：CLAUDE.md、project/user/global scope、`.claude/`、commands、skills、agents、settings、hooks、MCP、tools、session/runtime/model-facing boundary。

第一阶段**不要急着**建 `Claude Code X = DSH Y`；先把 Claude Code 自己解剖清楚。[RECOMMENDATION]

> 状态：本目标**已执行**（Phase 2 Step 1 = `migration/10`，Step 2 = `migration/11`）。

---

## 9. 第二阶段研究方法

```
真实 Claude Code Project
  + Claude Code 官方文档/源码/实际行为
        ↓
  Claude Code Project Model
        ↓
  Concept Mapping
        ↓
  Migration Design
        ↓
  实际 Migration
```
不要跳过 Project Model。
同名≠同 runtime abstraction：Claude Code Skill/Agent/Hook 与 DSH Plugin/Agent/Hook 不能仅凭名称一一对应。[INFERENCE/RECOMMENDATION]

---

## 10. 当前 UNKNOWN / 待研究问题（已按 Phase 3.2 更新）

### DSH 侧
- **profile 如何建立** → **已解决**：`web` 为 shipped 模板 profile，首次 boot 自动初始化。[FACT]
- **workspace 与 Claude Code project 的空间关系** → **已解决（决策 + 实测）**：**直接采用原目录为 DSH workspace**（不复制），已实测 adopt 成功且项目零副作用（`migration/14` §A/B）。[FACT]
- DSH agent 是否应让研究 workspace 去读 sibling Claude Code project？sandbox/filesystem permissions 如何影响？→ **部分解决**：sandbox 边界值可见（`workspace-write` / `approval=ask`，见 `00` §7.5.3）；具体读取策略仍 [UNKNOWN]。[FACT/UNKNOWN]

### Claude Code / CLAUDE.md 侧（**必须分侧表述**）
- **DSH 侧承载 CLAUDE.md 的机制** → **已是 [FACT]**：`dsh-agent-instructions` 按 cwd 的 project root 发现并注入 `CLAUDE.md`，产物是 durable user-role instruction，位于 step 1、首次 model request 之前（机制见 `04`；runtime 取证见 `migration/14` §C/D）。
- **user-global 层（`$DSH_HOME/AGENTS.md`）** → **已是 [FACT]（2026-09-12 E2E）**：新 session 首次请求前注入；**已存在 session 在下一个 step 感知新增/修改（含非 touch 修改）**；永久 language policy 已在真实工作流生效（`experiments/dsh-runtime/2026-09-12-global-agents-e2e.md`、`04` §6.1）。[FACT]
- **Claude Code 原生侧的 CLAUDE.md 精确加载/继承语义**（哪些文件算 project CLAUDE、`@`import、user CLAUDE 叠加、优先级）→ 仍 **[UNKNOWN]**（本 specimen 无 CC 源码/runtime 证据，需 CC 官方文档或其它 specimen）。[UNKNOWN]
- CC command/skill/agent/hook 真实 runtime 关系、MCP 与 model-facing tools 如何连、settings 与 runtime 边界 → 本 specimen **未使用**这些机制 → [UNKNOWN]，**不阻塞**本项目迁移。[UNKNOWN]

### Migration 侧
- 哪些可直迁为文件、哪些须重新建模、哪些无对应物；各属 Host plane / Agent plane / runtime infrastructure → **已有决策基线**（`migration/12`）；实际执行仍在 Phase 3.3+。[FACT/UNKNOWN]

---

## 11. 阶段状态（截至最新）

> **⚠️ 命名消歧**：本表是 **PJOS 迁移线**的 Phase 编号。browser-lab 实验线**另有自己的编号**（`B3.3 / B3.3b / B3.4 / B3.5 / B3.6`），见 `experiments/browser-mcp/` —— 两套编号**不要混用**。

### 11.1 PJOS 迁移线
| 阶段 | 内容 | 状态 |
|---|---|---|
| Phase 1 | DSH 源码考古（filesystem / bundle / profile / host / Root Include / patch / session） | **完成**（`00`/`01`/`02`/`03`） |
| workspace 迁移 | 原机器 → 当前机器（`D:\Projects\dsh-test`） | **完成**（含 `archive/session-logs/`） |
| Phase 2 Step 1 | Claude Code Project Inventory & Boundary | **完成**（`migration/10`） |
| Phase 2 Step 2 | Claude Code ↔ DSH Concept Mapping | **完成**（`migration/11`） |
| Phase 2 收尾 | Migration Decision Record | **完成**（`migration/12`，READY WITH CAVEATS） |
| Phase 3.1 | Migration Design | **完成**（`migration/13`） |
| Phase 3.2 Step 1 / 1B | `workspace.create` 源码验证 + 真实 PJOS workspace adopt 验收 | **完成 PASS**（`migration/14` §A/B） |
| Phase 3.2 Step 2A / 2B | `dsh-agent-instructions` 源码验证 + CLAUDE.md runtime injection 取证 | **完成 PASS**（`migration/14` §C/D） |
| Phase 3.3 | Minimal Migration（真实数据使用 / 写入安全 / privacy 运行期验证 / rollback 实测） | **未开始** |
| Phase 3.4 | Validation 全量（instruction 行为、filesystem 边界、隐私） | **未开始** |
| Phase 3.5 | Optional Recreate（skill / DSH-specific automation） | **未开始** |

### 11.2 Browser MCP 线（browser-lab）
| 阶段 | 内容 | 状态 |
|---|---|---|
| B3.3 | 创建 `browser-lab` profile | **完成**（`experiments/browser-mcp/2026-09-11-B3.3-…`） |
| B3.3b | web profile MCP 挂载状态只读检查（结论：installed 但未 mounted） | **完成**（`…-B3.3b-…`） |
| B3.4 | 向 `browser-lab` patch 层插入 `mcp-playwright` Entry 并 dump 验证 | **完成**（`…-B3.4-…`） |
| B3.5 | **E2E tool invocation**：`browser_navigate` + `browser_snapshot` 真实执行（`example.com`） | **完成 PASS**（`…-B3.5-…`） |
| B3.6 | **Interactive JS-rendered SPA E2E**：真实招聘 SPA + `browser_click`（`[ref=eN]`）→ 服务端结果集变化 | **完成 PASS**（`…-B3.6-interactive-spa-e2e.md`） |
| — | Instruction 线：`$DSH_HOME/AGENTS.md` global instruction E2E（新 session + existing session + 永久 language policy） | **完成 PASS**（`experiments/dsh-runtime/2026-09-12-global-agents-e2e.md`、`04` §6.1） |

### 11.3 Profile / Bundle 隔离线（browser-lab）

| 阶段 | 内容 | 状态 |
|---|---|---|
| P1 | **prep**：read-only 基线 + 源码闭环（归属写入面 / 读取面 / 无继承） | **完成**（`experiments/profile-isolation/2026-09-15-whale-widget-profile-isolation-prep.md`） |
| P2 | **install + E2E**：`browser-lab` profile-local 安装 `dsh-whale-widget@0.3.0` + 运行验证 | **完成 PASS**（`…-browser-lab-install-e2e.md`） |
| — | `web` 非成员核对（逐文件哈希比对） | **完成 PASS** |
| — | AFTER `--dump-config` 合成树对照 | **未采集**（`--dump-config` 会重写 profile 的 `cordis.yml` 且需新进程）⇒ full E2E = **PARTIAL** |

> 长期知识沉淀于 **`07-profile-bundle-isolation.md`**。

### 11.4 DSH 安装 / 升级线

| 阶段 | 内容 | 状态 |
|---|---|---|
| P-1 | **事故**：全局 `npm install -g @deepseek-ai/dsh` rc.1 → rc.2（失败）→ rc.1 回滚（失败）→ **rc.3（恢复）** | **已恢复**（`experiments/dsh-install/2026-09-23-dsh-global-upgrade-rc1-to-rc3-incident.md`） |
| P-2 | **原始取证**：三份 npm debug log 原件归档（`logs-max=10` 裁剪风险） | **完成**（`evidence/logs/npm/`） |
| P-3 | **长期知识**：安装形态 / 三层解析模型 / 升级与回滚语义 | **完成**（`docs/08-dsh-installation-and-upgrade.md`） |

**长期结论（4 条可复用）**：

1. **[FACT]** 全局安装在 prerelease 上会重新解析宽松依赖范围 ⇒ **顶层版本与内部 sibling 版本可以不一致**；`dsh --version` 正确 ≠ 依赖树正确。
2. **[FACT]** `npm install -g <pkg>@<old>` **只固定顶层版本**，仍会重新解析依赖范围 ⇒ **top-level rollback ≠ dependency-tree rollback**；且全局 npm 安装**没有 lockfile** 可依赖。
3. **[FACT]** global DSH installation 被整体替换 **不会**删除 **profile-local bundle membership**（Whale 实证存活）。
4. **[FACT]** `install-scripts blocked` 在当前**已测**工作流（browser-lab / Web UI / Whale / Browser MCP）未造成可见故障。

**仍保留的 UNKNOWN**（详见 `08` §10）：npm prerelease caret 的完整匹配规则；导致 Loader 找不到 `dsh-sandbox-local` 的**具体依赖边 / 布局**；rc.3 恢复的决定性因素（exact pin / manifest 修复 / layout / 版本线对齐，无法拆分）；blocked scripts 对 **PTY / native subprocess / sandbox / 未测 agent tools** 的影响；官方是否有正式安装指导与 rollback 支持。

> **[UNKNOWN]（独立研究线，本次未建立因果）**：之前反复出现的 `file has not been read` / `file changed since it was read` / `file no longer exists` 与本次 DSH 版本升级 / 依赖事故的**关系未验证**。

### 11.5 官方 Desktop / mixed-version 兼容性线（**2026-10-05 CLOSED**）

| 阶段 | 内容 | 状态 |
|---|---|---|
| P0 / P1 / P2 | Desktop baseline、官方 Desktop 源码考古、备份 | 完成 |
| P13 | E1 取证工具链（fail-closed capture + validator + 显式 baseline binding） | 完成；R1 FALSE PASS、R2 FALSE FAIL 均已定位并修复 |
| E1 run1 / run2 | run1 baseline 被污染；run2 Stage A 操作成功但归因受污染 | 均保留为历史证据，不删除 |
| E1 run3 | baseline → A → B：Desktop 建 v4 session；旧 Web **无法 discover** | **FINAL: NOT DISCOVERABLE**；Stage C 未执行且不再执行 |
| Control B | 隔离 home 中 matched-version `0.2.0-rc.2` Web 打开同一 v4 session 副本 | **PASS**（discover + render 均通过） |

**长期结论（3 条）**：

1. **[FACT]** 官方 Desktop = Electron shell + desktop-host + bundled DSH runtime + updater；
   不引入新的 composition paradigm；引入**第二个 installation anchor**。详见 `09-dsh-desktop.md`。
2. **[FACT] `[0.1.5 → 0.2.x version boundary]`** 两个版本共用同一 `$DSH_HOME` 时有两个结构性断裂面：
   **settings 模型**（0.2 把 legacy `settings.yaml` import 并 rename 成 `.imported`，0.1.5 不认识它 ⇒
   重新 bootstrap 最小 settings ⇒ 显式 locale override 丢失 ⇒ locale 交回 browser resolution）
   与 **session format**（`SESSION_FORMAT_VERSION` 3 → 4；0.1.5 无 v4 codec，host listing 静默过滤 v4）。
3. **[CONCLUSION]** 观测到的互操作失败是 **runtime / session-format 版本边界**问题，
   **不是**泛化的 Desktop-vs-Web 不兼容（matched-version 对照已证实 0.2 Web 可以 discover/open/render 同一 v4 session）。

> 研究支线**正式关闭**。方法论教训沉淀于 `10-experiment-methodology.md`；
> 原始取证保留在 `../evidence/desktop/runtime/`（已按 `11` §Cleanup 收敛）。

> 核心结论（五条线）：
> 1. **「Claude Code project 的文件层可直接成为 DSH workspace 内容，且其根 CLAUDE.md 会被 DSH 自动承载为 project instruction」已在真实 runtime 端到端证实。**[FACT]（`migration/14`）
> 2. **「DSH Agent → dsh-mcp-client → MCP stdio → @playwright/mcp → Playwright → 本机 Chrome → web」链路已 E2E 验证，并已升级为可驱动真实 JS-rendered SPA 完成交互（`Interactive SPA E2E: PASS`）。**[FACT]（`experiments/browser-mcp/2026-09-12-B3.5-…`、`…-B3.6-…`、`05-browser-mcp.md`）
> 3. **`$DSH_HOME/AGENTS.md`（user-global instruction）已 E2E 验证**：新 session 在首次 model request 前注入；**已存在 session 亦在下一个 step 感知新增/修改（含非 touch 修改）**；永久 language policy 已在真实工作流中生效。[FACT]（`experiments/dsh-runtime/2026-09-12-global-agents-e2e.md`、`04` §6.1）
> 4. **「bundle 归属是 profile 私有的」已由源码 + 真实安装 + 运行三方证实；且全局 DSH 安装被替换不会波及 profile-local 归属。**[FACT]（`07-profile-bundle-isolation.md`、`08-dsh-installation-and-upgrade.md`、`experiments/dsh-install/2026-09-23-…`）

---

## 12. 下一步明确动作（历史记录）

> ⚠️ **本节保留为历史记录；其「下一步」已于后续 Phase 执行** —— 当前状态见 §11。原文如下（勿再当作当前状态）：

迁移前所写的下一步是「在另一台电脑准备研究环境」。该迁移**已完成**。后续实际执行：Phase 2（CC archaeology）→ Phase 3.1（design）→ Phase 3.2（adopt + runtime injection verification，**PASS**）。下一阶段为 Phase 3.3 Minimal Migration（尚未开始）。下一步**不是修改 DSH**。

**当前（2026-09 重构后）workspace 结构**：
```
D:\Projects\dsh-test\
├── README.md                 ← 总入口（30 秒了解全貌）
├── docs\                     ← 长期知识（00–06 + browser-mcp/ + migration/）
├── experiments\              ← 实验过程（browser-mcp/ dsh-runtime/ browser-probe/）
├── evidence\                 ← 原始 runtime 证据（config-dumps/ logs/）
├── scripts\                  ← 研究工具
└── archive\                  ← 历史/重复/淘汰（0.1.1-era/ superseded-dumps/ temp/ session-logs/）

D:\Projects\Personal Job Search OS\    ← 研究 specimen；**已 adopt 为 DSH workspace**（ID 92030ae8-…），已 runtime verified
```

---

*维护约定：本文随研究推进增量更新；底层结论变化时改 `00/01/02` 并在此注记；新证据/新 UNKNOWN 在此收敛。*

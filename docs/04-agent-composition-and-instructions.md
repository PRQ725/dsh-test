# 04 — Agent Composition 与 Instruction System

> 长期维护笔记 · DSH 的 **agent composition（agent preset）** 与 **instruction system（`dsh-agent-instructions`）**。
> 证据等级：`[FACT]`=源码/文件/实际行为直接证明；`[INFERENCE]`=多事实推导；`[UNKNOWN]`=未追到源码。
> 建立：2026-09。相关：`01-host-composition.md`（层级关系：Host Composition → DSH Runtime → Agent Runtime → Agent Composition → Agent Session → Model requests）、`00-dsh-local-filesystem.md`（路径事实）、`02-root-include-and-patch-composition.md` §J（两种 precedence 的对比）、`migration/14-phase32-execution-verification.md`（runtime 取证）。
> 锚点：`$DSH_HOME`；`<DSH>` = DSH 安装根 `...\node_modules\@deepseek-ai\dsh`。

---

## 0. 术语边界（先分清三个东西）

> **[UPDATED 2026-09]** 这三者在实践中极易混淆，必须分开：

| 名词 | 是什么 | 不是什么 |
|---|---|---|
| **`dsh-agent-instructions`** | 一个 **Cordis plugin**（package `@deepseek-ai/dsh-agent-instructions`），由 preset 的 `agent.cordis.yml` 以一行 plugin entry 挂载 | — |
| **`AGENTS.md` / `CLAUDE.md`** | **instruction source**（磁盘上的 Markdown 文件） | **不是** Cordis Entry、**不是** plugin、**不参与 composition 的 patch 解析** |
| **instruction（注入结果）** | plugin 读取 instruction source 后，在 agent runtime 中生成的 **durable user-role message** | 不是 config、不是 system prompt、不是 tool output |

**关键结论** [FACT]：
- **`AGENTS.md` 本身不是 Cordis Entry，也不是 plugin。** 它只是被 `dsh-agent-instructions` 读取的**数据文件**。
  因此它**不会**出现在 `--dump-config` 的 entry 列表里，也不能用 patch 语法去"定位"它。
- 要"挂载/启用" instruction loading，改的是 **preset 里的 plugin 行**；
  要"提供 instruction 内容"，写的是 **instruction source 文件**（`AGENTS.md` / `CLAUDE.md`）。
- 两件事分开：**plugin 决定"会不会读"；文件决定"读什么"。**

---

## 1. Agent preset 是什么

- preset = 一个目录，内含 **`agent.cordis.yml`**（+ 可选 `preset.yml` 展示元数据）。[FACT]
- 它是 **agent composition**：定义「这个 agent 是什么」——persona、模型可见工具、prompt 段。[FACT]
- **shipped preset 位置（0.1.5-rc.1）**：`<DSH>\node_modules\@deepseek-ai\dsh-agent-presets\presets\<id>\agent.cordis.yml`（旧版曾在 `<DSH>\config\agent-presets\`）。[FACT]
- **user-authored preset 根**：`$DSH_HOME\.agent-presets\<id>\agent.cordis.yml`（trust = `user`）。[FACT]
- 与 **host composition**（注册表 / sandbox / persistence / model route / web）是**层级包含**关系，而非平行层（见 `01` §六）。[FACT/INFERENCE]

## 2. Preset roster（shipped，0.1.5-rc.1）

| preset | 定位 | 是否挂载 `dsh-agent-instructions`（⇒ 是否自动加载 AGENTS/CLAUDE.md） |
|---|---|---|
| `standard` | 完整 coding agent（**默认**） | **是**（`config.maxBytes: 65536`） |
| `cordis` | Cordis 插件开发向（含 skills） | **是**（`maxBytes: 65536`） |
| `ptc` | 0.1.5 新增的组合 | **是**（`maxBytes: 65536`） |
| `minimal` | 最小组合 | **否** |

[FACT：四份 `agent.cordis.yml` 逐行核验；`code` 已不在 0.1.5 roster 中]
> 含义：**instruction 自动加载依赖 preset 是否挂载该插件**。`minimal` 会话**不会**自动加载 `AGENTS.md`/`CLAUDE.md`。[FACT/INFERENCE]

## 3. Preset scope / parentage（作用域链）

- 每个会话（agent）把所选 preset 挂进 agent scope；视图解析遵循 **`agent → preset → global`**（近者遮蔽远者）。[FACT：`dsh-agent-presets` README]
- roster 把 preset **每进程挂载一次**于一个 standing scope；命名该 preset 的会话通过 **scope parentage** 加入（非各自再挂一份）。[FACT]
- 子 agent（subagent）通过 `composeFrom(parentCtx)` **绑定**到父 agent 所运行的 composition，而非按 id 重挂——因此父的 composition 文件后来被编辑/删除，不影响已运行的父与其子。[FACT]
- `[UNKNOWN]` preset 内部各 plugin 行的完整 DI/effect 时序（`01` §五已记）。[UNKNOWN]

### 3.1 Roster 服务（`dsh-agent-presets`，ctx key `agentPresets`）[FACT，源码 README]

| 成员 | 语义 |
|---|---|
| `defaultId` | 未指定时挂载的 preset id |
| `list()` | 列出 roots 当前提供的全部 preset（earlier root wins 重复 id；**broken 也列出**，带 reason） |
| `resolve(id?)` | 按 id 解析（缺省 `defaultId`）；无 root 提供时抛错并列出可用 id |
| `mount(agentCtx, id?)` | 为一个 agent 组合 preset：确保其 standing mount（single-flight）+ 把 agent 的 scope key 挂到该 mount 下 |
| `composeFrom(agentCtx, parentCtx)` | **子 agent** 绑定到父已有 composition（同步、无组合失败面）；父未 join 任一 preset 时返回 `undefined`（rosterless 部署，非错误） |
| `composedPreset(agentCtx)` | 某个 **live agent** 实际运行的 preset（读 scope chain） |
| `recompose(agentCtx, id)` | 把 live agent 重新链接到另一 preset 的 standing composition（仅在该 agent 尚未产出任何内容时有效；**调用方负责该检查**） |
| `standingKeyFor(id?)` | 无 agent 的 host reader（冷读 transcript）解析 preset 注册用的 standing scope key |
| `roots` | 该 roster 扫描的 roots（按序，末尾为派生的 harness-home root） |
| `authorable` | 是否有 `user` trust root（决定能否创建 preset） |
| `read(id)` / `copy(from, id?, name?)` / `remove(id)` | 读原文 / 复制整个目录（唯一 authoring 写操作）/ 删除**本地作者** preset |

- `AgentPreset` 携带：`id`（目录名）、`trust`（`system` \| `user`，来自其所在 root）、`path`（composition 文件绝对路径）、以及**仅当无法组合 session 时**的 `broken`（一个人类可读 reason）。[FACT]
- Discovery **未 memoize**：`list()`/`resolve()` 每次重读 roots ⇒ 运行期新增的 preset 立即可见、删除的下次读取即消失；名字不合法（非 `[a-z0-9][a-z0-9-]*`）的目录被跳过；YAML 不可解析（含 `!!js` 用 Loader dialect 校验）或不是「具名 plugin 行列表」的目录标记为 `broken`（**不跳过**，因为跳过会「占着 id 却无从删除」）。[FACT]
- 每代 composition 记录文件 stamp（mtime+size）：session 发现 stamp 过期会启动下一代；**已 join 的会话保持它运行时的那一代**——即运行中会话的 composition 不会被文件改动追溯改写。[FACT]

## 4. `dsh-agent-instructions` 机制

### 4.1 目的 [FACT]
按 session 的 **cwd** 发现并加载「workspace/项目级 instruction 文件」，注入为模型可见的 baseline 上下文。

> **[2026-11-11 修正 · cwd 的权威来源]** 0.2.2 源码里 `cwd` **不是** `process.cwd()`，也**不是** session header 里的 `cwd` 字段，
> 而是 **`ctx.workingDirectory.ensure(agent, signal)`**（`lib/index.js` L1318，紧接 L1319 才 `findProjectRoot(cwd, …)`）。
> 即 **`working_directory` 服务是 instructions 链的唯一 cwd 事实源**；session header 的 `cwd` 只是创建时的初始值。
> 这决定了"进入目录"到底算不算数 —— 见 §4.10.2。

### 4.2 Discovery（找什么、在哪找）[FACT，源码 `lib/index.js`]
- **默认候选**：`instructionFileCandidates = ['AGENTS.md', 'CLAUDE.md']`。
- **local overlay**：`localInstructionFileCandidates = ['AGENTS.local.md', 'CLAUDE.local.md']`（同目录，渲染在同目录 base 之后）。
- **user-global**：固定 `$DSH_HOME/AGENTS.md`（**无** local overlay）；另有 shared agents root `<agentsHome>/AGENTS.md`（`$DSH_AGENTS_HOME` 或 `~/.agents`）。候选列表只作用于 project scope。
- **project root**：`findProjectRoot(cwd, projectRootMarkers)` 从 cwd **向上**找第一个含 marker 的目录；`projectRootMarkers` 默认 `['.git']`；**一路到文件系统根都没有 marker ⇒ root = 原始 cwd**（不是 `/`，也不会"选一个祖先"）。marker 探测遇到权限/IO 错误 ⇒ **直接失败并冒泡**，不换 root。
- **遍历链**：`ancestorChain(projectRoot, cwd)` = root → cwd 的**有序**目录链；每个目录查 base 候选 + local overlay。
- **链的上下界**：**上界 = projectRoot，下界 = cwd**。⇒ `cwd` 之下的子目录、以及其它分支（兄弟目录）**不在 baseline 内**；
  它们只能靠 §4.10 的"touch 增量发现"在会话中途进入。
- 候选名必须是**同目录文件名**：空串、`.`、`..`、含 `/` 或 `\` 的条目被忽略。[FACT]
- 缺失路径 ⇒ `absent`（跳过）；stat/resolve 异常 ⇒ 该 scope 标记 `unavailable`（临时不可用，不等于删除）。[FACT]

### 4.3 Precedence（优先级）[FACT]
- 渲染顺序 **broad → specific**：先 `$DSH_HOME/AGENTS.md`，再按 root→cwd 递增（最具体目录最后）。
- 注入文本明示："More specific instructions take precedence over broader ones. They do not override system, developer, or direct user instructions."（更具体优先，但不凌驾 system/developer/直接用户指令）。
- **预算裁剪策略**：在 `maxBytes` 内**保留最具体优先**——先整体丢弃更宽的整个文件，最后才截断最具体的文件；超限会发出可见的 budget 提示。

### 4.4 Dedup [FACT]
- **同目录**内候选若**trim 后内容字节相同**（SHA-1 over trimmed content）则合并为**最早的那个**（candidate 顺序 → 默认 `AGENTS.md` 先）。
  → 一个内容与 `AGENTS.md` 相同的 `CLAUDE.md` **只渲染一次**；内容确实不同的兄弟文件**都会**渲染。
- **跨目录绝不合并**（即使内容相同）。

### 4.5 Byte budget [FACT]
- `maxBytes` **必填**（部署显式决定 prompt 预算）；`maxSourceBytes` 单文件上限，默认 1 MiB。
- 非正/非有限 `maxBytes` ⇒ 禁用 baseline 与动态加载。
- 单文件超 `maxSourceBytes` ⇒ 忽略；渲染总量不得超 `maxBytes`（见 4.3 裁剪）。

> **[2026-11-08 版本注记 · `0.2.2-rc.1` 起：预算按链独立]**
> 上面的"单条渲染总量 ≤ `maxBytes`"是 **`0.2.1` 及更早**的行为。`0.2.2` 改为
> **user-global 链与 project 链各自**受 `maxBytes` 约束：一条同时携带两条链的消息**最多 2 × `maxBytes`**。
> 影响与新增规则：
> - **project 指令不再挤掉 global 指令**（这正是官方修复的动机）。
> - 一条链的剩余额度**不能**给另一条链用（不共享预算）。
> - 当两条链都能装下时，消息**不带** budget 提示；否则用一个 `<system-reminder>` 合并提示说明被省略/截断的路径。
> - 兜底：某条链无 frame 而合并 frame 会超过 `2 × maxBytes` 时，退化为"按单链、单预算"渲染
>   （此时**可能**省略一条本可装下的 global 文件；只在预算极小或提示本身接近预算时发生）。
> - 因此旧笔记里"`$DSH_HOME/AGENTS.md` 总是第一个被丢弃"现在要限定为
>   **"在它自己那条链内、相对于该链的其他文件"**；它不会因为 project 链变长而被丢掉。
> 证据：`dsh-agent-instructions` 0.2.2 README（per-chain budget）+ 官方发布块
> "Budget global and project AGENTS.md chains separately…up to twice maxBytes"；
> 决策笔记 `2026-10-16-separate-instruction-chain-budgets.md`。
> 审计目录：`../experiments/dsh-version-audit/0.2.1-rc.2-to-0.2.2-rc.1/`。

### 4.6 Injection timing [FACT，源码]
- 触发点：**`ctx.on("agent/pre-step")`**。
- 每个 live session 的**首个 eligible `agent/pre-step`** 组合 baseline；若下游 decision 进入**非空的首步 batch**，插件把 baseline **折入该最终 batch**（插在 claimed 消息之后），使直接 prompt 与 instruction 一起进入 step 1、到达**首次请求**。
- 被拒或空的首步 decision ⇒ baseline 留在 agent 的 `next-step` inbox，等待后续唤醒。
- 其它阶段（workspace init / session creation / preset mount）**不是**触发点。[FACT]

### 4.7 产物形态：durable user-role message [FACT]

> **[2026-11-11 修正]** 下面 baseline 的 `source` 形态已按 **0.2.2 真实 session log** 更正；
> 旧表述 `{ kind: 'plugin', plugin: 'agent-instructions' }` 是 0.1.5 时代的形状，已不成立。

- 注入用 `createUserMessage(...)` 构造，是 **user-role** 消息，不是 system prompt、不是 tool output。
- `source`（实测 `session-9fc9eb17-…` seq=11，0.2.2）：
  - **baseline**：`{ kind: 'agent-instructions', form: 'instructions', baseline: true, baselineIdentity: '<JSON 字符串>', changes: [...] }`
  - **增量（ADD / UPDATE / REMOVE）**：同形状但**无** `baseline`；`form` 恒为 `'instructions'`。
  - `changes[]` 元素：`{ action: 'set' | 'replace' | 'remove', scope, path, digest? }`。
  - **`scope` 的编码**：`<目录 scope>\u0000<候选文件名>`，例如 `user-global\u0000AGENTS.md`、`.\u0000AGENTS.md`、`.\u0000CLAUDE.md`；
    project 侧目录 scope **相对 projectRoot**（根为 `"."`，子目录形如 `experiments\long-running\...`）。
- **内容帧**：插件自有完整 `<system-reminder> … </system-reminder>` 帧；每条注入的 `user/message` **逐字**到达模型，无 core 包装。
- 帧内每个文件前有 `Instructions from: <路径>` 标题（如 `Instructions from: ~/.dsh/AGENTS.md`、`Instructions from: AGENTS.md`、
  `Instructions from: docs/AGENTS.md`）。
- **实测措辞**：真实 baseline 文本里**没有** README 模板中的 `<user-global-instructions>` / `<project-instructions>` 包裹标签，
  只有连续的 `Instructions from:` 段 + 开头那段统一说明。不要把 README 的模板当成逐字 wire format。
- 模型可见文本**不含隐藏状态标记**（状态在 typed source 里）。

### 4.8 Refresh（变更如何变得可见）

> **[UPDATED 2026-09-12 — runtime 实测修正]** 早期表述「变更只在 touch / resume / compaction-restore 时可见」**不准确**。

- **无文件 watcher**（源码确认：`dsh-agent-instructions` 不含 `fs.watch`）。[FACT]
- **实测（top-level session `session-665e3202-…`）**：对 `$DSH_HOME/AGENTS.md` 的**新增**与**后续修改**，都在**下一个 `agent/pre-step`（即下一个 model request 之前）**被感知并注入：
  - 文件新增 → 注入 baseline（`source.baseline=true`，`changes[].action="set"`）；
  - 文件内容变化 → 注入 **`Updated instructions from: ~/.dsh/AGENTS.md`**（带新内容）。
- **关键消歧** [FACT]：用 **`pwsh`（`Add-Content`）** 修改文件时**没有任何 touch 触发**（插件的 touch 只识别 first-party `read`/`write`/`edit`，且要求 `arguments.file_path`），
  但变更**仍被检测** ⇒ 变更感知来自 **pre-step 对 baseline scope 的重探测**，而非 touch 驱动。
- 源码解释：`reconcileInstructionContext(..., { includeBaselineScopes: keepVisibleBaseline })` 会把 **baseline scopes（含 `user-global`）** 加入探测集合，因此每次 entering pre-step 都会重新核对当前文件版本。[FACT/INFERENCE]
- touch（`read`/`write`/`edit`）仍会触发**更深/nested scope** 的发现（`descendantDirsBetween`），以及 `tools/result` 后的 projection。[FACT]
- 变更类型：新到达的更深 scope ⇒ **addition**；同文件改动 ⇒ **`Updated instructions from:`**；文件消失或成为同目录重复项 ⇒ **`Instructions removed:`**（tombstone，之后重现可再次加载）。[FACT]
- **[2026-11-11 追加] 还有第三种"变更源"：cwd 变了。** 通过 `working_directory` 改变 session cwd 会让
  `baselineIdentity` 变（它编码 `relative(cwd, projectRoot)`），于是**重建整条 baseline**，
  并对"旧链有、新链没有"的 scope 发 `remove` 墓碑。`[FACT，源码]` 但**运行期从未观测到 `remove`**（见 §4.10.6）。
- **[2026-11-11 追加] shell 里的 `cd` 不属于上述任何一条。** 它既不触发 touch，也不改 session cwd，
  因此**不会**加载次级目录的 `AGENTS.md` —— 这是刻意的设计，不是缺陷。细节与四种"进入目录"的对照见 **§4.10**。
- 未变的 path + SHA-1 digest 不重复注入；per-session/per-scope provider cache 仅存 `{path, version, digest, trimmedDigest}` 以加速 —— **实测该 cache 不阻止变更检测**。[FACT]
- **compaction** 遮蔽该事件后，下一次进入的 pre-step 会重组当前 baseline。[FACT]
- [UNKNOWN] 变更检测的**延迟上界**：实测为「下一个 pre-step / 下一个 model request」；若长时间没有新 step，是否会主动触发未验证。

### 4.9 错误/缺失行为 [FACT]
- CLAUDE.md 不存在 ⇒ 跳过，**不是错误**；不阻塞 agent 启动。
- 读失败 ⇒ 该文件跳过 / scope 暂不可用；温和降级。
- 无任何可加载候选且非 "replace" 场景 ⇒ 不注入（`undefined`）；"replace" 场景发显式空替换基线。
- 插件未挂载 or `maxBytes<=0` or 无 `ctx.fs` provider ⇒ no-op（providerless 产品仍可启动）。

### 4.10 多层级加载：根目录 / 子目录 / 兄弟目录（2026-11-11 新增）

> 版本：`@deepseek-ai/dsh@0.2.2-rc.1` · `dsh-agent-instructions@0.2.2-rc.1`。
> 证据：源码 `lib/index.js`（行号见各条）+ 本机 **79 份历史 session log** 中的 233 条真实注入（未新开 session）。

#### 4.10.1 直接回答核心问题

**可以每层各放一个 `AGENTS.md`，而且 `docs/AGENTS.md` 这种"旁支"也合法。** 但"会不会加载"取决于两件事：

1. **它在不在当前链上**。baseline 链 = `projectRoot → cwd`（含两端，broad→specific 累加）。
   ⇒ 从 `project` 启动：只加载 `project/AGENTS.md`（+ 用户全局）；**`src/AGENTS.md`、`docs/AGENTS.md` 都不加载**。
   ⇒ 从 `src` 启动：加载 `project/AGENTS.md` **和** `src/AGENTS.md` —— **父目录指令是累加，不是替换**，
   顺序 broad→specific，注入文本明说"更具体优先"，但不凌驾 system/developer/直接用户指令。
2. **cwd 有没有真的变**。只有"真的改变 session working directory"或"用 `read`/`write`/`edit` 碰到了更深目录"才会把新层拉进来。
   **shell 里 `cd` 不算**。

冲突处理：**累加 + 更具体优先**。同一目录里 `AGENTS.md` 与 `CLAUDE.md` 若 trim 后内容相同则只渲染一次（§4.4）；
内容不同则都渲染，`AGENTS.md` 在前。跨目录**从不合并**。

#### 4.10.2 "进入目录"的四种含义 —— 操作 / 是否加载 / 加载哪些 / 生效时机

| 操作 | 改变 instructions 的 cwd？ | 是否触发加载 | 会加载哪些文件 | 生效时机 |
|---|---|---|---|---|
| shell 工具里 `cd src` / `cd ..` | **否** | **否** | 无（每次 shell 调用是新进程，插件不解析 shell 语法） | — |
| 通过 `working_directory` 改 session cwd | **是** | **是** | 新 cwd 的整条链：`projectRoot … newCwd`；**旧链中不再属于新链的层会收到 `remove` 墓碑**（详见 4.10.4） | **下一次模型请求**（下一个 `agent/pre-step` 重建 baseline） |
| cwd 不动，`read`/`write`/`edit` 触碰 `src/x` | 否 | **是**（nested 增量） | 只加载 `src/AGENTS.md`（以及 `src` 到该文件父目录之间的中间目录各自候选）；**不加载** `src/components/AGENTS.md`（除非碰到的文件在 `components` 下） | **下一次模型请求**（写入 `next-step` inbox） |
| `glob` / `grep` / `read_image` / `pwsh` / `bash` / MCP 工具 | 否 | **否** | 无 | — |
| 新建 session（cwd 为 `src/components`） | — | **是**（baseline） | `projectRoot`→`src/components` 全链 3 个 `AGENTS.md` + 用户全局 | 首个请求（折入 step 1） |

**这些规则各自的证据等级**
- `cd` 不触发：源码 `FILE_TOUCH_TOOL_NAMES = new Set(['read','write','edit'])` 且要求 `arguments.file_path`（L1286-1296）；
  官方 README 的 Known Limitations 亦明说 *"a `bash` command that changes directories does not trigger nested instruction discovery"*。`[FACT]`
- `working_directory` 触发：L1318 `const cwd = await ctx.workingDirectory.ensure(agent, signal)`，
  且官方 README 首句 *"Changing the Session's working directory reloads the applicable project instruction chain before the next request."*。`[FACT]`
- touch 只按"文件所在目录"向上探到 **cwd**：`descendantDirsBetween(cwd, touchedPath)`（L684-690）+ L1127。`[FACT]`
- `glob/grep` 不产生 touch：不在工具名单内。`[FACT]`
- 生效时机 = 下一次模型请求：源码 `projectTouch` → `queueProjection` → `agent.inbox.prepend("next-step", …)`（L1446-1472），
  并且**运行期链式验证**了它（见 4.10.3）。`[FACT]`
- subagent 是否继承父的 instructions：**`[UNKNOWN]`**（未验证；不同 Agent 各自 `ctx.workingDirectory.ensure(agent)`，倾向"各自独立"，但没实测）。

#### 4.10.3 生效时机：一次完整的运行期链条（本机真实 log）

`session-3ac9dad2-…`（cwd = `D:\Projects\dsh-test`，该目录**没有** `.git` ⇒ projectRoot = cwd）：

```
seq 603  tool/call  name=write  file_path=D:\Projects\dsh-test\experiments\long-running\v0.2-work\adoption\dryrun-project\AGENTS.md
seq 607  step/end                    ← 该 step 的 touch 在此 flush
seq 608  agent/inbox/spliced         ← projection 结果 prepend 进 next-step
seq 609  agent/inbox/spliced
seq 610  step/start                  ← 下一步开始
seq 611  user/message  src.kind=agent-instructions  form=instructions
         <system-reminder>
         Additional instructions from: experiments\long-running\v0.2-work\adoption\dryrun-project\AGENTS.md
         These instructions apply to work under `experiments\long-running\v0.2-work\adoption\dryrun-project`. …
```

⇒ **写入一个 5 层深的子目录 AGENTS.md，在下一次模型请求就被注入**，路径以 **相对 projectRoot** 的形式显示，
并带一句"这些指令适用于 `<相对目录>` 下的工作"。
它**不会**在写出文件的那一轮里重发 —— 必须跨到下一个 step。

#### 4.10.4 返回父目录 / 切到兄弟目录：必须区分"当前有效"与"历史残留"

**注入产物是 durable user-role 消息**（§4.7）。所以"新指令进来"与"旧指令消失"是两件事：

- **当前有效集**由 `changes` 的状态机表达：`set` / `replace` / `remove`。
- **历史里旧的正文永远还在**（它是普通会话历史，会 compaction，但不会被删除）。
  ⇒ 即使发了 `remove`，模型在历史里**仍然能读到**那段旧文本；`remove` 只是"墓碑 + 声明不再适用"。
  **不能把"加载了新指令"等同于"旧指令已被移除"。**

**返回父目录（`src/components` → `project`）**
- `working_directory` 变化 ⇒ `workspaceBaselineIdentity` 里的 `projectRoot = relative(cwd, projectRoot)` 从 `..\..` 变成 `""` ⇒ **identity 变**
  ⇒ `keepVisibleBaseline=false` ⇒ `replacePreviousBaseline=true`。
- 此时对"上一版 baseline 里有、新版没有"的 scope 逐个发 `{action:'remove'}`（L1373-1377）。
- ⇒ **会**收到 `Instructions removed: src/components/AGENTS.md` 之类的墓碑，**但旧正文仍在历史里**。
- 运行期状态：`[INFERENCE]`（源码明确），**`[UNKNOWN]`（本机 233 条注入里 0 条 REMOVE，从未观测到）**。

**切到兄弟目录（`src` → `docs`，同深度）**
- `projectRoot = relative(cwd, projectRoot)` 对两者**都是 `..`** ⇒ **identity 不变** ⇒ **不重建 baseline**。
- 于是 `reconcileInstructionContext` 只把"当前可见 scope"（含 `src/AGENTS.md`）重新探测 —— 文件还在 ⇒ **不会 remove**；
  同时 `docs/AGENTS.md` 因进入 baselineScopes 而被加上。
- ⇒ **源码推断：同深度兄弟切换可能让旧兄弟的指令继续留在有效集里**（既不移除也不报错）。
  `[INFERENCE]`（依据 `workspaceBaselineIdentity` L39-48 不含 cwd 本身）+ **`[UNKNOWN]`（未实测）**。
  实际后果：别用"换到兄弟目录"来撤销上一层的规则；要撤销请显式改 `working_directory` 到**不同深度**，或改文件内容触发 `replace`。

**文件消失 / 变成同目录重复**
- 文件被删除或被 dedup ⇒ `probe.kind === 'absent'` 或 dedup 命中 ⇒ 若之前可见则发 `remove`（L1196-1199、L1173-1177）。`[FACT，源码]`
- 之后文件重现 ⇒ 可再次 `set`（墓碑后的重新加载）。`[FACT，源码]`

#### 4.10.5 文件变化与边界的补充

- **baseline 链内的文件改动会被发现**：每次 entering pre-step 都以 `includeBaselineScopes` 重探测 baseline scope，
  所以改 `projectRoot/AGENTS.md` 或**当前链上**的 `src/AGENTS.md` 会在下一个请求变成 `Updated instructions from:`。`[FACT，源码 + §4.8 实测]`
- **cwd 之下、但从未被 touch 过的层不会**被发现改动：它们还没进入探测集。`[FACT，源码]`
- **没有 watcher**：不使用 `fs.watch`；外部编辑只在"下一次 pre-step / 下一次成功 touch / resume 重建 baseline"时可见。`[FACT]`
- **root 向上查找的停止条件**：逐级检查 `projectRootMarkers`（默认 `['.git']`）；到达文件系统根仍未命中 ⇒ **root = 最初 cwd**；
  marker 探测出现权限/IO 错误 ⇒ **fail-closed**，抛错而不是挑一个祖先当 root。`[FACT，源码 L649-657 + L42 说明]`
- **全局 AGENTS.md 的参与方式**：baseline 链的**第一段**（`$DSH_HOME/AGENTS.md`，然后 `<agentsHome>/AGENTS.md`），
  与 project 链**各自**受 `maxBytes`（§4.5 的 2026-11-08 注记）。它**不受** cwd 影响，也不参与 `remove` 墓碑链（除非文件消失）。`[FACT，源码]`
- **符号链接**：最终组件是 symlink 的候选会被解引用并加载其目标内容（官方 README 明示为刻意行为，并提示不可信仓库要用 fs 策略/OS 沙箱约束）。`[FACT，README]`

#### 4.10.6 本机运行期证据（未新开会话，来自历史 session log）

扫描：`scripts/scan-instruction-injections.mjs`（只读，逐 frame 解 zstd，按 `source.kind='agent-instructions'` 统计）。

| 指标 | 值 |
|---|---|
| 扫描的 session 文件 | 79（0 个因过大跳过） |
| 含 instructions 注入的 session | 67 |
| 注入消息总数 | **233** |
| 其中 `ADD`（`Additional instructions from:`） | **7** |
| 其中 `UPDATE`（`Updated instructions from:`） | 63（按 session 计；消息级更多） |
| 其中 `REMOVE`（`Instructions removed:`） | **0** |
| 含 budget 提示 | **0** |

`ADD` 的实例（证明"cwd 不动、只碰更深文件"这条路径在真实使用中确实发生）：

| session | cwd | 被加载的嵌套文件 |
|---|---|---|
| `session-3ac9dad2-…` | `D:\Projects\dsh-test` | `experiments\long-running\v0.2-work\adoption\dryrun-project\AGENTS.md`（5 层深） |
| `session-82b6fded-…` | `D:\Projects\Personal Job Search OS` | `92-record\AGENTS.md` |
| `session-9fc9eb17-…` | 同上 | `92-record\AGENTS.md` |
| `session-183298af-…` | 同上 | `AGENTS.md`（root 层，会话中途才出现） |
| `session-183298af-…` | 同上 | `90-docs\private\audits\_planb-snapshot-20261014\AGENTS.md` |
| `26128fc7` / `1c4f609d` | 同上 | `~/.dsh/AGENTS.md`（**全局文件在会话中途新增**后被感知） |

另：`baselineIdentity` 实测值确实是 `{"projectRoot":"", ...}`（cwd == root 时 relative 为 `""`），
证实 identity **只编码 root 相对 cwd 的位置**，不编码 cwd 本身。

#### 4.10.7 仍未确认的事（以及需要的实验）

1. **`REMOVE` 在运行期是否真的会被发出、措辞与时机如何** —— 源码路径明确，但本机 233 条注入里 **0 条 REMOVE**。
2. **同深度兄弟切换的残留**（4.10.4 的推断）—— 需要实测。
3. **没有任何新 step 时是否会主动刷新** —— 目前只知道"下一次 pre-step"。
4. **subagent 是否继承父的 instructions 链**。
5. **一个目录里同时有 `AGENTS.md` + `AGENTS.local.md` + `CLAUDE.md`** 的实际渲染顺序与 dedup 组合（源码清楚，未跑）。

**一次受控实验即可闭合 1+2+5**，且不需要新 host / 不需要改任何真实项目：

```text
在 D:\Projects\dsh-test\_tmp-instr-probe\ 下建：
   .git\(占位)  AGENTS.md(MARKER-ROOT)  src\AGENTS.md(MARKER-SRC)
   src\components\AGENTS.md(MARKER-CMP)  docs\AGENTS.md(MARKER-DOCS)
然后在一个新 session 里只做 6 次 read/write，观察注入：
  ① cwd=probe 时 read src\components\a.txt  → 期望 ADD src + ADD src\components
  ② working_directory 改到 src\components    → 期望 baseline 重建
  ③ 改回 probe                                → 期望 REMOVE（这是唯一能拿到 REMOVE 的路径）
  ④ working_directory 改到 docs               → 观察 src 层是否残留
删除树 → 观察 REMOVE；probe 目录可整棵回滚。
```

> 这个方案**需要一次新 session + 若干模型调用**（约 6 个短轮次）。按你的要求，我**没有执行**，
> 等你确认。若不想跑，4.10.4 的兄弟切换结论请保持"按源码推断、未实测"的措辞，不要当成事实引用。

#### 4.10.8 实际布局建议

```text
project/                      # 有 .git ⇒ 这里就是 projectRoot
├── AGENTS.md                 # 放"全项目通用"：技术栈、命令、代码风格、禁止事项
├── src/
│   ├── AGENTS.md             # 只在 cwd=src 或更深处被读；放本模块的约定
│   └── components/
│       └── AGENTS.md         # 最具体，放"改这个目录时必读"的规则
└── docs/
    └── AGENTS.md             # 只有 cwd=docs（或更深）才加载
```

实用建议（按成本从低到高）：

1. **把真正"每次都要生效"的规则放在 `project/AGENTS.md`**。它是最可靠的一层：从任何子目录启动、或 cwd 变化时都会在链上。
2. **子目录 `AGENTS.md` 当"局部补充"，不要当"开关"**。它只在该目录成为 cwd、或被 touch 时进入历史；
   而且一旦进入，**旧文本会留在历史里**，靠 `remove` 墓碑声明失效。
3. **不要靠"换目录"来撤销规则**。要撤销就改文件内容（触发 `replace`）或删文件（触发 `remove` 墓碑）。
4. **不要跨分支共享同一条规则**：`src/AGENTS.md` 与 `docs/AGENTS.md` 是互斥的（同深度），
   想两边都生效就各自写一份，或上提到 `project/AGENTS.md`。
5. **用户全局 `$DSH_HOME/AGENTS.md` 放"跨项目"的东西**（语言要求、通用纪律），
   它有独立预算，不会被项目文件挤掉（§4.5）。
6. **同名重复要留意**：`CLAUDE.md` 若与 `AGENTS.md` 内容相同会被 dedup 掉一次（省 token）；
   内容一旦漂移就会**两份都加载** —— 这是有意的，不是 bug。
7. **想省 token**：子目录层级越浅、越少越好；每次 `ADD` 都是一条**持久**历史消息，直到 compaction。

## 5. Instruction source 的层级与边界

### 5.1 四种 instruction source（源码）[FACT]
| 层级 | 文件（默认候选） | 位置 | scope key |
|---|---|---|---|
| **user-global** | `AGENTS.md`（**只有这一个名字**） | **`$DSH_HOME/AGENTS.md`** | `user-global` |
| **project** | `AGENTS.md`、`CLAUDE.md` | `<projectRoot>/`（root = 向上找第一个含 `.git` 的目录） | `.` |
| **subdirectory** | 同上 | 从 projectRoot 到 cwd 的每一级目录 | 相对目录名 |

> **上表只覆盖 baseline（root→cwd 链）。** cwd **之下**的目录不在表内：它们只有在被
> `read`/`write`/`edit` 触碰后才会作为**动态 scope** 加入（`Additional instructions from:`），
> 其 scope key 是**相对 projectRoot 的目录路径**（如 `experiments\long-running\...`）。
> 完整机制、四种"进入目录"的对照、以及"返回/兄弟切换"的墓碑语义见 **§4.10**。
| **local overlay** | `AGENTS.local.md`、`CLAUDE.local.md` | 与同目录 base 文件并排（渲染在其后） | 同目录 |

- **`$DSH_HOME/CLAUDE.md` 不会被读取** —— user-global 文件固定为 `AGENTS.md`（源码 `USER_GLOBAL_FILE = "AGENTS.md"`）。[FACT]
- 常量：`DEFAULT_PROJECT_ROOT_MARKERS = [".git"]`、`DEFAULT_INSTRUCTION_FILE_CANDIDATES = ["AGENTS.md","CLAUDE.md"]`、`DEFAULT_LOCAL_INSTRUCTION_FILE_CANDIDATES = ["AGENTS.local.md","CLAUDE.local.md"]`。[FACT]

### 5.2 边界结论 [FACT]
- **`AGENTS.md`/`CLAUDE.md` 不是 DSH installation 文件，也不是 profile 文件**，而是 **project / workspace 级（或 user-global 级）instruction source**。
- 是否被加载 = 「文件存在」+「该 session 的 preset 挂载了 `dsh-agent-instructions`」+「maxBytes > 0」+「存在 `ctx.fs` provider」。
- 同一份 `CLAUDE.md`：在 `standard`/`cordis`/`ptc` 下会被自动注入；在 `minimal` 下**不会**。[FACT/INFERENCE]
- `$DSH_HOME/AGENTS.md` 是**机器/用户级**层，独立于任何 workspace —— 换上任何 workspace 都会先加载它。[FACT]

### 5.3 precedence 与 budget（与 `02` §J 呼应）
- 加载/渲染顺序 **broad → specific**：user-global → projectRoot → … → cwd（`.local` 紧随同目录 base 之后）。[FACT]
- 注入文本声明 **"More specific instructions take precedence over broader ones"**；但**没有代码级覆盖**，多份内容都会出现在同一条 `<system-reminder>` 里。[FACT]
- **byte budget**：`maxBytes`（shipped preset = `65536`）。⚠️ **这里旧结论已作废，见 §4.5 的 2026-11-08 注记**：
  `0.2.1` 及更早是"单条消息总量 ≤ `maxBytes`，超限时先整体丢弃最宽的文件"；
  **`0.2.2-rc.1` 起改为 user-global 链与 project 链各自受 `maxBytes`**（双链消息最多 2×），
  所以 `$DSH_HOME/AGENTS.md` **不再**因为 project 链变长而被丢弃，只在**它自己那条链内**相对更宽。
- 同目录候选若 trim 后内容相同 ⇒ 只保留**最早**一个（默认 `AGENTS.md` 优先于 `CLAUDE.md`）；**跨目录不去重**。[FACT]

## 6. Runtime evidence（真实会话取证）

[FACT] `migration/14-phase32-execution-verification.md` §D 记录的实测（session `session-1c4f609d-…`，cwd = PJOS）：
- 出现 `user/message`，`source.kind = agent-instructions`、`form = instructions`、`baseline = true`、`changes = [{action:'set', scope:'', path:'CLAUDE.md', digest}]`；
- text（7,372 字符）= `<system-reminder>` + `Instructions from: CLAUDE.md` + **PJOS CLAUDE.md 全文**；
- 该消息位于 **step 1、首次 model request 之前**；整个 session **零 tool 事件** ⇒ 注入非工具读取所致。

[FACT] user-global 层的独立实测（隔离环境，未触碰真实 `$DSH_HOME`）：
- 在 fake `$DSH_HOME` 放置 `AGENTS.md` + `CLAUDE.md`、fake project 放置 `CLAUDE.md`，
  调用真实的 `discoverBaselineInstructionFiles` / `loadBaselineInstructions` ⇒ 发现 **2 份**（`$DSH_HOME/AGENTS.md` 与 project `CLAUDE.md`，顺序 broad→specific），**`$DSH_HOME/CLAUDE.md` 未被发现**；
- cwd 深入子目录时变为 **3 份**（追加 `sub\AGENTS.local.md`）；
- `maxBytes=60` 时 `omitted = ["$DSH_HOME/AGENTS.md","CLAUDE.md"]` ⇒ 证实**最宽者先被丢弃**。

> **[2026-11-11 版本注记]** 上面这条 `maxBytes=60` 的观测是 **`0.1.5-rc.1` 时代**的结果，**只对
> "单条消息单预算"的旧模型成立**。`0.2.2-rc.1` 起预算按链独立（§4.5），所以同样的 `maxBytes=60`
> 在两条链都有文件时**应**得到"每条链各自装/丢"的不同结果。**本条不要当作当前行为引用**；
> 新模型下的具体 omitted 集合**未重跑**（`[UNKNOWN]`）。保留下来的价值是：它证明了
> "**同一链条内**更宽的文件先被整体丢弃"这条裁剪策略本身。`$DSH_HOME/AGENTS.md` 与 project `CLAUDE.md`
> 在旧模型里同属一条消息，所以前者被先丢；在新模型里它们分属两条链，**不再互相挤占**。

### 6.1 `$DSH_HOME/AGENTS.md` E2E（2026-09-12，真实 runtime + 真实模型 session）[FACT]

环境：`--profile browser-lab --port 3080`（唯一实例）· DSH `0.1.5-rc.1` · cwd `D:\Projects\dsh-test`。

| 场景 | session | 观察 | 等级 |
|---|---|---|---|
| **基线**（无 `AGENTS.md`） | subagent `d724e5cd-…` | 无 `agent-instructions` message；输出无实验 marker | [FACT] |
| **新 session**（有 `AGENTS.md`） | subagent `3d350dbc-…` | `user/message` 带 `source.kind=agent-instructions`/`form=instructions`/`baseline=true`/`changes[].path="~/.dsh/AGENTS.md"`，位于 **首次 `request/header` 之前**；模型输出第一行 = marker | [FACT] |
| **已存在 session**（文件新增） | top-level `session-665e3202-…`（创建于 2026-09-10） | 不重启、不新建 session，**下一个 step** 注入 baseline（log `seq=2471`） | [FACT] |
| **已存在 session**（内容修改，**非 touch**） | 同上 | 用 `pwsh Add-Content` 改文件（不触发 touch）后，下一 step 注入 `Updated instructions from: ~/.dsh/AGENTS.md` | [FACT] |
| **永久 language policy** | subagent `a2f6bb4d-…` | 注入永久策略（digest `7284c0c1…`）；模型默认中文 + 技术名词英文 | [FACT] |
| **既有 session 的独立复现**（且**从未触碰**该文件） | top-level `session-21dbfd25-…`（创建于 15:50，早于文件存在） | 不重启、不新建 session，本轮**下一个 step** 注入 baseline（log `seq=121`，digest `7284c0c1…` = 永久策略） | [FACT] |

- **A/B 唯一结构差异** = 多出那条 `agent-instructions` message，且位于 user probe 与 first model request 之间。[FACT]
- subagent 也是真实 session（`origin: subagent`、`delegationDepth: 1`、`parentSession`、独立 `session.v3.jsonl.zstd`），全局 instruction 同样注入。[FACT]
- **`session-21dbfd25` 的复现尤其干净**：该 session **从未对 `$DSH_HOME/AGENTS.md` 做任何 `read`/`write`/`edit`**（也不曾被其触达），却仍在下一 step 获得 baseline ⇒ 进一步排除 touch 依赖。[FACT]
- **永久 language policy 已在真实工作流中生效**：同一 session 的该轮（浏览器 SPA 交互任务）回答为中文、技术名词保持英文，而 prompt 未重复任何语言要求。[FACT]

## 7. 与 `preset.yml` / `agent.cordis.yml` 的关系

- `agent.cordis.yml` = agent composition 的 patch 行（如 `persona` / `agent-instructions` / `tool-fs` / `tool-pwsh` / `tool-jobs` / skill 行）。[FACT]
- `preset.yml` = 展示元数据（name/description/order）。[FACT]
- service 行必须落在带 `isolate` realm 的 group 内，否则发布到 root realm（process-global）会与其它 preset 冲突，`dsh-agent-presets` 在 mount 时拒绝。[FACT]

## 8. UNKNOWN

- preset 内各 plugin 的完整 effect/DI 时序与最终 model-visible 上下文的**字节级组装**（persona / instruction / tool schema 的精确拼接顺序）。[UNKNOWN]
- 「server 端最终把注入消息组成请求 payload」的最后一跳未被直接观察（见 `migration/14` §D.11）。[UNKNOWN/INFERENCE]
- `AGENTS.local.md` / `CLAUDE.local.md` overlay 在**真实项目**中的行为（本机 specimen 未使用）。[UNKNOWN]
- **subagent session 在自身后续轮次**是否同样感知变更（本实验未能驱动 subagent 的第二轮）——[UNKNOWN]（顶层 session 已实测为是）。
- 变更检测的**延迟上界**（无新 step 时是否主动触发）。[UNKNOWN]
- **[2026-11-11 追加]** 见 §4.10.7：`REMOVE` 的运行期形态、**同深度兄弟切换是否残留**、subagent 是否继承 instructions 链、
  以及"无新 step 时不刷新"这几条，均需一次受控实验（方案见 §4.10.7）才能定论。

---

## Evidence

| 证据 | 位置 |
|---|---|
| 项目级 CLAUDE.md 注入取证 | `migration/14-phase32-execution-verification.md` §D |
| **user-global AGENTS.md E2E** | `../experiments/dsh-runtime/2026-09-12-global-agents-e2e.md` |
| session 日志（A/B/C） | `$DSH_HOME\sessions\--D-Projects-dsh-test--\{d724e5cd…, 3d350dbc…, a2f6bb4d…}\session.v3.jsonl.zstd` |
| 顶层 existing session 注入 | `$DSH_HOME\sessions\--D-Projects-dsh-test--\session-665e3202-…/session.v3.jsonl.zstd`（`seq=2471`） |
| **多层级加载：`ADD` 的触发链** | `$DSH_HOME\sessions\--D-Projects-dsh-test--\session-3ac9dad2-…\session.v4.jsonl.zstd`：`seq=603`（`tool/call name=write`，`file_path=…\dryrun-project\AGENTS.md`）→ `seq=607`（`step/end`）→ `seq=608/609`（`agent/inbox/spliced`）→ `seq=611`（`user/message`，`src.kind=agent-instructions`，`Additional instructions from: experiments\long-running\…\AGENTS.md`） |
| **baseline 的 source 形状与 identity** | `$DSH_HOME\sessions\--D-Projects-Personal~0020Job~0020Search~0020OS--\session-9fc9eb17-…\session.v4.jsonl.zstd` `seq=11`（`baseline:true`，`baselineIdentity` 里 `projectRoot:""`，`changes[].scope` 形如 `user-global\u0000AGENTS.md` / `.\u0000AGENTS.md`） |
| **全库注入统计（233 条 / 7 ADD / 0 REMOVE）** | `scripts/scan-instruction-injections.mjs`（只读；`node scripts/scan-instruction-injections.mjs [--json]`） |
| 源码（cwd / chain / touch / reconcile） | `<DSH>\node_modules\@deepseek-ai\dsh-agent-instructions\lib\index.js`：L39-48（identity）、L649-657（root）、L664-690（chain / descendant）、L1127（nested scopes）、L1318-1320（`workingDirectory.ensure`）、L1373-1377（replace 时的 remove）、L1446-1472（projection → next-step）、L1286-1296（touch 工具名单） |
| 官方口径（per-chain budget / 限制） | 同包 `README.md`（Summary、Use this package、Known Limitations） |
| **既有 session 独立复现**（无 touch） | `$DSH_HOME\sessions\--D-Projects-dsh-test--\session-21dbfd25-…/session.v3.jsonl.zstd`（`seq=121`） |
| 真实工作流中语言策略生效 | `../experiments/browser-mcp/2026-09-12-B3.6-interactive-spa-e2e.md` §5 |
| session log 解码工具 | `../scripts/decode-session-log.mjs` |

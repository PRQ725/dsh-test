# 06 — DSH Runtime 与多进程行为

> 长期知识文档。主题：DSH 的持久层与运行期状态如何分离，以及**同时运行多个 DSH 进程**时会发生什么。
> 证据等级：`[FACT]` / `[INFERENCE]` / `[UNKNOWN]`。
> 建立：2026-09。相关：`00-dsh-local-filesystem.md`（路径事实）、`05-browser-mcp.md`（多进程场景正是在 browser-lab 上暴露的）。
>
> **边界**：本文讲**运行期**行为。若故障是 `dsh` 命令本身起不来 / `plugin tree failed to load`，那属于**安装层**（global install / npm 依赖图），不在本文范围 → 见 **`08-dsh-installation-and-upgrade.md`** §2 的三层解析模型。
>
> **Evidence**:
> - `experiments/dsh-runtime/2026-09-12-multiprocess-workspace-investigation.md`（只读调查报告本体）
> - `evidence/config-dumps/`（被调查期间的 composed tree 快照）

---

## 1. 问题的由来

在 browser-lab 实验期间，机器上**同时运行了两个 DSH 实例**（同一 `$DSH_HOME`）：

| 实例 | 监听 | PID（当时） | 启动时间（UTC） |
|---|---|---|---|
| `dsh web` | 127.0.0.1:**3080** | 14868 | 06:59:20 |
| `dsh --profile browser-lab` | 127.0.0.1:**3180** | 1044 | 07:44:29 |

现象：同一个 session（`session-21dbfd25-…`，标题 `browser-lab MCP runtime 验证`）在 **3180 上显示归属于 `dsh-test` workspace**，而在 **3080 上即使刷新页面仍显示为 `Ungrouped`**。[FACT：报告 §4]

---

## 2. 持久层 vs 运行期层（核心区分）

### 2.1 持久层（durable）—— 正确且完整 [FACT]
- **显式 workspace 归属**持久化在 `$DSH_HOME\storages\workspace.json`：
  `tables.workspaces["94e1e0d8-…"].sessionIds` **已包含**该 session。
- **session 自身的归属字段是 `identity.cwd`**（值 `D:\Projects\dsh-test`）；记录中**不存在** `workspaceId` / `projectId`。
- session 正文落盘于 `$DSH_HOME\sessions\--D-Projects-dsh-test--\<session-id>\session.v3.jsonl.zstd`（**formatVersion 3**）。
- `workspace.json` 的写入时间（07:50:33Z）比 **3180 启动晚 6 分钟**、比 **3080 启动晚 51 分钟** ⇒ 该次归属写入**只能由 3180 完成**（毫秒级与 session 目录 mtime 吻合）。

> **[ADDED 2026-09-12]** session header 的实测字段（`session.v3.jsonl.zstd` 首行）：[FACT]
> `{"type":"session","version":3,"id":…,"createdAt":…,"cwd":"D:\\Projects\\dsh-test","parentSession":<父 session id | 省略>,"isSeeded":false,"origin":"subagent","delegationDepth":1,"agentPreset":"standard"}`
> - **subagent session** 也是**持久的真实 session**：独立的 `session.v3.jsonl.zstd`，带 `parentSession`、`origin: "subagent"`、`delegationDepth: 1`。
> - 顶层 session 则省略 `parentSession`/`origin`，`delegationDepth: 0`。
> - ⇒ **会话数量不是「UI 上可见的会话数」**：subagent 会话不在侧栏展示，但同样落盘、同样加载全局 instruction。

### 2.2 运行期层（process-private）[FACT]
- `dsh-workspace` 的 `get()` / `list()` 读的是 **`this.entities`（内存）**；
  storage-domain 的 `table.get()` 读 **`this.records`（内存 Map）**。
- storage-domain 的语义是：**内存表服务每一次读**；`loadAll` 之后**不再回查磁盘**。
- **四个相关包中不存在任何文件监视器**（`fs.watch` / `watchFile` / chokidar 全无）。
- ⇒ 每个 DSH 进程持有**独立的内存 workspace registry**，且**没有跨进程失效/同步通道**。

### 2.3 与 registry 解耦的通路 [FACT]
- **会话内容**的通路是**扫描式**读取（`readdirSync` + 按需 `readFile` 扫 `sessions\<slug>\<id>\session.v3.jsonl.zstd`），与 workspace registry **完全解耦**。
- 这解释了一个看似矛盾的现象：在 3080 上该 session 明明显示 Ungrouped，**却能打开并看到完整对话**。

---

## 3. 结论：视图陈旧，不是数据丢失 [FACT/INFERENCE]

- **直接原因** [INFERENCE]（基于时间线 + 源码读路径）：3080 的 registry 是它 **06:59:20 启动时**载入的内存快照；而该 session 的归属在 **07:50:33** 才被 3180 写入。3080 内存里没有这条 ⇒ UI 的唯一判定函数 `owningGroupKey(workspaces, sessionId)` 返回兜底值 `UNGROUPED_KEY = ""` ⇒ 显示 Ungrouped。
- **刷新页面为什么无效** [INFERENCE]：刷新只重建**浏览器侧投影**，baseline 仍由 3080 Host 的**旧内存**生成。
- **durable 层是正确的**：`workspace.json` + session 目录的归属**正确且完整**；Ungrouped 是**stale view**，**no data loss**。

---

## 4. 结构性风险：双写同一文件且无锁/无监视

[INFERENCE，报告列为"附加风险（重要）"]
- `storages\workspace.json` 是**单文件、按内存全量重写**的 durable dump（storage-json 的写路径是整文件 `writeFile`）。
- 既然 3080 的内存是旧的，**3080 一旦因任何 workspace 操作触发 flush，就可能用不含该 session 的旧快照覆盖文件**，把 3180 写入的归属"写回丢失"。
- 即：**双 DSH 进程 + 共享 `$DSH_HOME` + 无锁无监视** 是**结构性隐患**，不是一次性 bug。

### Session write-handle ownership（写入句柄归属）
[FACT/INFERENCE]
- session 的**持久化写入**由持有该 live session 的进程负责（该 session 由 3180 创建/运行）。
- 但 **workspace 归属记录**是**另一个共享文件**，两个进程都可写 ⇒ 归属记录不存在"单一 owner"保护。
- [UNKNOWN] DSH 是否为 **session log 本身**设置了跨进程的单写者保护（如文件锁/租约）；报告未确认，且未搜到监视器。

---

## 5. 处置建议

[RECOMMENDATION]
1. **同一 `$DSH_HOME` 下只运行一个 DSH 主实例**；需要多 profile 时优先串行（用完停掉再起另一个），而不是并行。
2. 若已并行并观察到 workspace 归类异常：**重启整个 DSH 进程**（而非刷新页面）可**重建正确的 runtime state** —— 重启会让 registry 重新从持久层 `loadAll`。[INFERENCE，报告未实测]
3. 需要长期并行时，应视为**已知限制**：以持久层文件（`workspace.json` / session 目录）为准判断真实归属，而不是以 UI 归类为准。

---

## 6. FACT / INFERENCE / UNKNOWN 汇总

### [FACT]
1. session 归属字段是 `identity.cwd`，**不是** `workspaceId`/`projectId`（格式 formatVersion 3）。
2. 显式成员关系在 `storages\workspace.json` 的 `sessionIds`；该文件由 3180 于 07:50:33Z 写入。
3. `dsh-workspace.get()/list()` 与 storage-domain `table.get()` 都读**内存**；`loadAll` 后不回查磁盘。
4. `dsh-workspace` / `dsh-storage-json` / `dsh-storage-domain` / `dsh-storage` 中**没有任何文件监视器**。
5. 会话内容通路是 `readdirSync` + 按需 `readFile`，与 registry 解耦。
6. 两个实例共用同一 `$DSH_HOME`，因此共用同一个 `workspace.json`。
7. UI 归类唯一函数 `owningGroupKey`，兜底 `UNGROUPED_KEY = ""`。

### [INFERENCE]
1. 3080 显示 Ungrouped = 其内存 registry 缺少该归属（启动早于写入）。
2. 无跨进程失效通道 ⇒ 另一进程的写入对运行中进程不可见。
3. 刷新无效 = 只更新浏览器投影，数据源仍是旧内存。
4. `workspace.json` 全量重写 + 旧内存 ⇒ 存在**覆盖写丢失**风险。
5. 重启整个 DSH 进程可重建正确 runtime state（未实测）。

### [UNKNOWN]
1. 未直接观测 3080 的运行时内存（无 API、未重启、未做浏览器操作）。
2. 3080 之后是否真的发生过破坏性覆盖（当前文件仍正确）。
3. 是否存在未找到的跨进程协调机制（未全仓库穷举）。
4. 客户端 baseline 流的确切触发条件（刷新 / 重连 / 定时）。
5. session log 本身是否有跨进程单写者保护。
6. 长期是否会导致归属反复"丢失/恢复"。

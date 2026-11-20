# DSH 多进程 workspace 归类不一致 — 只读调查报告

> **[2026-09 重构说明]** 本报告原名 `DSH-MULTIPROCESS-WORKSPACE-INVESTIGATION.md`，现位于 `experiments/dsh-runtime/`。
> 其**长期知识**已提炼到 `docs/06-dsh-runtime-and-multiprocess.md`；本文件保留完整调查过程与原始观测。

**调查时间**：2026-09-12（now UTC ≈ 08:11）
**范围**：只读。未修改任何文件，未创建/删除/移动 session，未重启任何 DSH 服务，未做浏览器操作。
**环境**：3080 = PID 14868（启动 09/12 14:59:20）· 3180 = PID 1044（启动 09/12 15:44:29）· 共用 `$DSH_HOME=C:\Users\user02\.dsh`

> 本报告开头先纠正一个背景前提：**"当前 session"（我所在的会话）不是**被调查的那个 session。
> 真正出问题的是浏览器-实验那个 session，见下。

---

## 1. 该 session 的持久化记录

### Session ID

**`session-21dbfd25-7ec1-4490-b205-5c54b7e570a4`**

### 定位依据（三条互相印证）

| 证据 | 值 |
|---|---|
| projcache 记录中的 `title` | **`"browser-lab MCP runtime 验证"`** |
| 落盘位置 | `$DSH_HOME\sessions\--D-Projects-dsh-test--\session-21dbfd25-.../session.v3.jsonl.zstd`（73 898 B，07:57:34Z） |
| projcache 文件 | `$DSH_HOME\storages\session_projcache\sessions\session-21dbfd25-....json`（10 065 B，07:57:34Z） |

### workspace 归属字段 —— **存在，但不是 `workspaceId`**

session 记录里**没有** `workspaceId` 字段。归属以 **`cwd`** 的形式存储：

```json
"identity": {
  "formatVersion": 3,
  "createdAt": 1789199432816,
  "cwd": "D:\\Projects\\dsh-test",     ← 归属字段在这里
  "isSeeded": false,
  "inheritedEventCount": 0
}
```

- 字段名：**`identity.cwd`**
- 值：**`D:\Projects\dsh-test`**
- 记录内**不存在** `workspaceId` / `workspacePath` / `projectId` 任何变体（已做递归全字段扫描）。

**关键补充**：显式的 workspace 成员关系**不在 session 文件里**，而在**共享的 workspace 注册表**中：

```json
// $DSH_HOME\storages\workspace.json
"94e1e0d8-edab-4efb-a542-b2692c895b25": {
  "path": "D:\\Projects\\dsh-test",
  "title": "dsh-test",
  "sessionIds": [
    "session-21dbfd25-7ec1-4490-b205-5c54b7e570a4",   ← 本次调查的 session
    "session-dd5b0ae2-ccb2-436f-bd38-4ba880f35122",
    "session-665e3202-af85-462f-a897-7cd662332be1"
  ]
}
```

**即：该 session 的 workspace 归属在持久化层是存在的、且正确指向 `dsh-test`。**

---

## 2. `dsh-test` workspace 的持久化记录

文件：`$DSH_HOME\storages\workspace.json`（1 135 B，mtime 07:50:33Z）

| 字段 | 值 |
|---|---|
| Workspace ID | **`94e1e0d8-edab-4efb-a542-b2692c895b25`** |
| `path` | `D:\Projects\dsh-test` |
| `title` | `dsh-test` |
| `sessionIds` | 3 个（含被调查 session） |
| `createdAt` | `2026-09-08T06:20:02.410Z` |
| `updatedAt` | **`2026-09-12T07:50:33.077Z`** |

另一个 workspace（对照）：

| Workspace ID | path | title | sessionIds | updatedAt |
|---|---|---|---|---|
| `92030ae8-62db-4114-bf99-5ccdcb4c1449` | `D:\Projects\Personal Job Search OS` | Personal Job Search OS | 2 | `2026-09-11T07:52:52.285Z` |

全局：`global.workspaceIds` 顺序 = `[PJOS, dsh-test]`；`global.archivedSessionIds` = `[]`（未归档）。
另有 `global.initialized: true`。

---

## 3. `session → workspace` 判定逻辑（源码）

### UI 侧：唯一判定函数

`@deepseek-ai/dsh-client-ui-workspace`（`lib/types/client/tree.d.ts`）：

```ts
/** Group key for Sessions outside every Workspace. */
export declare const UNGROUPED_KEY = "";

/**
 * Resolve the Workspace browser group that owns one Session.
 * @param workspaces - authoritative Workspace membership.
 * @returns owning Workspace id, or UNGROUPED_KEY when no Workspace accounts for it.
 */
export declare function owningGroupKey(workspaces: readonly WorkspaceView[], sessionId: SessionId): string;
```

> *"Unassigned Sessions trail under Ungrouped"* —— **`Ungrouped` 是"没有任何 Workspace 认领该 session"的兜底桶，
> 不是"数据缺失"的标志。** 这一点与你的提醒一致。

因此 `session → workspace` 完全由 **`WorkspaceView.sessionIds` 是否包含该 sessionId** 决定。

### 该 membership 从哪来

`@deepseek-ai/dsh-api-workspace-controller`（Host Remote）→ `ClientWorkspaceModel`：

- `items = []`（客户端内存投影）
- `replaceBaseline(baseline)` —— 由**流式 baseline**安装完整投影（L117–123）
- `getSnapshot()` —— 返回 `snapshotCache`（L177–183）

即：**UI 的 workspace 列表 = 由 Host 推来的 baseline/increment，缓存在客户端内存。**

### Host 侧：registry 是进程内内存

`@deepseek-ai/dsh-workspace`（`lib/index.js`）：

```js
get(id)  { return this.entities.get(id); }            // L375-376
list()   { const entity = this.entities.get(id); ... } // L384-386
```

`@deepseek-ai/dsh-storage-domain`（`lib/index.js`）：

```js
get(key) { return this.records.get(key); }            // L241-243  ← 纯内存 Map
```

其文档（`dsh-session-projection-cache/lib/index.js` L109–112，描述同一 storage-domain 机制）明确写道：

> *"the domain's in-memory tables serve every read … a read can never observe a disk write the memory has not applied"*

**即：domain 打开时 `loadAll` 一次，此后所有读走内存；不存在"读时回查文件"的路径。**

### 是否存在跨进程/跨文件变更感知

对 `dsh-workspace` / `dsh-storage-json` / `dsh-storage-domain` / `dsh-storage` 全面搜索
`fs.watch` / `watchFile` / `chokidar` / `FSWatcher`：

> **全部为 "no watcher"（无任何文件监视器）。**

---

## 4. 为什么 3080 与 3180 显示不同

### 时间线（UTC）

| 时刻 | 事件 |
|---|---|
| 06:59:20 | **3080 启动**（PID 14868）→ 加载 workspace registry 到内存 |
| 07:44:29 | **3180 启动**（PID 1044）→ 同样加载 registry 到内存 |
| **07:50:33.077** | `workspace.json` 的 `updatedAt` = 该 session 被写入 `dsh-test.sessionIds` |
| **07:50:33.076** | **session 目录 `--D-Projects-dsh-test--` 的 mtime（与上一行同 1 毫秒级）** |
| 07:57:34 | `session.v3.jsonl.zstd` 与 projcache 最后写入（你在该 session 里的输入） |

### 判定

| 候选 | 结论 |
|---|---|
| **A. session 持久化数据本身没有 workspace 归属** | **排除** —— `identity.cwd` 存在，且 `workspace.json` 的 `sessionIds` 明确包含它 |
| **B. 归属存在，但 3080 的进程内存没有更新** | **成立，且是直接原因** |
| **C. 两个进程维护不同的 workspace/session index** | **成立，且是机制** —— B 与 C 是同一现象的两面：每个进程有独立内存 registry，无跨进程失效 |
| **D. UI 使用不同的归类规则** | **排除** —— 两端是**同一份**客户端代码（同一 `dsh-client-ui-workspace`），规则都是 `owningGroupKey` |
| **E. 3180 创建 session 时产生了只有 3180 知道的临时状态** | **部分成立但非主因** —— 归属**确实被持久化了**（07:50:33 那次写入），所以不是"只存在于 3180 内存"。但它**从未被推送给 3080** |
| **F. 其他** | 见下方"写入路径"的附加风险 |

### 为什么 3080 刷新页面也没用

刷新只触发**客户端**重新向 **3080 的 Host** 拉 baseline：

```
3180 Host ──write──> workspace.json          (durable，正确)
3080 Host ──read───> 自己的内存 registry       (06:59:20 载入，不含该 session)
3080 浏览器 ──refresh──> 3080 Host ──> 仍是旧 baseline ──> Ungrouped
```

**没有文件监视器，也没有跨进程失效通知**，所以 3080 的内存 registry
**不会**因为 3180 写了文件而更新。刷新浏览器只换客户端，不换 Host 的内存。

### 为什么在 3080 里仍能打开该 session 并看到完整对话

**因为会话内容与 workspace 归类是两条独立的数据通路：**

- **会话内容**：session store 是**扫描式**的 —— `dsh-session-persistence-jsonl` 用
  `readdirSync` + 按需 `readFile` 扫描 `sessions\<workspace-slug>\<id>\session.v3.jsonl.zstd`。
  3080 能直接在磁盘上找到该目录并读取，**与 workspace registry 无关**。
- **归类**：走 workspace registry 的**内存** `sessionIds`。

所以"能打开内容"与"显示 Ungrouped"**完全可以并存**，并不矛盾 —— 这也直接回答了你的提醒。

---

## 5. FACTS

1. 被调查 session 的 ID 是 **`session-21dbfd25-7ec1-4490-b205-5c54b7e570a4`**，标题 `"browser-lab MCP runtime 验证"`。
2. 它的 workspace 归属字段是 **`identity.cwd = "D:\Projects\dsh-test"`**；记录内**不存在** `workspaceId`/`projectId`。
3. 显式成员关系持久化在 **`$DSH_HOME\storages\workspace.json`** 的
   `tables.workspaces["94e1e0d8-..."].sessionIds`，**已包含该 session**。
4. `dsh-test` workspace ID = **`94e1e0d8-edab-4efb-a542-b2692c895b25`**，path `D:\Projects\dsh-test`，title `dsh-test`。
5. `workspace.json` 的 mtime / `updatedAt` = **07:50:33Z**，比 3180 启动（07:44:29Z）晚 6 分钟，
   比 3080 启动（06:59:20Z）晚 51 分钟 → **该次写入只能是 3180 做的**。
6. session 目录 `--D-Projects-dsh-test--` 的 mtime（07:50:33.076）与 workspace.json 写入（07:50:33.081）
   **毫秒级吻合** → 该 session 在 07:50:33 被归入 dsh-test。
7. UI 归类唯一函数 `owningGroupKey(workspaces, sessionId)`；`UNGROUPED_KEY = ""` 是"无人认领"的兜底。
8. `dsh-workspace` 的 `get()/list()` 读 `this.entities`（内存）；storage-domain 的 `table.get()` 读 `this.records`（内存 Map）。
9. storage-domain 文档明确：**内存表服务每一次读**，`loadAll` 之后不再回查磁盘。
10. 在 `dsh-workspace` / `dsh-storage-json` / `dsh-storage-domain` / `dsh-storage` 中
    **不存在任何文件监视器**（`fs.watch`/`watchFile`/chokidar 全无）。
11. 会话内容通路是**扫描式**读取（`readdirSync` + 按需 `readFile`），与 workspace registry 解耦。
12. 两个实例共用同一 `$DSH_HOME`，因此共用**同一个** `storages\workspace.json`。
13. 两个 DSH 进程都存活：3080 = PID 14868，3180 = PID 1044。

## 6. INFERENCE

1. **直接原因（对应候选 B）**：3080 的 workspace registry 是它 **06:59:20 启动时**载入的内存快照，
   而该 session 的归属在 **07:50:33** 才被写入（由 3180 完成）。3080 内存里没有这条，
   于是 `owningGroupKey` 返回 `UNGROUPED_KEY` → UI 显示 Ungrouped。
2. **机制（对应候选 C）**：两个进程各自持有**独立的内存 registry**，且**没有任何跨进程失效通道**
   （无文件监视、无事件总线）。所以"另一个进程改了共享文件"对运行中的进程**不可见**。
3. **为什么刷新无效**：刷新只重建**浏览器侧**投影；baseline 仍由 3080 Host 的旧内存生成。
4. **为什么内容仍可读**：会话正文走文件扫描通路，与 registry 内存解耦。
5. **这不是数据丢失**：durable 层（`workspace.json` + session 目录）**归属正确且完整**。
   Ungrouped 是**视图陈旧**，不是**数据缺失**。
6. **3180 之所以正确**：它的内存 registry 在 07:44:29 载入，且在 07:50:33 由自己附加并写入，
   因此它既有内存记录也有文件记录。
7. **候选 D 排除**：两端跑的是同一份客户端代码与同一套规则。
8. **附加风险（重要）**：`storages\workspace.json` 是**单文件、按内存全量重写**的 durable dump
   （1 135 B 单文件；storage-json 的写路径是整文件 `writeFile`）。
   既然 3080 的内存是旧的，**3080 一旦因任何 workspace 操作触发 flush，就可能用不含该 session 的
   旧快照覆盖文件**，把 3180 的归属写回丢失。这是"双写同一文件 + 无锁/无监视"的结构性隐患。

## 7. UNKNOWN

1. **我没有直接观测 3080 的运行时内存**（无 API 访问、按约束未重启、未做浏览器操作）。
   因此"3080 内存 registry 不含该 session"是**由时间线 + 源码读路径推断**，不是直接读取。
2. **3080 是否在 07:50:33 之后做过任何 workspace 写入**（从而可能已覆盖文件）未确认；
   当前文件**包含**正确数据，说明**尚未**发生破坏性覆盖，但不能排除将来发生。
3. **是否存在我未找到的跨进程协调机制**（例如某个仅在特定条件下启用的租约/锁）。
   我搜索了四个相关包，未发现监视器；但未做全仓库穷举。
4. **客户端 baseline 流的确切触发条件**（页面刷新 vs 重连 vs 定时）未逐一确认；
   但无论触发条件如何，**源数据是 3080 的旧内存**，结论不变。
5. **`workspace.json` 的存储 layout 是否为 `single`**：文件是单文件形态且 storage-json 有
   整文件 `writeFile` 路径，但**默认 layout 配置值**我未逐字确认。
6. **两个实例是否都执行了启动期的 "bootstrap from session headers"**（该逻辑会给
   未初始化 registry 补齐历史归属）未确认；若 3080 启动时 registry 已 initialized，
   则**不会**再补扫，这与其内存陈旧一致。
7. **长期后果**：是否会导致归属反复"丢失/恢复"，未做实验（按要求未改任何状态）。

---

## 结论

### 为什么 3180 把该 session 显示在 `dsh-test`，而 3080 刷新后仍显示为 `Ungrouped`？

**因为 workspace 归类由每个 DSH 进程各自的内存注册表决定，而 3080 的内存注册表是它启动时
（06:59:20Z）载入的旧快照；该 session 的归属是 3180 在 07:50:33Z 才附加并写入共享文件的。**

- 持久化层**是正确且完整的**：`workspace.json` 的 `sessionIds` 已包含该 session，session 的
  `identity.cwd` 也指向 `D:\Projects\dsh-test`。
- 3180 在同一个操作里既更新了自己的内存、也写了文件 → 它显示正确。
- 3080 的内存注册表**没有任何途径**得知 3180 的这次写入（四个存储/工作区包中**零文件监视器**，
  且 domain 的读**只走内存**），所以它继续认为该 session 无人认领 → 落到 `UNGROUPED_KEY`
  → UI 显示 `Ungrouped`。
- **浏览器刷新无效**，因为刷新只重建浏览器侧投影，baseline 仍由 3080 Host 的旧内存产生。
- **在 3080 能打开并看到完整对话并不矛盾**：会话正文走独立的文件扫描通路
  （`readdirSync` + 按需读 `session.v3.jsonl.zstd`），与 workspace registry 完全解耦。

**这对应你列出的可能性：直接原因是 B（进程内存未更新），机制是 C（两进程各自维护独立
workspace/session index，无跨进程失效）。A 和 D 已被证据排除；E 部分成立但非主因
（归属确实被持久化了，只是从未推送给 3080）。**

### 这是否意味着两个实例之间存在 session 数据共享，但 workspace/index 状态不同步？

**是的，但要精确区分"共享"的层次 —— 这两句话的答案不同：**

| 层次 | 是否共享 | 说明 |
|---|---|---|
| **Session 正文（对话记录）** | **共享，且是"每次读盘"式的共享** | 落在 `$DSH_HOME\sessions\...`，按需扫描读取，所以两个实例都能打开同一 session |
| **Workspace 归属 / 成员索引** | **不共享（只在文件层共享，在内存层各持一份）** | durable 文件是共享的，但**每个进程的内存 registry 是私有且只在启动时载入一次**，且**无失效通知** |
| **配置 / profile** | 共享（同一 `$DSH_HOME`） | 但每个进程在启动时读取并缓存 |

所以准确的表述是：

> **两个实例共享同一份持久化存储（session 正文 + workspace.json），
> 但 workspace/index 的"运行时视图"是各进程私有的内存快照，彼此之间没有任何同步或失效机制。
> 因此会出现"同一份数据、两个视图"的现象 —— 这正是本次观测到的 Ungrouped 与 dsh-test 的分歧。
> 这是视图陈旧（stale view），不是数据丢失（no data loss）。**

**并且存在一个需要警惕的次生风险**：由于 `workspace.json` 是**单文件全量重写**且**两进程都会写**，
3080 一旦因任何 workspace 操作 flush 其旧内存，**可能覆盖掉 3180 写入的归属**。
当前文件仍是正确的，说明尚未发生；但这是结构性隐患，建议在后续阶段单独评估（本阶段按约束未做任何变更）。

---

## 附：本阶段产物

| 文件 | 说明 |
|---|---|
| `DSH-MULTIPROCESS-WORKSPACE-INVESTIGATION.md` | 本报告 |
| `analyze-session-record.mjs` | 只读分析脚本（提取 session 记录的归属字段，不写任何 DSH 状态） |

**未修改任何 DSH 状态，未创建/删除/移动 session，未重启任何服务，未做浏览器操作。**

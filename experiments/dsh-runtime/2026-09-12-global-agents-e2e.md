# 2026-09-12 — `$DSH_HOME/AGENTS.md` 全局 instruction E2E 实验

> **实验类型**：runtime E2E（真实 DSH 实例 + 真实模型 session）。
> **结论摘要**：新 session 生效 **PASS**；**已存在 session 亦会感知新增/修改**（next step，无需 restart/新 session）**PASS**；permanent language policy 已安装并验证。
> 证据等级：`[FACT]` / `[INFERENCE]` / `[UNKNOWN]`。**行为证据与 runtime evidence 分别记录**。

---

## 1. 环境 [FACT]

| 项 | 值 |
|---|---|
| DSH 实例 | `... node_modules/@deepseek-ai/dsh/lib/bin.js --profile browser-lab --no-open --port 3080`（PID 28460，进程启动 2026-09-12 16:48:38） |
| profile | **browser-lab**（与目标一致） |
| port | **3080**（唯一实例；3180 未监听） |
| 版本 | `@deepseek-ai/dsh@0.1.5-rc.1` |
| `$DSH_HOME` | `C:\Users\user02\.dsh` |
| cwd（所有 session） | `D:\Projects\dsh-test` |
| 目标文件 | `C:\Users\user02\.dsh\AGENTS.md` |

- 未启动第二个 DSH 进程；未改端口；未创建 profile；未改 browser-lab patch（`cordis.patch.yml` mtime 仍为 15:10:27）；未改 `web` profile；未改 PJOS。[FACT]

> **方法学说明（重要）**：本实验**不能**通过 GUI 手动新建 session（agent 无法操作 UI）。
> 因此改用 **subagent 机制**创建真实 session：`subagent` = 一个**新的真实 DSH session**（`origin: subagent`、`delegationDepth: 1`、有自己的 `session.v3.jsonl.zstd`），
> 其 cwd 继承父 session、并**绑定父的 standing composition**（`composeFrom`），因此 `dsh-agent-instructions` 同样挂载并生效。
> 这与 GUI 新建 session 的**唯一差异**在 session 元数据与 composition 挂载方式；对「global instruction 是否被加载注入」这一被测变量无影响。[FACT/INFERENCE]

## 2. `AGENTS.md` 初始状态 [FACT]

- 实验前 **不存在** `C:\Users\user02\.dsh\AGENTS.md`，也**不存在** `$DSH_HOME/CLAUDE.md`。
- ⇒ 无需备份；实验后按 §八 将其**保留并替换为永久 language policy**（不删除）。

---

## 3. Session A（基线，AGENTS.md 写入前）

- session id：**`d724e5cd-f5b5-429f-9b8c-19a5033dc61a`**（`origin: subagent`, `delegationDepth: 1`, `agentPreset: standard`, cwd `D:\Projects\dsh-test`）
- 日志：`$DSH_HOME\sessions\--D-Projects-dsh-test--\d724e5cd-…/session.v3.jsonl.zstd`（7 个 zstd frame → 57,626 B / 18 events）
- prompt：「只做一件事：回复一句简短的话。…不要调用任何工具。」
- 模型输出：`好的，收到。` —— **无** `[GLOBAL-AGENTS-TEST]`。[FACT]

**event order** [FACT]
```
turn/start(4) → step/start(7) → user/message(9, source=user) → user/message(10, source=plugin/@deepseek-ai/dsh-system-prompt)
→ request/header(11) → assistant/message(14) → step/end(15) → turn/end(16)
```
- **不存在** `source.kind = agent-instructions` 的消息 ⇒ 无全局 instruction 注入（符合预期：文件不存在）。[FACT]

---

## 4. Session B（新 session，AGENTS.md = 实验规则）

- 写入 `AGENTS.md`（341 B / SHA-256 `3F7DAE5A…`），内容为 `[GLOBAL-AGENTS-TEST]` 实验规则。
- session id：**`3d350dbc-3c82-45a6-a16d-89bed7a89f64`**（同 A 的 session 形态）
- 日志：`…/3d350dbc-…/session.v3.jsonl.zstd`（7 frames → 58,856 B / 19 events）
- prompt：`请回复一句简短的话。`（**未**提及 AGENTS.md / marker / instruction test）
- 模型输出 [FACT]：
  ```
  [GLOBAL-AGENTS-TEST]
  你好，我准备好了。
  ```
  → 第一行严格以 `[GLOBAL-AGENTS-TEST]` 开头 ⇒ **行为证据 PASS**。

**runtime evidence** [FACT] —— `user/message seq=10`：
```json
{"kind":"agent-instructions","form":"instructions","baseline":true,
 "baselineIdentity":"{\"projectRoot\":\"\",\"projectRootMarkers\":[\".git\"],\"maxBytes\":65536,...}",
 "changes":[{"action":"set","scope":"user-global\u0000AGENTS.md","path":"~/.dsh/AGENTS.md","digest":"76f6ff27d04a754e6edc9f726394feaed00e0760"}]}
```
text = `<system-reminder>` + `Instructions from: ~/.dsh/AGENTS.md` + **AGENTS.md 全文**。

**event order 对比** [FACT]
```
Session A: turn/start → step/start → user(9) → system-prompt(10)      → request(11)
Session B: turn/start → step/start → user(9) → agent-instructions(10) → system-prompt(11) → request(12)
```
⇒ **A 与 B 的唯一结构差异 = 多出那条 `agent-instructions` message**，且它位于 **user probe 之后、first model request 之前**。[FACT]

⇒ 完整链路 **`$DSH_HOME/AGENTS.md` → `dsh-agent-instructions` → durable user-role instruction → first model request** 在真实 runtime 成立。[FACT]

---

## 5. Existing session（AGENTS.md 写入前已存在的 session）

- **直接对 Session A 追加一轮**：**未执行** —— subagent 以 `run_in_background: false` 运行且未登记为可续期子 agent（`list_agents` 返回空），无法再向 A 发送消息。该具体项：[UNKNOWN]。
- **替代证据（等价且更强）**：**本 agent 自己所在的顶层 session `session-665e3202-af85-462f-a897-7cd662332be1`**
  （`createdAt = 1788848402441` ≈ 2026-09-10，**远早于** AGENTS.md 存在）在**不重启、不新建 session** 的情况下感知了文件的新增与修改。[FACT]

### 5.1 新增（文件此前不存在 → 基线第一次出现）[FACT]
- 我在 22:05 创建 `AGENTS.md`（用 `write` 工具）后，**同一 session 的下一个 step** 收到：
  `<system-reminder> … Instructions from: ~/.dsh/AGENTS.md …`
- session log 证据：`user/message seq=2471`，`source.kind=agent-instructions`、`form=instructions`、`baseline=true`、
  `changes=[{action:"set",scope:"user-global\0AGENTS.md",path:"~/.dsh/AGENTS.md",digest:"76f6ff27…"}]`（digest 与 Session B 完全一致）。

### 5.2 修改（已有基线 → 内容变化）[FACT]
连续两次修改文件，均在**下一个 step** 收到 `Updated instructions from: ~/.dsh/AGENTS.md`（含新内容）：

| 变更 | 变更方式 | 是否被感知 |
|---|---|---|
| v2（追加 `[DYNAMIC-CHANGE-PROBE v2]`） | `write` 工具 | ✅ `Updated instructions from …` |
| **v3（追加 `[DYNAMIC-CHANGE-PROBE v3-pwsh-not-a-touch]`）** | **`pwsh`（`Add-Content`）** | ✅ **仍然被感知** |

**关键消歧** [FACT]：`dsh-agent-instructions` 的「touch」只识别 first-party `read`/`write`/`edit`（`FILE_TOUCH_TOOL_NAMES`，且要求 `arguments.file_path`）；
`pwsh` **不是** touch。v3 改动**没有任何 touch 触发**，却依然在下一 step 被检测并注入 →
**变更感知来自 `agent/pre-step` 的 baseline scope 重探测，而不是 touch 驱动。**

> ⚠️ **修正**：`docs/04` §4.8 原表述「变更只在 touch / resume / compaction-restore 时可见」**不准确**。
> 实测：**每个 entering pre-step 都会重新探测 user-global baseline scope**，因此外部修改（含非 touch 方式）会在**下一个 model request 前**生效。

### 5.3 独立复现（另一既有 session，**从未触碰**该文件）[FACT]

后续 Browser MCP `B3.6` 实验运行在**另一个既有 session** 上，构成对本节的独立复现：

- session：**`session-21dbfd25-7ec1-4490-b205-5c54b7e570a4`**（创建于 **15:50**，早于 AGENTS.md 存在；这是 browser-lab 的 MCP runtime session）
- 该 session 在 22:16 的浏览器任务轮次中，于 **`user/message seq=121`** 收到：
  `source.kind=agent-instructions`、`form=instructions`、`baseline=true`、`path="~/.dsh/AGENTS.md"`、
  **`digest="7284c0c1aca7a1f015dcfc2e44c3700d3555c068"`**（= 永久 language policy，与 Session C 完全一致）
- 该 session **从未对 `$DSH_HOME/AGENTS.md` 做任何 `read`/`write`/`edit`**，也未被其触达 ⇒ **进一步排除 touch 依赖**。
- 该轮最终回答为**中文**且技术名词保持英文，而 prompt **未重复任何语言要求** ⇒ 永久策略在**真实工作流**中生效。

> 与 §5.1/§5.2 的区别：§5.1/5.2 中，本 agent 的 session *自己写了*该文件（属 touch 路径）；§5.3 的 session **完全没碰过文件**，因此是更干净的「pre-step 重探测」证据。

---

## 6. Session C（永久 language policy 安装后的新 session）

- `AGENTS.md` 被替换为永久 language policy（626 B / SHA-256 `DFBC51358430BDC0…`）。
- session id：**`a2f6bb4d-520f-4be8-99c0-748992b56212`**
- prompt：`请解释一下 vector 和 list 的主要区别。`（未提及 AGENTS.md 或语言要求）
- runtime evidence [FACT]：`user/message seq=10`，`source.kind=agent-instructions`，`digest=7284c0c1aca7a1f015dcfc2e44c3700d3555c068`（= 永久策略内容的 SHA-1），text 含 `Instructions from: ~/.dsh/AGENTS.md` + 语言要求全文。
- 模型输出（行为验证）[FACT]：
  - **默认中文**回答；`C++ STL` / `std::vector` / `std::list` / `O(1)` / `operator[]` / `push_back` / `splice` / `memmove` / `copy-on-write` 类技术名词保持英文；
  - 表格用英文技术字段名 + 中文解释；
  - 无整篇英文。
  ⇒ **永久语言策略实际生效 PASS**。

---

## 7. 证据等级汇总（按任务要求逐项）

| # | 问题 | 结论 | 等级 |
|---|---|---|---|
| 1 | AGENTS.md 对**新 session** 是否生效 | 生效（baseline message 在 first request 前） | **FACT** |
| 2 | **existing session** 是否生效 | 生效（顶层 session 实测）；**直接对 Session A 续轮未执行** | **FACT**（顶层）/ **[UNKNOWN]**（subagent session 续轮） |
| 3 | instruction 是否进入 agent runtime | 是（`user/message` with `source.kind=agent-instructions`） | **FACT** |
| 4 | 是否进入**第一次 model request** | 是（在 `request/header` 之前） | **FACT** |
| 5 | 是否在后续 step **重新读取** | 是（每次 pre-step 重探测；非 touch 修改也被检测） | **FACT** |
| 6 | 是否存在 cache | provider 版本/digest cache 存在但**不阻止**变更检测；内容变更会重新读取并注入 | **FACT**（行为）/ [UNKNOWN]（cache 实现细节） |
| 7 | 是否需要新 session 才能看到修改 | **不需要** | **FACT** |
| 8 | 永久语言策略是否生效 | 生效 | **FACT** |

**其他观察** [FACT/INFERENCE]
- subagent session 同样是「真实 session」：`origin: subagent`、`delegationDepth: 1`、`parentSession: session-665e3202-…`、独立 `session.v3.jsonl.zstd`；全局 instruction 一样注入。[FACT]
- 实验窗口内本 agent 自己的 session 也被注入了 `[GLOBAL-AGENTS-TEST]` 规则，但**未**因此改变回答格式 —— 与注入帧自身声明「They do not override system, developer, or direct user instructions」一致（直接用户任务指令优先）。[FACT/INFERENCE]
- `$DSH_HOME/CLAUDE.md` 全程不存在，未参与。[FACT]

## 8. UNKNOWN

1. **Session A（subagent session）在其自身后续轮次是否感知变更**——未能驱动 A 的第二轮（无 durable agent id），故直接证据缺失。
2. provider 版本/digest cache 的内部失效条件（只验证了"不阻塞变更检测"这一行为）。
3. `AGENTS.local.md` / `CLAUDE.local.md` overlay 与 project 层在这些 session 中的组合行为（本实验只涉及 user-global）。
4. 非 touch 变更的检测**延迟上界**：实测为「下一个 pre-step / 下一个 model request」，但未测「无新 step 时是否会主动触发」。

---

## 9. Evidence

| 证据 | 位置 |
|---|---|
| Session A 日志 | `$DSH_HOME\sessions\--D-Projects-dsh-test--\d724e5cd-f5b5-429f-9b8c-19a5033dc61a\session.v3.jsonl.zstd` |
| Session B 日志 | `$DSH_HOME\sessions\--D-Projects-dsh-test--\3d350dbc-3c82-45a6-a16d-89bed7a89f64\session.v3.jsonl.zstd` |
| Session C 日志 | `$DSH_HOME\sessions\--D-Projects-dsh-test--\a2f6bb4d-520f-4be8-99c0-748992b56212\session.v3.jsonl.zstd` |
| 顶层 session（existing）日志 | `$DSH_HOME\sessions\--D-Projects-dsh-test--\session-665e3202-af85-462f-a897-7cd662332be1\session.v3.jsonl.zstd`（注入在 `seq=2471`） |
| 解码工具 | `scripts/decode-session-log.mjs` |
| 永久策略文件 | `$DSH_HOME/AGENTS.md`（SHA-256 `DFBC51358430BDC0091658C62925BFA9385621F6E07197BFADDC7B19A043872C`） |

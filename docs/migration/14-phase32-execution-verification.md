# Phase 3.2 — Execution & Verification Record

> 本文记录 Phase 3.2 的**实际执行与验证结果**（不是设计；设计见 `13-migration-plan.md`）。
> 证据等级：`[FACT]`=源码/filesystem/registry/session forensic/runtime experiment 直接观察；`[INFERENCE]`=由 FACT 推导但未直接观察；`[UNKNOWN]`=证据不足。
> 建立：2026-09。研究对象：`D:\Projects\Personal Job Search OS`（PJOS）；DSH `@deepseek-ai/dsh@0.1.1-rc.2`（**Step 1/1B/2A/2B 执行时的版本**；后已升级至 `0.1.5-rc.1`，本文件的机制结论已在 0.1.5-rc.1 复核仍成立）；当前机器 `$DSH_HOME = C:\Users\user02\.dsh`。
> 相关：`10`（CC Step 1）、`11`（Concept Mapping）、`12`（Decision Record）、`13`（Migration Plan）、`../04-agent-composition-and-instructions.md`（机制细节）。

> ### 本文地位
> Phase 2 文档（10/11/12）是**迁移前**的研究基线；`13` 是**设计**；本文是**执行期事实**。凡本文与前面文档冲突，以本文（更新的实测）为准，并已在相应文档标注。

---

## 0. Phase 3.2 执行总览

| Step | 内容 | 结果 |
|---|---|---|
| Step 1 | `workspace.create` / adopt 源码验证 | **PASS**（机制级；[FACT]） |
| Step 1B | 真实 workspace adoption 验收（UI 执行，日志侧验收） | **PASS**（[FACT]） |
| Step 2A | `dsh-agent-instructions` 对 CLAUDE.md 的加载机制（源码） | **PASS**（[FACT]） |
| Step 2B | CLAUDE.md runtime injection 真实取证 | **PASS**（[FACT]） |

---

## A. Step 1 — `workspace.create` / adopt 源码结论

### A.1 API 与语义 [FACT]
- `workspace.create` 请求 schema：`{ path: string }`，schema 注释原文 **"the existing directory to adopt"**（`@deepseek-ai/dsh-host-apiproxy\lib\types\api\workspace.schema.js`）。
- `@deepseek-ai/dsh-workspace` 的 `WorkspaceRegistry.create(path, title?)`：
  1. `realpathNormalize(path)` —— 用 `fs.realpath` 规范化（容忍尾斜杠、`..`）；
  2. `stat(canonical).isDirectory()` —— 不存在/非目录**拒绝**；
  3. `createCanonical(canonical, title)`：若已有同 canonical path 的实体则**直接复用**（不重复建、不改 title）；否则：
     - 构造 record `{ path, title: basename(canonical), sessionIds: [], createdAt, updatedAt }`；
     - 先写 `pendingMutation`（create 标记），再 `table.put(id, record)`；
     - 新 workspace 前插到 durable registry order。
- 幂等性：**同一 canonical path 重复调用返回既有 workspace**。[FACT]

### A.2 会不会动项目目录？**不会** [FACT]
源码路径 `create → createCanonical` 中**没有任何写入被采用目录的代码**：
- 不创建/修改项目内文件；不初始化 DSH-specific 文件；不触碰 `.git`；不改项目 metadata；不读项目内容（只 `realpath` + `stat`）。
- 唯一状态副作用是**注册记录**，经 `@deepseek-ai/dsh-storage-domain` 写入 `$DSH_HOME/storages/workspace.json` 的 `workspaces` 表。[FACT]
- `WorkspaceRegistry.delete(id)` 只删除**注册/顺序/session 记账**；README 明写 "The directory, user files, live Sessions, and persisted session logs are never touched"。[FACT]
- 因此 adopt 天然**可逆且不侵入**：撤销 = 移除注册，源目录不动。[INFERENCE]

### A.3 host 侧调用链 [FACT]
```
RPC "workspace.create"（dsh-host-apiproxy 分发表）
   → api.workspace.create(request)                 [ index.js L3016 ]
   → ensureWorkspace(path)                        [ index.js L2140 ]
        ├─ ctx.workspaceRegistry.resolveByPath(path)  → 命中则复用（created:false）
        └─ 否则 ctx.workspaceRegistry.create(path)     （created:true）
```
- `ensureWorkspace` 在 `workspaceCreationChain` 串行锁内执行（避免并发重复建）。[FACT]

### A.4 GUI "Add workspace" → 实际 API 调用链 [FACT]
```
Add workspace…（UI）
  @deepseek-ai/dsh-client-ui-workspace：WorkspaceBrowser / WorkspacePicker → WorkspacePickFlow
   ↓ 打开 directory-flow（native OS 目录选择器 / browse 对话框）取得一个被选目录 path
   ↓ flowOwner.onPicked(path)
   ↓ adoptDirectory(path) = createWorkspace({ path })            [ client.js L853 ]
   ↓ ctx.workspaces.create({ path })                             [ inject hook，client.js L2424/2431 ]
   ↓ callUnary("workspace.create", { path })                     [ 客户端对象层 ]
   ↓ RPC "workspace.create" → api.workspace.create → ensureWorkspace  （同上）
   ↓ 返回 workspace → onPick(workspace.workspaceId)（commit 后选中；失败落 retryable 文件夹错误框）
```
- **结论：`SAME CORE MECHANISM + EXTRA UI LOGIC`** —— adopt 本体与直接调 `workspace.create({path})` 完全一致（同一 RPC → 同一 `ensureWorkspace`）；UI 额外逻辑仅是「用 directory picker 取路径 + commit 后选中/刷新 + 失败对话框」，不改变 `workspace.create` 语义，也不产生项目目录副作用。[FACT]
- 说明：workspace 创建**没有** CLI 子命令（`dsh` CLI 仅 `web` 与 `plugin`）；`workspace.create` 是 host RPC，经 web/API 面调用。[FACT]

---

## B. Step 1B — 真实 workspace adoption 验收

### B.1 注册结果（registry 事实）[FACT]
`$DSH_HOME\storages\workspace.json` 现存在两条 workspace 记录：

| workspace | ID | path | title | createdAt |
|---|---|---|---|---|
| dsh-test | `94e1e0d8-edab-4efb-a542-b2692c895b25` | `D:\Projects\dsh-test` | dsh-test | 2026-09-08T06:20:02.410Z |
| **PJOS** | **`92030ae8-62db-4114-bf99-5ccdcb4c1449`** | **`D:\Projects\Personal Job Search OS`** | Personal Job Search OS | 2026-09-09T05:42:06.159Z |

- 两者 **path 不同、ID 不同**，是**两个独立 workspace**；dsh-test 未被替换。[FACT]
- PJOS 记录 `sessionIds: ["session-1c4f609d-34bf-46ad-9fc3-c1094a328998"]`。[FACT]
- registration 位于 **DSH state 层**（`$DSH_HOME/storages/workspace.json`），**不在** PJOS 项目目录内。[FACT]

### B.2 项目不变量（adopt 前 = adopt 后）[FACT]
> **[UPDATED 2026-09-12]** 下表是本阶段的**当时基线**。此后用户又推进了 PJOS：HEAD 已由 `6d06a6f3` 前进到 `b9a4857f`
> （新增提交 `1b67b44 chore(governance): separate candidate preferences from discovery rules`、`b9a4857 chore(candidate): remove legacy preferences pointer`），
> 工作树已 clean。因此**这三个 hash 不再是"当前"值**；如需当前基线请重新取 hash。此变更与本实验无关（早于 2026-09-12 22:0x 的实验窗口）。[FACT]
| 项 | 值（与 baseline 逐字一致） |
|---|---|
| git status | ` M CLAUDE.md` + `?? resumes/RES-20260815-001__master/` + `?? resumes/RES-20260815-002__tencent-game-client/` |
| HEAD | `6d06a6f30f34eeadba68cc410e27410e7e900edd` |
| CLAUDE.md SHA-256 | `C2154CC84A5EFEA972DC292591C80AF81B174A6015F907E7F101922AA3C62E23` |
| README.md SHA-256 | `B669D27451B047F0844BEF317A376F31D1A4C8532A4B3504B86508A61C3A196E` |
| .gitignore SHA-256 | `CECE9B274D511CCF6FBECCD7AB36DAB5EE1658CFE90F54DE64CAE290391F9E65` |
| 根目录 | 3 files + 11 dirs（不变） |

- **项目目录未出现 DSH registration/metadata/cache/session/artifact 文件**；`.claude/` 树不变（仅 `skills/job-search/` 骨架）。[FACT]
- 唯一搜索命中 `candidate/fact-base/profile.md` 是正则误报（"profile" 匹配），该文件为 adopt 前即 tracked 的既有候选人事实文件，非 DSH 产物。[FACT]

### B.3 **workspace adoption ≠ profile conversion** [FACT]
- PJOS 被 adopt 后**仍然没有** `cordis.yml` / `package.json` / `pnpm-workspace.yaml`——它只是被 DSH **登记为一个 workspace 目录**，**没有**变成 DSH profile/project。[FACT]
- profile 是**机器级**的 host 组合容器（`$DSH_HOME\profiles\<name>`）；workspace 是**注册的项目目录**（`workspace.json`）。二者是不同层。[FACT]（详见 `../00-dsh-local-filesystem.md`）

---

## C. Step 2A — `dsh-agent-instructions` 源码机制

> 完整机制知识已正式沉淀到核心笔记：`../04-agent-composition-and-instructions.md`。此处只记 Phase 3.2 的验证结论。

- DSH **支持** `CLAUDE.md`：默认候选 `instructionFileCandidates = ['AGENTS.md','CLAUDE.md']`，local overlay `['AGENTS.local.md','CLAUDE.local.md']`，root marker `['.git']`。[FACT：源码]
- 加载时机：`ctx.on("agent/pre-step")` —— 每个 live session 的**首个 eligible pre-step** 组合 baseline，并插入进入 step 1 的消息批次。[FACT：源码]
- 产物：**durable user-role message**（`createUserMessage`），`source.kind = agent-instructions`，内容为插件自有的 `<system-reminder>` 帧。[FACT：源码]
- **`standard` / `code` / `cordis` preset 挂载** `dsh-agent-instructions`（standard 配 `maxBytes: 65536`）；**`minimal` 不挂载**。[FACT：源码]
- 结论：CLAUDE.md 的 instruction 职能**存在直接承载机制**，前提是运行在挂载该插件的 preset 上、且项目根有 `.git` + `CLAUDE.md`。[FACT/INFERENCE]
- → 这使 `13-migration-plan.md` §15 的 BLOCKING UNKNOWN「dsh-agent-instructions 在目标 workspace 下的实际加载验证」在**机制层**成立；随后的 Step 2B 在**runtime 层**也证实。[FACT]

---

## D. Step 2B — CLAUDE.md Runtime Injection 真实取证

### D.1 实验对象 [FACT]
| 项 | 值 |
|---|---|
| session ID | `session-1c4f609d-34bf-46ad-9fc3-c1094a328998` |
| cwd | `D:\Projects\Personal Job Search OS`（session header 明示） |
| agentPreset | `standard`（session header） |
| storage path | `$DSH_HOME\sessions\--D-Projects-Personal~0020Job~0020Search~0020OS--\session-1c4f609d-34bf-46ad-9fc3-c1094a328998\session.jsonl.zstd` |
| 规模 | 1 turn / 1 step；`session_projcache` 记 turns=1, steps=1, decodeTokens=912 |

### D.2 探针 [FACT]
用户经正常 DSH Web GUI / standard runtime 发送（**不要求读文件、不调用工具**）：
> 请概括你当前收到的项目级工作规则，并指出其中最重要的三条约束。不要读取任何项目文件，也不要调用任何工具。

### D.3 session log 物理格式 [FACT]
- `session.jsonl.zstd` 为 **concatenated multi-frame zstd**：该文件实测含 **45 个 zstd frame（magic `28 B5 2F FD`）**，逐 frame 解码后拼接得 **76,776 bytes** JSONL。
- 若只用一次性 `zstdDecompressSync` 整文件解码，**只得到第 1 帧**（即 session header 行）——这是本轮回读时的实测坑。[FACT]
- header 行：`{"type":"session","version":0,"id":...,"createdAt":...,"cwd":...,"delegationDepth":0,"agentPreset":"standard"}`。[FACT]

### D.4 event order（seq 递增）[FACT]
```
session header
→ turn/start (seq=4)
→ step/start (seq=6, step 1)
→ user/message 探针           (seq=7,  source.kind=user)
→ user/message instruction 注入 (seq=8,  source.kind=agent-instructions)
→ user/message system-prompt  (seq=9,  source.kind=plugin, plugin=@deepseek-ai/dsh-system-prompt, form=snapshot)
→ session/title (seq=10)
→ request/header (seq=11)  ← 首次 model request
→ request/context (seq=12)
→ assistant/message (seq=932)
→ step/end (seq=933) → turn/end (seq=934, reason=completed)
```
- **instruction message (seq=8) 出现在首次 model request (seq=11) 之前，且与探针同处 step 1 首步消息批次**。[FACT]

### D.5 注入消息的实际字段与内容 [FACT]
- `type = user/message`，`role = user`（**durable user-role message**）。
- `source = { kind: "agent-instructions", form: "instructions", baseline: true, baselineIdentity: <...>, changes: [{ action: "set", scope: "", path: "CLAUDE.md", digest: "<sha1>" }] }`。[FACT]
- content 单条 text，长度 **7,372 字符**，结构：
  ```
  <system-reminder>
  The following workspace instructions may be relevant to your work. ...
  Instructions from: CLAUDE.md
  <CLAUDE.md 全文：Project Identity / 核心模块 / 16 核心对象 / 16 条核心边界 /
   Git 定位 / Privacy Rule / 事实与派生规则 / 核心数据流 / 修改规则 / Skill 原则 / 当前项目状态>
  </system-reminder>
  ```
- 即 **PJOS 根 `CLAUDE.md` 的内容被逐字包含**在该指令消息内。[FACT]

### D.6 工具调用排除 [FACT]
- **整个 session 没有任何事件类型以 `tool` 开头**（无 `tool/call`、`tool/result`、`tool-call-chunks`），也无 `read/edit/write/pwsh` 等 filesystem/shell 工具事件。[FACT]
- 故**未发生**对 `D:\Projects\Personal Job Search OS\CLAUDE.md` 的 filesystem tool 读取——注入**不是**工具读取所致。[FACT]
- 该 session 附带上下文：`permission/preset = workspace-write`、`sandbox/mode = workspace-write`、`approval/policy = ask`。[FACT]

### D.7 Agent 行为（corroboration）[FACT]
- Agent 的 reasoning 明写 "based on the CLAUDE.md content in the system reminder. No tool calls"。
- 回答正确复述：单一事实源（Candidate Fact Source / Original JD / Requirements）、Claim≠Evidence、Resume≠Fact Source、DATA_GAP/UNKNOWN ≠ SKILL_GAP、隐私三道防线、Git 不配 remote、版本不可变等。
- usage：`inputTokens=11115, outputTokens=912, reasoningTokens=73`（与 7.4 KB 指令注入一致）。[FACT]
- 说明：行为层是**旁证**，不是唯一证据；A/B/C/D 的 event/历史证据独立成立。[FACT]

### D.8 项目不变量 [FACT]
- 实验后 PJOS 的 git status / HEAD / 三个关键 hash **与 Step 1B baseline 完全一致**；无新增/删除/修改；未访问 `candidate/raw`。[FACT]

### D.9 四层证据矩阵 [FACT]
| Layer | 问题 | 证据 | 状态 | Confidence |
|---|---|---|---|---|
| A | CLAUDE.md 被自动发现？ | seq=8 注入消息、`Instructions from: CLAUDE.md`、无 tool 调用 | **PASS** | HIGH |
| B | instruction 是否注入成消息？ | seq=8 durable user/message，source.kind=agent-instructions，text 含 CLAUDE.md 全文 | **PASS** | HIGH |
| C | 是否进入首次 model request？ | seq 位序 7→8→9→11；在 step 1 内、request 前 | **PASS** | HIGH（实为 FACT） |
| D | 是否排除主动读文件？ | 全程零 tool 事件 | **PASS** | HIGH |

### D.10 最终判定
## PASS
DSH standard runtime + `dsh-agent-instructions` **能够自动发现并注入 PJOS 根 `CLAUDE.md`**，作为 project-scoped instruction 进入首次模型请求的 derived history —— 无需 Agent 调用任何 filesystem tool。[FACT]

### D.11 证据边界（不得夸大为 FACT）[UNKNOWN/INFERENCE]
- **C 的最后一跳**：我们直接观察到的是「指令 durable user/message 位于 step 1 且先于 request 事件」，以及「模型应答实际引用了内容且无工具」。**「server 端把该消息组装成发给模型的最终请求字节/tensor，并逐字节包含该文本」并未被直接观察** → 该最末跳为 **[INFERENCE]**，非 FACT。[INFERENCE]
- session log 中**未**记录完整的 request payload（仅 `request/header` 与 `request/context` 元信息）。[FACT]
- ~~尚未验证：…动态 refresh（touch-driven）在真实编辑文件后的表现~~ → **[RESOLVED 2026-09-12]**：`$DSH_HOME/AGENTS.md` E2E 已证明已有 session 在**下一个 step** 感知新增/修改，且**非 touch 修改（`pwsh`）同样被检测**；机制为 entering `agent/pre-step` 重探测 baseline scope。
  详见 `../../experiments/dsh-runtime/2026-09-12-global-agents-e2e.md` §5、`../04-agent-composition-and-instructions.md` §4.8/§6.1。
- 仍 [UNKNOWN]：反向对照（`minimal` preset 下不注入）、resume 兼容 baseline 的重放。

---

## E. Phase 3.2 之后的迁移状态

- 原 `13-migration-plan.md` §15 的两个 **BLOCKING UNKNOWN 均已 RESOLVED**：
  1. `workspace.create` adopt 对含 `.git`+大目录+私人子目录的真实项目**可行且无副作用** → Step 1B PASS。[FACT]
  2. `dsh-agent-instructions` 在目标 workspace 下**实际加载 CLAUDE.md** → Step 2A + 2B PASS。[FACT]
- 据此，Phase 3.2 的「采用既有目录为 workspace + 项目 instruction 自动承载」这条**最小可工作路径已被端到端证实**。[FACT]
- 仍未执行、仍待做的（属 Phase 3.3+）：真实项目数据上的 write 安全验证、privacy boundary 的运行期验证、Git workflow 运营决策、skill RECREATE。[FACT/UNKNOWN]

---

## F. 本记录维护约定
- 本文只记**执行与验证事实**；设计变更改 `13`；概念映射改 `11`；决策改 `12`。
- 凡新增 runtime 事实，必须写清 **session ID / 文件 / seq / 字段**，并区分 source FACT 与 runtime FACT 与 INFERENCE。

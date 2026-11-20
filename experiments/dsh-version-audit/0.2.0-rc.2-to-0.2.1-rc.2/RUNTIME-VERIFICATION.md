# RUNTIME-VERIFICATION — 0.2.1-rc.2 live environment

采集时间：2026-10-19 20:10 起（+08:00；审计在同一 session 内持续进行）
工作区：`D:\Projects\dsh-test`
方式：本 session 内的只读工具调用 + 新研究目录内的写入测试。**没有**提升权限、没有改配置、没有安装依赖。

---

## 1. 环境与身份

| 项目 | 值 | 证据等级 | 采集方式 |
|---|---|---|---|
| workspace | `D:\Projects\dsh-test` | FACT | `pwd` / `working_directory` 工具 |
| CLI package version | `0.2.1-rc.2` | FACT | `dsh --version`（直接输出） |
| 已安装 package.json version | `0.2.1-rc.2` | FACT | 读取 `...\npm\node_modules\@deepseek-ai\dsh\package.json` |
| Desktop bundled runtime | `0.2.0-rc.2` | FACT | `...\Programs\DeepSeek Harness\resources\runtime\primary-runtime\runtime.json` → `desktopVersion` |
| Active session runtime | `0.2.1-rc.2` | FACT（见下方链条） | tool surface + installation anchor |
| Session ID | `session-32aa9e1e-a677-4f88-8682-f9c639f0b48c` | FACT | `DSH_SESSION_ID` |
| Profile | `browser-lab` | FACT | `DSH_PROFILE` |
| `$DSH_HOME` | `C:\Users\user02\.dsh` | FACT | env |
| Web GUI URL | `http://127.0.0.1:3080` | FACT | env / runtime context |
| Node | `v24.20.0` | FACT | `node --version` |
| Git repo | **不存在**（`.git` absent；`git rev-parse --show-toplevel` 失败） | FACT | 文件系统 + 命令 |
| Active Goal | **无**（`get_goal` → `{"goal":null}`；projection `goal.current = null`） | FACT | 工具 + session projection |
| Session format | `4` | FACT | session header / delivery events |

### 1.1 为什么可以判定 active session 是 0.2.1-rc.2

1. 本 session 的 `request/header` 工具面（59 个）包含 `working_directory`。
2. `working_directory` 只由 `@deepseek-ai/dsh-tool-working-directory` 提供；本地 npm cache 中该包
   **只有 0.2.1-rc.2**，没有 0.2.0-rc.2 tarball（`evidence/cache-inventory.json` 的 onlyV2 列表）。
3. 本机唯一的 0.2.1 安装是全局 npm 的 `@deepseek-ai/dsh@0.2.1-rc.2`；Desktop bundled runtime 是 0.2.0-rc.2。
4. 当前 profile 是 `browser-lab`，而 `desktop` 是 Electron 专用 profile（0.2.1 CLI README 明确保留名）。
5. 所以当前 session 不可能是 Desktop 0.2.0 backend；它运行 0.2.1-rc.2 CLI/Web-profile runtime。

> 这是**运行时观测 + 安装锚点**的联合结论，不是只看 UI 版本号。`dsh --version` 单独存在时并不足以证明 backend，因此这里用了 0.2.1-only 工具作为判别器。

### 1.2 Desktop 仍然落后

Desktop 的 `runtime.json` 明确写 `"desktopVersion": "0.2.0-rc.2"`。CLI 升级**没有**升级 Desktop。
因此本仓库旧文档中“Desktop 0.2.0、全局 npm 0.1.5”的版本表，只有 Desktop 那一行仍成立；
全局 npm 一行已被本次升级取代。旧文档不改写，差异记录在 `KNOWLEDGE-DELTA.md` K19。

---

## 2. 权限与审批

来自本 session 的真实事件（不是配置推断）：

```text
permission/preset = workspace-write
sandbox/mode      = workspace-write
approval/policy   = ask
```

- 文件 policy：`workspace-write`（runtime context 与 session event 一致）。
- Approval：`ask`；本轮**没有**触发任何 approval 请求（没有需要批准的越权操作）。
- 没有申请 `danger-full-access`；没有写 workspace 外部；没有改全局配置/Profile/Provider/API Key/PATH/npm。

### 2.1 写入边界测试（安全范围内）

| 测试 | 结果 |
|---|---|
| 在 `experiments/dsh-version-audit/0.2.0-rc.2-to-0.2.1-rc.2/` 新建/覆盖研究文件 | PASS（本目录所有产物） |
| 创建 `evidence/` 子目录并写入 | PASS |
| 读取 workspace 外路径（`$DSH_HOME`、Desktop 安装目录、npm cache） | PASS（只读） |
| 向 workspace 外写入 | **NOT TESTED**（任务禁止；没有为了验证权限而越界写） |
| 越界写入被拒绝的运行时证据 | **NOT LIVE-TESTED IN THIS ROUND**；仅记录 mode = workspace-write |

---

## 3. 工具可用性

- `pwsh`：正常。审计中的命令、哈希、目录遍历均通过它完成。
- `read` / `write` / `edit` / `glob` / `grep`：正常。
- `working_directory`：正常；无参数调用返回 `D:\Projects\dsh-test`。
- `get_goal`：正常；返回 no goal。
- MCP：`mcp__playwright__*` 共 30 个工具出现在工具面，说明 `dsh-mcp-client` + `@playwright/mcp@latest`
  的 stdio bridge 已成功挂载（未实际打开浏览器）。
- 终端：本 profile **没有** terminal 工具；node-pty 的 ConPTY spawn 失败（见 §5），不影响本次审计。

### 3.1 环境限制：native stdout 不能被 PowerShell 捕获

审计中观察到：

```text
git --version                 -> 成功（直接输出）
git status --porcelain | ...  -> Program 'git.exe' failed to run: Access is denied
$v = node --version           -> V=（空）
node --version | Tee-Object   -> Program 'node.exe' failed to run: Access is denied
```

结论（FACT）：直接执行 native 命令可以；把 native stdout 接入 PowerShell pipeline / 变量捕获会被
sandbox 拒绝。这不是 DSH 工具失败，也不是版本回归；它影响了“把原始输出重定向到 evidence 文件”的方式。
因此部分 evidence 文本是**从会话直接输出转录**，并在文件中注明。

---

## 4. 模型与 Provider

| 项目 | 值 | 等级 |
|---|---|---|
| provider | `deepseek-official` | FACT（session `request/header.config`） |
| model ID | `deepseek-flash` | FACT |
| reasoningEffort | `low` | FACT |
| maxTokens | `256000` | FACT（request header） |
| contextWindow | `1000000` | FACT（request/context） |
| 显示名 | `DeepSeek-V4.1-Flash`（catalog）+ `1017` badge（client plugin） | FACT（源码） |
| 实际 API 路由到的权重版本 | **UNKNOWN** | 无法从本地独立验证 |

**不得**把 `DeepSeek-V4.1-Flash-1017` 的显示当作权重证明。`dsh-client-ui-deepseek-model-label-1017`
的 README 原文：“The `1017` marker is fixed client presentation, **not a server capability assertion**.”
它只改变 composer 的 label，不改变请求、不改变 cache key。

---

## 5. 安装完整性（只读）

详细原始记录：`evidence/install-health.txt`。摘要：

| 检查 | 结果 |
|---|---|
| `@deepseek-ai/dsh-subprocess-local@0.2.1-rc.2` 存在/可 import | PASS |
| `koffi@3.1.1`（含 `koffi.node`）存在/可 import | PASS |
| `node-pty@1.2.0-beta.15`（含 win32-x64 conpty prebuild）存在/可 import | PASS |
| `@google/genai@2.21.0` 可 import | PASS |
| `protobufjs@7.6.6` 可 import | PASS |
| 普通 `child_process.spawn`（stdio inherit） | PASS |
| node-pty `spawn` | **FAIL — `Cannot launch conpty`** |
| MCP bridge | PASS（工具面有 30 个 playwright 工具） |

PTY 失败的分类：**INSTALLATION / ENVIRONMENT ISSUE**，根因 **UNKNOWN**。不是已证实的 0.2.1 版本回归；
同一 node-pty 版本与 prebuild 都在，模块能加载，失败发生在创建 ConPTY 时。没有 0.2.0 runtime 可 A/B 对照。
**没有**执行 `npm rebuild` / `npm install` / `allow-scripts` / 下载 native binary。

---

## 6. 本轮明确未测的项

- 真实 Goal 创建、arm、resume、pause、自动续轮、round cap 实测（任务禁止；`GOAL LIVE TEST: NOT RUN`）。
- 越界写入被 sandbox 拒绝的实际运行时证据（任务禁止越界写）。
- v0.2 evaluator 的 Candidate/Hygiene/Adoption/Readiness 四模式 live 重跑。
- toolkit `SKILL.md` 的 live discovery（未安装到 skill root；当前 catalog 无该 skill）。
- Desktop 0.2.0 与 CLI 0.2.1 的 session 互操作（本轮不启动 Desktop）。
- 真实 API 路由到的权重版本（无本地可观测字段）。
- `ask` approval 的实际弹窗/批准链路（本轮无需要批准的操作）。

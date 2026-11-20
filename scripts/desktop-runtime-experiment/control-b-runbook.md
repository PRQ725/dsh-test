# Control B runbook — isolated matched-version (0.2.0-rc.2) Web control

> **状态：NEEDS REDESIGN — DESIGN ONLY。本轮不执行。**
> 目的 1（原有）：把「English → Chinese 回归」归因到 **runtime 版本** 还是 **Desktop 专属行为**。
> 目的 2（**2026-10-05 新增，优先级更高**）：验证 **matched-version Web 0.2.0-rc.2** 能否
> discover / open / render Desktop 0.2 创建的 **v4** session。
>
> **⚠️ 现有隔离方案无法观测 v4 session，必须先改（见 §7）。**

---

## 0. 为什么需要它

| 组 | Desktop | Web/CLI runtime | 现状 |
|---|---|---|---|
| **Control A** | 0.2.0-rc.2 | **0.1.5-rc.3** | **已观测**：settings 被 rename+导入 → 旧 Web 无 file provider → 极小 `settings.yaml` → locale override 丢失 → UI 跟浏览器语言 |
| **Control B** | 0.2.0-rc.2 | **0.2.0-rc.2** | **待做** |

**关键洞察**：`importLegacyDocument()` 位于 **`@deepseek-ai/dsh-settings` 插件**里，而它随 **runtime 版本** 走。
⇒ **真正的自变量是 runtime 版本，不是 Desktop vs Web。**

---

## 1. 隔离机制（已由源码确认）

| 机制 | 证据 |
|---|---|
| bundled CLI = 普通 `dsh` CLI | `dsh-desktop-host/lib/cli.js` 里 `import { runCli } from "@deepseek-ai/dsh/lib/bin.js"` |
| 无 Electron IPC 依赖 | `if (import.meta.main) { … await runDesktopCli(…) }` —— 设计上允许独立进程调用 |
| 调用形态已知 | `resources\runtime\cli\bin\dsh.cmd` |
| **`DSH_HOME` 可重定向** | `dsh-home-paths`：`const DSH_HOME_ENV = "DSH_HOME";` *"Environment variable that overrides the default DeepSeek Harness home."* |

---

## 2. ⛔ 强制 safety assertion（**启动前必须全部通过**）

```powershell
# ============================================================
# CONTROL B — SAFETY ASSERTIONS  (run these FIRST; abort on any failure)
# ============================================================
$ErrorActionPreference = 'Stop'
$REAL_HOME = 'C:\Users\user02\.dsh'
$ISO_HOME  = 'D:\Projects\dsh-desktop-controlB-home'
$APP       = 'C:\Users\user02\AppData\Local\Programs\DeepSeek Harness'
$CLI       = "$APP\resources\app.asar\dsh\node_modules\@deepseek-ai\dsh-desktop-host\lib\cli.js"

# --- A1. exact isolated home, never the real one ---
if ($env:DSH_HOME -ne $ISO_HOME) {
  throw "ABORT: `$env:DSH_HOME must be exactly '$ISO_HOME' (got '$($env:DSH_HOME)')."
}
Write-Host "[OK] DSH_HOME is the isolated control home" -ForegroundColor Green

# --- A2. real home fingerprints recorded BEFORE ---
$RTP = 'D:\Projects\dsh-test\evidence\desktop\runtime'
& 'D:\Projects\dsh-test\scripts\desktop-runtime-experiment\capture-shared-state.ps1' `
    -OutDir "$RTP\controlB-REAL-HOME-BEFORE" -Label controlB-real-before
& 'D:\Projects\dsh-test\scripts\desktop-runtime-experiment\capture-shared-state.ps1' `
    -OutDir "$ISO_HOME" -Label placeholder   # NO: never point capture at the isolated home
Write-Host "[OK] real-home BEFORE manifest recorded" -ForegroundColor Green

# --- A3. no other DSH host may be running ---
$cliHosts = @(Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
              Where-Object { $_.CommandLine -match 'dsh[\\/]lib[\\/]bin\.js' })
$desktop  = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -match '(?i)DeepSeek Harness' -or $_.CommandLine -match 'dsh-desktop-host' })
if ($cliHosts.Count -gt 0) { throw "ABORT: a CLI host is already running (pid $($cliHosts.ProcessId -join ','))" }
if ($desktop.Count  -gt 0) { throw "ABORT: Desktop is running (pid $($desktop.ProcessId -join ','))" }
Write-Host "[OK] no other DSH host running" -ForegroundColor Green

# --- A4. bundled CLI present ---
if (-not (Test-Path $CLI)) { throw "ABORT: bundled CLI entry not found at $CLI" }
if (-not (Test-Path "$APP\DeepSeek Harness.exe")) { throw "ABORT: DeepSeek Harness.exe not found" }
Write-Host "[OK] bundled runtime present" -ForegroundColor Green

# --- A5. profile name must NOT be the reserved one ---
$PROFILE_NAME = 'control-b'
if ($PROFILE_NAME -eq 'desktop') { throw "ABORT: never use the reserved 'desktop' profile for the control" }
Write-Host "[OK] profile name '$PROFILE_NAME' is not reserved" -ForegroundColor Green
```

> ⚠️ 上面 A2 的第二条命令是**反面示例**：**绝不能**把 capture 指向 isolated home 当基线。
> 真实 home 的 BEFORE/AFTER 才是判据。

---

## 3. Feasibility probes（**必须先做，且仅此四步**）

| # | 命令 | 期望 | 失败含义 |
|---|---|---|---|
| **P1** | 用 bundled CLI 跑 `--version` | 打印 `0.2.0-rc.2` | bundled CLI 无法脱离 Electron 独立启动 |
| **P2** | 跑 `--help` | 与 0.1.5 参数面一致 | 参数面有差异 |
| **P3** | 在**隔离 home** 启动一次 `--profile control-b` | `$ISO_HOME` 被创建；**真实 home 0 变化** | 隔离未生效 → **立即停止整个 Control B** |
| **P4** | 确认 `manageDesktopProfile` 对非保留 profile 无副作用 | 不触碰 `desktop` profile | 需改用其他方案 |

**P3 是安全门禁**：它同时验证「隔离确实生效」。

---

## 4. 执行形态（design，勿在本轮运行）

```powershell
$env:ELECTRON_RUN_AS_NODE = '1'
$env:DSH_HOME = 'D:\Projects\dsh-desktop-controlB-home'          # ★ 硬编码，A1 会断言
$env:DSH_DESKTOP_NODE_EXECUTABLE = "$APP\DeepSeek Harness.exe"

& "$APP\DeepSeek Harness.exe" --expose-internals $CLI `
    --profile control-b web --port 3199
```

**前置准备（人工作业）**：在隔离 home 里先手工放一份 legacy `settings.yaml`（含 `locale.preference: en`），
这样才能观察 **匹配版本下 import 后 locale 是否保活**。

---

## 5. 收尾判据

```powershell
# --- A6. real home must be UNCHANGED ---
& 'D:\Projects\dsh-test\scripts\desktop-runtime-experiment\capture-shared-state.ps1' `
    -OutDir "$RTP\controlB-REAL-HOME-AFTER" -Label controlB-real-after
& 'D:\Projects\dsh-test\scripts\desktop-runtime-experiment\compare-captures.ps1' `
    -Before "$RTP\controlB-REAL-HOME-BEFORE" -After "$RTP\controlB-REAL-HOME-AFTER" `
    -OutDir "$RTP\controlB-REAL-HOME-COMPARE"
```

**必须为 0**：`CONTENT-CHANGED` = 0、`ADDED` = 0、`DELETED` = 0。
（`MTIME-ONLY` 允许，但必须列出。）

**若非 0 ⇒ 隔离失败，Control B 结论作废，并需排查是哪一步写了真实 home。**

---

## 6. 已知风险（必须随结论一起写）

| # | 风险 | 等级 |
|---|---|---|
| L1 | `DeepSeek Harness.exe` 以 `ELECTRON_RUN_AS_NODE=1` 可能有 Electron 单实例锁 | UNKNOWN |
| L2 | **忘记设 `DSH_HOME` 会写真实 home** | **高**（A1 断言 + A6 复核双重防护） |
| L3 | asar 只能由 Electron 解析（普通 `node.exe` 读不了）⇒ 必须用 `DeepSeek Harness.exe` | FACT |
| L4 | bundled CLI 与 Desktop 应用同时运行可能抢单实例锁 ⇒ **串行** | UNKNOWN |
| L5 | `koffi` + `installWindowsCliSignals()` 在非 Desktop 场景的健壮性 | UNKNOWN |
| L6 | 端口 3199 是否可用（避开 3080/3180） | 待 P3 确认 |

> 注：L3 对**运行**成立。对**只读取源码**不成立 —— `scripts\read-asar.mjs` 直接用
> `node.exe` 解析 ASAR header 并按偏移读取单个条目，无需 Electron，也不解包 121 MB。

---

## 7. ⚠️ 设计缺口与修订（2026-10-05，run3 之后）

### 7.1 为什么必须改

[FACT] run3 已证明：Desktop 0.2.0-rc.2 能创建 v4 session，而 Web **0.1.5-rc.3 无法 discover**
（host listing 因 `SESSION_FORMAT_VERSION = 3` 而静默丢弃）。详见
`evidence\desktop\runtime\e1-run3-FORENSIC-v4-DISCOVERY.md`。

[FACT] 因此 Control B 的目标变为：**matched-version Web 0.2.0-rc.2 能否 discover / open /
render 那个 v4 session。**

**问题**：现有设计把 Control B 跑在隔离 home（`D:\Projects\dsh-desktop-controlB-home`）里，
而隔离 home 里**没有** run3 的 v4 session ⇒ 按现设计 **Control B 根本观测不到要测的对象**。

### 7.2 修订后的执行形态（推荐 B1：隔离 home + 注入 v4 副本）

**绝不**把 `$DSH_HOME` 指向真实 home 去做这个测试（§2 A1 断言不变）。

前置注入（**一次性、纯新增**，源文件只读不动）：

```powershell
# 源（只读）
$SRC_SESS = 'C:\Users\user02\.dsh\sessions\--D-Projects-dsh-desktop-runtime-test-3--\session-0d5e7d0c-c341-48c4-a149-81250d473f20'
$SRC_PC   = 'C:\Users\user02\.dsh\storages\session_projcache\sessions\session-0d5e7d0c-c341-48c4-a149-81250d473f20.json'
# 目标（隔离 home）
$ISO_HOME = 'D:\Projects\dsh-desktop-controlB-home'
$DST_SESS = "$ISO_HOME\sessions\--D-Projects-dsh-desktop-runtime-test-3--\session-0d5e7d0c-c341-48c4-a149-81250d473f20"
$DST_PC   = "$ISO_HOME\storages\session_projcache\sessions\session-0d5e7d0c-c341-48c4-a149-81250d473f20.json"

New-Item -ItemType Directory -Path $DST_SESS -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $DST_PC -Parent) -Force | Out-Null
Copy-Item -LiteralPath "$SRC_SESS\session.v4.jsonl.zstd" -Destination "$DST_SESS\session.v4.jsonl.zstd"
Copy-Item -LiteralPath $SRC_PC -Destination $DST_PC
# 断言副本逐字节相同，且源未被改动（比对前后 SHA-256）
```

并在隔离 home 手工写入一份最小 `storages\workspace.json`，其 run3 workspace 条目
`sessionIds` **包含** `session-0d5e7d0c-…`。理由：run3 证据显示 0.1.5 会把该数组替换成
自己的（v3-only）视图；Control B 需要在一个**正确**的初始状态下起跑，否则无法区分
「listing 修好了但 registry 仍然挡路」与「listing 本来就没修好」。
workspace.json 的形状照抄真实文件（unit `workspace`, `version: 2`,
`global.workspaceIds` / `global.archivedSessionIds` / `global.pinnedSessionIds` /
`tables.workspaces[<uuid>] = { path, title, sessionIds, createdAt, updatedAt }`）。

### 7.3 Control B 必须断言的四件事（按顺序）

| # | 断言 | 失败含义 |
|---|---|---|
| **C1** | 打开 workspace 后，v4 session **出现在 session list** 中（listing 层） | 0.2.0 也无法列举 v4 → 「版本边界是唯一差异」的模型被否证 |
| **C2** | workspace 被打开后 **没有产生新的 `session.v*.jsonl.zstd`** | reuse-or-create 在 matched version 下也失败（不同缺陷，同样重要） |
| **C3** | 打开该 session 后，Desktop 写入的 marker / history **完整渲染**（open + render） | 能列举但读不出内容 |
| **C4** | 隔离 home 内该 v4 日志的 size 与 SHA-256 在**未发消息**时保持不变；`workspace.sessionIds` 仍含 v4 id | 读取过程发生了隐式迁移或 registry 破坏 |

### 7.4 判据

* C1..C4 全 PASS ⇒ **`DISCOVERABLE + OPENABLE`（matched version）**，与 run3 的
  `NOT DISCOVERABLE`（mismatched version）构成一对干净对照，v4 边界被确证为**唯一**自变量。
* C1 FAIL ⇒ 模型被否证，存在第二个未知变量（可能是 registry 分组、profile mount、
  或某个我们尚未读到的过滤层）⇒ 回到 archaeology，不要继续 Control B 的其他步骤。
* C1 PASS 但 C3/C4 FAIL ⇒ v4 是「可列举但不可读 / 读取有副作用」，这是比 run3 更严重的发现。

### 7.5 不要做的事

* 不要为了 Control B 去改动真实 home 的 `storages\workspace.json`（run2 的教训：注册表会被
  重写）。要改就改隔离 home 的那一份。
* 不要在 Control B 里发送任何 prompt（C4 要求日志不变）。
* 不要把 Control B 的结论写成「Web 能不能读 v4」的普遍结论 —— 它验证的是**这一个**
  Desktop 生成的 v4 日志在 **matched-version** host 下的可发现性。


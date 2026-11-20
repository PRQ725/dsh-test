# DSH 文件系统地图（概念 ↔ 真实文件/路径；实例以原机器为准）

> 长期维护的研究笔记 · 记录 DSH 概念层与真实文件系统的对应关系。
> 证据等级：`[FACT]` = 文件/源码/实际行为可直接确认；`[INFERENCE]` = 由多个事实推导；`[UNKNOWN]` = 当前无法确认。
> 更新时间：2026-09-01（首次建立）

> ### 环境归属说明（迁移后必读）
> 本文正文中的具体用户名绝对路径（如 `C:\Users\12699\.dsh`、`C:\Users\12699\AppData\...`）是**第一阶段源码考古所用机器（原机器）**的历史实例，不是当前机器路径。[FACT]
> - 原第一阶段考古机器：`$DSH_HOME = C:\Users\12699\.dsh`；workspace = `D:\dsh-test`。[FACT]
> - 当前机器（本仓库现所在）：`$DSH_HOME = C:\Users\user02\.dsh`；workspace = `D:\Projects\dsh-test`。[FACT]
> - 本文描述的**架构性位置关系**对任意 DSH 安装成立，一律用 `$DSH_HOME` / `<DSH>` 表达概念层；凡出现 `12699` 的具体路径均指原机器历史事实，勿当作当前环境。

## 0. 关键锚点（原机器绝对路径，历史事实）

| 概念 | 真实路径 | 证据 |
|---|---|---|
| `$DSH_HOME` | `C:\Users\12699\.dsh` | [FACT] 环境变量 |
| DSH 安装目录 | `C:\Users\12699\AppData\Roaming\npm\node_modules\@deepseek-ai\dsh` | [FACT] |
| 当前 profile | `C:\Users\12699\.dsh\profiles\web` | [FACT] 唯一 profile |

## 0.1 当前环境与版本（★ 全库唯一版本事实源）

> **全库规则**：`docs/` 与 `experiments/` 中出现的 DSH 版本号，凡**未特别说明**者，一律是**该文档记录时**的环境。
> **"当前版本"以本表为准**；其他文档不复述版本号，只引用本节。

> ### ★★ 版本不是一个标量：本机有**两个 installation anchor**
> 官方 Desktop 引入了第二个 anchor，两者可并存、互不覆盖（详见 `09-dsh-desktop.md` §3）。
> 凡陈述"当前 DSH 版本"必须写明**哪个 anchor**。

| anchor | 路径 | 当前版本 | 采集时间 |
|---|---|---|---|
| **全局 npm DSH** | `C:\Users\user02\AppData\Roaming\npm\node_modules\@deepseek-ai\dsh` | `0.2.2-rc.1` | **2026-11-08** |
| **Desktop bundled runtime** | `...\Programs\DeepSeek Harness\resources\app.asar\dsh\node_modules\@deepseek-ai\dsh`（经 `resources\runtime\cli\bin\dsh.cmd` 调用） | `0.2.0-rc.2` | 2026-10-05（2026-11-08 复核仍未变） |

| 其他项 | 当前值 | 采集时间 |
|---|---|---|
| Node / npm | `v24.20.0` / `12.0.2`（DSH `0.2.2` 起**最低要求 Node ≥ 24.9**） | 2026-11-08 |
| Corepack / pnpm | `0.35.0` / `12.4.2`（`C:\Program Files\nodejs\`） | 2026-09-24 |
| `$DSH_HOME` | `C:\Users\user02\.dsh`（**两个 anchor 共享**，见 `09` §5） | 2026-10-05 |
| 本 workspace | `D:\Projects\dsh-test` | — |
| **Active Web session runtime** | `0.2.2-rc.1`（CLI/Web 的 `browser-lab` profile；**不是** Desktop） | **2026-11-08** |
| Cordis 版本（组合语义载体） | Core `4.1.0` · Loader `1.1.0` · Include `1.1.0` | **2026-11-08** |
| `$DSH_HOME\cordis.patch.yml` | **不存在**（跨 profile 共享层，见 `07` §6.1） | 2026-10-05 |
| `$DSH_HOME\settings.yaml` | 存在（两版本会互相 bootstrap / import，见 `09` §7） | 2026-10-05 |

> **[2026-11-08 跨版本复核（0.2.1-rc.2 → 0.2.2-rc.1）]** 全局 npm anchor 已升为 `0.2.2-rc.1`
> （`npm dist-tags`: `latest` = `next` = `0.2.2-rc.1`，`alpha` = `0.2.2-alpha.3`）。
> Desktop bundled runtime **仍未升级**，`runtime.json.desktopVersion` 与 exe FileVersion 均为 `0.2.0-rc.2`。
> 当前服务的 Web session 与全局 npm 同版本。判别依据：`DSH_PROFILE=browser-lab`、
> `dsh --version` = `0.2.2-rc.1`、安装 `package.json` 同版本，且 Desktop anchor 明确是 `0.2.0-rc.2`。
> 证据：`../experiments/dsh-version-audit/0.2.1-rc.2-to-0.2.2-rc.1/`。

> **[2026-10-19 跨版本复核]** 全局 npm 已由 `0.1.5-rc.3` 升为 `0.2.1-rc.2`；Desktop bundled runtime
> **未升级**，仍为 `0.2.0-rc.2`。当日正在服务的 Web session 运行在 **CLI/Web 的 `browser-lab` profile**
> （`0.2.1-rc.2`）上，不是 Desktop 后端。判别依据：该 session 的工具面包含 0.2.1 才有的
> `working_directory` 工具，且 profile 不是 Electron 保留的 `desktop`；不是只看 UI 版本号。
> 证据：`../experiments/dsh-version-audit/0.2.0-rc.2-to-0.2.1-rc.2/`。

> **[2026-10-19 模型层复核]** selected model ID = `deepseek-flash`，provider = `deepseek-official`。
> UI 显示 `DeepSeek-V4.1-Flash` + `1017` badge 只是客户端 label
> （`dsh-client-ui-deepseek-model-label-1017`），**不是权重版本证明**；实际 API 路由到的权重版本为
> `[UNKNOWN]`。证据：同目录 `RUNTIME-VERIFICATION.md` §4、`evidence/upstream/added/`。
>
> **[2026-11-08 版本注记]** 该 `1017` label 包在 `0.2.2-rc.1` 中**已被移除**（见
> `0.2.1-rc.2-to-0.2.2-rc.1` 审计 `onlyV1` 列表）。因此：
> - `0.2.1-rc.2` 及更早：UI 可能出现 `1017` badge，且它仍只是客户端展示。
> - `0.2.2-rc.1` 起：该 badge 组件不再随包分发，UI 上**不应再看到**它；
>   但"模型权重版本"依然是 `[UNKNOWN]`，**不能**因 badge 消失就反推路由到了别的权重。

**全局 npm DSH 版本演进**：
`0.1.1-rc.2`（第一阶段考古）→ `0.1.5-rc.1` → `0.1.5-rc.2`（升级失败）→ `0.1.5-rc.3`
→ `0.2.0-rc.2`（2026-10-05）→ `0.2.1-rc.2`（2026-10-19）→ `0.2.2-rc.1`（2026-11-08）。
rc.1 → rc.3 的升级事故记录见 `../experiments/dsh-install/2026-09-23-dsh-global-upgrade-rc1-to-rc3-incident.md`；
后续升级记录见 `08-dsh-installation-and-upgrade.md` §11。

**Desktop bundled runtime**：`0.2.0-rc.2`（Desktop 应用 FileVersion `0.2.0.0`）；2026-11-08 复核**仍未升级**，
与已升级的 CLI `0.2.2-rc.1` 并存。`[0.1.5 → 0.2.x]` 的两个不兼容面（settings 模型、session format）见
`09-dsh-desktop.md` §7 / §8；`0.2.0 → 0.2.2` **不在**该断裂面上（`SESSION_FORMAT_VERSION` 仍为 **4**）。

> ⚠️ **历史版本号不要"顺手改新"**：例如 "`0.1.5-rc.1` 起 agent-presets 移到包内" 记录的是**哪个 release 引入的变更**；改成 rc.3 会变成错误陈述。
> 只有**陈述"当前环境"**的句子才应更新。

## 1. 真实存在的目录与关键文件清单

### 1.1 `$DSH_HOME`（`C:\Users\12699\.dsh`）
- `profiles\` — profile 目录容器
- `profiles\web\` — 唯一 profile（web）
- `sessions\` — 会话日志存储
- `storages\` — 存储
- `.anonymous-user-id` — 匿名 id
- `.credentials.yaml` — 凭据
- `settings.yaml` — 用户设置
- `cordis.patch.yml` — **当前不存在**（home user layer，见 §6.5）

### 1.2 `profiles\web\`（profile 目录实际内容）
- `package.json` (207 B) — profile manifest
- `cordis.yml` (223 B) — profile root（内容为空 `[]`）
- `cordis.patch.yml` (217 B) — profile user layer（内容为空 `[]`）
- `pnpm-workspace.yaml` (61 B) — pnpm 设置（非组合文件，由 initProfile 生成）

### 1.3 DSH 安装目录（`...\node_modules\@deepseek-ai\dsh`）
- `lib\` — dsh CLI 构建产物（bin.js、profile-boot 等）
- `node_modules\@deepseek-ai\` — **shipped sibling 包**（230+ 个：dsh-base、dsh-web-app、dsh-app-boot、dsh-sandbox-local…），**每个还可能再带自己的 `node_modules`**
- `package.json` — dsh 自身清单

> **★ 安装是一个「依赖树」，不是一个包。** 顶层版本正确**不代表**内部依赖自洽。
> `resolveBundleDir` 所说的"**安装锚点**"解析的是这整棵树；树的一致性与物理布局由 **npm** 负责，不由 profile 模型保证。
> 分层模型与升级语义 → **`08-dsh-installation-and-upgrade.md`**。
>
> **[STALE] 历史更正**：`config\`（含 agent-presets）是 **0.1.1 时代**该目录下的内容；**0.1.5 起 agent-presets 已移到 `@deepseek-ai/dsh-agent-presets\presets\`**（见 §1.5）。

### 1.4 两个 bundle（安装在 dsh 的嵌套 node_modules 下）
- `...\node_modules\@deepseek-ai\dsh-base\`（含 `cordis.patch.yml`，450 行）
- `...\node_modules\@deepseek-ai\dsh-web-app\`（含 `cordis.patch.yml`，445 行）

### 1.4b ★ shipped 包 vs profile-local 包（**路径区分，勿混淆**）

| 类别 | 路径 | 由谁安装 | 归属决定者 |
|---|---|---|---|
| **shipped bundle / sibling**（dsh-base、dsh-web-app、dsh-mcp-client…） | `<DSH>\node_modules\@deepseek-ai\<pkg>\` | `npm install -g @deepseek-ai/dsh` | 顶层 DSH 的依赖声明 |
| **profile-local 插件**（如 `dsh-whale-widget`） | `$DSH_HOME\profiles\<name>\node_modules\<pkg>\` | `dsh plugin --profile <name> add <pkg>` | 该 profile 的 `package.json`（`dsh.profile.bundles`） |
| **共享 module fallback** | `$DSH_HOME\profiles\node_modules\@deepseek-ai\<pkg>\`（Junction） | 由 DSH `healProfilesModuleFallback()` 在 **boot 时**维护，指向**当前**安装 | **无归属**（只影响可解析性） |

> ⇒ **两类安装互不隶属**：全局安装被整体替换，**不会**删除 profile-local 的 bundle membership（实证见 `08` §8）。
> 详见 `07-profile-bundle-isolation.md`、`08-dsh-installation-and-upgrade.md` §8 / §9。

### 1.5 `@deepseek-ai/dsh-agent-presets\presets\`（shipped agent presets）

> **[UPDATED 2026-09]** 旧版（0.1.1-rc.2）位于 `<DSH>\config\agent-presets\`；**0.1.5-rc.1 起移到 `dsh-agent-presets` 包内**：
> `<DSH>\node_modules\@deepseek-ai\dsh-agent-presets\presets\<id>\agent.cordis.yml`。[FACT]
- roster（0.1.5-rc.1）：`cordis\` `minimal\` `ptc\` `standard\` — 每个含 `agent.cordis.yml`（+ `preset.yml` 展示元数据）。
  （旧 roster 中的 `code` 已不在 0.1.5。）
- 用户自定义 preset 根：**`$DSH_HOME\.agent-presets\<id>\agent.cordis.yml`**（trust = `user`；本机当前**不存在**）。[FACT]

## 2. 概念名称 vs 真实文件 vs 注释概念

### 2.1 "base.cordis.yml" / "web.cordis.yml"
- **不是真实文件**。本机在 dsh 安装目录、`$DSH_HOME`、workspace 三处递归搜索均无此二名文件。
- **是源码注释中的概念简称**：出现在 agent preset `standard\agent.cordis.yml` 顶部注释里（0.1.5-rc.1 路径：`<DSH>\node_modules\@deepseek-ai\dsh-agent-presets\presets\standard\agent.cordis.yml`），指代"base bundle + web-app bundle 两段 host 组合"。
- 实际 host 组合载体是 bundle 的 **`cordis.patch.yml`** 文件。
- 等级：[FACT]（搜索无此文件）+ [INFERENCE]（其语义对应当前 bundle patch 机制）。

> ⚠️ 旧认知需修正：不要把 `base.cordis.yml` / `web.cordis.yml` 当作真实文件名；真实文件是 `dsh-base\cordis.patch.yml` 与 `dsh-web-app\cordis.patch.yml`。

### 2.2 host plane / agent plane
- 非单独文件，是两个**组合平面**：host = profile bundle 组合；agent = 会话挂载的 preset 组合。
- 等级：[FACT]（源码注释 + 运行机制）+ 无单独对应文件。

## 3. 概念 → 实际文件/目录 映射表

| 概念 | 实际文件/目录 | 本机存在? | 组合位置 | Plane | 证据 |
|---|---|---|---|---|---|
| DSH_HOME | `C:\Users\12699\.dsh` | ✅ | — | — | [FACT] |
| profile | `C:\Users\12699\.dsh\profiles\web` | ✅ | — | — | [FACT] |
| profile manifest | `...\profiles\web\package.json` | ✅ | 声明 bundle 顺序 | host | [FACT] |
| profile root | `...\profiles\web\cordis.yml` | ✅（空 `[]`） | 组合底基（空 base） | host | [FACT] |
| profile user layer | `...\profiles\web\cordis.patch.yml` | ✅（空 `[]`） | 所有 bundle 之后 | host | [FACT] |
| bundle | dsh-base / dsh-web-app 包目录 | ✅ | bundle 层 | host | [FACT] |
| bundle patch | 每个 bundle 的 `cordis.patch.yml` | ✅ | root 之上、按 bundles 顺序 | host | [FACT] |
| home user layer | `C:\Users\12699\.dsh\cordis.patch.yml` | ❌ **无单独对应文件** | profile 层之后 | host | [FACT] |
| CLI --patch overlay | 无文件（CLI 参数 `<path>`） | 本次未传 | home 层之后 | host | [FACT] |
| agent preset | `<DSH>\node_modules\@deepseek-ai\dsh-agent-presets\presets\<id>\agent.cordis.yml` 等（0.1.5-rc.1；旧版在 `config\agent-presets\`） | ✅（默认 standard） | 运行时会话挂载 | **agent** | [FACT] |
| host plane | 无单独文件（= bundle patch 组合） | — | profile 组合 | host | [FACT]/[INFERENCE] |
| agent plane | 无单独文件（= preset 组合） | — | 会话 scope | agent | [FACT]/[INFERENCE] |

## 4. 结构图（真实路径 + 概念角色注释）

```
C:\Users\12699\.dsh                                    ($DSH_HOME)
├── profiles\
│   └── web\
│       ├── package.json                              ← profile manifest（声明 dsh.profile.bundles 顺序）
│       ├── cordis.yml                                ← profile root（空 []，Loader baseUrl 锚点）
│       ├── cordis.patch.yml                          ← profile user layer（空 []）
│       └── pnpm-workspace.yaml                       ← 非组合文件（pnpm 设置）
│   └── node_modules\                                 ← profiles 级平面符号链接目录（healProfilesModuleFallback 维护）
├── sessions\  storages\  settings.yaml  .credentials.yaml  .anonymous-user-id
└── cordis.patch.yml                                  ← home user layer 【当前不存在】

C:\Users\12699\AppData\Roaming\npm\node_modules\@deepseek-ai\dsh    (dsh 安装, 原机器历史实例)
├── lib\                                              ← dsh CLI 构建产物
└── node_modules\@deepseek-ai\
    ├── dsh-agent-presets\presets\                    ← agent presets（0.1.5-rc.1 起；旧版在 config\agent-presets\）
    │   ├── standard\agent.cordis.yml                 ← agent preset（默认；agent composition）
    │   ├── cordis\agent.cordis.yml
    │   ├── ptc\agent.cordis.yml                       (0.1.5 新增)
    │   └── minimal\agent.cordis.yml
    ├── dsh-base\
    │   ├── package.json                              ← 其 dsh.bundle.patch 声明
    │   └── cordis.patch.yml                          ← bundle layer ①（1×insert，78 行）
    ├── dsh-web-app\
    │   ├── package.json                              ← 其 dsh.bundle.patch 声明
    │   └── cordis.patch.yml                          ← bundle layer ②（27 override + 2 insert + 24 disabled）
    └── (其余 @deepseek-ai/* 插件包)
```

## 5. 真实文件间的关系（结合源码）

- **profile/package.json → bundle**：`dsh.profile.bundles`（有序数组）列出 bundle 包名；`loadProfile`（`@deepseek-ai/dsh-app-boot\lib\index.js`）对每个名字用 `resolveBundleDir` 双锚点解析到实际包目录。[FACT]
- **bundle/package.json → bundle patch**：`"dsh": { "bundle": { "patch": "./cordis.patch.yml" } }`；`loadProfile` 读取该字段拼出 patch 绝对路径，用 `loadOverlayPatches` 解析。[FACT]
- **profile/cordis.yml 的作用**：profile root。空 `[]`；`prepareProfile` 每次 boot 重写；Loader 以它为 include 锚定 `baseUrl`，实际树在空列表上叠加 patch 而成。[FACT]
- **profile/cordis.patch.yml 的作用**：profile user layer。空 `[]`；在所有 bundle 层之后、home 层之前应用。[FACT]
- **`$DSH_HOME/cordis.patch.yml` 当前是否存在**：**不存在** ⇒ home user layer 为空/缺失。[FACT]
- **agent-presets/standard/agent.cordis.yml 的作用**：agent 预设组合；定义会话所见工具（tool-fs/tool-pwsh 等）。host 的 `agent-presets` 行 `default: standard`，运行时 `presets.mount(agentCtx, preset)` 挂入 agent scope。[FACT]

## 6. 组合顺序（供参考）

```
host plane（applyEntryPatches 单次摊平）:
  空 root (cordis.yml)
    ← dsh-base/cordis.patch.yml  (insert)
    ← dsh-web-app/cordis.patch.yml (override/disable)
    ← profiles\web\cordis.patch.yml (空)
    ← $DSH_HOME\cordis.patch.yml (缺失)
    ← --patch (本次未传)

agent plane（运行时会话挂载）:
  presets.mount → standard\agent.cordis.yml  (独立提供 agent 工具)
```

## 7. 已确认 / 仍未知

- [FACT] 无 `base.cordis.yml` / `web.cordis.yml` 真实文件（仅概念简称）。
- [FACT] `$DSH_HOME\cordis.patch.yml` 不存在（home 层为空）。
- [FACT] agent-presets 默认 `standard`。
- [UNKNOWN] agent-presets 行 `default: standard` 具体由哪个 bundle patch 行产生（未溯源到具体补丁）。
- [UNKNOWN] 本次会话是否显式切换过 preset。

## 7.5 Workspace / Session / Sandbox（运行期对象层）

> 这三个是 **DSH 运行期对象**，落在 `$DSH_HOME` 的 state 层，**不在**项目目录里。证据：源码 + `$DSH_HOME\storages` 实测。[FACT]

### 7.5.1 Workspace [FACT]
- **workspace = 一个被 DSH 登记的项目目录**（不是 profile，不是拷贝）。注册记录：`$DSH_HOME\storages\workspace.json`（`@deepseek-ai/dsh-storage-domain` 的 `workspaces` 表）。
- 记录字段：`path`(canonical)、`title`、`sessionIds[]`、`createdAt`、`updatedAt`；`global.workspaceIds[]` 保存 durable 顺序。
- **登记机制**：`ctx.workspaceRegistry.create(path)` = `fs.realpath` → 必须存在且为目录 → 同 canonical path 复用，否则写一条记录。**只写 `$DSH_HOME` 注册表，不写项目目录、不碰 `.git`、不初始化项目内文件**（详见 `migration/14-phase32-execution-verification.md` §A）。
- `delete(id)` 只删注册/顺序/session 记账；目录、用户文件、session log 都不动。[FACT]
- **workspace ≠ profile**：profile 是机器级 host 组合容器（`$DSH_HOME\profiles\<name>`）；workspace 只是「被注册的项目目录」。**adopt 一个目录不会让它变成 DSH profile**（其根仍无 `cordis.yml`/`package.json`）。[FACT]

### 7.5.2 Session [FACT]
- session = 一个 workspace 下一次会话；header 带 `id` / `createdAt` / `cwd` / `delegationDepth` / `agentPreset` 等。
- 存储：`$DSH_HOME\sessions\<workspace-key>\<session-id>\session.v<N>.jsonl.zstd`（`<N>` 为 session format 版本，当前为 `v4`；key 由 cwd 派生，如 `--D-Projects-dsh-test--`）。
- **物理格式 = concatenated multi-frame zstd**：单文件由多个 zstd frame 顺序拼接（实测一个 1-turn session 含 45 个 frame）。用一次性 `zstdDecompressSync` 整文件解码**只会得到第 1 帧**；必须逐 frame 解码后拼接。[FACT]
- 另见 `$DSH_HOME\storages\session_projcache.json`（各 session 的 identity 与统计，如 turns/steps/decodeTokens/title）。
- **[2026-10-19 复核，0.2.1-rc.2]** session format 仍为 **v4**，实际文件名为 `session.v4.jsonl.zstd`；0.2.0 与
  0.2.1 的 `SESSION_FORMAT_VERSION` 都是 `4`，因此 `0.1.5` 时代的 `[v3 → v4]` 边界**不适用于** `0.2.0 → 0.2.1`。
  证据：`../experiments/dsh-version-audit/0.2.0-rc.2-to-0.2.1-rc.2/`。
- **[2026-11-08 复核，0.2.2-rc.1]** session format **仍为 `v4`**（`SESSION_FORMAT_VERSION = 4`，
  `dsh-session-format-v3-to-v4` 仍在），因此 `0.2.0 → 0.2.2` 同样**不触发** `[v3 → v4]` 断裂面。
  `stat`/`list` 快照新增 `location: { kind: 'jsonl', path }`（指当前选中的物理 generation）。
  证据：`../experiments/dsh-version-audit/0.2.1-rc.2-to-0.2.2-rc.1/`。
- **[2026-11-08 新增，0.2.2]** 两条与"读 session"相关的结构变化：
  1. **Session Projection 注册改为异步**（`sessionProjections.register` 返回/要求 awaitable handle）：
     插件必须在启动时**持有 handle** 才能读；旧的"注册即返回 disposer、按 key 直接读"仍兼容但已**弃用**。
     受影响的插件（含 `dsh-goal` / `dsh-plan-mode` / `dsh-permission-presets`）在 0.2.2 都改成
     "激活期 await 注册 + 保留 handle"。[FACT，0.2.2 包 README + 官方发布块]
  2. **Session API 拆成独立接口**：读**快照**与**持续订阅**（event log / 运行状态 / projection 数据）
     分成不同入口，不再要求用同一条流同时做两件事。[FACT，官方发布块；本机未逐一 live 验证]
- **[2026-10-19 新增机制，0.2.1]** `working_directory` 服务允许改变**单个 Session** 的当前目录；该值由 session
  projection 持久并作为 required user context 注入，但**已有进程与 sandbox grant 保持各自边界**，不会随 cwd
  自动重划。不要把“改 cwd”当成“改 workspace root”或“改 sandbox 授权”。[FACT，0.2.1 源码/README]
- session ≠ workspace：session 是运行期会话与其 event log，不是项目资产；session archive 也不等于可直接跨机 resume（见 `03` §5）。[FACT]

### 7.5.3 Sandbox / permission / approval [FACT]
- 由 **host plane** 拥有（见 `01` §六）。会话事件中可见其生效值：
  - `sandbox/mode`（如 `workspace-write`）
  - `approval/policy`（如 `ask`）
  - `permission/preset`（如 `workspace-write`）
- 这些是**运行期生效的边界值**，不是项目文件。
- **[2026-10-19 复核]** 边界值是 **session 级配置**，不是安装级常量：同一天内，用户可以把该 session 从
  `workspace-write` / `ask` 改为 `danger-full-access` / `never`。不要把“DSH 版本”直接映射成“权限值”；
  引用边界时必须同时写明**哪个 session / 何时**。[FACT，本机 runtime context + session events]
- **[2026-11-08 更新，0.2.2]** `dsh-permission-presets` 的钉扎时机由 **session 创建**改为
  **Agent 创建**（`agent/created`），并因此**额外依赖 Agent registry**；读取 projection 的 handle
  在激活期取得，"reader 未就绪时 Agent 创建会回滚"。⇒ 权限值仍是 session 级事实，但**产生时机**
  绑定在 Agent 创建上。[FACT，0.2.2 `dsh-permission-presets` README]
- **[2026-11-08 更新，0.2.2]** 审批提示文案现在**显式说明本次是否在请求用户授权**，用于消除
  "`never` 策略到底意味着什么"的歧义。若在 `never` 下看到审批相关文字，它可能只是说明性文案，
  **不等于**存在可批准的门。[FACT，官方发布块；本机 `never` 下无审批实测]

### 7.5.4 Tool execution plane（2026-11-08 新增，0.2.2）[FACT]

0.2.2 把"工具如何被呈现给模型"从 `dsh-tools` 的**一个 config 字段**拆成了**可挂载的 executor 插件**：

| 项 | 0.2.1 及更早 | 0.2.2 |
|---|---|---|
| 呈现模式 | `dsh-tools` 的 `mode: native \| ptc`（含已移除的 `both`） | **executor 插件**：`dsh-tool-executor-native` / `dsh-tool-executor-ptc`，按 scope（deployment / preset / Agent）择近生效 |
| 环境变量 | `DSH_TOOLS_MODE` | **已移除**（`lib` 代码零命中；仅存于迁移说明文档） |
| 旧 config 键 | `dsh-tools` 接受 `mode` | **`mode` 与 `maxParallelSubCalls` 都被声明为 `z.never()`**：留着旧键**会校验失败并报出来**，不是被静默忽略 |
| 并发 | `maxParallelToolCalls` 由 agent-loop 的工具调度拥有 | 归 **executor** 拥有；`maxParallelToolCalls` 仍存在，但作为 **batch 参数**传入并**优先于** executor 配置 |
| 工具可见性 | 每 agent 的静态可见集 | 新增**按 step 条件启用**（`register(def, { when })` + `resolve()` 得到 step-owned `ResolvedToolSet`） |

- 本机 `dsh-base`：`tool-executor-native` **启用**、`tool-executor-ptc` **`disabled: true`** ⇒ 默认 native。[FACT，本机 patch]
- **`fs-observation-policy`：装配层未挂载，但运行期"先读"守卫仍然存在 —— 三层要分开说**（`[FACT]` + `[INFERENCE]` + `[UNKNOWN]`）
  - **① 出厂装配（`dsh-base`）**：该 entry 存在但 `disabled: true`（本机 L292-294）。`[FACT]`
  - **② 当前 profile 有效装配（`browser-lab` = base + web-app + whale）**：逐层核对 —— `dsh-web-app`
    与三个 preset（`presets/cordis.patch.yml` / `standard.patch.yml` / `ptc.patch.yml` / `minimal.patch.yml`）
    **都没有**重新挂载它；`$DSH_HOME\profiles\browser-lab\cordis.patch.yml` 也没有；
    全安装树无任何 js/yml 以 entry id 引用它。⇒ **有效组合里该插件未挂载**。`[FACT]`
  - **③ 实际运行行为**：**仍然会拒绝**改未读文件 / 被外部改过的文件。本会话实测错误文本为
    `cannot modify "…": file has not been read — read the file, then retry` 与
    `cannot edit "…": file changed since it was read`。这两句**只**由 `dsh-tool-fs` L477/478 产出
    （它把 `FS_NOT_OBSERVED` / `FS_STALE_VERSION` 规范化成这个措辞）。`[FACT，本会话真实工具返回]`
  - **推论**：既然 policy 插件未挂载，另一个能抛这两个错误码的来源是**provider（`dsh-fs-local`）本身**
    （`FS_NOT_OBSERVED` L506/508/1025，`FS_STALE_VERSION` L937/939/1023/1024/1030/1032）。
    ⇒ 这道守卫**至少部分来自 provider 层**，与 0.2.2 是否"默认关闭 policy 插件"**不是同一件事**。`[INFERENCE]`
  - **仍未定位**：无 policy 时 provider 自己的观测台账具体在哪个分支生效（provider 何时拿到 `expected`）。
    要彻底判定需要一次受控实测（新建 temp 文件 → 不读直接 `edit`），本轮**未做**。`[UNKNOWN]`
  - **旧笔记怎么错的**：`0.2.1-rc.2` 的 `dsh-tool-fs` README 在两条 model guidance 里写着
    *"(the default fs-observation-policy requires it)"*，`0.2.2-rc.1` 把该括注**删掉了**。
    也就是说"默认要求先读"这句只存在于**包 README 措辞**里，与 `dsh-base` 的 `disabled: true` 长期矛盾。
    ⇒ 正确表述是：**"policy 插件默认不挂载" ≠ "没有先读守卫"**。
  - **实用结论**：改文件前仍然应该先 `read`（运行期会拒）；但**不要**把"policy 插件已启用"当作
    版本对比的差异点，也不要据此推断 `write`/`edit` 无条件成功。若确实需要**显式**启用该插件
    （以获得 `FS_NOT_OBSERVED` 的**策略原因**文本），把该行改成 `disabled: false`。
- **`apply_patch`（0.2.2 新增工具）默认不注册**：本机 `dsh-base` 的 `tool-fs.config.applyPatch: false`，
  `dsh-web-app/presets/cordis.patch.yml` 同样是 `false`。要启用需把该行改 `true`。
  **注意**：0.2.2 的 `dsh-tool-fs` README 声称 "`dsh-base` 和 Web `standard` preset enable it"，
  与**本机实际 patch 值不一致** ⇒ 以 patch 文件为准，README 该句记为 `[DISCREPANCY]`。[FACT，本机 patch 逐行核对]

---

## 8. 需要修正的旧认知

1. **"base.cordis.yml + web.cordis.yml 语义"（文件名）** → 本机不存在这两个文件；真实载体为 `dsh-base\cordis.patch.yml` + `dsh-web-app\cordis.patch.yml`。二者只是 agent-preset 注释中的概念简称。
2. **不要臆造 home 层文件** → `$DSH_HOME\cordis.patch.yml` 当前不存在，home user layer 为空；地图中需标"无单独对应文件"。
3. **agent 工具 ≠ host profile 组合** → `tool-fs`/`tool-pwsh` 等工具由 agent preset（standard）在 agent plane 提供，而非 profile 组合；host dump 中它们 disabled 不矛盾。

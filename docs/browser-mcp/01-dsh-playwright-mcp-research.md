# 01 — DSH × Playwright MCP 接入研究（`dsh-mcp-client` 包与 schema）

> **文档定位**：**长期知识文档**（`docs/browser-mcp/`）。本文件是 Browser MCP 研究线的**包 / 配置 schema 层**结论；上层集成与 E2E 见 `docs/05-browser-mcp.md`，执行过程见 `experiments/browser-mcp/`。
> **证据等级**：文中 `[FACT]` / `[INFERENCE]` / `[UNKNOWN]` 沿用原文标注。

**角色**：本地 DSH 架构研究员（本地验证）
**日期**：2026-09-11
**DSH**：`@deepseek-ai/dsh@0.1.5-rc.1` · Node v24.20.0 · npm 12.0.2 · pnpm 未安装
**DSH_HOME**：`C:\Users\user02\.dsh`
**实验工作区**：`D:\Projects\dsh-test`
**阶段**：研究（未安装、未修改任何配置）

> 本报告全部结论来自对**当前机器上真实安装的 DSH 包**（`~/.dsh/profiles/node_modules/` 与
> `C:\Users\user02\AppData\Roaming\npm\node_modules\@deepseek-ai\dsh\`）的源码 / d.ts / YAML 直读，
> 不依赖背景资料。背景资料中"之前研究得到的架构证据"已逐条重新验证，**结论是：字段仍有变化**（见 §1.6）。

---

## 1. 已确认 FACT

### 1.1 `dsh-mcp-client` 存在且已可用

| 项 | 值 |
|---|---|
| 包名 | `@deepseek-ai/dsh-mcp-client` |
| 版本 | `0.1.5-rc.1`（与 DSH 同版本） |
| 安装位置 | `C:\Users\user02\.dsh\profiles\node_modules\@deepseek-ai\dsh-mcp-client` |
| 入口 | `lib/index.js`（33 477 字节 / 790 行） |
| 类型声明 | `lib/types/{index,connection,tools,transport}.d.ts` |
| Cordis 插件名 | `export const name = "mcp-client"` |
| `inject` | `["tools"]` |
| 依赖 | `@modelcontextprotocol/sdk ^1.12.0`（**已装 v1.30.0**）、`zod`、`schemastery` |

**关键：`src/` 未随包发布，只有 `lib/`。** 所以"读源码"只能读 `lib/index.js` + `lib/types/*.d.ts`；
`README.md` 引用的 `src/index.ts` 在本机不存在（那是仓库内路径）。

### 1.2 配置 schema（来自 `lib/types/index.d.ts` L25–75 与 runtime L743–760）

配置是一个 **`z.union`**，由 `transport` 字段判别（discriminated union）：

**stdio 分支**
```yaml
transport: stdio              # z.const("stdio")  —— 必需
serverName: <name>            # z.string().required().pattern(/^[A-Za-z0-9_-]{1,32}$/)  —— 必需
command: <exe>                # z.string().required()  —— 必需
args: []                      # z.array(String).default([])
env: {}                       # z.dict(String).default({})
cwd: ""                       # z.string().default("")
toolCallTimeoutMs: 60000      # z.number().default(60000)
failOnStartupError: false     # z.boolean().default(false)
reconnect: {...}              # 可选，schema 内部各自带 default
```

**streamable-http 分支**
```yaml
transport: streamable-http    # z.const("streamable-http")  —— 必需
serverName: <name>            # 必需，同上 pattern
url: <endpoint>               # z.string().required()  —— 必需
headers: {}                   # z.dict(String).default({})
toolCallTimeoutMs: 60000
failOnStartupError: false
reconnect: {...}
```

**reconnect 子 schema**（`lib/index.js` L737–741，默认值常量 L472–477）

| 字段 | 默认 | 约束 |
|---|---|---|
| `enabled` | `true` | boolean |
| `initialDelayMs` | `500` | min 1 |
| `maxDelayMs` | `30000` | min 1 |
| `maxAttempts` | `10` | min 1，整数 |

未知字段会 **抛错**（`lib/index.js` L491：`is not a reconnect option`），不是静默忽略。

**硬常量**：`DEFAULT_TOOL_CALL_TIMEOUT_MS = 60000`（L728）、
`SERVER_NAME_PATTERN = /^[A-Za-z0-9_-]{1,32}$/`（L730）、`GENERATION_CLOSE_TIMEOUT_MS = 5000`（L478）。

### 1.3 两种 transport 的实际实现（`lib/index.js` L40–50）

```js
case "stdio": return new StdioClientTransport({
    command: config.command,
    args: config.args,
    env: buildChildEnv(config.env),
    cwd: config.cwd
});
case "streamable-http": return new StreamableHTTPClientTransport(
    new URL(config.url), { requestInit: { headers: config.headers } });
```

**（a）stdio = 由 DSH 进程 `spawn` 一个子进程**，走 MCP SDK 官方 `StdioClientTransport`。
`args` 注释明确写着 **"passed directly, without shell interpolation"** —— 不经 shell，无 shell 注入面。

**（b）stdio 子进程的 env 是被"消毒"的**（`buildChildEnv` L28–33 调用
`@deepseek-ai/dsh-subprocess` 的 `scrubbedParentEnv()`）：

- 在 `dsh-subprocess/lib/index.js` L32：`SENSITIVE_ENV_PATTERN = /KEY|PASSWORD|SECRET|TOKEN/i`
- L52：凡是**键名**匹配该模式、或键名以 `DSH_`（大小写不敏感）开头的变量 **一律剥离**
- `PATH`、`PATHEXT`、`TEMP` 等都保留

> **这是一条必须提前知道的实战约束**：stdio MCP 子进程里 **拿不到 `DEEPSEEK_API_KEY`，
> 也不会有 `DSH_HOME` / `DSH_WEB_URL` 等 `DSH_*` 变量**。对 Playwright MCP 本身无影响
> （它不需要密钥），但如果将来接需要 API key 的 MCP server，必须显式写进 `env:` 才能穿透。

### 1.4 profile / patch 机制（来自 `dsh-app-boot` 与启动器 `profile-boot-Dk-7KqJc.js`）

**分层顺序**（`apps/cli/lib/profile-boot-Dk-7KqJc.js` L74–79 注释 + `dsh-app-boot/lib/types/profile.d.ts` L7–13）：

```
空根 []  →  dsh.profile.bundles 中每个 bundle 的 patch（按数组顺序）
         →  profile 自己的 cordis.patch.yml
         →  --patch 叠加文件（argv 顺序）
         →  启动器旗标派生的 patch（如 telemetry 开关）
```

- 根配置文件是 `cordis.yml`（`PROFILE_ROOT_FILENAME`），**注释明确写"Edit cordis.patch.yml, not this file"**
- **home 级 patch 也存在**：`$DSH_HOME/cordis.patch.yml`（`homePatchPath()`，`profile-boot` L116–118），
  **应用在所有 profile 之上**。本机 **不存在**，未被创建。
- `patchReload: live` = 启动后 **watch** patch 文件并热重载（`watchUserPatches`）；`startup` = 只应用一次。

**patch 条目的真实语义**（`cordis-plugin-include/lib/index.js` L57–103，即 `applyEntryPatches`）：

```yaml
- insert: [ ...EntryOptions ]     # 无 id → 追加到根条目列表
- id: <targetId>                  # 有 id → 定位既有条目
  config: {...}                   #   整体替换该条目的 config（不合并！）
  disabled: true                  #   禁用该条目
  name: <expected>                #   可选校验，不匹配则警告并跳过
- id: <groupEntryId>
  insert: [ ... ]                 # 目标必须是 group:true，否则警告跳过
```

要点：
1. **`insert` 不带 `id` 就是追加到根列表** —— 这正是加 MCP 条目该用的形式。
2. **patch 的 `config` 是整体替换，不是深合并**（`dsh-base/cordis.patch.yml` L6–9 明说）。
3. 命中失败只 **warn 并跳过**，不会让启动失败 —— 意味着**打错 id/字段可能静默不生效**。
4. 输入永不被 mutate（`structuredClone`），后续 patch 可以命中前面 patch 插入的条目。

**根条目形状**（`dsh-base/cordis.patch.yml` L15–22 为权威范例）：
```yaml
- insert:
    - id: timer
      name: '@deepseek-ai/cordis-plugin-timer'
```
即根条目 = `{ id, name, config?, disabled?, ... }`，`name` 为包名，**在 profile 目录下解析**。

### 1.5 「MCP 工具会不会真的被 agent 看见」——已验证，是**会的**，且是**全局**

这是本次研究里最关键的集成问题，已从源码确认：

- `dsh-web-app/cordis.patch.yml` L393–400 给出 registry 的权威形状描述：
  > *"It is host+per-scope layered (the tools-registry shape): deployment-level providers …
  > register into its **global layer**, while a preset's … registers into that **preset's layer**,
  > and each agent reads the **merged** catalog its scope chain selects."*
- `dsh-tools/lib/index.js` L2767–2782：`register(definition)` →
  `this.layers.effect(this.ctx, layer => layer.tools.insert(name, definition), …)`
  —— **注册层由调用者 `ctx` 的 scope 决定**。
- `dsh-scope/lib/types/store.d.ts` L96–133：`ScopedLayers` 拥有 **`global`** 层与 exact-scope 覆盖层；
  `chainLayers(scope)` 返回 scope 的祖先链；`merge(scope, pick)` = **global 具名条目 + scope 链影子**。
- L2564（dsh-tools）注释：*"Scoped registrations shadow globals"*。

**推论（高置信）**：在 **profile 根**（无 scope）插入 `dsh-mcp-client`，其 `ctx.tools.register()`
落在 **global 层**，因此 **`standard` preset 的 agent 会自动看到 `mcp__<serverName>__*` 工具，
无需新增/复制 preset**。这与背景资料里"直接 insert 即可"的做法一致 —— 现在有源码支撑。

**副作用（必须知情）**：工具进的是 **global 层，不是某个 preset 的层**。
在这个 profile 里**所有 preset**（`minimal` / `standard` / `ptc` / `cordis`）的 agent
都会看到这些 MCP 工具。若将来只想给特定 agent 开放浏览器能力，**global insert 做不到**，
需要改走 `$DSH_HOME/.agent-presets`（`includeUserRoot`，见 web-app patch L473–479）
自建 preset 并在其中挂载。

### 1.6 与背景资料的**差异**（我做了独立验证，结论是"字段没变，但语义要说清"）

| 背景资料 | 实际验证结果 |
|---|---|
| `insert:` + `id` + `name` + `config` 形式 | ✅ 正确，且是 `dsh-base` 自己在用的形式 |
| `transport: stdio`，`command: npx`，`args: [...]` | ✅ 字段名与类型全部一致（`command` 为**必需**） |
| `serverName` | ✅ 存在，且是**必需** + 正则约束 `[A-Za-z0-9_-]{1,32}` |
| 远程用 `streamable-http` + `url` | ✅ 正确，另有 `headers`（默认 `{}`） |
| （未提及） | ⚠️ `reconnect` 子配置**未知字段会抛错**；`env` 会被消毒；`config` 是**整体替换**非合并 |

**没有发现字段被删除或改名。** 唯一需要纠正的认知是：`config` 在 patch 里是整块替换，
所以不要试图"局部覆盖"一个既有条目的 config。

### 1.7 pnpm 问题的定性 —— **与 MCP 接入无关，不阻塞后续实验**

源码链路（`apps/cli/lib/plugin-Ddi42qoW.js`）：

- L105–124：`dsh plugin` 是**薄转发器** —— `spawnSync("pnpm", args, { cwd: profileDir })`
- L116：spawn 失败时打印 `pnpm not found on PATH — install pnpm to manage profile plugins`
- L124：pnpm 执行返回非 0 时打印 `pnpm failed in profile directory <dir>` ← **你看到的就是这条**

**结论：**
1. `dsh plugin *` 的**唯一职责**是管理 profile 的 **npm 依赖 / bundles**（`reconcilePlugins` 会改写
   `package.json` 的 `dsh.profile.bundles`）。它是 **pnpm 转发器**，不参与运行时的插件挂载。
2. **MCP server 不经由 `dsh plugin` 配置**。MCP 是 profile patch 层里的一个**配置条目**，
   由 `dsh-mcp-client` 在运行时读取。两者是完全不同的层。
3. 因此 **pnpm 缺失 → 不阻塞 MCP 接入**。
4. **那 244 个 `@deepseek-ai/*` 包是怎么来的？** 不需要 pnpm —— 启动器有自动修复机制：
   `healProfilesModuleFallback()`（`dsh-app-boot/lib/index.js` L657–676）会
   `mkdir -p ~/.dsh/profiles/node_modules`，再按 DSH 安装的依赖闭包
   **自动建立 symlink / proxy**。所以**每次 DSH 启动都会自愈**这套模块回退目录。

> **pnpm 唯一可能被需要的场景**：如果以后要把某个 MCP server 作为**独立 npm 包**装进 profile
> （需要 `dsh plugin add <pkg>`）。但 `@playwright/mcp` 我们**不需要**这样做：它由 `npx` 在
> stdio 子进程里按需解析，完全绕开 `dsh plugin` 与 pnpm。

### 1.8 Playwright MCP 现状（仅元数据查询，未安装）

`npm view @playwright/mcp`（**只读 registry 查询**）：

| 项 | 值 |
|---|---|
| 最新版本 | `0.0.80` |
| `engines` | `node >= 18` ← 本机 v24.20.0，**满足** |
| `dependencies` | `playwright@1.63.0-alpha-2026-08-31`、`playwright-core@1.63.0-alpha-2026-08-31` |
| `bin` | `playwright-mcp` → `cli.js` |

**关于"是否会被迫下载浏览器"—— 已查证 `scripts`，两者均为空：**

- `npm view playwright@1.63.0-alpha-2026-08-31 scripts` → **无输出（无 install/postinstall）**
- `npm view playwright-core@... scripts` → **无输出**

即 **`npm i` / `npx` 不会自动下载 Chromium**；浏览器下载只在显式执行
`playwright install` 时发生。`playwright` 包本体只含 CLI 与下载器逻辑。

这与上一阶段实验的发现相印证：`@playwright/mcp` 支持
`--browser=chrome|msedge` 与 `--cdp-endpoint=<url|channel>`，可复用**本机已装**的
Chrome 153 / Edge 152（两者均已实测可被 CDP 驱动）。

**npm 缓存现状**：`npm cache ls @playwright/mcp` 只命中
`make-fetch-happen:request-cache:https://registry.npmjs.org/@playwright%2fmcp`
（**仅 registry 元数据**，被 `npm view` 写入）。**tarball 未缓存** → 首次 `npx` 需联网。

### 1.9 现有 profile 未被污染（基线快照）

| 目标 | 状态 |
|---|---|
| `~/.dsh/profiles/web/package.json` | 原样（bundles = base + web-app，`patchReload: live`） |
| `~/.dsh/profiles/web/cordis.patch.yml` | 原样（仅注释 + `[]`） |
| `~/.dsh/cordis.patch.yml`（home 级） | **不存在** |
| `~/.dsh/profiles/browser-lab`（拟建实验 profile） | **不存在** |
| `D:\Projects\Personal Job Search OS` git status | **CLEAN（零改动）** |

---

## 2. INFERENCE

1. **链路的每一环都已被本地证据覆盖，技术上没有阻断点**：
   `dsh-mcp-client` 已装且 SDK v1.30.0 就位 → 配置 schema 明确 → 挂载点（profile 根 insert）明确
   → 工具可见性机制（global 层 + scope 链 merge）已确认 → Playwright MCP 版本与 Node 要求满足
   → 本机 Chrome/Edge 上一阶段已实测可被 CDP 驱动且不触发风控。

2. **最省事的落地形态是 stdio**：`transport: stdio` + `command: npx` +
   `args: ['-y','@playwright/mcp@latest', ...]`。不需要 pnpm、不需要装包进 profile、
   不需要长期后台服务 —— MCP server 的存活期 = DSH 进程的子进程存活期，由
   `reconnect`（默认 10 次、0.5s 起指数退避到 30s）自动兜底。

3. **首次启动需要联网**（tarball 未缓存）。这会把"离线可复现性"变成实验的一个变量：
   建议第一次 `npx` 预热时把行为与耗时单独记录，避免日后把它误读为"DSH 挂了"。

4. **DSH 的 stdio env 消毒对本次实验无影响**，但**必须在文档里写下来**，
   否则将来接需要 token 的 MCP server 时会踩坑（子进程里 `*_TOKEN`/`*_KEY` 全空）。

5. **pnpm 与 MCP 是两条正交的路**。我判断你看到的报错会**持续存在**（加 profile 也一样，
   因为这是全局缺 pnpm），但**不会阻塞 MCP**。它只影响 `dsh plugin` 家族命令。

6. **工具是全局可见的**，这在实验阶段是**优点**（不用碰 preset，改动面最小），
   但在"长期 Discovery"阶段可能变成**缺点**（每个 preset 的 agent 都被塞进一堆
   Playwright 工具的 schema token）。这是将来需要重新决策的点。

---

## 3. UNKNOWN

以下必须在下一阶段**实测**，我不做假设：

1. **`npx -y @playwright/mcp@latest` 在本机网络下的首次行为**：能否解析、耗时、
   是否真的不触发浏览器下载（`scripts` 为空是强证据，但 `npx` 路径未实测）。
2. **Playwright MCP 在 stdio 下的启动握手是否会被 env 消毒影响**：理论上不需要密钥，
   但未实测（例如它是否依赖 `HOME`/`USERPROFILE` 定位缓存目录）。
3. **工具实际注册后的名字形态**：`mcp__<serverName>__<rawName>` 的 raw 名与总数未知
   （Playwright MCP 暴露的工具集与其 schema 体积会直接影响每次请求的 token）。
4. **`--browser=chrome` / `--cdp-endpoint` 参数在本机是否真能复用系统 Chrome**
   （避免 Chromium 下载）。上一阶段验证了 CDP 可驱动本机 Chrome，但**未经由 Playwright MCP 验证**。
5. **是否需要 `--headless`**，以及有头/无头对风控与渲染的差异（上一阶段全部 headless）。
6. **新建 profile 的模块解析**：新 profile 的 `node_modules` 回退是否与 `web` 完全等价
   （`healProfilesModuleFallback` 会自愈，但未实测 `browser-lab` 场景）。
7. **MCP 工具与 fs/sandbox/approval 栈的交互**：浏览器工具是否有权限门槛
   （`dsh-user-approval` 在本 session 已禁用，行为未查）。
8. **`mcp-client` 是否导出 profile bundle patch**（若导出，才可能走 `dsh plugin` 路径）。
   目前判断：**不导出**（它是 plugin，不是 bundle；`dsh-base` 里也没有它的条目）——待最终确认。
9. **多 profile 并存时 global 层的隔离性**：不同 profile 是两个独立 DSH 进程，
   理应互不影响，但未实测。

---

## 4. 推荐的最小实验方案

**目标**：用**最小改动面**打通 `DSH → dsh-mcp-client → Playwright MCP → 本机 Chrome`，
且**完全不触碰默认 web profile**（因为当前这个 GUI 就跑在它上面）。

### 方案 A（推荐）：专用实验 profile + stdio + 复用本机 Chrome

**步骤 1 — 建独立实验 profile（不改 web）**
```
dsh --profile browser-lab --from-default-profile web
```
副作用：仅新建 `~/.dsh/profiles/browser-lab/{package.json,cordis.yml,cordis.patch.yml}`。
不碰 web profile。官方机制：`PROFILE_TEMPLATES.web = { bundles: [base, web-app], patchReload: 'live' }`。

**步骤 2 — 在该 profile 的 patch 里加一个 MCP 条目**（形状已由 §1.2 / §1.4 确定）
```yaml
- insert:
    - id: mcp-playwright
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: browser
        transport: stdio
        command: npx
        args:
          - '-y'
          - '@playwright/mcp@latest'
          - '--browser=chrome'      # 复用本机 Chrome，避免下载 Chromium
          - '--headless'
        failOnStartupError: true     # 让启动失败变响，而不是静默少工具
```
`failOnStartupError: true` 是**有意的**：默认 `false` 会"启动成功但没有工具"，
在 smoke test 阶段这是最难排查的失败模式。

**步骤 3 — 先离线校验组合，再真正启动**
```
dsh --profile browser-lab --dump-config
```
这一步**不启动 app、不 spawn MCP server**，只把 patch 层合成后打印。
用于确认：条目进了根列表、`name` 能解析、没有 warn 被静默跳过。

**步骤 4 — 启动并观察**
```
dsh --profile browser-lab web --port <另一个端口>
```
（**不要复用现有 3080**，避免与当前 GUI 冲突。）
预期：启动日志出现 MCP server 连接与工具同步；工具列表出现 `mcp__browser__*`。
用一个**只读**动作做 smoke test（例如导航到 `about:blank` 或读取页面标题），
**第一轮不要碰目标招聘站**，把"协议是否通"和"网站是否配合"分成两个变量。

**步骤 5 — 通过后再做目标站验证**（沿用上一阶段只读纪律）。

### 方案 B（备选）：`--patch` 一次性叠加，完全不落盘 profile

```
dsh --profile web --patch D:\Projects\dsh-test\mcp-browser.patch.yml
```
优点：零持久化改动。
**但我不推荐作为首选**，因为 `--profile web` 意味着**在默认 profile 上叠加**，
而"不修改默认 web profile"是你的明确边界 —— 虽然 `--patch` 不改文件，
但它改变的是**默认 profile 的实际运行组合**，语义上仍属灰色地带。
若你批准，它是最轻的路径；若不批准，走方案 A。

### 明确不推荐的两条路

- **home 级 patch**（`~/.dsh/cordis.patch.yml`，当前不存在）：它**作用于所有 profile**，
  且 `patchReload: live` 会热重载 → **会影响你正在用的这个 GUI 会话**。风险最高，不采用。
- **`dsh plugin add @playwright/mcp`**：会引入 pnpm 依赖，而且**方向错了** ——
  Playwright MCP 是 MCP **server**，不是 DSH **plugin**，不属于 `dsh.profile.bundles`。

---

## 5. 需要修改的文件：准确路径 + 原因（**尚未修改，等批准**）

| # | 路径 | 操作 | 原因 | 是否影响现有 GUI |
|---|---|---|---|---|
| 1 | `C:\Users\user02\.dsh\profiles\browser-lab\`（整个目录） | **新建**（由 `--from-default-profile` 生成） | 实验隔离容器；新 profile 与 web 完全独立 | **否** |
| 2 | `C:\Users\user02\.dsh\profiles\browser-lab\cordis.patch.yml` | 写入 §4 的 `insert` 条目 | 唯一能挂载 MCP client 实例的位置（§1.4 的 patch 层） | **否** |
| 3 | `D:\Projects\dsh-test\` 下的实验记录文件 | **新建** | 保存 dump-config 输出、启动日志、工具清单 | **否** |

**明确不修改**：
- `C:\Users\user02\.dsh\profiles\web\*`（默认 web profile，当前 GUI 正在使用）
- `C:\Users\user02\.dsh\cordis.patch.yml`（home 级，会波及所有 profile）
- `D:\Projects\Personal Job Search OS`（**不碰**，git 保持 CLEAN）
- 系统环境变量、现有 session / storage

---

## 6. 是否需要 pnpm？—— **不需要**

**结论：本方案的 MCP 接入完全不需要 pnpm，且 pnpm 缺失不构成阻塞。**

理由（每条都有源码依据）：

1. **`dsh plugin` 才是 pnpm 的唯一消费者**，而它只管 profile 的 npm 依赖/bundles
   （`plugin-Ddi42qoW.js` L109 `spawnSync("pnpm", ...)`，L124 报错文本与你看到的一致）。
2. **MCP server 是 profile patch 里的一个配置条目**，由 `dsh-mcp-client` 在**运行时**读取，
   与 `dsh plugin` / `package.json.dependencies` 无关。
3. **`@playwright/mcp` 由 `npx` 在 stdio 子进程内按需解析**，不装进 profile，
   因此绕开 pnpm 与 `dsh plugin` 整条路径。
4. **连那 244 个 `@deepseek-ai/*` 包都不需要 pnpm** —— 启动器
   `healProfilesModuleFallback()` 会自动建 symlink/proxy 回退目录。
5. 官方 README 也把 `dsh plugin` 定位为 *"manage a profile's plugins by forwarding … to pnpm"*，
   是**插件依赖管理**用途，不是运行前置条件。

**pnpm 会在什么时候才成为必要条件？**
仅当我们要把某个 MCP server 或插件作为**独立 npm 包安装进 profile**
（`dsh plugin --profile X add <pkg>`）时才需要。**当前方案不触发这个条件。**

---

## 7. 安全边界自查

| 边界 | 状态 |
|---|---|
| 未修改 Personal Job Search OS | ✅ `git status --porcelain` 为空（CLEAN） |
| 未修改默认 web profile | ✅ `package.json` / `cordis.patch.yml` 均原样 |
| 未删除 session / storage | ✅ |
| 未安装 Playwright MCP | ✅ 仅 `npm view`（只读 registry 查询） |
| 未安装 pnpm | ✅ |
| 未修改系统环境变量 | ✅ |
| 未绕过任何网站安全机制 | ✅ 本阶段未访问任何网站 |
| 仅只读调查 + 本报告文件 | ✅ 本文件为唯一落盘产物 |

---

## 8. 下一步建议（**等你批准后再执行**）

1. **先批准方案 A 的步骤 1–3**（建 profile → 写 patch → `--dump-config` 离线校验）。
   这三步**不联网、不 spawn MCP、不启动 app**，风险最低，却能验证 90% 的配置正确性。
2. **步骤 4（首次 `npx`）前确认联网可用**，并预期一次下载 + 可能的启动延迟；
   若失败，先区分是"网络/包解析"还是"MCP 协议"问题。
3. **批准后我再动手**；同时请确认**用另一个端口**启动实验 profile 是否可以（避免与 3080 冲突）。
4. 若要保留"只给特定 agent 浏览器能力"的可能性，请提前告知 —— 那需要改走
   `$DSH_HOME/.agent-presets` 自建 preset，而不是 root insert（见 §1.5）。

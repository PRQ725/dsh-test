# 07 — Profile / Bundle 隔离（归属、写入面与共享层）

> 长期知识文档。回答"**bundle 到底属于谁**"这一类问题。
> 相关：`01-host-composition.md`（composition 机制本身）、`06-dsh-runtime-and-multiprocess.md`（多进程/持久层）、`00-dsh-local-filesystem.md`（路径事实）。
> 执行细节留在 `../experiments/profile-isolation/`。

---

## 0. 本文回答的问题

| 问题 | 去哪 |
|---|---|
| 某个第三方 bundle 属于哪个 profile？ | §2、§3 |
| `dsh plugin --profile X add <pkg>` 到底写了哪些文件？ | §3 |
| profile 之间会不会继承？ | §4 |
| "磁盘上装了这个包" 等于 "这个 profile 挂了这个 bundle" 吗？ | §5 |
| 有哪些**跨 profile 共享层**会破坏隔离？ | §6 |
| 怎么证明隔离（证据等级怎么分）？ | §7 |

---

## 1. 三个必须分开的概念

| 概念 | 载体 | 作用 |
|---|---|---|
| **Profile** | `$DSH_HOME/profiles/<name>/` | 一个独立的组合容器；**每个 DSH 进程只加载一个** |
| **Bundle** | 声明了 `dsh.bundle.patch` 的 npm 包 | 一层 patch |
| **Bundle membership** | `<profile>/package.json` → `dsh.profile.bundles` | **唯一** 决定"这个 profile 有哪些 layer"的地方 |

> **package 存在于磁盘** 与 **bundle 被某个 profile 挂载** 是**两个独立事实**。见 §5。

---

## 2. 归属的唯一权威来源 [FACT]

`<profile>/package.json`：

```json
{
  "name": "dsh-profile-browser-lab",
  "private": true,
  "dependencies": { "dsh-whale-widget": "^0.3.0" },
  "dsh": { "profile": {
    "bundles": ["@deepseek-ai/dsh-base", "@deepseek-ai/dsh-web-app", "dsh-whale-widget"],
    "patchReload": "live"
  } }
}
```

- **`dsh.profile.bundles` 是 layer 列表**（顺序 = patch 应用顺序）。
- `dependencies` 只是 npm 依赖，**不**决定 layer；但 `dsh plugin` 会用它来 reconcile bundles。
- 列出 bundle 但该包没有 `dsh.bundle` → **fail loud**（源码 `loadProfileDirectory`：`profile bundle … declares no dsh.bundle in its package.json`）。这是误配置，不是"没有补丁"。

**解析锚点顺序**（`resolveBundleDir`）：**先 dsh 安装锚点，后 profile 目录**。
⇒ 契约：in-box bundle（如 `dsh-base`）**永远**来自运行中的 dsh 安装，不会被 profile 本地副本顶替。

> ### ★ 两个必须补上的前提（2026-09-24 增补）
>
> 1. **"安装锚点"是一个依赖树，不是一个单 package。** 顶层版本正确**不保证**树自洽。
>    树的一致性与物理 `node_modules` 布局由 **npm** 负责，**不由 profile 模型保证**。
>    ⇒ 本节只解决"**去哪找**"，不保证"**找得到**"。
> 2. 因此 **"从安装解析" ≠ "必然可用"**。安装层损坏时，报错会从 Cordis Loader 冒出来
>    （`plugin tree failed to load: … could not be resolved`），但**根因层是安装 / 依赖图**，不是 profile、也不是 Cordis。
>
> 分层模型与升级语义 → **`08-dsh-installation-and-upgrade.md`**（§2 三层解析模型、§4 回滚语义）。
> 实证：2026-09-23 全局升级事故 —— `../experiments/dsh-install/2026-09-23-dsh-global-upgrade-rc1-to-rc3-incident.md`。

---

## 3. `dsh plugin --profile <name> add <bundle>` 的写入面 [FACT，源码]

实现：`…/@deepseek-ai/dsh/lib/plugin-Ddi42qoW.js`（`runPlugin`）。

```js
const dir = resolveProfileDir(profile);                  // $DSH_HOME/profiles/<profile>
if (!existsSync(dir/package.json)) initProfile(dir, …);  // 首次使用才初始化
spawnSync("pnpm", args, { cwd: dir, … });                // pnpm 在【该 profile 目录】内运行
if (exitCode === 0) reconcilePlugins(before, dir);       // 只回写【该 profile 的】package.json
```

**该命令改动的文件（全部在目标 profile 目录内）**：

| 文件 | 何时 |
|---|---|
| `<profile>/package.json` | 总是（pnpm 写 dependencies；`reconcilePlugins` 写 `dsh.profile.bundles`） |
| `<profile>/pnpm-lock.yaml` | 首次安装时新建 |
| `<profile>/pnpm-workspace.yaml` | 仅在 pnpm 需要写 profile 级配置时（如 supply-chain `minimumReleaseAgeExclude`） |
| `<profile>/node_modules/` | pnpm 安装落点（`nodeLinker: hoisted` ⇒ 提升到 profile 的 `node_modules`） |

**该命令不会改动**：其他 profile、`$DSH_HOME` 根、`$DSH_HOME/profiles/node_modules`（共享 fallback）。
⇒ **[FACT] `dsh plugin --profile X add <bundle>` 修改的是 X 的 dependency / bundle membership，且只修改 X。**

### 3.1 membership 何时被写入 [FACT]

`reconcilePlugins()` 按**安装后的真实解析状态**判定，而非按命令行 spec：

```js
const isBundle = exportsPatch(packageName, profileDir);   // resolveBundleDir + 包内 dsh.bundle.patch !== undefined
if (isBundle && !plugins.includes(packageName)) plugins.push(packageName);
else if (!isBundle) warn("… declares no dsh.bundle — installed as a plain dependency, not a profile layer");
// 反向：曾经是 dependency 且已不再是 bundle → 从 plugins 移除
```

- 因此 `github:` / `file:` / `link:` / 别名 spec 都能按**真实包名**回收。
- 非 bundle 依赖**不会**成为 layer（只打 warning）。
- 出厂模板自带的 in-box bundle 不是 dependency，**永不被此逻辑触碰**。

### 3.2 `--dump-config` 是写操作 [FACT]

`--dump-config` → `prepareProfile()` → **无条件 `writeFileSync(<profile>/cordis.yml, PROFILE_ROOT_CONFIG)`**，且必须**新起一个进程**。
⇒ 想采一份离线 dump，**无法避免**重写目标 profile 的 `cordis.yml`（内容恒为常量 `[]` + 注释，但 **mtime 会变**）。
**live 确认（两次）**：`browser-lab/cordis.yml` 的 mtime 精确等于两次 DSH 进程启动时刻（`2026-09-15 13:34:43` / `20:42:38`）。

---

## 4. Profile 之间**不存在**继承 [FACT]

- 源码注释（`initializeProfileFromDefault`）原文：
  > "This copies only the template's bundle list and patch-reload policy; local state from the same-named shipped profile is not read, and **no inheritance metadata is persisted**."
- `loadProfileDirectory` / `loadProfile` 全程**只读单个** profile 目录，不引用任何其他 profile。
- 出厂模板只有 `acp / web / headless / sdk / sdk-minimal`（`PROFILE_TEMPLATES`）。
  - 自定义 profile（如 `browser-lab`）由 `dsh plugin` 以 `DEFAULT_PROFILE_BUNDLES = ["@deepseek-ai/dsh-base"]` 初始化。
  - **`--from-default-profile <t>` 只是"复制一次出厂模板的 bundle 列表"，不是持续继承。**

**推论 [INFERENCE]**：`browser-lab` 拥有 Web UI 能力，是因为它**自己**声明了 `dsh-web-app`，**不是**因为"继承了 `web`"。
（判据：两者 `dsh.profile.bundles` 相同，但这是各自独立声明的结果 —— `browser-lab` 不在 `PROFILE_TEMPLATES` 中。）

**归一化边界** [FACT]：`normalizeShippedProfile()` 只对**出厂模板名**且 bundle 列表**恰好等于**出厂元组时回写 `package.json`。
一旦加入第三方 bundle，列表即变为 **user-owned**，DSH **不再自动改写**它（⇒ 升级 DSH 也不会帮你清理已加进去的 bundle）。

---

## 5. package 可解析 ≠ bundle mounted（核心区分）

| 状态 | 判据 | 后果 |
|---|---|---|
| **package 可解析** | `<somewhere>/node_modules/<pkg>/package.json` 存在 | 仅"能 import" |
| **bundle mounted** | `<profile>/package.json` → `dsh.profile.bundles` 含 `<pkg>` | 其 patch 进入合成树 |

- **只有后者会让 entry 出现在合成树里。** [FACT，源码 `loadProfileDirectory`]
- 具体地说：磁盘存在性**不产生 layer**；`--dump-config` 的 entry 列表**不是** `dsh.profile.bundles`。
- 常见误读：
  - ❌ "`profiles/node_modules` 里能解析到 X ⇒ 某 profile 挂了 X"
  - ❌ "`dsh --profile web --dump-config` 里看到 X ⇒ `web` 的 bundles 里有 X"（dump 是**合成 entry 列表**）
  - ✅ "`<profile>/package.json` 的 `dsh.profile.bundles` 含 X ⇒ X 是 X 的 layer"（但**归属仍在该 profile**）

### 5.1 真实数据示例（`dsh-whale-widget@0.3.0`）[FACT]

| 观测量 | 值 |
|---|---|
| `browser-lab/node_modules/dsh-whale-widget/` 存在 | ✅ |
| `browser-lab/package.json` bundles 含 `dsh-whale-widget` | ✅ |
| `web/package.json` bundles 含 `dsh-whale-widget` | ❌ |
| `web/node_modules/` | 空目录 |
| `profiles/node_modules/dsh-whale-widget` | ❌ 不存在 |

两个 ✅ 恰好同时为真，所以**必须分开陈述**；若只有第一个 ✅，合成树里**不会有** whale 的 entry。

---

## 6. 跨 profile 共享层清单（隔离的边界）

| # | 路径 / 机制 | 是否跨 profile | 能否破坏 bundle 隔离 | 状态（2026-09-15 核对） |
|---|---|---|---|---|
| 1 | `$DSH_HOME/cordis.patch.yml`（home 补丁层） | **是（所有 profile）** | **⚠️ 能 —— 唯一真实泄漏通道** | **不存在** |
| 2 | `--patch <file>` / `--patch` overlay | 是（该次启动） | 能（显式） | 未使用 |
| 3 | `$DSH_HOME/profiles/node_modules/`（共享 module fallback） | 是 | **不能**（只影响可解析性） | 存在，**不含** whale |
| 4 | `$DSH_HOME` 根级运行时状态（`settings.yaml`、`.credentials.yaml`、`storages/`、`sessions/`、`AGENTS.md`） | 是 | 否（非 bundle 层） | — |
| 5 | 插件自定义的 HOME 级状态（如 whale 的 `.dshw-*.json`、`whale-*/`） | **是** | 否（但会**共享状态**） | 已存在（本轮产生） |
| 6 | 默认端口（`dsh-web-app`: `port: !!js ctx.webStartup.port ?? 3080`） | 是（机器级） | 否（但两个 profile 抢同一端口） | 3080 被 browser-lab 占用 |
| 7 | 环境变量（`DSH_TELEMETRY_DISABLED` 等 `!!js` 输入） | 是（进程级） | 影响合成结果本身 | 未固定 |

### 6.1 `$DSH_HOME/cordis.patch.yml` 为什么是唯一真通道 [FACT，源码]

`composeProfile()` 的 patch 栈顺序：

```
bundlePatches  →  profile.patches  →  homePatches  →  overlays(--patch)
                                        ↑
                        源码注释：machine-local preferences that apply to
                        EVERY profile, so it outranks the per-profile layer
```

- 它被 `watchUserPatches` **热监视** ⇒ 改文件对所有已加载 profile 生效。
- 因此：把 `insert` 写进这里 ⇒ **所有 profile 都会拿到**，与"profile-local install"是**两个不同概念**。
- **它当前不存在**（2026-09-15 两次核对均为 `Test-Path` = False）。

### 6.2 `profiles/node_modules/` 为什么不算泄漏 [FACT，源码]

- 由 `healProfilesModuleFallback()` 维护；源码注释：*"The shared `$DSH_HOME/profiles/node_modules` **mirrors the dsh installation dependency closure**."*
- 实测：内容全部是指向 dsh 安装目录的 **Junction**（`dsh`、`dsh-base`、`dsh-web-app` …）⇒ 它是**安装依赖闭包**的镜像，不是用户插件的落点。
- 每个 profile 另有**私有**的 `<profile>/.dsh-module-fallback/node_modules`，软链进 `<profile>/node_modules`；源码注释：*"pnpm-managed entries remain authoritative, and **another profile's links cannot change its resolution**."*
- 实测：`dsh plugin` 装 whale 后，该共享目录**仍不含 whale**。

#### ★ 它会**跟随当前安装被重建**（2026-09-23 实证）[FACT]

- `healProfilesModuleFallback()` 在 **profile 启动时**自愈维护该目录，junction 目标指向**当前**安装。
- **实证**：rc.3 安装完成于 `2026-09-23 13:11:25`，而该目录 `LastWriteTime = 13:27:45`（**晚约 16 分钟**，即首次 boot 时被重建）。
- 重建后它包含 `dsh-sandbox-local`（指向新安装），但**仍不含** `dsh-whale-widget`。
- ⚠️ 与 §6.1 的唯一泄漏通道**区分开**：`$DSH_HOME/cordis.patch.yml` 改的是**归属**（会真的把 bundle 注入所有 profile）；
  本目录改的只是**可解析性**。

> 详见 `08-dsh-installation-and-upgrade.md` §9。

---

## 7. 归属纪律（写证据时必须遵守）

| 证据类别 | 能证明什么 | 不能证明什么 |
|---|---|---|
| **文件证据**（`package.json` / lockfile / 哈希） | bundle membership、range vs lock 版本 | 运行时是否 apply |
| **命令输出证据**（`dsh plugin` 的 stdout） | 安装动作成功、解析到的版本 | 最终落盘状态（须再读文件核对） |
| **人工 UI 观察** | 最终用户可见效果 | 中间链路 |
| **runtime 证据**（HTTP 状态码、插件写入的状态文件） | 插件**已 apply 并对外服务** | Cordis entry 启动 / `inject` 解析的**过程** |
| **源码支持的强推论** | 机制解释 | 不得伪装成新的 runtime trace |

**三条硬规则**：

1. **不得**把"磁盘上能解析到包"写成"某 profile 拥有该 bundle"。
2. **不得**把 `--dump-config` 的 entry 列表写成 `dsh.profile.bundles`。
3. **不得**把浏览器信任栅栏返回的 **401/403** 写成"插件失败"；也不得把 **404** 与 **401** 混为一谈 ——
   实测：**未注册路径 → 404，已注册路径 → 401**，因此 401/404 **可用于判定路由是否注册**。

---

## 8. 已确认结论速查

### [FACT]

- `dsh plugin --profile <name> add <bundle>` 只修改**目标 profile** 的 dependency 与 `dsh.profile.bundles`；写入面限于 `$DSH_HOME/profiles/<name>/`。
- `dsh.profile.bundles` 是 layer 的**唯一**输入；bundle 解析顺序为「安装锚点 → profile 目录」。
- **package 可解析** 与 **bundle mounted** 是两个独立概念；只有后者进合成树。
- **profile 之间不存在继承**（无继承元数据；加载只读单个目录）。
- 自定义 profile 的默认 bundles 是 `["@deepseek-ai/dsh-base"]`（**不含** `dsh-web-app`）。
- `--dump-config` 是无条件重写 `<profile>/cordis.yml` 的**写操作**，且需要新进程。
- `$DSH_HOME/cordis.patch.yml` 是**跨 profile** 层且 **outranks** profile 层；它当前不存在。
- `$DSH_HOME/profiles/node_modules` 只镜像**安装依赖闭包**，且"另一个 profile 的链接不能改变本 profile 的解析"。
- `browser-lab` 与 `web` 是**两个独立 profile**，bundle 列表各自独立声明。
- **`browser-lab` 可独立安装并运行第三方 bundle**（实例：`dsh-whale-widget@0.3.0`，E2E PASS）。
- **"安装锚点"解析的是一个依赖树**；其内部一致性由 **npm** 保证，**不由 profile 模型保证**（见 §2 增补）。
- **global DSH installation 被整体替换 ≠ profile-local bundle membership 消失**（2026-09-23 全局升级事故实证：全局安装换成 rc.3 后，`browser-lab` 的 whale 归属与运行状态均存活）。
- `$DSH_HOME/profiles/node_modules` 会在 **profile boot 时被 DSH 重建**并重新指向当前安装；这只改变**可解析性**，不改变**归属**。

> **本文不覆盖**：全局安装形态、npm 依赖图、升级 / 回滚语义 → 见 **`08-dsh-installation-and-upgrade.md`**。

### [INFERENCE]

- 装进 profile A 的 bundle **不会**出现在 profile B 的合成树（由"无继承 + 写入面唯一"推出；已由 browser-lab→web 单向实践支持）。
- `web` profile 自其 `cordis.yml` mtime（2026-09-12 16:18:42）起未被 boot 过。

### [UNKNOWN]

- 两个 profile 同时挂同一 bundle 时，HOME 级状态文件（`.dshw-*`）的并发写行为。
- 是否值得/能否在非侵入前提下采集 AFTER `--dump-config`（受 §3.2 写操作约束）。

---

## 9. 与 `dsh-whale-widget` 相关的最小事实集

（作为本命题的**已工作实例**保留，避免以后重复研究）

- **bundle 声明**：`package.json` → `dsh: { bundle: { patch: "./cordis.patch.yml" } }`。
- **patch 内容**：单个 `insert`（无 target id）→ 追加到 profile 根 entry 列表：
  ```yaml
  - insert:
      - id: dsh-whale-widget
        name: dsh-whale-widget
  ```
- **运行时依赖**：`inject: ['webServer', 'credentials']`
  - `webServer` ← `dsh-web-app` 的 `id: webserver`（`@deepseek-ai/dsh-host-webserver`）
  - `credentials` ← `dsh-base` 的 `id: credentials`（`@deepseek-ai/dsh-credentials-local`）
  - ⇒ **只有同时含 `dsh-base` + `dsh-web-app` 的 profile 才能满足**（`web` 与 `browser-lab` 都满足）。
- **副作用面**：21 条 `/dsh-whale/*` 路由 + `webServer.tapIndex` 注入 `<script src="/dsh-whale/widget.js">`；状态写在 `$DSH_HOME` **根**（`.dshw-*.json`、`whale-roles/`、`whale-audio/`、`whale-bubble-imgs/`）。
- **安装**：`dsh plugin --profile <name> add dsh-whale-widget[@version]`；需要 pnpm。
- **实测安装版本**：`0.3.0`（dependency range `^0.3.0`）。

---

## Evidence

| 主题 | 来源 |
|---|---|
| 归属写入面 / read 面 / 无继承 的源码 | `…/@deepseek-ai/dsh/lib/plugin-Ddi42qoW.js`、`…/dsh-app-boot/lib/index.js`（L312–398、L640–909）、`…/dsh/lib/profile-boot-Dk-7KqJc.js`（L206–257） |
| read-only 基线与命题判定 | `../experiments/profile-isolation/2026-09-15-whale-widget-profile-isolation-prep.md` |
| 真实安装 + 运行 E2E + web 非成员核对 | `../experiments/profile-isolation/2026-09-15-whale-widget-browser-lab-install-e2e.md` |
| browser-lab patch 层事实 | `../experiments/browser-mcp/2026-09-12-B3.4-mcp-client-mount.md`、`../evidence/config-dumps/browser-lab-composed-tree-AFTER-mcp.yml` |
| 多进程 / 持久层 | `06-dsh-runtime-and-multiprocess.md` |

---

## 10. 官方 Desktop 下的同一条纪律 [0.2.0-specific]

[FACT] 本文的区分（**package presence ≠ mounted bundle**；**shared `node_modules` ≠ profile inheritance**）
对官方 Desktop 同样成立：Desktop 使用**保留 profile 名** `desktop`，与 `browser-lab` / `web` 各自独立。

[FACT] 跨版本实测：Desktop 启动后 `browser-lab` / `web` 的 `package.json` 与 `cordis.patch.yml`
哈希保持不变（见 `../evidence/desktop/runtime/` 各 stage 的 profile / home invariants 段）。

> 详见 `09-dsh-desktop.md` §6。


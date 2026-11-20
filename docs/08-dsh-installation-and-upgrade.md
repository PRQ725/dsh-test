# 08 — DSH 安装与升级（global installation / dependency graph / upgrade 语义）

> 长期知识文档。回答"**DSH 这套程序本身是怎么装上的、升级时什么会变、坏了怎么判断在哪一层**"。
> 相关：`00-dsh-local-filesystem.md`（路径事实）、`07-profile-bundle-isolation.md`（profile-local 归属）、`06-dsh-runtime-and-multiprocess.md`（运行期行为）。
> 事故过程与原始证据留在 `../experiments/dsh-install/` 与 `../evidence/logs/npm/`。

---

## §0 Scope

### 本文回答

| 问题 | 去哪 |
|---|---|
| DSH 全局安装是什么、装在哪、里面有什么 | §1 |
| 一个 bundle 从 npm 到 Cordis 要穿过哪几层？每层谁负责？ | §2（**核心**） |
| 为什么顶层版本一样，装出来的依赖树可能不同？ | §3、§4 |
| 升级 DSH 会不会动到我的 profile / 插件？ | §8 |
| `$DSH_HOME/profiles/node_modules` 是什么、会不会被升级改写？ | §9 |
| `install-scripts blocked` 要不要管？ | §6 |
| 升级前后该核对什么？ | §7 |

### 与相邻文档的边界（不要重复、不要混淆）

| 文档 | 负责 | **不**负责 |
|---|---|---|
| `00` | 概念 ↔ 本机路径；**当前版本的事实源** | 升级语义 |
| `01` / `02` | composition 机制、patch 算子 | 包从哪来 |
| **`08`（本文）** | **全局安装形态、npm 依赖图、模块解析分层、升级/回滚语义** | profile 内 bundle 归属 |
| `07` | **profile-local** bundle membership、`dsh plugin` 写入面、跨 profile 共享层 | npm 全局安装 |
| `06` | 运行期持久层 vs 进程内存、多进程 | 安装生命周期 |

> ⚠️ **两个"install"必须分开说**：
> - **global DSH installation** = `npm install -g @deepseek-ai/dsh` → 装的是**DSH 程序本身**（含 shipped bundle 包）。
> - **profile-local plugin install** = `dsh plugin --profile X add <pkg>` → 装的是**某个 profile 的插件**。
> 二者的目录、写入者、影响范围、失败后果都不同。见 §8。

**当前 DSH 版本以 `00-dsh-local-filesystem.md` 的记录为准**（本文不复述版本号，避免多处漂移）。

---

## §1 Global installation layout

### 1.1 安装根

```
<npm global prefix>\node_modules\@deepseek-ai\dsh\
├─ package.json            ← 顶层 manifest（bin: dsh → lib/bin.js）
├─ lib\*.js                ← CLI 实现（profile-boot / plugin / …）
└─ node_modules\
   └─ @deepseek-ai\        ← ★ shipped sibling 包（230+ 个）
      ├─ dsh-base\
      ├─ dsh-web-app\
      ├─ dsh-app-boot\
      ├─ dsh-sandbox-local\
      ├─ dsh-subprocess-local\
      └─ …（含各自的嵌套 node_modules）
```

本机实测：`C:\Users\user02\AppData\Roaming\npm\node_modules\@deepseek-ai\dsh`。

### 1.2 三类版本来源（不要混为一谈）

| 类别 | 例 | 版本策略 |
|---|---|---|
| **顶层包** | `@deepseek-ai/dsh` | 用户显式请求 |
| **shipped sibling** | `@deepseek-ai/dsh-base`、`dsh-web-app`、`dsh-app-boot`、`dsh-sandbox-local`、`dsh-subprocess-local` … | 由顶层 manifest 声明，通常与顶层同属一个 release line |
| **vendor / 工具包** | `@deepseek-ai/cordis`、`cordis-plugin-*`、`cosmokit`、`schemastery`、`node-addon-system`、`commander`、`js-yaml` | **独立版本线**，有各自的版本号 |

⇒ **[FACT] 一个 DSH 安装里出现多种版本号是正常的**，不能只看"有没有版本不一致"就判断坏了。
判断标准是：**同一 release line 的包是否自洽**（例如 `dsh-*` 家族是否一致），以及**声明与实际是否相符**。

### 1.3 关键认识

> **"运行中的 installation anchor" 是一个依赖树，不是一个单 package。**

DSH 的 bundle 与插件解析都挂在"**运行中的 dsh 安装**"这个锚点上（`docs/07` §2 / §3）。
但那个锚点指向的是一个**树**——顶层包正确**不代表**树自洽。这是本文存在的根本理由。

### 1.4 没有 lockfile

**[FACT]** 全局 npm 安装在 `<npm prefix>\node_modules\` 下**不产生** `package-lock.json`，也**不产生** `.package-lock.json`（本机实测两者均不存在）。

后果：
- 安装结果**不可复现**——同一组命令在不同时间可能装出不同的树。
- **没有本地记录可以还原旧树**。
- ⇒ 升级前若要留档，只能自己记录（§7）。

---

## §2 Three-layer resolution model（本文核心）

从"npm 上有这个包"到"Cordis 里跑起来一个 plugin"，要穿过三层。**每层的责任方不同**：

```
① npm package dependency graph
     责任方：npm（arborist）
     产物：一份"谁要什么版本、最终选中哪个版本"的决议
        │
        ▼
② physical nested node_modules layout
     责任方：npm（写盘）
     产物：磁盘上的目录树 —— 包被放在哪一层 node_modules
        │
        ▼
③ DSH resolution
     责任方：DSH Loader / dsh-app-boot
     - installation anchor 解析（resolveBundleDir 的第一锚点）
     - profile resolution anchor 解析（第二锚点）
     - shipped bundle → dsh.bundle.patch → patch layer
        │
        ▼
④ Cordis runtime
     责任方：Cordis
     产物：plugin activation（apply / inject 满足）
```

### 每层的失效表现

| 层 | 失效时你看到什么 |
|---|---|
| ① 依赖图 | `npm warn ERESOLVE …`、版本错配、树里有不该有的版本 |
| ② 物理布局 | 包**存在但放错层级**；同一包出现多份嵌套副本 |
| ③ DSH 解析 | `dsh: plugin tree failed to load: … could not be resolved` |
| ④ Cordis | `inject` 不满足、plugin 不 apply、服务缺失 |

> **关键**：③ 的报错（"could not be resolved"）**通常说明 ① / ② 已经坏了**。
> Cordis 只是**报错出口**，不是根因层。

### 2.1 与 `docs/07` 的接口

`07` §3 描述的「解析锚点顺序：**先安装锚点 → 后 profile 目录**」是本文 §2 的 ③ 层。
⇒ **[FACT] ③ 层的输入（"安装"）本身是 ①/② 的产物**；因此 **profile 模型无法保证 ①/② 的正确性**。
「in-box bundle 永远来自运行中的 dsh 安装」这句话**仍然成立**，但它隐含的前提是"那个安装自洽"。

---

## §3 Prerelease version drift

### [FACT] 本次事故中观察到的行为

- rc.1 顶层声明 sibling 为 **`^0.1.5-rc.1`**，rc.2 为 **`^0.1.5-rc.2`**。
- 两者**实际解析到 `0.1.5-rc.3`**。
- 同期 rc.1 / rc.2 的 **vendor** 也用 caret，并解析到更高版本：`@deepseek-ai/cordis ^4.0.2 → 4.0.4`、`cordis-plugin-hmr ^1.0.17 → 1.0.19`、`cordis-plugin-include ^1.0.7 → 1.0.9`、`js-yaml ^4.2.0 → 4.3.2`。
- rc.3 的对应声明改为 **exact pin**（`4.0.2` / `1.0.17` / `1.0.7`）。

### [FACT] 两条可复用结论

1. **顶层版本与内部 sibling 版本可以不一致。** "`dsh --version` 显示正确"**不等于**"依赖树正确"。
2. **`npm install -g <pkg>@<version>` 只固定被请求的顶层版本**；其依赖范围仍会被重新解析。

### [UNKNOWN]

**npm 对 prerelease 的 caret 完整匹配规则，本轮没有独立验证。**
本记录只证明了**结果**（`^0.1.5-rc.1` 命中 `0.1.5-rc.3`），**没有**证明规则本身。

> ⚠️ **不要过度泛化**为"所有 caret prerelease 一定如此"。不同 major/minor/patch 组合、不同 npm 版本的行为可能不同。

---

## §4 Top-level rollback semantics（重点）

> ### [FACT]
> ```
> npm install -g @deepseek-ai/dsh@<old-version>
> ```
> 只固定 **top-level requested version**；npm **仍会重新解析其 dependency ranges**。
>
> 因此：
> ```
> top-level rollback  ≠  dependency-tree rollback
> ```

**本次事故的直接证据**：把顶层装回 `0.1.5-rc.1` 后，`dsh --version` 确实回到 rc.1，**但内部 sibling 仍被重新解析到 rc.3**，启动**仍然失败**。

**加重因素**：全局 npm 安装**没有 lockfile**（§1.4）⇒ 没有任何本地机制可以把依赖图恢复到旧状态。

### [RECOMMENDATION] 故障恢复的正确方向

| 做法 | 评价 |
|---|---|
| 装回旧 top-level 版本 | ❌ **通常不行** —— 依赖范围会重新解析 |
| **对齐 release line**（把顶层升到与已解析出的 sibling 同一线） | ✅ 本次实际恢复路径 |
| 备份整个安装目录后再升级 | ✅ 稳妥，但体积大、且 `bin` 链接需一并处理 |
| 依赖"重装一遍就好了" | ❌ 重装是**重新解析**，不是还原 |

---

## §5 rc.3 recovery lesson

### [FACT] 当前状态

- 当前 rc.3 安装的 **dependency tree 自洽**：`@deepseek-ai/*` 家族 230 个包全部为 `0.1.5-rc.3`；其余 9 个为独立版本线的厂商/工具包，**与 rc.3 的 exact pin 吻合**。
- ERESOLVE 风暴消失（事件数 **280 → 0**）。
- browser-lab boot 正常；profile-local bundle（Whale）正常；Browser MCP 正常。

### [UNKNOWN]

**rc.3 的恢复究竟是下列哪一项起决定作用，无法拆分**：

- **exact pin**（`cordis 4.0.2` 等，消除 peer 冲突）
- **package manifest 修复**
- **layout 改变**
- **release-line alignment**（顶层与 sibling 同线）

⇒ 因为**这几项在 rc.3 中同时发生了变化**，本次事故**不能**归因到其中单独一项。

### [RECOMMENDATION]

把"**顶层与 shipped sibling 处于同一 release line**"作为首要检查项；exact pin 是加分项，但不要把"改 exact pin"当成通用修复手段。

---

## §6 install-scripts / allowScripts

### [FACT] 现象

npm 12 会阻止未被 `allowScripts` 覆盖的 lifecycle scripts，并打印：

```text
npm warn install-scripts N packages had install scripts blocked because they are not covered by allowScripts:
npm warn install-scripts   <pkg>@<ver> (<hook>: <command>)
```

本次涉及 **5 个唯一 package**：

| package | 被阻止的脚本 |
|---|---|
| `@deepseek-ai/dsh-subprocess-local` | `postinstall: node scripts/ensure-spawn-helper.mjs` |
| `koffi` | `install: node ./cnoke.cjs -P . -D src/koffi --prebuild --release` |
| `node-pty` | `install: node scripts/prebuild.js \|\| node-gyp rebuild` + `postinstall: node scripts/post-install.js` |
| `@google/genai` | `preinstall: echo 'preinstall: no-op'` |
| `protobufjs` | `postinstall: node scripts/postinstall` |

### [FACT] 当前已验证的影响面

以下工作流**均正常**：browser-lab、Web UI、Whale Widget、Browser MCP。

### [UNKNOWN] 未验证的影响面

**是否影响**：

- PTY（`node-pty` 的 native build 被阻止）
- native subprocess（`koffi` 的 native build 被阻止；`dsh-subprocess-local` 的 spawn helper 被阻止）
- sandbox
- 其他**未测试**的 agent tools

> ⚠️ **措辞纪律**：
> ✅ 只能说 "install-scripts blocked 被观察到，但在**当前已测试工作流**中未造成可见故障"。
> ❌ **不要**写"这些 scripts 完全不需要"，也**不要**写"所有相关功能都不受影响"。
> ❌ **不要**为了消除警告而直接把脚本全部放行 —— 放行 native 构建脚本本身有安全与稳定性含义。

---

## §7 Upgrade checklist

> **[RECOMMENDATION]** 操作性清单，非官方规范。

### 升级前

- [ ] `dsh --version`
- [ ] `npm view @deepseek-ai/dsh dist-tags`（确认 `latest` / `next` 指向哪里）
- [ ] `npm view @deepseek-ai/dsh version`
- [ ] `npm ls -g @deepseek-ai/dsh --depth=0`
- [ ] **记录 profile 指纹**：每个在用 profile 的 `package.json` / `cordis.patch.yml` /（若有）`pnpm-lock.yaml` / `pnpm-workspace.yaml` 的 **size + mtime（+ hash）**
- [ ] **记录当前能力基线**：能否 boot、Web UI、已挂载的第三方 bundle、Browser MCP
- [ ] 记录 `$DSH_HOME/cordis.patch.yml` 是否存在（跨 profile 共享层）

### 升级

- [ ] **使用 exact top-level version**：`npm install -g @deepseek-ai/dsh@<exact>`
- [ ] **保留安装日志**（npm 默认 `logs-max=10`，超限会被静默裁剪；必要时先备份 `_logs`）

### 升级后（**按层验证，不要只看 `dsh --version`**）

- [ ] **安装层**：`dsh --version`、`npm ls -g @deepseek-ai/dsh --depth=0`
- [ ] **安装层**：安装输出里有无 `ERESOLVE`、有无 `install-scripts blocked`
- [ ] **安装层（必要时）**：`@deepseek-ai/dsh-*` 家族版本是否一致、是否与顶层同线
- [ ] **解析层**：能否 boot 一个 profile
- [ ] **应用层**：Web UI、已挂载的第三方 bundle、Browser MCP
- [ ] **profile 完整性**：profile 文件 mtime 是否与升级前一致（**应该不变**）
- [ ] **共享层**：`$DSH_HOME/cordis.patch.yml` 状态是否与升级前一致

---

## §8 Global install vs profile-local state

> ### [FACT]
> **global DSH installation 被替换 ≠ profile-local bundle membership 被删除。**

**实证**：2026-09-23 的升级事故中，整个全局安装被替换（`node_modules` 全部换成 rc.3），而：

- `browser-lab/package.json`（含 `dsh-whale-widget` 与三项 bundles）**未被修改**；
- `browser-lab/cordis.patch.yml`（MCP 条目）**未被修改**；
- `web` profile 的四个文件**全部未被修改**；
- Whale 的运行时状态文件在事故后**仍在被写入**。

**原因**（见 `07` §2/§4）：bundle membership 存在 **profile manifest**（`dsh.profile.bundles`）里，**不在安装里**；"安装"只是 bundle 包的**来源**。

### 诊断含义

故障时**先定位层**：

| 现象 | 先查 |
|---|---|
| `dsh` 命令本身起不来 / plugin tree failed to load | **global installation / dependency graph**（本文） |
| 某个 profile 的 bundle 不生效 / 归属不对 | **profile-local**（`07`） |
| 两个进程看到不同状态 | **runtime / 多进程**（`06`） |

---

## §9 Shared fallback behavior

### `$DSH_HOME/profiles/node_modules`

**[FACT] 性质**（源码注释）：*"The shared `$DSH_HOME/profiles/node_modules` **mirrors the dsh installation dependency closure**."*

**[FACT] 由 DSH 重建，不由 npm 写**：`healProfilesModuleFallback()` 在 **profile 启动**时自愈维护该目录（junction 指向当前安装）。

**实证**：2026-09-23 rc.3 安装于 `13:11:25`，该目录 `LastWriteTime = 13:27:45`（**晚约 16 分钟**），junction 目标已指向新安装。

### 它会变什么、不会变什么

| | 会变 | 不会变 |
|---|---|---|
| 可解析性 | ✅ 会跟随当前 installation | — |
| profile-local bundle membership | — | ❌ **不受影响**（在 profile manifest 里） |
| profile-local 插件是否进入该目录 | — | ❌ **不会**（实测 Whale 从未出现在此） |

⇒ **[FACT] 它改变的是"可解析性"，不是"归属"。**
配合 `07` §5 的归属纪律：**能解析 ≠ 被挂载**；**被 DSH 重建 ≠ 变成某个 profile 的 bundle**。

---

## §10 UNKNOWN

| # | UNKNOWN | 影响 |
|---|---|---|
| U1 | **npm prerelease caret 的完整匹配规则** | 无法预测"下一次安装会不会再漂移" |
| U2 | 具体哪条 **dependency edge / nested layout** 导致 Loader 找不到包 | 无法做精准预防 |
| U3 | rc.3 恢复的**决定性因素**（exact pin / manifest 修复 / layout / 版本线对齐） | 不知道哪一项是通用解法 |
| U4 | `ERESOLVE … error: 'INVALID'` 与同时存在的多份 `cordis` 落点的精确关系 | 诊断线索不完整 |
| U5 | **install-scripts blocked 对 PTY / native subprocess / sandbox / 未测 agent tools 的影响** | 不能断言"无影响" |
| U6 | 官方是否有正式 **installation guidance / upgrade procedure / rollback 支持** | 本文全部建议都是 [RECOMMENDATION] |
| U7 | 官方是否有对应的 issue / fix / release note | 同上 |
| U8 | 全局安装在**同一 `$DSH_HOME` 多 profile 并发运行**时升级的行为 | 与 `06` 的多进程风险叠加 |

---

## Evidence

| 主题 | 来源 |
|---|---|
| 完整事故过程、命令、分级 | `../experiments/dsh-install/2026-09-23-dsh-global-upgrade-rc1-to-rc3-incident.md` |
| npm 原始日志（三份原件 + SHA-256） | `../evidence/logs/npm/` |
| 关键行提炼（含归因更正说明） | `../evidence/logs/npm/EXCERPTS-2026-09-23.md` |
| 当前安装树版本快照（rc.3 恢复后） | `../evidence/install-snapshots/2026-09-24-dsh-sibling-versions.txt` |
| 解析锚点 / module fallback 源码 | `@deepseek-ai/dsh-app-boot/lib/index.js`（`resolveBundleDir` / `healProfilesModuleFallback` / `loadProfileDirectory`） |
| `dsh plugin` 写入面源码 | `@deepseek-ai/dsh/lib/plugin-Ddi42qoW.js` |
| profile-local 归属与共享层 | `07-profile-bundle-isolation.md` |
| 全局安装被替换后 profile-local 存活的前序实证 | `../experiments/profile-isolation/2026-09-15-whale-widget-browser-lab-install-e2e.md` |

---

## §11 第二 installation anchor：官方 Desktop bundled runtime [0.2.0-specific]

[FACT] 本机现在有**两个互相独立的 installation anchor**，本文 §1–§10 描述的"全局安装"
只覆盖其中第一个：

| anchor | 路径 | 版本 | 备注 |
|---|---|---|---|
| 全局 npm DSH | `C:\Users\user02\AppData\Roaming\npm\node_modules\@deepseek-ai\dsh` | 见 `00` §0.1 | 本文主体 |
| Desktop bundled runtime | `...\Programs\DeepSeek Harness\resources\app.asar\dsh\node_modules\@deepseek-ai\dsh`（经 `resources\runtime\cli\bin\dsh.cmd` 调用） | 见 `00` §0.1 | Desktop 自带 |

[FACT] 两者**可并存、互不覆盖**：Desktop 不写全局 npm 目录；升级全局 npm 不动 `app.asar`。
[RECOMMENDATION] 因此本文的**三层解析模型要按 anchor 分别套用**；诊断"为什么行为变了"时
先确认**是哪个 anchor 在跑**，再问版本。

[FACT] 两个 anchor 之间跨了 `[0.1.5 → 0.2.x version boundary]` 的两个不兼容面（settings 模型、
session format），因此"升级全局 npm 到与 Desktop 同一条版本线"本身就是一个**有兼容性含义**的动作，
而不只是版本号变化。见 `09-dsh-desktop.md` §7 / §8。

### §11.1 升级记录

见本文 §12（每次实际升级后追加）。


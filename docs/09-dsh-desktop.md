# 09 — 官方 DeepSeek Desktop（architecture · version boundaries · mixed-version 兼容性）

> 本文回答：官方 Desktop 是什么？它和全局 npm DSH 是什么关系？0.1.5 与 0.2.x 共用同一个
> `$DSH_HOME` 时会在哪两个面上结构性不兼容？结论是什么？
>
> 证据等级沿用全库规范（`[FACT]` / `[INFERENCE]` / `[UNKNOWN]`）。
> **版本标签**：本文大量内容**只对特定版本成立**，一律显式标注
> `[0.2.0-specific]` 或 `[0.1.5 → 0.2.x version boundary]`。
> **不要**把这些当成永久 universal architecture。
>
> 研究状态：**CLOSED**（2026-10-05）。原始证据见 §Evidence。

---

## §0 Scope

### 本文回答

1. 官方 Desktop 的进程/组成结构是什么？（§1）
2. Desktop 有没有引入新的 composition paradigm？（§2）
3. "第二 installation anchor" 意味着什么？边界怎么划？（§3、§4）
4. 共享状态面在哪里？哪些是共享、哪些是隔离？（§5、§6）
5. `[0.1.5 → 0.2.x version boundary]` settings 模型如何断裂？（§7）
6. `[0.1.5 → 0.2.x version boundary]` session format 如何断裂？（§8）
7. matched-version 对照实验证明了什么？（§9）
8. `session/end-seed` 是什么、对取证意味着什么？（§10）

### 与相邻文档的边界

| 主题 | 去哪 |
|---|---|
| 路径 / 目录 / `$DSH_HOME` 概念映射 | `00-dsh-local-filesystem.md` |
| bundle / profile / patch 组合语义 | `01`、`02` |
| profile 归属、写入面、共享层 | `07-profile-bundle-isolation.md` |
| 全局安装形态、三层解析、升级语义 | `08-dsh-installation-and-upgrade.md` |
| 实验方法论（quiet baseline / fail-closed / PS 5.1） | `10-experiment-methodology.md` |
| Desktop 研究的原始取证 | `../evidence/desktop/` |

---

## §1 Desktop 的组成 [0.2.0-specific]

[FACT] 官方 Desktop 是 **Electron shell + desktop-host + bundled DSH runtime + updater**
的组合，而不是"另一个 DSH 产品"：

| 组成 | 证据 |
|---|---|
| Electron shell | `C:\Users\user02\AppData\Local\Programs\DeepSeek Harness\DeepSeek Harness.exe`（244 MB，Electron 产物：`chrome_*.pak`、`resources.pak`、`icudtl.dat`、`v8_context_snapshot.bin`） |
| desktop-host | `resources\app.asar\dsh\node_modules\@deepseek-ai\dsh-desktop-host\lib\cli.js`（`app.asar` 121 MB） |
| bundled DSH runtime | `app.asar\dsh\node_modules\@deepseek-ai\*`（整套 `@deepseek-ai/dsh-*` 插件包） |
| 独立 runtime 目录 | `resources\runtime\`：`bin\node`、`cli\bin\dsh.cmd`、`primary-runtime\dependencies\{node,pnpm,python}`、`versions.json` |
| updater | `C:\Users\user02\AppData\Local\@deepseek-aidsh-desktop-updater`、`resources\app-update.yml` |

[FACT] bundled CLI 就是一个普通 DSH CLI，可以脱离 Electron 独立启动：

```cmd
:: resources\runtime\cli\bin\dsh.cmd
set "ELECTRON_RUN_AS_NODE=1"
"%~dp0..\..\..\..\DeepSeek Harness.exe" --expose-internals "%~dp0..\..\..\app.asar\dsh\node_modules\@deepseek-ai\dsh-desktop-host\lib\cli.js" %*
```

[FACT] 实测 `dsh.cmd --version` → `0.2.0-rc.2`，`dsh.cmd web --port <p>` 可正常起 Web UI。
（注意 `L3`-类误解："asar 只能由 Electron 解析"**只对运行成立**；只读取源码时可直接解析 ASAR
header 按偏移读条目，见 `../scripts/read-asar.mjs`。）

## §2 Desktop 没有引入新的 composition paradigm

[FACT] Desktop 仍然是 `profile + bundles + Cordis patch stream`。

[FACT] `$DSH_HOME\profiles\desktop\cordis.patch.yml` 就是一个**普通 profile user layer**，
里面是标准 patch entry（`id` / `name` / `config`），例如 `locale`、`ui-settings-general`、
`agent-default-model` 等 `@deepseek-ai/dsh-client-*` entry。

[FACT] 也就是说：Desktop 只是**多了一个 runtime + 一个保留 profile 名**，
没有引入新的组合原语。`01`/`02`/`07` 的组合语义对它**同样适用**。

## §3 第二 installation anchor

[FACT] 本机同时存在两个互相独立的 DSH installation anchor：

| anchor | 路径 | 版本（2026-10-05） |
|---|---|---|
| 全局 npm DSH | `C:\Users\user02\AppData\Roaming\npm\node_modules\@deepseek-ai\dsh` | `0.1.5-rc.3` → 见 `00` §0.1 |
| Desktop bundled runtime | `...\Programs\DeepSeek Harness\resources\app.asar\dsh\node_modules\@deepseek-ai\dsh` | `0.2.0-rc.2` |

[FACT] 两者**可以并存**，互不覆盖：Desktop 不会写全局 npm 目录，全局 npm 升级也不会动
`app.asar`。

[INFERENCE] 因此"当前 DSH 版本"不再是一个标量。凡陈述版本时必须写成
"**哪个 anchor + 哪个版本**"。

### §3.1 2026-10-19 版本复核（CLI 升级后）

[FACT] 全局 npm anchor 已从 `0.1.5-rc.3` 升为 `0.2.1-rc.2`；Desktop bundled runtime 仍为 `0.2.0-rc.2`
（`resources\runtime\primary-runtime\runtime.json` → `desktopVersion`，本次未升级）。

[FACT] 当日正在服务的 Web session 属于 **CLI/Web 的 `browser-lab` profile**，运行 `0.2.1-rc.2`，不是
Desktop 后端。判别依据：该 session 的工具面包含 0.2.1 才有的 `working_directory` 工具，且 profile 不是
Electron 保留的 `desktop`；不是只看 UI 版本号。

[INFERENCE] 因此“两个 anchor 并存 + 共享 `$DSH_HOME`”的结论在 2026-10-19 仍成立，但版本组合已从
`0.1.5-rc.3 + 0.2.0-rc.2` 变为 `0.2.1-rc.2 + 0.2.0-rc.2`。§7/§8 的 `[0.1.5 → 0.2.x]` 断裂面针对的是
更早的边界，不能直接套到 `0.2.0 → 0.2.1`：后者的 session format 仍为 v4（见 `00` §7.5.2）。

[FACT] 证据：`../experiments/dsh-version-audit/0.2.0-rc.2-to-0.2.1-rc.2/`（`FINAL-REPORT.md` §2、
`RUNTIME-VERIFICATION.md` §1）。

### 3.2 2026-11-08 版本复核（`0.2.2-rc.1`）

[FACT] 全局 npm anchor 已由 `0.2.1-rc.2` 升为 **`0.2.2-rc.1`**；Desktop bundled runtime **仍未升级**：
`runtime.json` 的 `desktopVersion` = `0.2.0-rc.2`，`DeepSeek Harness.exe` 的 `FileVersion` = `0.2.0-rc.2`。
两个 anchor 的差距现在是 **`0.2.2-rc.1`（npm）vs `0.2.0-rc.2`（bundle）**，跨 **两个 minor**。

[FACT] 当日服务的 Web session 与全局 npm 同版本（`0.2.2-rc.1`，`browser-lab` profile）。
判别依据是 `dsh --version` + 安装 `package.json` + `DSH_PROFILE`，以及 Desktop anchor 明确读到
`0.2.0-rc.2`；不是只看 UI 版本号。

[INFERENCE] "两个 anchor 并存 + 共享 `$DSH_HOME`"结论继续成立。§7/§8 的 `[0.1.5 → 0.2.x]` 断裂面
仍**不能**套到 `0.2.x → 0.2.y`：`0.2.2` 的 `SESSION_FORMAT_VERSION` 仍为 **4**（见 `00` §7.5.2），
settings 模型也未再变。

[FACT] 一个容易误读的信号：`0.2.1` 时代的 `1017` 模型 label 组件
（`dsh-client-ui-deepseek-model-label-1017`）在 `0.2.2-rc.1` 中**已被移除**。所以"UI 上不再有 1017
badge"**不能**用来推断 Desktop 与 CLI 的差异，也**不能**推断权重版本变了——权重版本始终 `[UNKNOWN]`
（见 `00` §0.1 模型层注记）。

[RECOMMENDATION] 当两个 anchor 相差两个 minor 时，"同一个 session 在两个 anchor 上行为一致"这种
假设**风险更高**；本仓库尚未重做 Desktop↔CLI 的 v4 session 互操作（`NOT RETESTED`，见审计 UNKNOWN）。

[FACT] 证据：`../experiments/dsh-version-audit/0.2.1-rc.2-to-0.2.2-rc.1/`
（`RUNTIME-VERIFICATION.md` §1 第 7、10 项、`evidence/runtime-identity.txt`）。

## §4 runtime / profile / executable / install anchor 是四个独立边界

[FACT] 这四个维度互相独立，混用会导致错误结论：

| 维度 | 是什么 | 本机示例 |
|---|---|---|
| **install anchor** | 包从哪棵 node_modules 解析 | 全局 npm 树 / `app.asar` 内树 |
| **runtime** | 实际执行的 DSH 代码 | `0.1.5-rc.3`（npm） / `0.2.0-rc.2`（bundle） |
| **executable** | 启动器 | 全局 `dsh.cmd` / `DeepSeek Harness.exe` + `ELECTRON_RUN_AS_NODE=1` |
| **profile** | 组合层与 bundle 成员边界 | `browser-lab`、`web`、`desktop`（Desktop 保留） |

[RECOMMENDATION] 写证据时四者都要写明，否则"版本升级了但行为没变"这类结论无法解释。

## §5 shared product state 仍在同一个 `$DSH_HOME`

[FACT] Desktop 与全局 CLI 共用同一个 `$DSH_HOME`（`C:\Users\user02\.dsh`）；
`DSH_HOME` 环境变量可覆盖它（`dsh-home-paths`: `DSH_HOME_ENV = "DSH_HOME"`）。

[FACT] 属于**共享状态面**的至少包括：

| 面 | 路径 |
|---|---|
| 用户设置 | `$DSH_HOME\settings.yaml` |
| 凭据 | `$DSH_HOME\.credentials.yaml` |
| 会话日志 | `$DSH_HOME\sessions\<workspace-dir>\<session-id>\session.vN.jsonl.zstd` |
| 存储 / registry | `$DSH_HOME\storages\`（含 `workspace.json`、`session_projcache\`） |
| 全局指令 | `$DSH_HOME\AGENTS.md` |
| profile 池 | `$DSH_HOME\profiles\` |

[INFERENCE] 这是全部 mixed-version 问题的**共同前提**：两个不同 runtime 读写同一份产品状态，
而这份状态的格式在两个版本之间发生了不兼容变化。

## §6 Desktop profile bundle isolation 继续成立

[FACT] `07` 的核心区分对 Desktop 同样成立：

* **package presence ≠ mounted bundle**：包在磁盘上不代表 profile 挂了它；
* **shared node_modules ≠ profile inheritance**：`$DSH_HOME\profiles\node_modules` 是共享
  *解析*层，不是组合继承。

[FACT] 本机 Desktop 使用保留 profile 名 `desktop`
（`$DSH_HOME\profiles\desktop\`），与 `browser-lab` / `web` 各自独立。

[FACT] 跨版本实测：Desktop 启动后 `browser-lab` 与 `web` 的 `package.json` /
`cordis.patch.yml` 哈希保持不变（见 `../evidence/desktop/runtime/` 各 stage 的
profile/home invariants 段）。

---

## §7 `[0.1.5 → 0.2.x version boundary]` settings 模型

### 0.1.5 侧

[FACT] 存在 **file-backed settings provider**：`@deepseek-ai/dsh-settings-file`。
`$DSH_HOME\settings.yaml` 就是 active user settings。

[FACT] Web 0.1.5 **不认识** `settings.yaml.imported`（在该版本源码中零命中）。

### 0.2.x 侧

[FACT] `@deepseek-ai/dsh-settings-file`（0.1.5 的 file-backed provider）在 0.2.0 中**已不存在**
（安装树中无该包）。**`$DSH_HOME\settings.yaml` 不再是 active authoritative store。**

[FACT] 启动后 legacy 文档被**移走**：

```
$DSH_HOME\settings.yaml  --rename-->  $DSH_HOME\settings.yaml.imported
```

并由 `importLegacyDocument()` 按 section 导入到**对应 Cordis entry 的 `config`**
（本机导入目标：`$DSH_HOME\profiles\desktop\cordis.patch.yml`，即该 profile 的 user patch layer）。

[FACT] 源码语义（`importLegacyDocument()`）：

```js
if (!existsSync(path)) return;        // 没有 legacy 文件就完全不动
await rename(path, imported);          // 移走（Windows 上覆盖已存在的 .imported）
// 然后按 section 写入同一 id 的 Cordis entry 的 config
```

### settings system 的实际工作方式 [0.2.0-specific]

[FACT] 0.2.x 的 settings 不是"独立的 settings store"，而是**挂在 Cordis entry config 上**：

1. **plugin / service 自己声明 `Config` schema**（schemastery）。例：
   `dsh-client-ui-settings-general` → `const Config = z.object({ welcomeNoticeVersion: z.string().volatile() })`；
   `dsh-agent-default-model` → `static Config = z.object({ provider, model, reasoningEffort })`。
2. **`dsh-settings` 通过 `configEditor` 定位 entry**：`static inject = ["configEditor", "profileContext"]`；
   它枚举 `configEditor.configuration()` 得到 `{ entry, inherited, override }`，再按 **Cordis entry id** 匹配
   （`configEditor.entries().find(row => row.options.id === ns)`）。
3. **用 plugin 自己的 `Config` schema 生成 / 编辑 settings**
   （`dsh-settings/lib/types/schema.js`：*"Derive editable forms and plain values from plugin Config schemas"*），
   并经 `configEditor.edit(entry, …)` 写回。
4. **最终写 entry config override**，落盘到该 profile 的 `cordis.patch.yml`。

[FACT] 因此 `ui-settings-general` 与 `agent-default-model` 都是
**Cordis plugin / service entry + 它的 `config`**；它们**不是**独立于 Cordis 的 "settings object"。
（`agent-default-model` 还会 `settings.configure({ auto: false }, fiber)` 选择退出 settings 自动托管。）

### `cordis.patch.yml` 的角色：settings 与 plugin system 在此汇合

[FACT] 该文件**不只**表示 plugin activation / composition。它是 profile 的 patch 层
（`PatchOptions[]`，语义见 `02` §E），同时承载两类操作：

| 形态 | 含义 |
|---|---|
| `insert: […]` | **entry 插入 / activation**（composition） |
| `- id: <entry-id>` + `config: {…}` | **entry config override**（`config` 是**整键替换**，不是 merge） |

[FACT] 本机 `profiles\browser-lab\cordis.patch.yml` 两者都有：
`insert: mcp-playwright`（activation）+ `id: agent-default-model / config:`（override）。

[RECOMMENDATION] 可以说"**settings 与 plugin system 在 Cordis config layer 汇合**"，
但**不能**说"settings 本身就是 plugin"。

### `.imported` 的准确语义

[FACT] `.imported` **不是**普通 backup，也**不是**纯 marker，而是
**"已被消费的 legacy document"**：内容就是被移走的那个 `settings.yaml`。

[FACT] 它**不是 active settings source** —— active 值此时已经在 profile entry config 里。
[FACT] 它**不是 durable immutable backup**：它没有历史积累，会被下一次 import 覆盖（见下）。

[FACT] 实测其行为是 **rolling single-slot**：只要旧 host 又生成新的 `settings.yaml`，
下次 0.2 runtime 启动就会再次 rename，并**覆盖**旧的 `.imported`。

> 本机三次观察：`7A7CCB3C…`(175 B) → `0D6DBB77…`(176 B) → `EA141B86…`(52 B) → `28AB17AE…`(151 B)。
> 后两次覆盖分别发生在 2026-10-05 的 Desktop 启动与 global CLI 升级到 0.2.0 后的首次启动；
> 被覆盖的旧内容**在磁盘上已不存在**（证据管线只记 size + SHA-256，不保存内容；
> 其导入结果保留在对应 profile 的 `cordis.patch.yml`）。

### profile-local 含义（限定性表述）

[FACT] 0.2.x 中 settings 更接近 **profile-scoped config**：每个 profile 有**自己的**
`cordis.patch.yml`，因此**可以**各自持有不同的 entry config override
（本机 `profiles\desktop` 与 `profiles\browser-lab` 的 patch 内容确实不同）。

[UNKNOWN] 是否存在**不经过 entry config**（因而仍偏 central）的 settings 类型，本轮**未穷尽验证**。
⇒ **不要**把"所有 settings 都必然是 profile-local"写成 universal FACT；
只写"**主要 settings entry** 是 profile-scoped 的"。

### 必须避免的错误表述

| ❌ 不要写 | ✅ 应写 |
|---|---|
| "settings 变成了插件" | plugin / entry 一直是 Cordis 原语；**改变的是 authoritative settings value 的存放位置与编辑路径** |
| "`settings.yaml.imported` 是新版 active settings 文件" | 它只是**被消费过的** legacy document；active 值在 profile entry config |
| "所有设置被集中迁移进一个新的 settings plugin" | settings **分散**在各 plugin 自己的 `Config` + 对应 entry 的 `config` 中，**没有**统一的新 settings plugin |

### 结构性 shared-settings incompatibility [0.1.5 → 0.2.x version boundary]

两个版本共用同一个 `$DSH_HOME` 时会形成**闭环冲突**：

```
0.2 runtime : settings.yaml --import--> settings.yaml.imported + profile Cordis entry
0.1.5       : 不认识 imported
            → active user settings 缺失
            → 重新 bootstrap 一个最小 settings.yaml
            → 下次 0.2 启动又把它 import 走（覆盖 .imported）
```

[FACT] 0.1.5 重新 bootstrap 出来的最小 `settings.yaml` 只含 `ui-onboarding`
（`welcomeNoticeVersion`），这是客户端确认 onboarding 时自动写的唯一 namespace；
`locale` / `agent-default-model` 等**只在用户显式操作时才写**，因此不会自动回来。

### 用户可见结果：locale 回退（必须精确表述）

[FACT] 在 0.2 导入之前，`profiles\desktop\cordis.patch.yml` 里显式存在
`locale: { preference: en }`。

[FACT] `dsh-client-locale` 的语义是：`LOCALE_PREFERENCE_FIELD = "preference"`，
**absence delegates to the browser**；`FALLBACK_LOCALE = "en"`（不是 zh）。

⚠️ **禁止的表述**：~~"Desktop 把 en 改成了 zh"~~。
✅ **准确表述**：

> Desktop 的 legacy import **导入并移走了** legacy 中那个**显式的 active locale override**；
> 旧 Web **不认识 imported settings**，所以在重新 bootstrap 时**失去了这个 override**；
> 于是 UI 的 locale 改由 **browser language resolution** 决定，因而可能显示中文。

[INFERENCE] 因果链 **STRONGLY SUPPORTED，不是 CONFIRMED**：其中一个环节是"浏览器实际
`navigator.languages` 是什么"，该值**未被直接观测**。不要把整条链写成 FACT。

[FACT] 若 legacy `settings.yaml` **不存在**，`importLegacyDocument()` 是 no-op，
因此 0.2 启动**不会**产生任何 settings churn（E1 run3 Stage A 实测 churn = 0）。

## §8 `[0.1.5 → 0.2.x version boundary]` session format

| | `0.1.5-rc.3` | `0.2.0-rc.2` |
|---|---|---|
| `SESSION_FORMAT_VERSION` | **3** | **4** |
| format catalog `currentVersion` | 3 | 4 |
| 注册 codecs | v0–v3 | v0–v4 |
| `currentEncoder` | `releasedV3SessionFormatCodec` | `releasedV4SessionFormatCodec` |
| migration chain | v0→v1, v1→v2, v2→v3 | …、v2→v3、**v3→v4** |
| `dsh-session-format-v3-to-v4` | **未安装** | 存在 |
| 读 v3 | `status: "current"` | `current`（codec + v3→v4 migration） |
| 读 v4 | `status: "unsupported"` | `status: "current"` |
| 写 | **仅 v3** | **仅 v4** |
| dual-read（v3+v4） | 无 | **有** |

[FACT] v4 格式边界**引入于 0.1.5-rc.3 → 0.2.0-rc.2 之间**，方式是新增
`dsh-session-format-v3-to-v4` 包并把 `SESSION_FORMAT_VERSION` 3 → 4。

[FACT] catalog 构造会**拒绝高于 currentVersion 的 codec**，并要求 `0..currentVersion`
每一版都有 codec；因此 0.1.5 结构上**无法**接受 v4。

### 文件名匹配器是 version-agnostic（这是关键区分）

[FACT] 两个版本的 canonical basename 正则相同：

```js
/^session(?:\.v([1-9][0-9]*))?\.jsonl$/u        // dsh-session-format
```

JSONL backend 再拼压缩后缀 `.jsonl.zstd` / `.jsonl`，解析前剥掉。

[FACT] 因此 `session.v4.jsonl.zstd` **是合法文件名**，解析结果为 `4`；
generation 选择器取**数值最高**者。**文件名层没有版本过滤**。

### 失败层（0.1.5，实测 + 源码）

```
FILESYSTEM DISCOVERY : PASS   （readdir 能枚举到 v4 文件并解析出 version 4）
HOST INDEX           : FAIL   （readGenerationHeader 被 v3-only catalog 判 unsupported）
UI SURFACING         : NOT ROOT CAUSE（sidebar 只渲染 host 已给出的列表）
LOADER               : 也不支持 v4，但正常 UI 路径在之前已被过滤
```

[FACT] 决定性代码在 `dsh-session-persistence-jsonl` 的 `listArtifacts()`：

```js
const selected = await this.resolveGenerationInDirectory(dir, signal);   // 找到了 v4
try { header = await this.readGenerationHeader(selected, void 0, signal); }
catch (error) {
    if (error instanceof SessionFormatUnsupportedError) continue;          // ← 静默丢弃
    throw error;
}
```

[FACT] 按 id 直开会走到第二个闸门（`requireStoredLog()`），抛出用户可见文案：

```
session "<id>" uses log format v4, but this harness reads only v3:
the log was written by a newer harness — upgrade the harness to open it
```

[FACT] 进入一个只含 v4 session 的 workspace 时，0.1.5 会**新建一个空白 v3 session**：
`dsh-client-ui-workspace` 的 `openWorkspace → connectWorkspace` 会先找本 workspace 里的
**blank** session，找不到就 `sessions.create({ workspaceId })`；host 用**自己当前格式**（v3）
落盘。目标 v4 session 不在可见列表里，且它带完整 turn、本来就不是 blank，两个原因都成立。

## §9 matched-version 对照（Control B）[0.2.0-specific]

[FACT] 在隔离 `$DSH_HOME` 中注入 run3 那个 v4 session 的**副本**（源文件只读不动），
用 bundled `0.2.0-rc.2` Web 打开同一 workspace：

* **DISCOVERY PASS** —— 侧边栏列出该 session，标题 `E1 interoperability marker`
  来自它自己的 `session/title` 事件；
* **RENDER PASS** —— 完整渲染用户 marker 与 Desktop 的完整回复；
* format 保持 **v4**，原有事件完整；
* 会另建一个空白草稿 session，但那也是 **v4**（同格式，不是 v3 回退），
  且目标 id 被**保留**在 `workspace.sessionIds` 中。

[FACT] 于是：

```
0.2 matched-version Web can discover/open/render Desktop-created v4 sessions.
0.1.5 cannot discover the same v4 session because its session catalog stops at v3.
[CONCLUSION] observed interoperability failure is a runtime/session-format
             version-boundary issue, not a generic Desktop-vs-Web incompatibility.
```

[FACT] 附带（registry 语义差异）：0.1.5 打开 workspace 后把
`storages\workspace.json` 的 `sessionIds` **替换**成自己（v3-only）的视图，
目标 v4 id 因此从该 workspace 的关联列表中消失；0.2.0 则是**保留并追加**。
[INFERENCE，高置信] 这是一次**元数据关联丢失**，不是 session 数据破坏；
（判定依据：A/B 两阶段文件同尺寸不同哈希，两个候选 id 同为 44 字符，而 v3 session 当时尚不存在。）

## §10 `session/end-seed`

[FACT] 打开 / attach 一个 session 时可能**一次性**追加一个事件：

```json
{"type":"session/end-seed","seq":N,"time":<ms>,"data":{}}
```

[FACT] 特征：

* **append-only**：只追加，不重写既有事件；
* 有 guard 防止正常路径重复追加（本机多次观察 `endSeedCount` 单次 +1）；
* **不代表 migration**，**不代表 destructive rewrite**，**不代表 history loss**；
* 在两个版本、以及 Desktop/Web 两侧都观察到同一行为
  （例：某 v4 session 在 Desktop 启动时 31→32 events、`endSeedCount` 0→1；
  同一 session 被 0.2 Web 只读打开时出现完全相同的 31→32、0→1）。

[RECOMMENDATION] 未来 session forensic **不能**用"只读打开后 SHA-256 必须完全不变"
作为绝对判据。应区分：

| 良性 | 恶性 |
|---|---|
| benign one-time `session/end-seed` append | destructive mutation / format change / history loss |
| 判据：仅末尾 +1 事件、`endSeedCount` 单次 +1、原事件逐类计数不变、格式不变 | 判据：既有事件被改写/删除、格式升降级、`events` 下降、出现 `.bak`/`.imported`/第二个 `session.vN` 文件 |

---

## §11 明确不在本文范围

* E1 的 A→B→C 全链路结论：见 `../evidence/desktop/runtime/e1-run3-CLASSIFICATION-NOTE.md`
  与 `e1-run3-FORENSIC-v4-DISCOVERY.md`。
* Control B 的完整步骤与两个 literal 条款的限定：见
  `../evidence/desktop/runtime/controlB/CONTROL-B-RESULT.md`。
* 实验方法论：见 `10-experiment-methodology.md`。

## Evidence

| 结论 | 来源 |
|---|---|
| Desktop 组成、`dsh.cmd`、`read-asar` | `../scripts/read-asar.mjs`；`resources\runtime\cli\bin\dsh.cmd`（本机实测） |
| settings 边界 | `../evidence/desktop/runtime/e1-run3-BASELINE-PRECONDITIONS.md`；`e1-BASE-QUIESCENT-R2-VALIDATOR-NOTE.md` |
| session format 边界 | `../evidence/desktop/runtime/e1-run3-FORENSIC-v4-DISCOVERY.md` |
| run3 分类 | `../evidence/desktop/runtime/e1-run3-CLASSIFICATION-NOTE.md` |
| Control B | `../evidence/desktop/runtime/controlB/CONTROL-B-RESULT.md` |
| 全局安装 / 升级语义 | `08-dsh-installation-and-upgrade.md` |
| 原始 stage 取证（**已归档**） | `../evidence/desktop/archive/2026-10-05-desktop-research-final.zip`（v4 session 各 stage 的 capture / baseline / compare + 真实 home BEFORE/AFTER 指纹；sha256 见同目录 `.sha256.txt`） |
| 松散保留的 verdict / fingerprint / metadata | `../evidence/desktop/runtime/`（`e1-BASE-QUIESCENT*-VERDICT.txt`、`*-CAPTURE-FINGERPRINTS.txt`、`e1-run3.metadata.json`、`e1-run3.session.lock.json`） |
| 本次清理的取舍记录 | `../evidence/desktop/cleanup-manifest-before.md`、`../evidence/desktop/cleanup-manifest-after.md` |

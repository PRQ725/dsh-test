# DSH 全局升级事故：0.1.5-rc.1 → rc.2（失败）→ rc.1 回滚（失败）→ rc.3（恢复）

- **事故日期**：2026-09-23（安装目录 `CreationTime = 2026/9/23 13:11:25`）
- **记录建立**：2026-09-24
- **类型**：**global DSH installation / dependency graph / module resolution incident**
- **不是**：profile corruption incident
- **状态**：**已恢复**（无需再做修复动作）
- 相关长期知识：`../../docs/08-dsh-installation-and-upgrade.md`
- 原始证据：`../../evidence/logs/npm/`（三份 npm debug log 原件 + README + EXCERPTS）

---

## 0. Summary / Status

| 项 | 结果 |
|---|---|
| DSH `0.1.5-rc.3` | **PASS** |
| browser-lab boot | **PASS** |
| Web UI | **PASS** |
| Whale Widget `0.3.0` | **PASS** |
| Browser MCP | **PASS** |

**归因定性**：

- 这是 **global DSH installation / dependency graph / module resolution** 层的事故。
- **不是 profile corruption incident** —— `browser-lab` 与 `web` 的 profile 文件全程未被修改（§9）。
- Cordis 的 `plugin tree failed to load` 是**报错出口**，不是根因层（§10）。

**一句话**：`npm install -g` 在 prerelease 上重新解析了宽松的依赖范围，装出一棵 **顶层旧版 + 内部 rc.3 版本混装**的树，导致 Loader 解析不到 `@deepseek-ai/dsh-sandbox-local`；而"把顶层版本装回 rc.1"**并不能**恢复旧树。最终以 **rc.3 版本线对齐**恢复。

---

## 1. Background

事故前环境：

| 项 | 值 |
|---|---|
| DSH | `@deepseek-ai/dsh@0.1.5-rc.1` |
| Node | `v24.20.0` |
| npm | `12.0.2` |
| pnpm | `12.4.2` |
| 主要 profile | `browser-lab` |

事故前能力基线：Web UI 正常、Browser MCP 正常、`dsh-whale-widget@0.3.0` 正常、自定义 profile 配置正常。

**升级动机**：尝试升级 DSH，并**顺便**观察之前频繁出现的 file read/write consistency guard 问题是否会改善。

> ### [UNKNOWN] 与 file consistency guard 的关系
>
> 之前反复出现的
> `file has not been read` / `file changed since it was read` / `file no longer exists`
> 与**本次 DSH 版本升级 / dependency incident 的关系未验证**。
>
> **本次记录不建立任何因果关系**：不把升级事故写成 guard bug 的 root cause，也不把 rc.3 当前正常运行写成 guard 已修复。
> 这是一条**完全独立**的后续研究线。

---

## 2. Pre-upgrade baseline

**版本四联查询**（[FACT：人工命令输出]）：

```text
dsh --version                                  → 0.1.5-rc.1
npm view @deepseek-ai/dsh dist-tags            → { latest: '0.1.5-rc.2', next: '0.1.5-rc.3', alpha: '0.1.7-alpha.2' }
npm view @deepseek-ai/dsh version              → 0.1.5-rc.2
npm list -g @deepseek-ai/dsh --depth=0         → @deepseek-ai/dsh@0.1.5-rc.1
```

**profile-local 状态**：`browser-lab` 的 `package.json` 当时为

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

**基线指纹**（2026-09-24 复核时仍与之逐项一致，见 §9）：`package.json` / `pnpm-lock.yaml` / `pnpm-workspace.yaml` mtime 均为 `2026-09-15 20:41:4x`；`cordis.patch.yml` mtime `2026-09-12 15:10:27`。

> ⚠️ **本次事故的前置基线不含"完整依赖树"** —— 全局 npm 安装不产生 lockfile（§5），且旧树已被覆盖，因此事故前的精确树**从未被记录**，事后也无法还原。

---

## 3. rc.2 upgrade

```powershell
npm install -g @deepseek-ai/dsh@0.1.5-rc.2
```

**结果**（[FACT]）：

- 安装完成；`dsh --version` → `0.1.5-rc.2`；`npm list -g @deepseek-ai/dsh --depth=0` → `@deepseek-ai/dsh@0.1.5-rc.2`。
- 安装过程出现**大量** `npm warn ERESOLVE overriding peer dependency`。
- npm 12 **阻止了若干 lifecycle scripts**（`install-scripts blocked`）。
- 阻止列表中出现 `@deepseek-ai/dsh-subprocess-local@0.1.5-rc.3` —— 注意**版本是 rc.3**。

**严格分级**：

| # | 陈述 | 等级 |
|---|---|---|
| a | top-level DSH = `0.1.5-rc.2` | **[FACT]** |
| b | 日志中出现 `@deepseek-ai/dsh-subprocess-local@0.1.5-rc.3` | **[FACT]** |
| c | ERESOLVE peer dependency 冲突**大量**出现 | **[FACT]**（原件量化见 §7） |
| d | 顶层 rc.2 而内部 sibling 已 `0.1.5-rc.3` | **[FACT]**（`placeDep … CONFLICT for: … want: ^0.1.5-rc.2` 实放 `@0.1.5-rc.3`） |

> 日志文件：`evidence/logs/npm/2026-09-23T04_00_54_627Z-debug-0.log`

---

## 4. rc.2 boot failure

```powershell
dsh --profile browser-lab --no-open --port 3080
```

**核心错误**（[FACT：人工输出]）：

```text
Error: dsh: plugin tree failed to load:
dsh: plugin(s) failed to load: @deepseek-ai/dsh-sandbox-local;
Cordis startup failed because these plugin(s) could not be resolved
```

调用栈指向全局安装：`C:\Users\user02\AppData\Roaming\npm\node_modules\@deepseek-ai\dsh\...`

**分级**：

| # | 陈述 | 等级 |
|---|---|---|
| a | 故障发生在 **DSH 全局程序安装 / plugin resolution** 阶段 | **[FACT]** |
| b | 报错出口是 Cordis Loader | **[FACT]** |
| c | Cordis 是**报错出口**而非根因层 | **[INFERENCE]**（§10） |
| d | **没有证据**表明 `browser-lab` profile 自身配置损坏 | **[FACT]**（§9 事后复核确认文件未变） |

---

## 5. rc.1 rollback attempt

```powershell
npm install -g @deepseek-ai/dsh@0.1.5-rc.1
```

**结果**（[FACT]）：

- 顶层版本**确实回到** `0.1.5-rc.1`（`dsh --version` / `npm list -g` 均确认）。
- 但安装日志中**仍然出现** `@deepseek-ai/dsh-subprocess-local@0.1.5-rc.3`，且仍有 `install-scripts blocked`。
- 再次启动，**仍然报** `@deepseek-ai/dsh-sandbox-local could not be resolved`。

### ★ 本次事故长期价值最大的事实之一

> **[FACT] 恢复旧 top-level version，并没有恢复旧 dependency tree。**
>
> 即：
> ```
> top-level rollback  ≠  dependency-tree rollback
> ```
> 执行 `npm install -g @deepseek-ai/dsh@<old>` 只固定了**被请求的顶层版本**；npm **仍会重新解析其依赖范围**，因此在 prerelease 场景下会重新装出（部分）更新的 sibling。

**日志直接证据**（rc.1 回滚日志）：

```text
node_modules/@deepseek-ai/dsh @deepseek-ai/dsh-base@0.1.5-rc.3     CONFLICT for: @deepseek-ai/dsh@0.1.5-rc.1 want: ^0.1.5-rc.1
node_modules/@deepseek-ai/dsh @deepseek-ai/dsh-app-boot@0.1.5-rc.3 CONFLICT for: @deepseek-ai/dsh@0.1.5-rc.1 want: ^0.1.5-rc.1
```

读法：**声明的 `want` 是 `^0.1.5-rc.1`，实际 placed 的是 `0.1.5-rc.3`。**

> 日志文件：`evidence/logs/npm/2026-09-23T04_38_36_190Z-debug-0.log`

---

## 6. rc.3 recovery

```powershell
npm install -g @deepseek-ai/dsh@0.1.5-rc.3
```

**结果**（[FACT]）：

- 安装过程明显干净：**没有**之前那一大批 `ERESOLVE overriding peer dependency`（原件量化：**0**）。
- 仅剩 `node-domexception` deprecated warning，以及 5 个 `install-scripts blocked`。
- `dsh --version` → `0.1.5-rc.3`。
- `dsh --profile browser-lab --no-open --port 3080` → **正常启动**。

**恢复后能力确认**（[FACT：人工确认]）：browser-lab boot PASS · Web UI PASS · Whale Widget PASS · Browser MCP PASS。

> 日志文件：`evidence/logs/npm/2026-09-23T05_11_08_017Z-debug-0.log`

**2026-09-24 只读复核补充**（[FACT]）：

| 项 | 值 |
|---|---|
| `dsh --version` | `0.1.5-rc.3` |
| 顶层 `package.json` version | `0.1.5-rc.3` |
| 安装目录 `CreationTime` | `2026/9/23 13:11:25` |
| 运行实例 | PID 18268，`--profile browser-lab`，启动 `2026/9/24 12:56:06`，LISTEN `127.0.0.1:3080` |
| whale 运行时状态 | `.dshw-usage.json` 于 `2026/9/24 15:23:33` 仍被写入 ⇒ **whale 在 rc.3 上持续活跃** |

---

## 7. npm log forensics

> 全部取自 `evidence/logs/npm/` 的三份**原件**。逐条已与原件复核。
> **计数口径**：`ERESOLVE` 的"行数"与"事件数"不同（每事件 45 行），下表两者都列。

### 7.1 ERESOLVE 规模

| 日志 | 含 `ERESOLVE` 的行数 | `overriding peer dependency` 事件数 | 首条位置 |
|---|---|---|---|
| rc.2 首次升级 | **12600** | **280** | npm seq 525 / 物理行 526 |
| rc.1 回滚 | **12600** | **280** | npm seq 515 / 物理行 516 |
| rc.3 恢复 | **0** | **0** | 无 |

> ⚠️ **"12600" 只属于 incident evidence，不得进入长期知识结论。** 长期知识只保留"ERESOLVE 风暴消失"这一可复用对比。

### 7.2 [FACT] rc.1 / rc.2 顶层对 `dsh-*` sibling 使用 `^0.1.5-rc.x`

```text
rc.2: node_modules/@deepseek-ai/dsh @deepseek-ai/dsh-base@0.1.5-rc.3 CONFLICT for: @deepseek-ai/dsh@0.1.5-rc.2 want: ^0.1.5-rc.2
rc.1: node_modules/@deepseek-ai/dsh @deepseek-ai/dsh-base@0.1.5-rc.3 CONFLICT for: @deepseek-ai/dsh@0.1.5-rc.1 want: ^0.1.5-rc.1
```

### 7.3 [FACT] rc.1 / rc.2 实际解析出 rc.3 sibling

```text
@deepseek-ai/dsh-sandbox-local@^0.1.5-rc.3      （fetch manifest）
@deepseek-ai/dsh-subprocess-local@^0.1.5-rc.3   （fetch manifest）
@deepseek-ai/dsh-base@0.1.5-rc.3                （placeDep）
@deepseek-ai/dsh-app-boot@0.1.5-rc.3            （placeDep）
1507 silly placeDep …/dsh-base @deepseek-ai/dsh-sandbox-local@0.1.5-rc.3 CONFLICT for: @deepseek-ai/dsh-base@0.1.5-rc.3 want: ^0.1.5-rc.3
```

### 7.4 [FACT] rc.1 / rc.2 的 **vendor callback**：caret 也向更高版本解析

```text
@deepseek-ai/cordis@4.0.4                OK for: @deepseek-ai/dsh@0.1.5-rc.2 want: ^4.0.2
@deepseek-ai/cordis-plugin-hmr@1.0.19    OK for: @deepseek-ai/dsh@0.1.5-rc.2 want: ^1.0.17
@deepseek-ai/cordis-plugin-include@1.0.9 OK for: @deepseek-ai/dsh@0.1.5-rc.2 want: ^1.0.7
js-yaml@4.3.2                            OK for: @deepseek-ai/dsh@0.1.5-rc.2 want: ^4.2.0
node-addon-require-builtin@0.1.6         OK for: @deepseek-ai/dsh@0.1.5-rc.2 want: ^0.1.4
```

> **归因更正记录**：本知识库在 2026-09-24 的首次提取中曾因正则丢失包名，把 `want: ^0.1.4` 误归给 `dsh-*` sibling。**按原件更正**：`^0.1.4` 属于 **`node-addon-require-builtin`**；sibling 的声明是 `^0.1.5-rc.1` / `^0.1.5-rc.2`。参见 `EXCERPTS-2026-09-23.md` L2 的归因提醒。

### 7.5 [FACT] rc.3 的相关依赖声明发生变化 —— 至少一部分改为 **exact pin**

```text
node_modules/@deepseek-ai/dsh @deepseek-ai/cordis@4.0.2                OK for: @deepseek-ai/dsh@0.1.5-rc.3 want: 4.0.2
node_modules/@deepseek-ai/dsh @deepseek-ai/cordis-plugin-hmr@1.0.17    OK for: @deepseek-ai/dsh@0.1.5-rc.3 want: 1.0.17
node_modules/@deepseek-ai/dsh @deepseek-ai/cordis-plugin-include@1.0.7 OK for: @deepseek-ai/dsh@0.1.5-rc.3 want: 1.0.7
node_modules/@deepseek-ai/dsh @deepseek-ai/dsh-base@0.1.5-rc.3         OK for: @deepseek-ai/dsh@0.1.5-rc.3 want: ^0.1.5-rc.3
```

| package | rc.1 / rc.2 | rc.3 |
|---|---|---|
| `@deepseek-ai/cordis` | `^4.0.2` → 实装 **4.0.4** | **`4.0.2`（exact）** |
| `@deepseek-ai/cordis-plugin-hmr` | `^1.0.17` → 实装 **1.0.19** | **`1.0.17`（exact）** |
| `@deepseek-ai/cordis-plugin-include` | `^1.0.7` → 实装 **1.0.9** | **`1.0.7`（exact）** |
| `dsh-*` sibling | `^0.1.5-rc.1` / `^0.1.5-rc.2` → 实装 **rc.3** | `^0.1.5-rc.3` |

### 7.6 [FACT] peer 冲突的结构

```text
525 warn ERESOLVE overriding peer dependency {
525 warn ERESOLVE   edge: { type: 'peer', name: '@deepseek-ai/cordis', spec: '4.0.2', error: 'INVALID',
525 warn ERESOLVE           from: { name: '@deepseek-ai/dsh-acp-app', version: '0.1.5-rc.3', … } }
```

（rc.1 日志的 seq 1508 为同型冲突，`from` 是 `@deepseek-ai/dsh-sandbox-local@0.1.5-rc.3`）

⇒ 冲突对象是 **`@deepseek-ai/cordis`**，peer spec 为 **exact `4.0.2`**，提出方是 **rc.3 的 sibling**。

### 7.7 [FACT] install-scripts blocked

| | rc.1 回滚 | rc.3 恢复 |
|---|---|---|
| npm 自报 | **6 packages** | **5 packages** |
| 唯一包 | 5 | 5 |
| `dsh-subprocess-local` 出现次数 | **2** | **1** |

被阻止的脚本（逐字）：

```text
@deepseek-ai/dsh-subprocess-local@0.1.5-rc.3 (postinstall: node scripts/ensure-spawn-helper.mjs)
koffi@3.3.1                                  (install: node ./cnoke.cjs -P . -D src/koffi --prebuild --release)
node-pty@1.2.0-beta.15                       (install: node scripts/prebuild.js || node-gyp rebuild; postinstall: node scripts/post-install.js)
@google/genai@1.52.0                         (preinstall: echo 'preinstall: no-op')
protobufjs@7.6.6                             (postinstall: node scripts/postinstall)
```

[INFERENCE] `dsh-subprocess-local` 在 rc.1 期被列两次，与同期日志中该包存在**多个嵌套落点**一致；rc.3 只列一次，与树形态收敛一致。**未逐点还原嵌套结构，故为推论。**

---

## 8. Root-cause model

### 8.1 [FACT]（直接观测到，无需推断）

- **mixed-version tree 存在**：顶层 rc.1 / rc.2 期间，内部 sibling 已是 `0.1.5-rc.3`（§7.2/7.3）。
- **vendor caret 漂移存在**：`cordis` 4.0.2→**4.0.4**、`hmr` 1.0.17→**1.0.19**、`include` 1.0.7→**1.0.9**（§7.4）。
- **peer dependency conflicts 存在**：280 个事件，类型 `peer`，对象 `@deepseek-ai/cordis`，`spec: '4.0.2'`，`error: 'INVALID'`（§7.6）。
- **runtime resolution failure 存在**：Loader 报 `@deepseek-ai/dsh-sandbox-local could not be resolved`（§4）。
- **rc.3 对齐后恢复**：ERESOLVE 事件数 280→**0**，boot 与四项能力全部 PASS（§6）。
- **显式回滚无效**：把顶层装回 rc.1 未恢复旧树（§5）。

### 8.2 [INFERENCE] 根因链（**强推论，但非直接 trace**）

```text
top-level broad caret（^0.1.5-rc.1 / ^0.1.5-rc.2）
  → npm 解析到更新的 sibling packages（0.1.5-rc.3）
  → sibling / vendor 版本不一致（rc.3 sibling + cordis 4.0.4）
  → peer 冲突（rc.3 sibling 要求 exact cordis 4.0.2，树中却是 4.0.4）
     + 嵌套 node_modules 树形态异常
  → Loader 无法从 installation anchor 解析 @deepseek-ai/dsh-sandbox-local
  → Cordis 报 plugin tree failed to load
  → rc.3 版本线对齐 + exact pin 后，链式错配消失，恢复正常
```

### 8.3 ★ [UNKNOWN] 必须保留的最后一跳

> **具体是哪一条 dependency edge / 哪一种 nested layout，导致 Loader 最终找不到 `@deepseek-ai/dsh-sandbox-local` —— 未还原。**
>
> - 故障期**完整依赖树快照不存在**（安装树已被 rc.3 覆盖）。
> - Loader 的**解析过程轨迹从未采集**（无 runtime resolution trace）。
> - 因此 §8.2 的**最后一跳**是**推论**，不是直接观测。
>
> **不得把 root-cause model 写成 100% 直接 trace。**

### 8.4 [UNKNOWN] 关于 "INVALID"

日志中 `edge.spec` 与 `dep.version` 均显示 `4.0.2`，却标 `error: 'INVALID'`；同时顶层另有 `cordis@4.0.4` 落点（§7.4）。**是哪一层的版本导致 INVALID，本轮未逐点还原。**

---

## 9. Profile integrity check

**目的**：证明本次事故**不是** profile corruption，并强化 `global DSH install ≠ profile-local bundle membership`。

### 9.1 [FACT] `browser-lab` profile 文件在升级过程中未被修改

| 文件 | size | mtime | 判断 |
|---|---|---|---|
| `package.json` | 308 | `2026-09-15 20:41:43` | **未变** |
| `pnpm-lock.yaml` | 408 | `2026-09-15 20:41:43` | **未变** |
| `pnpm-workspace.yaml` | 114 | `2026-09-15 20:41:41` | **未变** |
| `cordis.patch.yml` | 925 | `2026-09-12 15:10:27` | **未变** |
| `cordis.yml` | 223 | `2026-09-24 12:56:08` | 内容恒为常量（`prepareProfile` 每次 boot 重写）；mtime 变化属**正常预期** |

`browser-lab/package.json` 内容仍含 `dsh-whale-widget` 且 bundles 仍为三项。

### 9.2 [FACT] `web` profile 未被本次全局升级触碰

| 文件 | mtime |
|---|---|
| `web/package.json` | `2026-09-10 15:50:19` |
| `web/cordis.patch.yml` | `2026-08-28 17:21:45` |
| `web/cordis.yml` | `2026-09-12 16:18:42` |
| `web/pnpm-workspace.yaml` | `2026-08-28 17:21:45` |

全部为**升级前**的时间戳。

### 9.3 [FACT] Whale 在 rc.3 上继续活跃运行

`$DSH_HOME` 下 whale 运行时状态在事故后仍在更新：`.dshw-usage.json` 于 `2026-09-24 15:23:33` 被写入（13279 B）；`.dshw-size.json` / `.dshw-turn.json` 于 `2026-09-24 15:21:5x` 被写入。

⇒ **[FACT] 全局安装被整体替换，而 profile-local bundle membership 与运行状态均存活。**

### 9.4 [FACT] `$DSH_HOME/cordis.patch.yml` 仍不存在

跨 profile 共享补丁层在本次事故前后**均不存在**，未参与事故。

### 9.5 附带观察（不改变结论）

`$DSH_HOME/profiles/node_modules`（共享 module fallback）的 `LastWriteTime = 2026/9/23 13:27:45`，**晚于 rc.3 安装（13:11:25）约 16 分钟** ⇒ 由 DSH 的 `healProfilesModuleFallback()` 在 boot 时自愈重建，junction 目标指向**当前**安装。该目录包含 `dsh-sandbox-local`，但**不含** `dsh-whale-widget`（profile-local 插件不进共享层）。详见 `docs/08` §9 与 `docs/07` §6.2。

---

## 10. Layer attribution

| 层 | 角色 | 依据 |
|---|---|---|
| **global DSH installation** | **主因层** | 安装根 `…\npm\node_modules\@deepseek-ai\dsh` 被整体替换；所有冲突路径都在其下 |
| **npm dependency graph（arborist）** | **主因层** | 280 个 ERESOLVE 事件；caret → 更高版本解析；rc.3 的 exact pin |
| **Node module resolution（嵌套 node_modules）** | **症状载体** | 多层嵌套落点；Loader 无法解析 `dsh-sandbox-local` |
| **Cordis runtime** | **报错出口**（非根因） | `plugin tree failed to load` 是对上述解析失败的陈述 |
| **profile composition** | **未涉及** | §9.1 / §9.2 逐文件时间戳 |
| **agent runtime** | **未涉及** | 事故全程未进入 agent 会话层 |

> **明确写死**：**[FACT] Whale 与 `browser-lab` profile 本身最终都没有损坏。**
> 问题集中在：**全局 DSH installation / sibling dependency resolution / plugin resolution**。

---

## 11. FACT / INFERENCE / UNKNOWN

### [FACT]

| # | 事实 | 证据 |
|---|---|---|
| F1 | 三次安装命令与目标版本 | npm argv（`evidence/logs/npm/README.md` §1） |
| F2 | rc.1 / rc.2 顶层以 **caret `^0.1.5-rc.1` / `^0.1.5-rc.2`** 声明 `dsh-*` sibling | `placeDep … want:` 行 |
| F3 | 上述 caret **实际解析到 `0.1.5-rc.3`** | `… CONFLICT for: … want: ^0.1.5-rc.1`，实放 `@0.1.5-rc.3` |
| F4 | rc.1 / rc.2 的 **vendor** 也用 caret 并解析到更高版本（cordis 4.0.4 / hmr 1.0.19 / include 1.0.9 / js-yaml 4.3.2） | `… OK for: … want: …` 行 |
| F5 | rc.3 **改用了 exact pin**（cordis `4.0.2` / hmr `1.0.17` / include `1.0.7`），sibling 为 `^0.1.5-rc.3` | rc.3 日志 |
| F6 | ERESOLVE **事件数**：rc.2 = 280、rc.1 回滚 = 280、rc.3 = **0**（对应行数 12600 / 12600 / 0） | 精确计数 |
| F7 | 冲突类型为 **peer**，对象 `@deepseek-ai/cordis`，`spec: '4.0.2'`，`error: 'INVALID'`，提出方为 rc.3 sibling | ERESOLVE 块 |
| F8 | npm 12 阻止 lifecycle scripts：rc.1 回滚 **6 条 / 5 唯一包**，rc.3 **5 条 / 5 唯一包** | `warn install-scripts` |
| F9 | 被阻止脚本的具体命令（见 §7.7） | 同上 |
| F10 | **回滚顶层版本未恢复旧树**：装回 rc.1 后仍解析出 rc.3 sibling 且仍启动失败 | rc.1 日志 + 人工输出 |
| F11 | rc.3 安装后 `dsh --version` = `0.1.5-rc.3`，boot 与四项能力 PASS | 人工确认 + 2026-09-24 复核 |
| F12 | **当前安装树自洽**：239 个 `@deepseek-ai/*` 中 **230 个为 `0.1.5-rc.3`**；其余 9 个为独立版本线的厂商/工具包（cordis 4.0.2、cordis-plugin-group 1.0.2、include 1.0.7、loader 1.0.3、timer 1.1.4、cosmokit 1.8.5、node-addon-system 0.1.2、schemastery 3.18.2）——**与 rc.3 的 exact pin 吻合** | `evidence/install-snapshots/2026-09-24-dsh-sibling-versions.txt` |
| F13 | 全局 npm 安装**没有 lockfile**（`package-lock.json` 与 `.package-lock.json` 均不存在） | `Test-Path` |
| F14 | `browser-lab` 与 `web` 的 profile 文件在事故前后**未被修改** | §9.1 / §9.2 |
| F15 | Whale 在 rc.3 上持续活跃（状态文件事故后仍在写入） | §9.3 |

### [INFERENCE]

| # | 推论 | 强度 |
|---|---|---|
| I1 | §8.2 的根因链（caret → 更新 sibling → 版本错配 → peer 冲突 + 嵌套树 → Loader 失败） | **强**（F2–F7 均已为 FACT），但**最后一跳未直接观测** |
| I2 | rc.3 的恢复由 **版本线对齐 + exact pin** 共同作用 | **中**（无法拆分各自贡献，见 U3） |
| I3 | rc.1 期 `dsh-subprocess-local` 在 allow-scripts 列表出现两次，反映存在**多份嵌套副本** | **中** |
| I4 | 回滚失败的机制是"重新 install 会重新解析 semver 范围"，而非缓存损坏 | **强**（F3/F10） |
| I5 | `profiles/node_modules` 在 boot 时被 `healProfilesModuleFallback()` 重建并重新指向当前安装 | **强**（mtime 差 + 源码注释；重建过程本身未逐步观测） |

### [UNKNOWN]

| # | UNKNOWN |
|---|---|
| U1 | **npm 对 prerelease 的 caret 完整匹配规则** —— 本轮只证明了**结果**（`^0.1.5-rc.1` 命中 `0.1.5-rc.3`），**未独立验证规则本身** |
| U2 | **哪一条具体 dependency edge / 哪种嵌套 layout** 导致 Loader 最终无法解析 `dsh-sandbox-local`（§8.3） |
| U3 | rc.3 的恢复究竟是 **exact pin** / **package manifest 修复** / **layout 改变** / **release-line alignment** 中的哪一项起决定作用（三者同时变了，无法拆分） |
| U4 | `error: 'INVALID'` 与同时存在的 `cordis@4.0.4` 落点之间的精确关系（§8.4） |
| U5 | install-scripts blocked 是否影响 **PTY / native subprocess / sandbox / 其他未测 agent tools** |
| U6 | 官方是否已有对应的 issue / fix / release note |
| U7 | DSH prerelease 安装是否应使用 **exact version / lock / overrides / 专用流程**（目前只有 [RECOMMENDATION]） |
| U8 | 之前的 **file read/write consistency guard** 问题与本次升级是否存在关系（**无证据，不关联**） |
| U9 | 事故前（rc.1 原始安装）的**完整依赖树** —— 从未记录，且已被覆盖 |

---

## 12. Evidence

| 内容 | 路径 |
|---|---|
| npm 原件：rc.2 首次升级 | `../../evidence/logs/npm/2026-09-23T04_00_54_627Z-debug-0.log`（sha256 `BE2910A8…`） |
| npm 原件：rc.1 回滚 | `../../evidence/logs/npm/2026-09-23T04_38_36_190Z-debug-0.log`（sha256 `225D598E…`） |
| npm 原件：rc.3 恢复 | `../../evidence/logs/npm/2026-09-23T05_11_08_017Z-debug-0.log`（sha256 `9736C6C2…`） |
| 原件说明与检索指引 | `../../evidence/logs/npm/README.md` |
| 关键行提炼 | `../../evidence/logs/npm/EXCERPTS-2026-09-23.md` |
| 当前安装树版本快照 | `../../evidence/install-snapshots/2026-09-24-dsh-sibling-versions.txt` |
| 长期知识 | `../../docs/08-dsh-installation-and-upgrade.md` |
| 相关：profile / bundle 隔离 | `../../docs/07-profile-bundle-isolation.md` |
| 相关：全局安装被替换后 profile-local 存活的前序实验 | `../profile-isolation/2026-09-15-whale-widget-browser-lab-install-e2e.md` |

---

## 13. Lessons / Recommendations

> 以下均为 **[RECOMMENDATION]**（操作性建议），**不冒充官方规范**。

1. **prerelease DSH 安装优先显式指定 exact top-level version**（`npm install -g @deepseek-ai/dsh@<exact>`）。本次 rc.3 的成功安装正是显式指定版本的。
2. **升级前记录基线**：`dsh --version`、`npm view … dist-tags`、`npm ls -g @deepseek-ai/dsh --depth=0`、以及 profile 文件指纹（size + mtime + hash）。
3. **不要**把"重新安装旧 top-level version"当作完整 rollback。全局 npm 安装**没有 lockfile**，无法恢复旧依赖树；正确做法是**对齐 release line**，而不是回退单点版本。
4. **升级后按层验证**，而不是只看 `dsh --version`：
   - 安装层：`npm ls -g`、sibling 版本一致性、有无 `ERESOLVE`
   - 解析层：能否 boot 一个 profile
   - 应用层：Web UI / 已挂载的第三方 bundle / Browser MCP
   - **profile 完整性**：profile 文件 mtime 是否被意外改动
5. **区分两个安装层**：`npm install -g @deepseek-ai/dsh`（全局安装）与 `dsh plugin --profile <name> add <pkg>`（profile-local）互不隶属。诊断时先确认故障在哪一层。
6. **`install-scripts blocked` 应记录，但不要未经验证就全部 allow**。当前 [FACT] 已测工作流（browser-lab / Web UI / Whale / Browser MCP）正常；[UNKNOWN] PTY / native subprocess / sandbox 等边界。
7. **保留 npm 日志**。npm 默认 `logs-max=10`，超限会静默裁剪；事故证据应在恢复后**立即**移出 `_logs` 目录（本次已归档到 `evidence/logs/npm/`）。
8. **不要把版本升级计划与"观察某个疑似 bug 是否改善"绑定**。本次把两个目的混在一起，使归因更复杂；file consistency guard 与本事故**关系未验证**，应作为独立研究线。

# Whale Widget × Profile 隔离 —— 实验前准备与基线记录（Prep + Pre-experiment Baseline）

- **日期**：2026-09-15（记录窗口 20:03–20:12）
- **类型**：read-only 准备轮（prep）。**本轮不执行任何安装/挂载/配置变更。**
- **被测命题**：
  > bundle 的归属单位是 **profile**：只加到 `web` 的 bundle，不应自动进入 `browser-lab` 的合成 Cordis 树。
- **本轮成功判据**（用户口径）：
  > 不是"证明插件能用"，而是"证明我们已经具备一个干净、可归因的实验前基线"。
- **归属纪律**（贯穿全文）：
  - [FACT] 只写已被源码/磁盘/进程观察直接证实的；
  - [INFERENCE] 写明推论链；
  - [UNKNOWN] 不为了完整性升格；
  - **"package 在磁盘上存在" ≠ "某个 profile 拥有这个 bundle"**。

---

## 0. 本轮禁止项与实际遵守情况

| 禁止项 | 本轮行为 |
|---|---|
| `dsh plugin … add` | 未执行 |
| 安装 `dsh-whale-widget` | 未执行 |
| 修改 `web` / `browser-lab` profile | 未执行（仅 stat/读取） |
| 修改 `$DSH_HOME` | 未执行 |
| 修改 settings / Browser MCP 配置 | 未执行 |
| 启动新的 DSH 实例 | 未执行 |
| 重启当前 DSH | 未执行 |
| 删除文件 | 未执行 |
| 为验证方便临时改配置 | 未执行 |
| 发现 DSH 进程时只记录、不干预 | 已遵守（见 §2.3） |

**唯一写入**：本知识库文档（`experiments/profile-isolation/`），不属于上述任何禁止项。

---

## 1. 目标仓库事实（A）

- **仓库**：`https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget`
- **npm 包名 / 版本**：`dsh-whale-widget@0.3.0`
- **抓取方式**：GitHub REST tree API（`/git/trees/HEAD?recursive=1`）+ `raw.githubusercontent.com/main/*`
- **HEAD sha**：`40cebc2937aea674247a0d0e03e16c154f7b9864`

### 1.1 仓库结构 [FACT]

```
DeepSeek-Balance-Whale-Widget/
├─ package.json                 (1020 B)
├─ cordis.patch.yml             (719 B)     ← 挂载声明
├─ README.md                    (27998 B)
├─ whale-widget-prompt.md       (21457 B)   ← 完整规格/架构文档
├─ LICENSE  .gitignore  .github/workflows/publish.yml
├─ lib/index.js                 (152701 B)  ← 宿主侧插件本体
└─ assets/                      ← 前端与前端资源
   ├─ whale-widget.js (650618 B)  DSH2.png  DSniang1.png  DSniang02.png
   ├─ rua.gif  bubble-petpet.gif  bubble-money1.gif
   └─ Ya1/Ya2/D1/D2.mp3  minecraft-exp-orb.wav  task-end-a.wav
```

### 1.2 包元数据 → 这是 **bundle**，不是普通依赖 [FACT]

```json
{
  "name": "dsh-whale-widget",
  "version": "0.3.0",
  "type": "module",
  "main": "lib/index.js",
  "files": ["lib", "assets", "cordis.patch.yml", "README.md"],
  "dsh": { "bundle": { "patch": "./cordis.patch.yml" } }
}
```

- `dsh.bundle.patch` 的存在，正是 `reconcilePlugins` 判定"加入 layer stack"的唯一依据（见 §4.2）。
- **注意**：包内 `dependencies` 字段**完全缺失**——它对 DSH 的依赖全部通过运行时 Cordis `inject` 表达（§1.5），不在 npm 依赖图里。

### 1.3 挂载声明内容 [FACT]

`cordis.patch.yml`（全部内容）：

```yaml
- insert:
    - id: dsh-whale-widget
      name: dsh-whale-widget
```

- `insert` **不带 target `id`**，按 DSH patch 语义追加到 **profile 根 entry 列表**。
- `name: dsh-whale-widget` 是包名（由 Loader 从 profile / 安装锚点解析），不是相对路径。
- 文件头部注释同时是安装说明：`dsh plugin --profile web add dsh-whale-widget`。**仓库作者自己把落点写成 `web` profile。**

### 1.4 安装机制（README 给出的 4 条路径）[FACT]

| 方式 | 命令 | 说明 |
|---|---|---|
| A 本地资源包 | `dsh plugin --profile web add link:<abs dir>` | `link:` 软链安装；`file:` 拷贝安装 |
| B GitHub | `dsh plugin --profile web add github:MeteorNOX/DeepSeek-Balance-Whale-Widget` | 走 git，需 `allowBuilds` |
| C 本地仓库 | `dsh plugin --profile web add link:.`（仓库根目录执行） | 不要写成 `link:.\dsh-whale-widget` |
| D npm | `dsh plugin --profile web add dsh-whale-widget` | 发布后 |

- 官方提示：`dsh plugin` 会把参数转发给 **pnpm**，成功后自动把包名加入 `dsh.profile.bundles`。
- 官方提示：安装后需**重启 `dsh web`**，再 F5。
- 卸载：`dsh plugin --profile web remove dsh-whale-widget`。

### 1.5 运行时依赖（决定它能在哪些 profile 生效）[FACT]

`whale-widget-prompt.md` 给出导出形态：

```js
const name = 'dsh-whale-widget';
const inject = ['webServer', 'credentials'];
function apply(ctx) { … }
export { name, inject, apply };
```

并监听 `ctx.on('session/event', …)` 做每轮消耗结算，通过 `webServer.tapIndex` 注入 `<script defer src="/dsh-whale/widget.js">`。

本机 DSH 安装中这两个服务的提供者 [FACT]：

| 服务 | provider 行 id | 所属 bundle |
|---|---|---|
| `webServer` | `webserver` (`@deepseek-ai/dsh-host-webserver`) | **`@deepseek-ai/dsh-web-app`** |
| `credentials` | `credentials` (`@deepseek-ai/dsh-credentials-local`) | `@deepseek-ai/dsh-base` |

**推论 [INFERENCE]**：该 bundle 只有在**同时**含 `dsh-base` 与 `dsh-web-app` 的 profile 上才可能真正 apply；只挂 `dsh-base` 的 profile（如 `dsh plugin` 为自定义 profile 初始化出的默认 `["@deepseek-ai/dsh-base"]`）会让 `inject` 无法满足。

### 1.6 副作用面（实验要观察的"可观测差异"）[FACT]

- **热点路由**：21 条 `/dsh-whale/*` 路由注册在**该进程的 webServer** 上（`/dsh-whale/balance.json`、`/size.json`、`/widget.js`、`/image.png`、`/last-turn.json`、`/audio*.json`、`/sound/*.mp3` …）。
- **页面注入**：`tapIndex` 向 index.html 注入 `<script src="/dsh-whale/widget.js">`。
- **HOME 级状态文件**（注意：写在 `$DSH_HOME` 根，**不是** profile 目录）：
  `.dshw-size.json`、`.dshw-usage.json`、`.dshw-turn.json`、`.dshw-bubble.json`、`.dshw-api.json`、`.dshw-usage-archive.json`、`.dshw-codex.json`；
  目录 `whale-roles/`、`whale-audio/`、`whale-bubble-imgs/`。
- **出网**：`GET https://api.deepseek.com/user/balance`（凭据 `DEEPSEEK_API_KEY`）。
- **凭据写入**：自定义模型密钥写进 DSH 官方凭据服务（本机 `$DSH_HOME/.credentials.yaml`）。

> ⚠️ README 的 `dsh --profile web --dump-config` 验证段落说"应该能看到 `dsh-whale-widget` 在 bundles 里"——**这个措辞不准确**：`--dump-config` 输出的是**合成后的 entry 列表**，不是 `dsh.profile.bundles`。bundle 归属只能看 profile 的 `package.json`。这正是本轮"归属纪律"要防的混淆。

---

## 2. 实验前基线（B）

### 2.1 环境指纹 [FACT]

| 项 | 值 |
|---|---|
| 记录时间 | 2026-09-15 20:03–20:12 |
| DSH 版本 | `@deepseek-ai/dsh@0.1.5-rc.1` |
| Node | `v24.20.0` |
| npm | `12.0.2` |
| pnpm | **NOT FOUND（未安装）** |
| `$DSH_HOME` | `C:\Users\user02\.dsh` |

### 2.2 profile 指纹 [FACT]

| 文件 | 大小 | mtime | SHA-256 |
|---|---|---|---|
| `profiles/web/package.json` | 236 | 2026-09-10 15:50:19 | `B07F71CBA5C341F6BD6EBF1316573588817E3A15629A86F11D34D4A01A82C94B` |
| `profiles/web/cordis.patch.yml` | 217 | 2026-08-28 17:21:45 | `EF189A8C27DB6D63930AA3046A3040482E952EAFCB7487C644D508E8D461F027` |
| `profiles/web/cordis.yml` | 223 | 2026-09-12 16:18:42 | `C300DCF2EBC5F02062D6591268D29D3DB6FE45E0CB138F5467276FE2BA06076E` |
| `profiles/web/pnpm-workspace.yaml` | 61 | 2026-08-28 17:21:45 | `AE7C5B68E2F157528E62885804E69E88583897B775E03C86FCBE52FEAF498ABA` |
| `profiles/browser-lab/package.json` | 244 | 2026-09-11 22:37:50 | `8D5D531DAFD910789DDEFA66DFDBF5132342FFB8A02E1AF7DA3903A2398A7A67` |
| `profiles/browser-lab/cordis.patch.yml` | 925 | 2026-09-12 15:10:27 | `EFBE0E95CB160B52C2F3D5B3C204F1EF6963932EBD99E96F2524D60F74F30C76` |
| `profiles/browser-lab/cordis.yml` | 223 | 2026-09-15 13:34:43 | `C300DCF2EBC5F02062D6591268D29D3DB6FE45E0CB138F5467276FE2BA06076E` |
| `profiles/browser-lab/pnpm-workspace.yaml` | 61 | 2026-09-11 22:37:50 | `AE7C5B68E2F157528E62885804E69E88583897B775E03C86FCBE52FEAF498ABA` |

两个 profile 的 `package.json` [FACT]：

```json
// profiles/web/package.json   (name: dsh-profile-web)
// profiles/browser-lab/package.json   (name: dsh-profile-browser-lab)
{
  "private": true,
  "dependencies": {},
  "dsh": { "profile": {
    "bundles": ["@deepseek-ai/dsh-base", "@deepseek-ai/dsh-web-app"],
    "patchReload": "live"
  } }
}
```

- **bundle 成员完全相同**：两者都是 `["@deepseek-ai/dsh-base", "@deepseek-ai/dsh-web-app"]`。
- `web/cordis.patch.yml` 是纯模板（`[]`，无任何条目）；`browser-lab/cordis.patch.yml` 只含一条 `mcp-playwright` 的 `insert`（Phase 3.4 产物）。
- `cordis.yml` 两者哈希相同 —— 因为它被 `prepareProfile` 每次启动重写为同一常量（§4.4）。
- `pnpm-workspace.yaml` 两者哈希相同（`packages: [.]` + `nodeLinker: hoisted` + `autoInstallPeers: false`）。

### 2.3 运行中的 DSH 进程（**仅记录，未干预**）[FACT]

```
PID 13800   node …/@deepseek-ai/dsh/lib/bin.js --profile browser-lab
            启动于 2026-09-15 13:34:41
            LISTEN 127.0.0.1:3080
PID 13308   npx -y @playwright/mcp@latest --browser=chrome   (browser-lab 的 MCP 子进程)
PID 10448   node … @playwright/mcp/cli.js --browser=chrome
```

- 只有一个 DSH 实例；3180 无监听。
- `--profile browser-lab` 未传 `--port`，默认端口来自 `dsh-web-app` patch 的 `port: !!js ctx.webStartup.port ?? 3080`。

### 2.4 whale 存在性：全部为 **否** [FACT]

| 检查点 | 结果 |
|---|---|
| `web/package.json` 的 `dsh.profile.bundles` 含 whale | ❌ |
| `browser-lab/package.json` 的 `dsh.profile.bundles` 含 whale | ❌ |
| `profiles/web/node_modules/dsh-whale-widget` | ❌ 不存在（`web/node_modules` 为空目录） |
| `profiles/browser-lab/node_modules/dsh-whale-widget` | ❌ 不存在（同上为空） |
| `profiles/node_modules/dsh-whale-widget` | ❌ 不存在 |
| `$DSH_HOME` 下 `.dshw-*` / `whale-*` | ❌ 不存在 |
| 两个 profile 的 `package.json` 含 `dependencies` | ❌ 均为 `{}` |
| 知识库全文检索 `(?i)whale` | ❌ 0 命中 |

### 2.5 全局/共享层存在性 [FACT]

| 路径 | 状态 |
|---|---|
| `$DSH_HOME/cordis.patch.yml`（home 补丁层） | **不存在** |
| `$DSH_HOME/cordis.yml` | 不存在 |
| `$DSH_HOME/package.json` | 不存在 |
| `$DSH_HOME/.agent-presets/` | 不存在 |
| `$DSH_HOME/profiles/node_modules/` | **存在**（共享 module fallback，见 §6.2） |
| `$DSH_HOME/settings.yaml` | 存在（`ui-onboarding` / `locale.preference: en` / `agent-default-model: deepseek-flash`） |
| `$DSH_HOME/.credentials.yaml` | 存在（223 B） |
| `$DSH_HOME/AGENTS.md` | 存在（626 B，全局长语言策略） |
| `$DSH_HOME/storages/` | `workspace.json` (1193 B)、`session_projcache.json` (7911 B) |

### 2.6 已有 composed-tree dump（历史基线）[FACT]

| 文件 | 大小 | 时间 | 条目数 | SHA-256 |
|---|---|---|---|---|
| `evidence/config-dumps/browser-lab-composed-tree-BEFORE-mcp.yml` | 17614 | 2026-09-12 15:10:24 | 152 | `359C02847B7184FCB7AD741D45A68FD3DD01C089CEC5D7662F146AAB3824ED18` |
| `evidence/config-dumps/browser-lab-composed-tree-AFTER-mcp.yml` | 17936 | 2026-09-12 15:10:31 | 153 | `281CDA93787B72D37095F2F3442CDBEE770E68C5F012CD8A2ACCBB163E7C0934` |

两份 dump 的 entry id 差集**恰好一项**：`mcp-playwright` [FACT]。

### 2.7 为什么本轮**没有**新产出 `web-before-whale.yml` / `browser-lab-before-whale.yml`

用户提议的这两个文件名，**本轮主动放弃生成**，原因如下：

1. `--dump-config` 走 `prepareProfile`，而 `prepareProfile` **无条件重写** profile 的 `cordis.yml`（`writeFileSync`）→ 属于"写 profile"。
2. 且它必须**新起一个 DSH 进程** → 违反"不启动新实例"。
3. **活证据**：`browser-lab/cordis.yml` 的 mtime = `2026-09-15 13:34:43`，正好是 PID 13800 启动（`13:34:41`）后 2 秒 —— 启动即重写 [FACT]。

**替代方案（本轮采用，且不伪造溯源）**：

- `browser-lab` **当前** pre-whale 合成树 = 现存 `browser-lab-composed-tree-AFTER-mcp.yml`。
  理由：bundle 列表未变（§2.2），profile patch 自 2026-09-12 15:10:27 起未变，安装版本未变（§2.2/§2.1）。
  这仍是 **[INFERENCE]**（"输入未变 ⇒ 输出不变"），不是新采样的 dump。
- `web` **当前** pre-whale 合成树：
  **[INFERENCE]** 与 `browser-lab-composed-tree-BEFORE-mcp.yml` 内容等价 —— 因为两者 bundle 列表完全相同、`web` 的 patch 层为空、无 home 层、无 `--patch` overlay；且 BEFORE dump 内**不含任何 profile 专属绝对路径**（全文只有 `!!js process.env.*` 表达式），说明它是这些输入的纯函数。
  证据强度：**中**（强推论，非实测）。

> 若需要**实测**的 web dump，必须在实验轮执行：先停止/避开 PID 13800 的 3080 占用，再运行一次 `dsh --profile web --dump-config`（需 pnpm 无需安装，但会重写 `web/cordis.yml`——内容不变、mtime 变）。

### 2.8 基线的工具链前置缺口 [FACT]

- **pnpm 未安装** → `dsh plugin --profile web add …` 会走 `spawnSync("pnpm", …)`，`ENOENT` 分支直接返回 **127** 并打印 `dsh: pnpm not found on PATH — install pnpm to manage profile plugins`。
- 因此**正式实验的第一步前置**是安装 pnpm（全局环境变更，超出本轮范围）。

---

## 3. profile 合成模型（源码证据）

全部证据来自本机安装：

- `…\node_modules\@deepseek-ai\dsh\lib\profile-boot-Dk-7KqJc.js`（CLI 侧启动/合成）
- `…\node_modules\@deepseek-ai\dsh\lib\plugin-Ddi42qoW.js`（`dsh plugin` 实现）
- `…\node_modules\@deepseek-ai\dsh\node_modules\@deepseek-ai\dsh-app-boot\lib\index.js`（profile/bundle 解析与 module fallback）

### 3.1 合成顺序 [FACT]

`composeProfile()` 的 patch 栈（`profile-boot` L213–L257）：

```
bundlePatches        ← dsh.profile.bundles 顺序展开的各自 dsh.bundle.patch
profile.patches      ← <profile>/cordis.patch.yml
homePatches          ← $DSH_HOME/cordis.patch.yml      （注释原文：machine-local preferences that apply to every profile, so it outranks the per-profile layer）
overlays             ← CLI --patch（argv 顺序）
(+ telemetry switch  ← DSH_TELEMETRY_DISABLED 生成的单行 overlay)
```

最终：

```js
composeEntries([bundlePatches, profile.patches, homePatches, overlays])
  === applyEntryPatches([], layers.flat())   // 与 boot include 同一次调用
```

即：**一次 `applyEntryPatches`，later patch wins；`config` 整键替换；`disabled` 后写覆盖。**

### 3.2 谁决定"哪些 bundle 属于某个 profile" [FACT]

`loadProfileDirectory()`（`dsh-app-boot` L843–L871）：

```js
const manifest = readProfileManifest(binName, dir);        // 只读这一个 package.json
const bundles  = manifest.dsh?.profile?.bundles ?? [];
const layers = bundles.map((packageName) => {
  const packageDir = resolveBundleDir(binName, packageName, installAnchor, dir);
  const declared   = JSON.parse(readFileSync(join(packageDir,'package.json'),'utf8')).dsh?.bundle?.patch;
  if (declared === undefined) throw new Error(`dsh: profile bundle ${...} declares no dsh.bundle in its package.json`);
  return { packageName, packageDir, patchPath: join(packageDir, declared), patches: loadOverlayPatches(binName, patchPath) };
});
```

- **唯一输入**是 `$DSH_HOME/profiles/<name>/package.json` 的 `dsh.profile.bundles`。
- 解析锚点顺序（`resolveBundleDir` L826–L832）：**先安装锚点**（`…/@deepseek-ai/dsh/package.json`），**后 profile 目录**；注释明确这是"每个 in-box bundle 永远来自运行中的 dsh 安装"的契约。
- 列了 bundle 但包内没有 `dsh.bundle` → **fail loud**（不是"没有补丁"）。

### 3.3 **没有** profile 间继承 [FACT]

- `initializeProfileFromDefault()` 的源码注释原文：
  > "This copies only the template's bundle list and patch-reload policy; local state from the same-named shipped profile is not read, and **no inheritance metadata is persisted**."
- `loadProfileDirectory` / `loadProfile` 全程只读**单个** profile 目录，不引用任何其他 profile。
- `PROFILE_TEMPLATES` 只有 `acp / web / headless / sdk / sdk-minimal`（`dsh-app-boot` L328–L349）→ **`browser-lab` 不在其中，是自定义 profile**（由 `dsh plugin --profile browser-lab add …` 以 `DEFAULT_PROFILE_BUNDLES = ["@deepseek-ai/dsh-base"]` 初始化，之后补加 `dsh-web-app`）。
- `web` 是**出厂模板名**；但 `normalizeShippedProfile()` 只在 bundle 列表**恰好等于**出厂元组时回写，一旦新增第三方 bundle（如 whale）就不再匹配 → 该列表成为 **user-owned，DSH 不会再动它**。

**结论 [FACT]**：profile 之间不存在继承关系，`browser-lab` 的 Web UI 能力来自它**自己**声明了 `dsh-web-app`，**不是**来自"继承 `web`"。

### 3.4 每次 profile 加载都会重写 `cordis.yml` [FACT]

`prepareProfile()`（`profile-boot` L206–L211）：

```js
const profile = loadProfile(NAME, name, INSTALL_ANCHOR, undefined, { userLayer });
writeFileSync(join(profile.dir, PROFILE_ROOT_FILENAME), PROFILE_ROOT_CONFIG);
```

注释解释：整棵树都是 patch 层，Loader 的 tree write-back 可能把合成行烤进这个文件，导致下次启动重复 insert；该文件存在的唯一理由是给 Loader 一个真实的 include root 来锚定 `baseUrl`。

→ 因此 `web/cordis.yml` 与 `browser-lab/cordis.yml` 内容恒等、哈希相同（§2.2 已实测）。

---

## 4. `dsh plugin --profile web add <pkg>` 源码行为

实现位于 `plugin-Ddi42qoW.js`（全文 130 行）。

### 4.1 它写哪里 [FACT]

```js
function runPlugin(profile, args) {
  const dir = resolveProfileDir(profile);                 // $DSH_HOME/profiles/<profile>
  if (!existsSync(join(dir,'package.json'))) { …initProfile(dir, template?.bundles ?? DEFAULT_PROFILE_BUNDLES, …) }
  const before = readProfileManifest(NAME, dir);
  const result = spawnSync("pnpm", args.map(a => anchorPathSpec(a, process.cwd())), { cwd: dir, stdio: "inherit", shell: win32 });
  if (exitCode === 0) reconcilePlugins(before, dir);
}
```

- `resolveProfileDir(name, home)` = `join(home, "profiles", name)`，并对 name 做校验（拒绝 `""`、`/`、`\`、`.`、`..`、`node_modules`）。
- pnpm 的 **cwd = 该 profile 目录** → 安装落点在 `<profile>/node_modules`，依赖清单写在 `<profile>/package.json`。
- 仅有的 manifest 写入是 `writeProfileManifest(profileDir, after)` —— **同一目录内**。

**→ 全程没有任何一处写入其他 profile、`$DSH_HOME` 根、或共享 fallback 目录。** [FACT]

### 4.2 什么时候进 `dsh.profile.bundles` [FACT]

`reconcilePlugins()`：

```js
for (const packageName of dependencies) {
  const isBundle = exportsPatch(packageName, profileDir);       // resolveBundleDir(...) + readProfileManifest(dir).dsh?.bundle?.patch !== undefined
  if (isBundle && !plugins.includes(packageName)) { plugins.push(packageName); changed = true; }
  else if (!isBundle && !beforeDeps.has(packageName)) stderr.write("… declares no dsh.bundle — installed as a plain dependency, not a profile layer …");
}
// 反向：曾经是 dependency 且已不再是 bundle → 从 plugins 中移除
```

- 判定依据是**安装后的真实解析状态**，不是命令行 spec → `github:` / `file:` / `link:` / 别名都能按真实包名回收。
- 非 bundle 的依赖**不会**成为 layer，只打印一行 warning。
- 模板自带的 in-box bundle 不是 dependency，**永不被此逻辑触碰**。

### 4.3 对 whale 的具体推演 [INFERENCE，链路为 FACT]

`dsh plugin --profile web add dsh-whale-widget`：

1. `dir = C:\Users\user02\.dsh\profiles\web`
2. pnpm 在 `web/` 下安装 `dsh-whale-widget`，写入 `web/package.json` 的 `dependencies`
3. `exportsPatch("dsh-whale-widget", web_dir)` → `resolveBundleDir` 命中 → 读到 `dsh.bundle.patch = "./cordis.patch.yml"` → **true**
4. `web/package.json` → `dsh.profile.bundles = ["@deepseek-ai/dsh-base","@deepseek-ai/dsh-web-app","dsh-whale-widget"]`
5. 重启以 `web` 启动的 DSH → whale patch 成为第 3 个 bundle layer → `insert` 把 `{id: dsh-whale-widget, name: dsh-whale-widget}` 追加到根 entry 列表 → 插件 apply（`inject: webServer, credentials` 均满足）→ 注册 21 条路由 + `tapIndex`。

**`browser-lab` 全程零参与**。

### 4.4 `--dump-config` 是不是写操作 [FACT]

是。`--dump-config` → `prepareProfile(name, userLayer=true, …)` → `loadProfile(...)` + **`writeFileSync(<profile>/cordis.yml, PROFILE_ROOT_CONFIG)`**。

---

## 5. 理论矩阵判定（E）

命题拆成可判定的子句：

| # | 子句 | 判定 | 依据 |
|---|---|---|---|
| E1 | bundle 归属记录在 profile 的 `package.json: dsh.profile.bundles` | ✅ **成立** | §3.2、§4.2 |
| E2 | 该归属记录是 `loadProfileDirectory` 的**唯一** layer 输入 | ✅ **成立** | §3.2（只读单个 manifest） |
| E3 | 不存在 profile→profile 继承 | ✅ **成立** | §3.3（源码注释显式否认 + 无继承元数据） |
| E4 | 只装进 `web` 的包，**不会**写进 `browser-lab` 的 bundles | ✅ **成立** | §4.1（`runPlugin` 的写入面仅限 `--profile` 指定目录） |
| E5 | 只装进 `web` 的包，**不会**出现在 `browser-lab` 的合成树 | ✅ **成立（推论）** | E2+E3+E4 ⇒ 该包的 patch 不会进入 browser-lab 的 layer 栈 |
| E6 | 只装进 `web` 的包，**不会**出现在 `browser-lab` 进程的 HTTP 路由里 | ✅ **成立（推论）** | 路由由插件 apply 时注册；E5 ⇒ 未 apply；且两者是**不同进程**（§2.3） |
| E7 | `package 在磁盘上存在` 等价于 `某 profile 拥有该 bundle` | ❌ **不成立**（明确否定） | 归属只看 bundles 列表；磁盘存在性只是 resolvable |
| E8 | 官方支持"把 bundle 只加到 `web`"这一用法 | ✅ **成立** | whale 自带 `--profile web` 安装说明；`PROFILE_TEMPLATES.web` 存在 |

**总结 [INFERENCE，基于上述 FACT]**：
命题整体**成立**，且已在源码层面可判定；E5/E6 尚缺**同一机器上的端到端实测**（那是正式实验的任务，见 §7）。

**必须保留的反例边界**（否则 E5 会被过度泛化）：

- 如果 `$DSH_HOME/cordis.patch.yml` 存在且含 `insert` whale → **所有 profile 都会拿到**（§6.1）。
- 如果启动时用 `--patch <file>` → 该次启动的所有 profile 都会拿到（§6.3）。
- 如果 pnpm 把包装到了 `profiles/node_modules`（共享 fallback 目录）→ 包对 browser-lab 变得**可解析**，但**仍不是 bundle layer**（§6.2）→ 这正是"package 在磁盘上存在 ≠ profile 拥有 bundle"的字面实例。

---

## 6. 全局 / 共享层风险（F）

按"能否把 web-only bundle 泄漏到 browser-lab"排序：

### 6.1 `$DSH_HOME/cordis.patch.yml`（home 补丁层）—— 唯一真正的泄漏通道 ⚠️

- 代码：`homePatchPath() = join(resolveDshHome(), "cordis.patch.yml")`；`composeProfile` 把它排在 **profile 层之后**，注释原文："machine-local preferences that **apply to every profile**, so it **outranks** the per-profile layer"。
- 且它是 **hot-watch** 的（`watchUserPatches(ctx, { filename: homePatchPath(), compose: composeLive })`）—— 改文件即对所有已加载 profile 生效。
- **当前状态：文件不存在** [FACT]。
- 风险：任何人若把 whale 的 `insert` 写进这里，就等于"全局安装"，命题的隔离性立即失效。
- **风险等级：高。实验必须显式断言该文件在 BEFORE/AFTER 均不存在。**

### 6.2 `$DSH_HOME/profiles/node_modules/`（共享 module fallback）

- 由 `healProfilesModuleFallback()` 维护；源码注释："The shared `$DSH_HOME/profiles/node_modules` **mirrors the dsh installation dependency closure**."
- 实测内容：全部是指向 `…\npm\node_modules\@deepseek-ai\dsh\node_modules\@deepseek-ai\*` 的 **Junction**（`dsh`、`dsh-base`、`dsh-app-boot`、`dsh-web-app`、`dsh-mcp-client` …），且是 `profiles/` 这一层的一个**真实目录（非 junction）**。
- 每个 profile 另有**私有**的 `<profile>/.dsh-module-fallback/node_modules`（本机两个都为空）+ 由它软链进 `<profile>/node_modules`（本机两个都为空）。
- 源码注释明确："pnpm-managed entries remain authoritative, and **another profile's links cannot change its resolution**."
- 风险：即便某天 whale 出现在这里，它只是**可解析**；`dsh.profile.bundles` 不变 ⇒ 不是 layer ⇒ 不进树。
- **风险等级：低（但必须用"归属纪律"把它写清楚，避免误读为"browser-lab 有了"）。**

### 6.3 `--patch` overlay

- `overlays` 来自 argv，排在栈的最后一层（最高优先级）。
- `loadOverlayPatches(NAME, resolve(file))`，与 profile 无关。
- 风险：实验期间若用 `--patch` 做注入，等于人为取消隔离。
- **风险等级：中（可控，只要不主动使用）。**

### 6.4 出厂模板归一化 `normalizeShippedProfile`

- 只对**出厂模板名**（含 `web`）且 bundle 列表**恰好等于**元组时回写 `package.json`。
- 一旦 `web` 的列表变成 `[base, web-app, dsh-whale-widget]`，就不再匹配 ⇒ 列表变为 user-owned，DSH 不再自动改写。
- 反向风险：这也意味着**升级 DSH 不会帮你清理**已加入的 user-owned bundle。
- **风险等级：低。**

### 6.5 进程/端口耦合（实践陷阱）

- `web` 与 `browser-lab` 的 webServer 默认端口都是 **3080**（`port: !!js ctx.webStartup.port ?? 3080`）。
- 当前 3080 被 PID 13800（browser-lab）占用 [FACT]。
- 风险：装完 whale 后直接 `dsh web` 会端口冲突（本知识库已有 `evidence/logs/browser-lab-first-boot-EADDRINUSE.log` 同类先例）。实验需显式指定 `--port` 或先停 browser-lab。
- **风险等级：中（可操作，但必须在设计里写死）。**

### 6.6 `$DSH_HOME` 根级的**运行时状态**共享

- whale 的 `.dshw-*.json`、`whale-roles/`、`whale-audio/`、`whale-bubble-imgs/` 都在 `$DSH_HOME` 根，**不按 profile 分目录**。
- 推论 [INFERENCE]：若同一台机器上两个 profile 都挂了 whale，两者会**共享同一份外观/账本状态**（乃至并发写同一文件）。
- 本实验只挂 `web`，所以这属于"未来风险"，但它是"profile 隔离"这一命题的**重要边界反例**。
- 另有 `$DSH_HOME/AGENTS.md`（agent 层，对所有 profile 生效）、`settings.yaml`、`.credentials.yaml`、`storages/`、`sessions/` 也都是 HOME 级共享。

### 6.7 环境变量对合成结果的影响

- 合成树里有大量 `!!js process.env.*`（`DSH_TELEMETRY_MODE`、`DSH_TELEMETRY_OTLP_URL`、`DSH_PERMISSION_MODE`、`DSH_TOOLS_MODE` …），并由 `resolveTelemetryPatch(DSH_TELEMETRY_DISABLED, …)` 追加可能的单行 overlay。
- ⇒ **dump 是环境的函数**，不是纯配置的函数。两次 dump 的差异分析必须固定环境变量。

---

## 7. 正式实验设计（G，**本轮不执行**）

### 7.1 前置（需用户批准，属于全局变更）

1. 安装 pnpm（`dsh plugin` 硬依赖，当前 NOT FOUND）。
2. 准备 whale 来源（`github:` 或本地解压目录）；`github:` 方式还需处理 pnpm `allowBuilds` 拦截。
3. 端口规划：停掉 browser-lab 的 3080 占用，或给 web 实例显式 `--port`。
4. 确认 `$DSH_HOME/cordis.patch.yml` 在全程不存在（或内容冻结）。

### 7.2 观测矩阵（BEFORE / AFTER）

| 观测量 | 采集方式（只读优先） | `web` BEFORE | `web` AFTER | `browser-lab` BEFORE | `browser-lab` AFTER |
|---|---|---|---|---|---|
| O1 `dsh.profile.bundles` | 读 `package.json` + SHA-256 | 无 whale | **应含** whale | 无 whale | **应仍无** whale |
| O2 `dependencies` | 同上 | `{}` | 应含 whale | `{}` | `{}` |
| O3 磁盘可解析性 | `Test-Path <profile>/node_modules/dsh-whale-widget` | False | True | False | **False** |
| O4 共享 fallback | `Test-Path $DSH_HOME/profiles/node_modules/dsh-whale-widget` | False | **待测**（预期 False） | False | 同上 |
| O5 合成树 Entry | `dsh --profile <n> --dump-config`（**写 `cordis.yml`，需新进程**） | 152 entries | 应 +1 = 153 | 153 entries | **应仍 153** |
| O6 HTTP 路由 | `curl 127.0.0.1:<port>/dsh-whale/balance.json` | 404 | 200 或 401/403（信任栅栏） | 404 | **应仍 404** |
| O7 页面注入 | `curl /` 看是否含 `/dsh-whale/widget.js` | 无 | 有 | 无 | **应仍无** |
| O8 HOME 状态文件 | 枚举 `$DSH_HOME/.dshw-*`、`whale-*` | 无 | **可能出现** | 无 | 不新增（browser-lab 未运行 whale） |
| O9 profile 文件哈希 | §2.2 全表 | 冻结 | 仅 web 变 | 冻结 | **应全部不变** |

**O9 是判定"零泄漏"最硬的证据**：`browser-lab/{package.json,cordis.patch.yml,cordis.yml}` 三份哈希在 AFTER 必须与 BEFORE 完全一致。

### 7.3 必须预设"反例触发"步骤（否则实验只是自证）

1. **负向对照 N1**：把 whale 的 `insert` 放进 `$DSH_HOME/cordis.patch.yml` → 预期 **browser-lab 也拿到**（证明 §6.1 泄漏通道真实存在，隔离不是"自动化保证"）。
   - ⚠️ 该步骤会修改 `$DSH_HOME`，须单独批准并在结束后复原（记录前后哈希）。
2. **负向对照 N2**：在 browser-lab 启动参数上加 `--patch <whale insert>` → 预期**当次运行**生效。用于分离"layer 来源"与"进程"。
3. **对照 N3（非 web profile）**：把 whale 加到 `headless` profile（只有 `dsh-base`）→ 预期 `inject: ['webServer']` 无法满足，插件不 apply（验证 §1.5 推论）。

### 7.4 判据

- **主假设成立**：O1(browser-lab)=无 whale ∧ O3(browser-lab)=False ∧ O5(browser-lab) 不变 ∧ O6/O7(browser-lab)=404/无 ∧ O9(browser-lab) 哈希不变。
- **主假设被推翻**：任一 browser-lab 观测量出现 whale 痕迹 —— 此时必须沿 §6 逐条定位泄漏通道，**不得**归因于"DSH 会自动同步"。

### 7.5 归属纪律（写进实验记录的硬约束）

- 不得把"`profiles/node_modules` 里能解析到 whale"写成"browser-lab 拥有 whale"。
- 不得把 `--dump-config` 的 entry 列表写成 `dsh.profile.bundles`。
- 不得把 O6 的 **401/403** 写成"插件失败"（那是信任栅栏在工作），也不得把 404 与 401/403 混为一谈。
- 任何"AFTER 有变化"的结论，必须同时给出"变化的写入者是谁"（`runPlugin` / `prepareProfile` / 手工编辑）。

---

## 8. 本轮知识库产出（H）

| 文件 | 状态 | 说明 |
|---|---|---|
| `experiments/profile-isolation/2026-09-15-whale-widget-profile-isolation-prep.md` | **新建** | 本文件：A–I 全部结论与实验设计 |
| `experiments/profile-isolation/` | **新建目录** | profile 隔离专题 |
| 其余 `docs/`、`evidence/`、`scripts/`、`archive/` | **未改动** | 本轮不引入未经实测的新 dump |

**刻意未做**：

- 未生成 `evidence/config-dumps/web-before-whale.yml` / `browser-lab-before-whale.yml`（理由见 §2.7）。
- 未把 §2.7 的 [INFERENCE] 提升为 [FACT]。

---

## 9. 遗留 UNKNOWN（I）

| # | UNKNOWN | 影响 | 消解方式 |
|---|---|---|---|
| U1 | 本轮**没有实测** `web` 的 composed tree；其"等价于 BEFORE-mcp dump"是强推论而非实测 | E5 的证据强度 | 实验轮跑一次 `dsh --profile web --dump-config` |
| U2 | pnpm 安装 whale 时**是否**会写入 `$DSH_HOME/profiles/node_modules`（共享 fallback） | §6.2 风险等级 | AFTER 阶段检查该目录 + 其 mtime |
| U3 | `github:` 方式安装时 pnpm 的 `allowBuilds` 是否需要人工干预（whale 的 `publish.yml` 存在，包内有 `prepare` 才需要）| 前置步骤可行性 | 读 `package.json` scripts（当前 `package.json` 未声明 `scripts` → [INFERENCE] 大概率不需要） |
| U4 | whale 在 `inject` 不满足时（非 web profile）的**确切**表现：完全不 apply / 报错 / 阻塞 boot | N3 对照的预期值 | 实验轮实测 |
| U5 | `dsh plugin` 在 pnpm 缺失时是否**留下半成品**（例如已 init profile 但未安装） | 失败恢复 | 读源码：`initProfile` 在 `spawnSync` 之前 ⇒ **会**留下已初始化的 profile [FACT 级源码推论]；实际行为待测 |
| U6 | 两个 profile 若都挂 whale，`.dshw-*` 的并发写行为 | §6.6 | 未来实验 |
| U7 | whale 的 `tapIndex` 注入是否对其他 profile 的 index.html 有影响（不同进程则无） | 隔离边界 | 与 O7 合并验证 |
| U8 | README 所述 GitHub 仓库/npm 包是否与 `main` 分支 HEAD 完全一致（未取 npm registry 元数据） | 溯源 | 实验轮 `npm view dsh-whale-widget`（注意 `--cache` 指向可写目录） |
| U9 | `$DSH_HOME/settings.yaml` 的 `locale.preference: en` 与 whale UI 的中文文案是否有交互 | 低 | 忽略 |
| U10 | `browser-lab` 是否是唯一自定义 profile；未来新建自定义 profile 的默认 bundles 是 `["@deepseek-ai/dsh-base"]`（**不含 web-app**） | 实验前提 | 已 [FACT]：`DEFAULT_PROFILE_BUNDLES` |

---

## 10. 一句话结论

> 在本机 0.1.5-rc.1 上，**bundle 归属是 profile 私有的事实**已有完整源码链证明：写入面（`runPlugin`）、读取面（`loadProfileDirectory`）、以及"无继承"（源码注释显式否认）三者闭合。
> 当前 `web` 与 `browser-lab` 的 bundle 列表**完全一致且都不含 whale**，`$DSH_HOME` 无任何 whale 痕迹，home 补丁层不存在 —— **基线干净、可归因**。
> 唯一的真实跨 profile 泄漏通道是 `$DSH_HOME/cordis.patch.yml`；其余共享层（`profiles/node_modules`、HOME 级运行时状态）只影响**可解析性/状态共享**，不影响 **layer 归属**。
> 端到端实测（E5/E6）需要 pnpm + 一次 `web` 实例启动，属下一轮。

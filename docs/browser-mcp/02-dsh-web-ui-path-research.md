# 02 — DSH Web UI 官方操作路径研究（三平面与 UI 覆盖度）

> **文档定位**：**长期知识文档**（`docs/browser-mcp/`）。本文件提出并论证了 **DSH 的「三平面」框架**（Profile management / Host plugin composition / Agent preset composition）与各平面的 UI 覆盖度；这是判断"MCP 能不能从 UI 配置"的依据。上层集成见 `docs/05-browser-mcp.md`。
> **证据等级**：文中 `[FACT]` / `[INFERENCE]` / `[UNKNOWN]` 沿用原文标注。

**范围**：仅调查 DSH Web UI 是否提供 Profile 管理、Profile 选择、以及向 Profile 添加/配置 Plugin instance 的**官方 UI 路径**。
**阶段**：研究（**未创建 profile、未修改配置、未安装任何东西、未装 pnpm、未装 Playwright MCP**）
**DSH**：`@deepseek-ai/dsh@0.1.5-rc.1` · 实际运行进程：PID 19696 `dsh web --no-open`（监听 127.0.0.1:3080）

> 证据来源 = 本机已装包的 README / `lib/*.js` / `lib/types/*.d.ts` 直读 +
> 已合成的 `dsh --profile web --dump-config`（539 行）+ 对 3080 的只读 HTTP 探测。
> 未依据任何其他版本的文档推测。

---

## 0. 先厘清三个平面（这是本次调查的核心框架）

DSH 里"插件"这个词横跨三个**互不相通**的平面。混为一谈是本次调查要避免的主要错误：

| 平面 | 是什么 | 载体文件 | 谁管理它 | UI 覆盖度 |
|---|---|---|---|---|
| **① Profile management** | 选哪个 profile 启动、profile 的 bundle 列表、模块解析 | `<DSH_HOME>/profiles/<name>/package.json`（`dsh.profile.bundles`）、`cordis.yml` | `dsh` 启动器 / `dsh plugin`(pnpm) | **零** |
| **② Host plugin composition** | profile 根条目列表：装载哪些 Cordis 插件实例及其 config | `<profile>/cordis.patch.yml` + `$DSH_HOME/cordis.patch.yml` + bundle 自带 patch | 手工编辑 patch 层 | **只读**（inventory）+ 仅"配置值"编辑（settings 命名空间） |
| **③ Agent preset composition** | 会话用哪套 agent 组合（工具集、prompt、委派后端） | `<DSH_HOME>/.agent-presets/<id>/agent.cordis.yml`；随包发布的内置 preset 在 `dsh-agent-presets/presets/` | `agentPresets/*` API + UI roster 卡片 | **部分**（复制 / 设默认 / 删除 / 查看；**不能编辑组合文本**） |

**关键区分**：`dsh-mcp-client` 属于 **② Host plugin composition**。
下面所有"UI 能不能加 MCP"的问题，答案都由第 ② 行的覆盖度决定 —— **不能**。

---

## 1. FACT

### 1.1 关于 Profile 管理（问题 1、2）—— **UI 完全没有**

**(a) 没有任何 profile 相关的客户端 / API / host 代码。**
对全部 `dsh-client-ui-*`、`dsh-api-*`、`dsh-host-*`、`dsh-workspace` 包做 `profile` 关键词穷举搜索，
**唯一命中全是无关语义**：

- `dsh-client-ui-brand-official`：构建产物 profile（`official` build profile）
- `dsh-client-ui-settings-models`：LLM provider 的 `profile` 字段
- `dsh-host-open-in-app`：PowerShell `-NoProfile` 参数
- `dsh-client-ui-sidebar-documentpreview`：某个库文件里的字符串
- `dsh-web-frontend`：语法高亮规则

**没有一条**是 DSH profile 的创建 / 列举 / 切换。

**(b) `--profile` 是启动器 + 应用层 CLI 旗标，不是 UI 概念。**
`dsh-web-app/lib/startup.js` 的 `webCommand()` 只解析
`--host / --port / --trusted-host / --no-open`，其 help 文本里的用法是
`dsh --profile web --port 8080` —— **profile 在 `dsh` 启动器层选定，web 应用自己不认识它**。

> **[2026-11-08 版本注记 · `0.2.2-rc.1` 起 web 旗标扩充]** 上一段是 `0.1.5-rc.1` 的旗标集合。
> 本机 `0.2.2-rc.1` 实测 `dsh --profile web --help` 现在接受：
>
> | 旗标 | 语义 |
> |---|---|
> | `--host <host>` | 绑定**一个具体的本地 IPv4/IPv6 字面地址**；**通配地址被拒绝**（不再接受 `0.0.0.0` / `::`） |
> | `--port <port>` | 同上；`0` 表示让 OS 选空闲端口 |
> | `--no-open` | 不自动打开浏览器 |
> | `--public-url <url>` | 在**打印/打开/runtime-context/`DSH_WEB_URL`** 四处广告该 HTTP(S) 根；**不授予信任**；支持带路径前缀的反向代理入口 |
> | `--trusted-host <authority...>` | 追加 `/api` 浏览器信任栅栏接受的口径（可重复） |
> | `--tls-cert <file>` + `--tls-key <file>` | **原生 HTTPS 监听**（PEM 证书链 + 未加密私钥，必须成对给） |
> | `-h, --help` | |
>
> ⇒ 结论对 (b) 仍然成立（profile 仍由启动器层决定，web 应用不认识 profile），
> 但**"web 只有四个旗标"这条已过期**；且"只能跑明文 HTTP"也不再成立。
> 证据：本机 `dsh --profile web --help`（2026-11-08）+ 官方发布块
> "Web 支持通过 `--public-url` 指定…；支持绑定指定的 IPv4/IPv6 地址，并通过 `--tls-cert` 和
> `--tls-key` 配置原生 HTTPS 监听"。
> 审计：`../../experiments/dsh-version-audit/0.2.1-rc.2-to-0.2.2-rc.1/`。

**(c) 插件清点服务明确"不能变更，也不识别 profile"。**
`dsh-host-plugin-inventory/README.md` L100：
> *"**No provenance or mutation** — the service does not identify which bundle, profile, or override introduced an entry, and it cannot enable…"*

即 **连"这个条目来自哪个 profile"都说不出**，更谈不上创建 profile。

**(d) 对 3080 的实测**：`GET /` 与 `GET /api/profile/list`、`/api/profiles`、
`/api/pluginInventory/list` **全部返回 401**。`/api` 是 Typert RPC + 浏览器会话认证
（`dsh-client-connection` 为每个 Host API 方法做会话鉴权），且因为 (a) 已证明代码里不存在
profile 方法，401 只是认证栅栏，**不存在一个未被 UI 暴露但可调的 profile 端点**。

> **结论（问题 1、2）**：**UI 不能创建 profile，不能选择 profile，不能从 web profile 复制/继承，
> 也不会生成任何文件或注册到 DSH_HOME。** 这一整块是 **CLI-only + 文件级**。

### 1.2 关于向 Profile 添加 Plugin instance（问题 3、4）—— **UI 不能**

**(a) 「Plugin configuration」标签页不是"添加器"，而是"值编辑器"。**
`dsh-client-ui-settings-plugins/README.md`：
- 作者卡片的**固定名单**只有 4 个：shell executor（`bash`）、`agent-loop`（工具并行度）、
  `subagent-model-selection`、`web-search-deepseek`（L28）。
- 它渲染什么 = **两个账本的交集**：*"the namespaces a live Host plugin registered, and the
  cards registered under those keys"*（L32）。**没有"添加插件"或"填写 transport/serverName/command/args"的入口。**
- **`dsh-mcp-client` 不在名单里，也不注册 settings 命名空间**（其 config 是 Cordis entry 的 `config`，
  不是 settings namespace）。因此**它的卡片永远不会出现**。

**(b) 写盘目标不是 profile patch。**
卡片保存写入的是 **settings 文档**：`dsh-settings-file/lib/index.js` L32 →
`<harness home>/settings.yaml`（即 `C:\Users\user02\.dsh\settings.yaml`）。
**它不写 `cordis.patch.yml`**。当前该文件只有 4 行（`ui-onboarding` / `locale` / `agent-default-model`），
没有、也不会有 MCP server 条目。

**(c) Plugin 列表标签页是纯只读。**
`dsh-client-ui-settings-plugin-inventory` 的 **Plugin list** 标签：*"lets Web users inspect plugins
**without changing their configuration**"*，agent preset 在前、global 平面折叠。
`dsh-host-plugin-inventory` L40 明说：*"It **cannot enable, disable,** …"*。

**(d) 全局限制（决定性问题）** —— `dsh-client-ui-settings-plugins` L95：
> *"**Only host-plane plugins appear** — a plugin an agent preset mounts carries its configuration
> inline in that preset's `agent.cordis.yml` and **cannot register a settings namespace at all**,
> so this section lists nothing for it."*

L96 还补了一刀：卡片需要浏览器半包，**仓库外的插件必须自己复现那套 lazy-CJS 构建**。

> **结论（问题 3、4）**：**UI 不能添加任何新的 DSH Plugin instance。**
> 不能加 `dsh-mcp-client`，不能填 `transport / serverName / command / args`。

### 1.3 关于 reload（问题 5）—— 分平面回答

| 对象 | 是否有免重启的 reload | 证据 |
|---|---|---|
| `cordis.patch.yml`（平面②） | **有**：`patchReload: live` = 启动后 watch 并热重载 | `profile-boot-Dk-7KqJc.js`（`watchUserPatches`）；web 模板即 `live` |
| MCP server 断线 | **有**：`reconnect` 自动重连（500ms 起、指数退避到 30s、默认 10 次） | 上一阶段已确认 `RECONNECT_DEFAULTS` |
| 插件条目增删（平面②） | **有**（live profile 下改 patch 文件即热重载） | 同上 |
| settings 卡片值 | 保存即生效（settings 文档提交信号） | L60–61、L97 |
| **Agent preset（平面③）** | **需要新会话**：*"A preset is fixed when a session is created"*；且 *"editing those values remains **the preset editor's job**"* | `dsh-client-ui-agent-preset` L12 |

**但注意**：平面②的"免重启 reload"有个前提 —— **你得手工编辑 patch 文件**。
UI 没有任何"编辑 composition"或"reload 按钮"。所谓"live"是文件监视器的行为，不是 UI 功能。

### 1.4 UI 在平面③（Agent preset）能做什么 —— 这是 UI 唯一有写能力的插件相关区域

`dsh-client-ui-agent-preset/README.md` L32 与 `dsh-agent-presets/lib/types/authoring.js`：

**能：**
- **复制**一个既有 preset 建新的（`copyComposition`，L96–117）—— *"the **only** way a preset is created"*
- **设为默认**（写 `agent-presets` settings 命名空间的 `default` 字段）
- **删除**自定义 preset（*"deleting removes the preset directory"*）
- **定位/打开**自定义 preset 目录（`settings.canOpenAgentPresetDirectory()`，无桌面打开器时只显示路径文本）
- 只读查看内置 preset（**无定位、无删除**）

**不能：**
- *"the browser **edits no composition text**"* —— **浏览器不编辑任何组合文本**
- 内置 preset 只读：*"A shipped preset opens in a read-only viewer"*
- `broken` 的 preset 卡片**连复制都禁用**（*"a copy of a broken preset is another broken preset"*）
- *"**Composition edits are invisible to the page**"*（L82）—— 文件在浏览器外被改，页面收不到通知

**产出路径**：用户自建 preset 落在 `<DSH_HOME>/.agent-presets/`
（`dsh-agent-presets/lib/index.js` L195 `USER_PRESET_DIR = ".agent-presets"`；
L188 `includeUserRoot` 默认 `true`）。
**该目录当前不存在** —— 说明本机从未通过 UI 建过 preset。

**复制语义细节**（`authoring.js`）：*"The copy carries everything the source directory holds … 
Symlinks are dereferenced so the copy is self-contained."*，且
*"`order` … [is] not [carried] — a copy presenting itself identically to its source"*
→ 复制是**整目录自包含拷贝，并刻意剥离 `order`**，避免与源冲突。

### 1.5 In-UI 动态 Cordis 组合（附加线索）—— 不能替代持久配置

`dsh-tool-cordis` 允许模型创建/运行/停止临时动态包（host code / browser code）。
**但已确认它在本 web profile 中未启用**：已合成的 539 行配置里**没有 `dsh-tool-cordis`** 条目
（只有 `cordis-host-runner`、`cordis-client-runner`、`ui-cordis`）。

即便启用，按其 README 也**不满足需求**：
> *"Definitions exist only in **process memory** and **disappear when DSH restarts**;
> the package does **not write repository files**, install dependencies, or **change `cordis.yml`**."*

→ **内存态、重启即失、不写配置**，作为 MCP 接入的持久方案不可行。

### 1.6 已安装的 Settings 区域清单（UI 实际有的东西）

`Settings →` 下实际挂载：**General**（shell/连接恢复）、**Models**、
**Plugins**（含 *Plugin configuration* + *Plugin list* 两个 tab）、**Agent Preset**（roster）、
**Permission**、以及 goal / jobs / skill 等特性区。

**其中没有任何一项是 Profile 或 Cordis composition 编辑器。**

### 1.7 只读安全自查

| 项 | 状态 |
|---|---|
| 未创建 profile | ✅ `~/.dsh/profiles/browser-lab` 不存在 |
| 未修改任何配置 | ✅ `web/package.json`、`web/cordis.patch.yml` 原样；`$DSH_HOME/cordis.patch.yml` 不存在 |
| 未安装 pnpm / Playwright MCP | ✅ |
| 未删除 session / storage | ✅ |
| 未修改 Personal Job Search OS | ✅ git CLEAN |
| 唯一落盘产物 | ✅ 本报告 |

---

## 2. INFERENCE

1. **UI 的可写面是"配置值"，不是"组合结构"。** DSH 的 UI 设计清晰地划了一条线：
   **组合（哪些插件、怎么连）在文件里；值（参数、密钥、默认项）在 settings 里。**
   `dsh-mcp-client` 的 `transport / serverName / command / args` 属于**组合**，因此天然落在 UI 之外。
   这不是遗漏，而是与 L95 那条限制一致的架构取向。

2. **三个平面的 UI 成熟度与其"危险度"负相关。** 平面③（preset）能改 agent 的工具集与 prompt，
   所以 UI 只给"复制/删除"，**把编辑组合文本留给文件**；平面②能改进程级插件装载，
   所以 UI **只读**；平面①能换整个应用形态，所以 UI **完全没有**。
   这个规律暗示：**不要期待未来版本在不改架构的前提下给 UI 加上"添加插件条目"**。

3. **本项目要走的路径必然是 CLI + 文件，UI 无法替代。** 上一阶段推荐的
   `--from-default-profile` + 手写 `cordis.patch.yml` 条目，**没有 UI 等价物**。

4. **但 UI 在一个地方有真实价值**：如果将来要把浏览器能力**只给某个 agent**，
   平面③的 preset 机制是唯一正规途径，而 UI 的**复制 preset**能省掉手抄目录的功夫 ——
   不过随后的**编辑 `agent.cordis.yml` 仍需手工**，且要**新开会话**才生效。

5. **`patchReload: live` 是"免重启"的真正来源，而它是文件监视器，不是 UI 按钮。**
   所以"UI 提供 reload"这个问法的答案是：**UI 不提供，但基础设施提供了（对 patch 文件）**。

---

## 3. UNKNOWN

以下我**没有**验证，不做假设：

1. **UI 的实际视觉布局与按钮文案**。我读的是源码/README + 只读 HTTP 探测；
   `/api` 需浏览器会话认证（401），我**没有在真实界面上点过**。
   因此"Plugins 页面里确实看不到 mcp-client 卡片"是**源码级结论**，非目视确认。
2. **`agentPresets/copy` 在真实 UI 中的完整交互**（对话框字段、id 校验反馈、失败横幅）。
3. **`settings/openAgentPresetDirectory` 在本机是否有可用桌面打开器**
   （`dsh-host-open-in-app` 已启用，但 host-directory-picker 系列的实际行为未实测）。
4. **设置卡片写入 `settings.yaml` 后，Host 是否需要重启才反映到运行中的会话**。
5. **是否存在未在 web profile 中启用的 UI 包**（例如某个我做关键词搜索时未命中的
   实验性 profile 管理界面）。我搜的是**已安装**的包；若未来版本新增包，结论需重评。
6. **多 profile 并存时的 UI 行为**（若同时跑 `browser-lab` 与 `web`，两个 GUI 是否互不干扰）——
   理论上两个独立进程互不影响，未实测。
7. **`--patch` 叠加进来的条目是否也出现在 inventory tab**（理论上会，未实测）。

---

## 4. 推荐的最安全 UI-first 操作路径

**前提结论：本轮研究表明 —— 完成 MCP 接入这件事，UI 无法独立完成。**
所以"UI-first"只能理解为：**先用 UI 把能确认的事情确认掉，再把必须 CLI/手写的最小改动交给 CLI/文件。**

### 阶段 0（纯 UI，只读，零风险）—— 建议先做

在 http://127.0.0.1:3080 里，**只看不点保存**：

1. **Settings → Plugins → Plugin configuration**
   确认卡片名单就是那 4 个（bash / agent-loop / subagent-model-selection / web-search-deepseek），
   **确认没有 `mcp-client` 卡片 → 直接验证 FACT 1.2(a)**。
2. **Settings → Plugins → Plugin list**
   浏览 global 平面，确认能看到当前装载的插件与各自的 `id` / 模块名 / 启用状态。
   **记下 `tools`、`agent-presets`、`web` 这几行的形态**，作为将来 MCP 条目出现后的对照基线。
   确认此页**没有任何编辑/添加控件 → 验证 FACT 1.2(c)**。
3. **Settings → Agent Preset**
   确认 roster 卡片只有"复制 / 设为默认 / 删除 / 定位"，**没有编辑组合文本的入口**
   → 验证 FACT 1.4。注意内置 preset 是只读卡片。
4. **在 Settings → General 里找 profile 相关项** → 预期**找不到**
   → 验证 FACT 1.1。

**阶段 0 产出**：一份"UI 能做什么"的目视确认记录（补上 UNKNOWN #1）。

### 阶段 1（CLI，最小改动，不碰默认 profile）

**这是唯一能真正推进的路径**，且**必须在 UI 之外进行**：

1. `dsh --profile browser-lab --from-default-profile web` —— 建独立 profile（UI 做不到）
2. 手写 `C:\Users\user02\.dsh\profiles\browser-lab\cordis.patch.yml` 的 `insert` 条目（UI 做不到）
3. `dsh --profile browser-lab --dump-config` —— **离线校验**（不联网、不 spawn、不启动）
4. 另端口启动，回到 **Settings → Plugin list** 用 UI **目视确认 `mcp__browser__*` 工具已注册**
   —— 这是 UI 在本方案里**唯一真正有用的角色：验证器**。

### 判断准则（哪些必须 CLI / 手写）

| 需求 | UI | CLI | 手写文件 |
|---|---|---|---|
| 创建/选择/切换 profile | ❌ | ✅ `--from-default-profile` / `--profile` | — |
| 添加插件 instance（含 `dsh-mcp-client`） | ❌ | ❌ | ✅ `cordis.patch.yml` 的 `insert` |
| 配置 MCP 的 transport/serverName/command/args | ❌ | ❌ | ✅ 同上 |
| 改 host-plane 插件**值**（bash/agent-loop/…） | ✅ Settings→Plugins | — | —（写 `settings.yaml`） |
| 查看当前插件组合（诊断） | ✅ Plugin list（只读） | ✅ `--dump-config` | — |
| 复制/删除/设默认 agent preset | ✅ Settings→Agent Preset | — | — |
| **编辑** agent preset 的组合文本 | ❌ | ❌ | ✅ `.agent-presets/<id>/agent.cordis.yml` |
| reload patch 改动 | ❌ | — | ✅ 改文件即触发热重载（`live`）；无 UI 按钮 |

### 明确的"不要做"

- **不要**指望 Settings 里那个磁盘图标能帮你加 MCP —— 它打开的是 **agent preset 目录**，不是 profile patch。
- **不要**为了 UI 化而启用 `tool-cordis` 走内存态动态包 —— 重启即失，不适合 Discovery。
- **不要**改 `$DSH_HOME/cordis.patch.yml`（home 级）—— 它作用于所有 profile，且 `live` 热重载会**影响当前 GUI**。

---

## 5. 一句话总结

> **DSH Web UI 在"插件"这件事上是有意设计的半只眼睛：能看（只读 inventory），
> 能改值（settings 卡片），但既不能建 profile，也不能加插件条目 ——
> 组合结构永远留在 `cordis.patch.yml` 与 `agent.cordis.yml` 里。**
> 因此 MCP 接入必须走 CLI + 手写 patch；UI 的最佳用途是**验证结果**。

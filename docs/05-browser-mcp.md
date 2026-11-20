# 05 — Browser MCP（DSH × Playwright MCP）

> 长期知识文档。把 browser-lab 实验线上「已确认的能力」提炼为可复用知识；执行细节留在 `experiments/browser-mcp/`。
> 证据等级：`[FACT]` / `[INFERENCE]` / `[UNKNOWN]`。建立：2026-09。
> 相关：`01-host-composition.md`（Host plugin composition）、`04-agent-composition-and-instructions.md`、`06-dsh-runtime-and-multiprocess.md`。
>
> **Evidence**:
> - `docs/browser-mcp/01-dsh-playwright-mcp-research.md`（`dsh-mcp-client` 包与 schema 研究）
> - `docs/browser-mcp/02-dsh-web-ui-path-research.md`（三平面框架 / UI 覆盖度）
> - `experiments/browser-mcp/2026-09-11-B3.3-browser-lab-profile-creation.md`
> - `experiments/browser-mcp/2026-09-11-B3.3b-web-profile-mcp-mount-check.md`
> - `experiments/browser-mcp/2026-09-12-B3.4-mcp-client-mount.md`
> - `experiments/browser-mcp/2026-09-12-B3.5-e2e-tool-invocation.md`（**E2E 取证 · 最小 tool invocation**）
> - `experiments/browser-mcp/2026-09-12-B3.6-interactive-spa-e2e.md`（**E2E 取证 · Interactive SPA**）
> - `evidence/config-dumps/browser-lab-composed-tree-BEFORE-mcp.yml` / `-AFTER-mcp.yml`
> - `experiments/browser-probe/`（裸 CDP/BiDi 层面的前置探测）

---

## 1. 验证过的链路

```
DSH Agent
  → dsh-mcp-client              （Cordis plugin，Host plugin composition）
  → MCP stdio transport
  → @playwright/mcp             （npx -y @playwright/mcp@latest）
  → Playwright
  → Chrome（本机）
  → web
```
[FACT：`experiments/browser-mcp/2026-09-12-B3.5-e2e-tool-invocation.md` 记录的真实 tool 调用与结果]

---

## 2. `dsh-mcp-client`（Host 侧 MCP 桥）

| 项 | 值 | 等级 |
|---|---|---|
| package | `@deepseek-ai/dsh-mcp-client` | [FACT] |
| version | **`0.1.5-rc.1`**（与 DSH 同版本 lockstep） | [FACT] |
| Cordis plugin name | `mcp-client` | [FACT] |
| `inject` | `["tools"]` | [FACT] |
| 依赖 | `@modelcontextprotocol/sdk`（`^1.12.0`；实测装到 v1.30.0）、`zod`、`schemastery` | [FACT] |
| 发布的产物 | **只有 `lib/`，没有 `src/`** —— 读源码只能读 `lib/index.js` + `lib/types/*.d.ts` | [FACT] |
| 归属平面 | **Host plugin composition**（不是 agent preset，也不是 profile 管理） | [FACT] |

> `src/` 缺失意味着：**不要**按 package README 里的仓库路径去找 `src/index.ts`。

## 3. 配置 schema（`transport` 判别的 `z.union`）

### stdio 分支（本项目使用）
```yaml
transport: stdio          # 必需；z.const("stdio")
serverName: <name>        # 必需；pattern /^[A-Za-z0-9_-]{1,32}$/
command: <exe>            # 必需
args: []                  # 默认 []
env: {}                   # 默认 {}
cwd: ""                   # 默认 ""
# 另有 failOnStartupError 一类行为开关（见 B3.4 记录）
```
[FACT：`experiments/browser-mcp/2026-09-12-B3.4-mcp-client-mount.md` §schema]

### `serverName` 的含义
[FACT]
- 它是一个**逻辑服务器名**（受上表 pattern 约束），用于在 Host 侧标识这一个 MCP server 实例。
- **它同时决定暴露给模型的工具名前缀**：实测模型侧工具名为 **`mcp__<serverName>__<tool>`**。
  本项目 `serverName: playwright` ⇒ `mcp__playwright__browser_navigate`、`mcp__playwright__browser_snapshot`。

## 4. 实际挂载的 Entry（browser-lab profile）

写入 `C:\Users\user02\.dsh\profiles\browser-lab\cordis.patch.yml` 的条目 [FACT]：

```yaml
- id: mcp-playwright
  name: '@deepseek-ai/dsh-mcp-client'
  config:
    serverName: playwright
    transport: stdio
    command: npx
    args:
      - '-y'
      - '@playwright/mcp@latest'
      - '--browser=chrome'
```
- `id: mcp-playwright` 是该 **Cordis Entry 的 id**（patch 层的定位键），与 `serverName` 是**两件事**：前者是 composition 里的行标识，后者是 MCP server 的逻辑名 / 工具名前缀来源。
- `--browser=chrome` 用引号包裹，避免 YAML 把前导 `-` 解析为列表标记。[FACT：B3.4]

### 合成结果验证 [FACT]
| 状态 | 条目数 | `mcp` 命中 | Evidence |
|---|---|---|---|
| BEFORE mount | 152 | **0** | `evidence/config-dumps/browser-lab-composed-tree-BEFORE-mcp.yml` |
| AFTER mount | 153 | **3**（`- id: mcp-playwright` 等） | `evidence/config-dumps/browser-lab-composed-tree-AFTER-mcp.yml` |

> 判据来源：`--dump-config` 使用的是与 boot 相同的 `applyEntryPatches` 合成算法 ⇒ **composed tree 里没有 = 没挂载**。

### 4.1 browser-lab profile 的当前 bundle 成员（2026-09-15 更新）[FACT]

`browser-lab` 的 `dsh.profile.bundles` 现为 `["@deepseek-ai/dsh-base", "@deepseek-ai/dsh-web-app", "dsh-whale-widget"]`（第三方桌面挂件；专题见 `07-profile-bundle-isolation.md`）。

- 该 bundle 走的是 **bundle patch 层**（由 `dsh.profile.bundles` 驱动）；而上面那条 `mcp-playwright` 走的是 **profile user patch 层**（`cordis.patch.yml`）。**两者是不同的 layer 来源**，不要混为一谈。
- `browser-lab/cordis.patch.yml` 本身**未变**（仍是上面那 925 B，sha `EFBE0E95CB160B52C2F3D5B3C204F1EF6963932EBD99E96F2524D60F74F30C76`）。
- ⚠️ **whale widget 不是 Browser MCP 的一部分**；本文的链路与 E2E 结论与它无关，不要把它写进 MCP 能力清单。
- 该改动之后**未重采** `--dump-config`（`--dump-config` 会重写 profile 的 `cordis.yml` 且需新进程）⇒ 上表的 **153** 仍是 **AFTER-mcp（pre-whale）** 基线，不是当前树的实测值。

## 5. `@playwright/mcp`（被 stdio 拉起的 MCP server）

| 项 | 值 | 等级 |
|---|---|---|
| 拉取方式 | `npx -y @playwright/mcp@latest` | [FACT] |
| **实测解析到的版本** | **`0.0.80`** | [FACT：B3.5 runtime 内 `npm ls @playwright/mcp` 输出] |
| 目标浏览器 | 本机 **Chrome**（`--browser=chrome`） | [FACT] |

> ⚠️ 因为用的是 `@latest`，**实际版本会随后续 npx 拉取漂移**；`0.0.80` 只是**本次验证的版本**，不是锁定版本。[FACT/INFERENCE]

### Playwright MCP 使用 accessibility tree
[FACT]
`browser_snapshot` 返回的**不是原始 HTML**，而是 **accessibility snapshot（YAML 结构）**，形如：

```yaml
- generic [ref=e2]:
  - heading "Example Domain" [level=1] [ref=e3]
  - paragraph [ref=e4]: This domain is used in documentation examples ...
  - paragraph [ref=e5]:
    - link "Learn more" [ref=e6] [cursor=pointer]:
      - /url: https://iana.org/domains/example
```
- 每个节点带 `[ref=eN]`，这是**后续交互（click/type）的定位句柄**。
- 这解释了为什么 Browser MCP 比"静态 HTML 抓取"更适合 SPA：它直接给出**渲染后可交互的结构**。

## 6. MCP tool catalog

[FACT] 本机已**实际调用成功**的工具（模型侧命名）：

| 工具名 | 实际调用情况 |
|---|---|
| `mcp__playwright__browser_navigate` | ✅ 调用成功（B3.5 `example.com`；B3.6 真实 SPA） |
| `mcp__playwright__browser_snapshot` | ✅ 调用成功（B3.5、B3.6 多次） |
| `mcp__playwright__browser_click` | ✅ 调用成功（**B3.6**：`target: e143`） |

[UNKNOWN] `@playwright/mcp@0.0.80` 的**完整 tool 清单**未逐项穷举（只确认上述三个 + 它们成功返回）。

## 7. E2E 验证（Phase B3.5）—— **PASS**

[FACT，来自 `experiments/browser-mcp/2026-09-12-B3.5-e2e-tool-invocation.md` / session `session-21dbfd25-…` 的 event log]

| 步骤 | 实际观测 |
|---|---|
| 1. `browser_navigate` | 参数 `{"url": "https://example.com"}`；返回 `- Page URL: https://example.com/`、`- Page Title: Example Domain` |
| 2. `browser_snapshot` | 参数 `{}`；返回 accessibility tree YAML（含 `heading "Example Domain"`、`link "Learn more"`、`[ref=eN]`） |

- 该 session 的 event log 中 `tool/call` 与 `tool/result` **各 20 条**，其中包含上述两次 MCP 调用与其成功结果（`isError: false`）。
- 另有进程级旁证：Chrome 由 `playwright-mcp --browser=chrome` 的 node 进程谱系拉起。[FACT]

⇒ **结论：DSH Agent 能通过 `dsh-mcp-client` 真正驱动本机 Chrome 完成一次最小浏览器操作（navigate + accessibility snapshot）。** [FACT]

### 7.1 Interactive JS-rendered SPA E2E（Phase B3.6）—— **PASS**

[FACT，来自 `experiments/browser-mcp/2026-09-12-B3.6-interactive-spa-e2e.md`，session `session-21dbfd25-…` 的 event log]

对**真实招聘 SPA** `https://bambulab.jobs.feishu.cn/campus`（Title `欢迎加入拓竹科技`）执行：**1 次 navigate + 2 次 snapshot + 1 次 filter click**。

| 步骤 | tool / 参数 | 实际观测 |
|---|---|---|
| 1 | `browser_navigate` → SPA URL | Title `欢迎加入拓竹科技`；`Console: 0 errors, 4 warnings` |
| 2 | `browser_snapshot` `{}` | accessibility tree；`开启新的工作（167）`，pagination 末页 `17` |
| 3 | **`browser_click`** `{element:"城市筛选树中的「深圳」筛选项", target:"e143"}` | URL 新增 **`location=CT_128`** |
| 4 | `browser_snapshot` `{}` | `开启新的工作（147）`，pagination 末页 **`15`**；`Console: 1 errors, 6 warnings` |

- **`target: "e143"` 就是 accessibility tree 的 `[ref=eN]`** ⇒ 用页面语义定位交互元素成立。[FACT]
- 结果集 `167 → 147`、分页 `17 → 15`、URL 新增 `location=CT_128` ⇒ **筛选真实改变了服务端结果集，而非仅视觉变化**。[FACT]
- Chrome 由 `playwright-mcp --browser=chrome` 以 `--remote-debugging-pipe` + profile `ms-playwright-mcp\mcp-chrome-79b2345` 启动；MCP 进程链与 DSH 实例（PID 28460，`--profile browser-lab --port 3080`）归属已核对。[FACT]

⇒ **Browser MCP 当前能力状态：`Interactive JS-rendered SPA E2E: PASS`**（已验证 navigate / snapshot / 结构理解 / 识别 interactive elements / `[ref=eN]` 定位 / click / 交互后 snapshot / 前后对比 / 真实 SPA 筛选状态改变 / 服务端结果集变化）。[FACT]

> ⚠️ **归因纪律**：本轮同时装有 `$DSH_HOME/AGENTS.md`（language policy）。**Browser MCP 的成功与 AGENTS.md 无关** —— 后者只影响语言行为，不影响 MCP 链路可用性。两件事须分开记录。[FACT]
> [UNKNOWN] 同一轮 console 出现 `1 errors, 4–6 warnings`；**内容与原因未读取、未归因**，不得解释为 MCP / Playwright 自身错误。

## 8. 与「裸 CDP/BiDi 探测」的关系

- `experiments/browser-probe/` 证明：对目标 SPA（`bambulab.jobs.feishu.cn/campus`）而言，**必须等 settle** 才能拿到渲染后的职位列表（初次渲染 `textLength≈47`，settle 后 `≈2541`）。[FACT]
- [INFERENCE] 这正好说明 Browser MCP 的价值：`browser_navigate` 之后用 `browser_snapshot` 拿 **settle 后的 accessibility tree**，而不是依赖静态 HTML。

## 9. UI 覆盖度（能否用 Web UI 配置这些）

[FACT，来自 `docs/browser-mcp/02-dsh-web-ui-path-research.md`]
DSH 里"插件"横跨**三个互不相通的平面**：

| 平面 | 载体 | UI 覆盖度 |
|---|---|---|
| ① Profile management | `profiles/<name>/package.json`（`dsh.profile.bundles`）、`cordis.yml` | **零** |
| ② **Host plugin composition** | `<profile>/cordis.patch.yml` + `$DSH_HOME/cordis.patch.yml` + bundle patches | **只读** inventory + 仅"配置值"编辑（settings 命名空间） |
| ③ Agent preset composition | `$DSH_HOME/.agent-presets/<id>/agent.cordis.yml`；内置在 `dsh-agent-presets/presets/` | **部分**（复制/设默认/删除/查看；**不能编辑组合文本**） |

⇒ `dsh-mcp-client` 属于 **②** ⇒ **Web UI 不能添加/配置 MCP**，必须**手工编辑 patch 层**。[FACT]

## 10. 已知限制 / UNKNOWN

- [FACT] **已从 MCP 链路上验证**：`browser_navigate`、`browser_snapshot`、**`browser_click`**（含用 `[ref=eN]` 定位并通过点击改变服务端结果集）—— 见 §7 / §7.1。
- [UNKNOWN] **更复杂交互尚未系统验证**：复杂搜索输入、多条件组合筛选、翻页、详情页深层导航、表单填写/提交。
- [UNKNOWN] 同一轮 console 出现的 `1 errors, 4–6 warnings` 的具体内容与原因（未读取、未归因）。
- [UNKNOWN] `@playwright/mcp@latest` 的版本漂移风险与兼容边界未评估。
- [UNKNOWN] 多 MCP server 共存（多个 entry / 多个 serverName）时的行为未验证。
- [UNKNOWN] MCP 工具在 **agent preset** 侧的可见性裁剪（哪些 preset 能看到 `mcp__*` 工具）未系统性验证。
- [INFERENCE] 由于 `mcp-client` `inject: ["tools"]`，它注册的工具进入 host tools registry，再按 scope 对 agent 可见 —— 与 `01-host-composition.md` 的模型一致，但未逐 preset 实测。

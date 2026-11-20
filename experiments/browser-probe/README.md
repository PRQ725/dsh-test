# browser-probe — 浏览器自动化探测实验 bundle

> **实验性质**：READ-ONLY 浏览器能力探测（CDP / WebDriver BiDi）。所有脚本自述为 **READ-ONLY**：不修改请求、不做 interception、不规避反爬。
> **目标站点**：`https://bambulab.jobs.feishu.cn/campus`（Bambu Lab 招聘页，JS-rendered SPA，基于飞书 ATS-X / SaaS Career）。
> **证据等级**：本 README 中的环境/结果数据来自本 bundle 内 `reports/*.json` 与 `logs/*.log` 的**实际内容**。[FACT]

## 1. 实验目的

验证「用本机浏览器自动化能力，能否取到 JS-rendered SPA 的真实渲染结果」——即在**不依赖任何反爬规避**的前提下，判断：

1. 能否连上浏览器的自动化端点（CDP HTTP / WebSocket，或 Firefox WebDriver BiDi）；
2. 能否导航到目标 SPA 并等到 settle（异步渲染完成）；
3. 能否拿到**渲染后**的 DOM 与截图；
4. 目标页面是否存在反爬/验证码信号（只做观测记录，不做规避）。

> 该实验是后续 **Browser MCP** 研究（`docs/05-browser-mcp.md`）的前置探索：先用裸 CDP/BiDi 确认"能拿到什么"，再评估 MCP 化的价值。

## 2. 时间与环境

| 项 | 值（来自 reports/logs） |
|---|---|
| 实验日期 | 2026-09-11 ~ 2026-09-12（见 `logs/*.log` mtime 与 bundle 生成时间） |
| Chrome | `Chrome/153.0.8010.36`，协议 `1.3`（CDP，端口 `9222`） |
| Edge | 同为 Chromium 内核（CDP，端口 `9222`；见 `edge-report.json`） |
| Firefox | `154.0.1`，headless，W3C **WebDriver BiDi**，端口 `9224`；`moz:profile` 曾指向 `D:\Projects\dsh-test\browser-probe\ff-profile`（该临时 profile 目录未保留） |
| 目标 URL | `https://bambulab.jobs.feishu.cn/campus` |

> [UNKNOWN] `edge-report.json` 中的浏览器版本号未在本 README 逐字引用；如需精确版本请直接读该 report。

## 3. 目录与文件含义

```
experiments/browser-probe/
├── README.md          ← 本文件
├── scripts/           ← 7 个 READ-ONLY 探测脚本（Node ESM, .mjs）
├── reports/           ← 8 个 JSON 结果报告（机器可读结论）
├── captures/          ← 7 个 HTML DOM 抓取 + 10 个 PNG 截图（原始证据，体积最大）
└── logs/              ← 8 个浏览器进程 stdout/stderr 日志
```

### 3.1 `scripts/`（脚本用途）

| 脚本 | 端口 | 用途 |
|---|---|---|
| `cdp-probe.mjs` | 9222 | Chrome CDP 综合能力探测（HTTP endpoint → attach → 启用域 → navigate → evaluate → DOM/截图 → performance）。产出 `chrome-report.json` |
| `cdp-settled-capture.mjs` | 9222 | 自起 headless Chrome，仅抓 **settled** DOM（最小、自闭环） |
| `cdp-visual.mjs` | 9222 | 对已打开的 CDP 页面做 **post-settle** 视觉检查并截图 |
| `cdp-interact.mjs` | 9222 | **真实鼠标事件**交互能力测试（Ant-Design 风格 tree filter checkbox） |
| `cdp-filter-diag.mjs` | 9222 | 重置到干净加载后，dump 真实 filter DOM 结构，用于精确定位点击目标 |
| `cdp-clickthrough.mjs` | 9222 | 点击职位卡片，验证 SPA 是否路由到 detail 页 |
| `bidi-probe.mjs` | 9224 | Firefox **WebDriver BiDi** 探测（`ws://127.0.0.1:9224/session` → session.new → 订阅 → navigate → evaluate → DOM/截图）。产出 `firefox-bidi-report.json` |

> 全部脚本头部均标注 `READ-ONLY`。[FACT]

### 3.2 `reports/`（JSON 是什么）

两类 schema：

- **CDP 综合报告**（`chrome-report.json`、`chrome-filter-dom-diag.json`、`chrome-interaction-test.json`、`chrome-clickthrough.json`、`chrome-postsettle-state.json`）：字段 `tag / port / url / layers{1..9} / console / requests / warnings / eval / evalAfterWait / performance / summary`。
  - `layers` 按探测阶段给出 `{ok, detail}`：`1.cdp_http_endpoint`、`2.page_target_found`、`3.cdp_websocket_attach`、`4.domains_enabled`、`4b.navigate`、`5.js_execution`、`6.rendered_dom`、`7.screenshot`、`8.performance_timing`、`9.after_settle_render`。
- **BiDi / 简化报告**（`firefox-bidi-report.json`、`edge-report.json`、`edge-postsettle-state.json`）：字段 `allCaptchaTextMatches / bodyTextLen / firstJobText / iframes / jobCardCount / overlays / scrollHeight / title / url`，以及 Firefox 的 `capabilities / contextTree / navigation / eval / evalAfterWait / summary`。

### 3.3 `captures/`（HTML 与 PNG 是什么）

- **`*.html`**：两个阶段各一份 —— `*-rendered-dom.html`（初次渲染后）与 `*-rendered-dom-settled.html`（**settle 之后，最终态**）。
  `00-static-curl.html` 是用 `curl` 抓到的**静态 HTML**（未执行 JS），作为对照基线。
- **`*.png`**：截图。其中 `*-screenshot.png` 是 **layer 7 的早期截图**（此时 SPA 尚未渲染完成，页面接近空白，因此 `chrome-screenshot.png` 与 `edge-screenshot.png` **逐字节相同**，均 6566 bytes；`firefox-screenshot.png` 5501 bytes）。
  `*-screenshot-settled*.png`（800+ KB）才是**渲染后**的有效视觉证据；`chrome-clickthrough-detail.png` / `chrome-detail-page.png` 是点击进入 detail 页后的截图。

### 3.4 `logs/`（含空文件）

| 文件 | 说明 |
|---|---|
| `chrome-stderr.log`（12,943 B） | Chrome 侧主要诊断输出 |
| `edge-stderr.log`（1,268 B） | Edge 侧诊断输出 |
| `ff-stderr.log`（39 B） | Firefox 侧诊断输出（很短） |
| `chrome-defaultprof-err.log`（244 B） | 使用 default profile 启动时的错误 |
| **`chrome-stdout.log` / `chrome-defaultprof-out.log` / `edge-stdout.log` / `ff-stdout.log`（均 0 B）** | **空文件**——浏览器把输出都写到了 stderr，stdout 无内容。保留以证明"确实为空"，无信息量 |

## 4. 关键结果（来自 reports）[FACT]

- **三浏览器均成功**：Chrome / Edge（CDP）与 Firefox（BiDi）都完成了 `endpoint → attach/session → navigate → JS evaluate → rendered DOM → screenshot`。
  - Chrome `summary`: `cdpReachable:true, browserLaunched:true, domObtained:true, jsExecuted:true, renderedContent:true, requestCount:74, failedRequestCount:0`
  - Firefox `summary`: `bidiEndpoint:true, sessionCreated:true, navigated:true, jsExecuted:true, domObtained:true, renderedContent:true, jobIdsFound:10`
- **settle 前 vs settle 后差异巨大**：初次渲染 `textLength≈47`、`anchorCount=6`；settle 后 `textLength≈2541`、`anchorCount=16`、`jobishAnchorCount≈11`。→ **必须等 settle，否则抓不到职位列表**。
- **确实抓到了 JS 渲染出的职位数据**：settle 后可见职位锚点（如 `/campus/position/7682701506303117614/detail`），Firefox 报出 10 个 job id。
- **观测到反爬信号**（仅记录，未规避）：`antiBotSignals.slideVerifyScript=true`、`signatureRefsInHtml=1`；`visibleCaptchaText` 在不同 run 中为 `false` / `true`（同 bundle 内不一致）→ 说明站点行为有波动。
- **一次 `405`**：`/api/v1/search/job/posts?...` 首次返回 405，之后同类请求 200（见 `requests`/`warnings`）。

> ⚠️ 不要把上述结果外推为"任意站点均可稳定抓取"——本 bundle 只证明了**对这一个 SPA 站点**的探测可行性与行为观察。[INFERENCE/UNKNOWN 边界]

## 5. 与 Browser MCP 研究的关系

- 本 bundle 是**裸协议层**（CDP / BiDi）探测，回答"浏览器自动化能拿到什么"。
- **`docs/05-browser-mcp.md`** 记录的是**上层集成**：DSH Agent → `dsh-mcp-client` → MCP stdio → `@playwright/mcp` → Playwright → Chrome → web 的 E2E 验证。
- 二者是**互补证据**：本 bundle 证明"渲染后的真实 DOM 可达"；Browser MCP 证明"DSH Agent 可通过 MCP 工具真的驱动浏览器"。
- [INFERENCE] 本 bundle 观察到的"必须等 settle"直接解释了下游为什么需要 Playwright MCP 的 `browser_snapshot`（accessibility tree）而不是静态 HTML 抓取。

## 6. 已知缺口

- [UNKNOWN] 本 bundle **原本没有 README**，本文件由后续整理补充；实验的**逐次运行时间线**未保留（只能从文件 mtime 与 report 内 `performance` 推断）。
- [UNKNOWN] `ff-profile` 临时浏览器 profile 未保留（report 中留有路径引用）。
- [UNKNOWN] `edge-postsettle-state.json`（279 B）与 `edge-report.json` 的差异原因未记录。

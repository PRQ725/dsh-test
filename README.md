# dsh-test — DSH 研究知识库

> **DSH（DeepSeek Harness）本机研究 workspace**。这里不是应用源码仓库，而是**研究知识库 + 实验档案**：
> 研究 DSH 自身架构、把真实 Claude Code 项目迁移到 DSH、以及用 Browser MCP 驱动真实浏览器。
> 全部结论按 `[FACT]` / `[INFERENCE]` / `[UNKNOWN]` 标注证据等级。

---

## 30 秒了解：目录职责

| 目录 | 放什么 | 不放什么 |
|---|---|---|
| **`docs/`** | **长期知识**（已提炼的结论、架构、机制） | 实验过程流水账 |
| **`experiments/`** | **实验过程 / 执行记录**（命令、时间、PID、hash、运行结果） | 已提炼的结论 |
| **`evidence/`** | **原始 runtime 证据**（config dump、日志等不可再生快照） | 解读性文字 |
| **`scripts/`** | **研究工具**（只读分析脚本） | 一次性命令 |
| **`archive/`** | **历史 / 重复 / 淘汰材料**（0.1.1 时代产物、重复 dump、临时文件、旧 session log） | 仍在被引用的知识或证据 |

> 约定：**新知识必须回流到 `docs/`**；`experiments/` 与 `evidence/` 只提供可追溯的过程与原始数据。

---

## 当前研究进度

### 1. DSH 架构（已基本建立）
- Host 与 Agent 的**层级关系**已明确：`Host Composition → DSH Runtime → Agent Runtime → Agent Composition → Agent Session → Model requests`（**不是两个平行层**）。→ `docs/01-host-composition.md`
- **Composition 语义**：patch 是 **ordered patch stream**（不是 config merge）；`config` 是 whole-key replacement；`disabled` 是 last-write-wins。→ `docs/02-root-include-and-patch-composition.md`
- **两种 precedence 不矛盾**：Host 层「后写覆盖」vs Agent instruction「具体优先」。→ `docs/02` §J

### 2. Instruction System（已研究，**已 E2E 验证**）
- **全局 instruction = `$DSH_HOME/AGENTS.md`**（user-global），与 workspace/cwd 无关，所有非 `minimal` 的会话都会自动加载。
- `AGENTS.md` / `CLAUDE.md` 是 **instruction source**（数据文件），**不是** Cordis Entry、**不是** plugin；
  真正读取并注入它们的是 plugin **`dsh-agent-instructions`**。
- 层级：user-global → projectRoot → … → cwd（`.local` overlay）。
  **父目录层是累加、不是替换**；冲突时"更具体优先"（提示层声明，无代码级覆盖）。
  **`cwd` 之下的子目录不在初始链上**：只有 `working_directory` 真改了 cwd、或 `read`/`write`/`edit` 碰到了更深文件，
  才会把 `src/AGENTS.md` 这类次级层拉进来；**shell 里 `cd` 不触发**。
  预算：`0.2.2` 起 global 链与 project 链**各自**受 `maxBytes`（双链最多 2×，见 §11）。
  → 完整机制与"操作→是否加载"对照表：`docs/04` **§4.10**
- preset 覆盖：`standard` / `cordis` / `ptc` 挂载该插件；`minimal` **不挂载**。
- **[2026-09-12 E2E]** 新 session 会在**首次 model request 前**收到注入；**已存在 session 也会在下一个 step 感知新增/修改**（不重启、不新建 session；非 touch 修改同样被检测）。
- → `docs/04-agent-composition-and-instructions.md`、`experiments/dsh-runtime/2026-09-12-global-agents-e2e.md`

### 3. Browser MCP（**E2E 已 PASS**）
链路已端到端验证，当前状态 **`Interactive JS-rendered SPA E2E: PASS`**：
```
DSH Agent → dsh-mcp-client → MCP stdio → @playwright/mcp → Playwright → 本机 Chrome → web
```
- **B3.5（最小 tool invocation）**：`browser_navigate` → `https://example.com`；`browser_snapshot` → accessibility tree YAML（含 `[ref=eN]`）。
- **B3.6（Interactive SPA）**：对真实招聘 SPA `https://bambulab.jobs.feishu.cn/campus` 执行 1×navigate + 2×snapshot + **1×`browser_click`（`target: e143`，即 accessibility tree 的 `[ref=eN]`）**，
  点击「城市 → 深圳」后：结果集 `167 → 147`、分页 `17 → 15`、URL 新增 `location=CT_128` ⇒ **真实改变了服务端结果集**。
- → `docs/05-browser-mcp.md`、`experiments/browser-mcp/2026-09-12-B3.5-e2e-tool-invocation.md`、`experiments/browser-mcp/2026-09-12-B3.6-interactive-spa-e2e.md`

### 4. Runtime / 多进程（已研究）
- DSH **持久层**（`$DSH_HOME/storages/*.json` + session log）与**进程私有内存 registry** 分离；
  **没有跨进程失效/同步通道**。
- 双 DSH 进程共用 `$DSH_HOME` ⇒ 会出现 **workspace 归类 stale view**；且 `workspace.json` 全量重写存在**双写覆盖风险**。
- → `docs/06-dsh-runtime-and-multiprocess.md`

### 5. Claude Code → DSH 迁移（PJOS）
- PJOS 已 adopt 为 DSH workspace（`92030ae8-…`），**项目零修改**；其根 `CLAUDE.md` 已被 DSH 自动承认为 project instruction（runtime 取证）。
- → `docs/migration/10`–`14`

### 6. Profile / Bundle 隔离（**P2 已完成，full E2E = PARTIAL**）
- **P1（prep，read-only）**：源码闭环 + 干净基线 —— 归属写入面 `runPlugin`、读取面 `loadProfileDirectory`、"无继承"三者闭合。
- **P2（install + E2E）**：在 **`browser-lab`**（不是 `web`）上 `dsh plugin --profile browser-lab add dsh-whale-widget@0.3.0`，
  `browser-lab/package.json` 的 `dsh.profile.bundles` 变为 `[dsh-base, dsh-web-app, dsh-whale-widget]`；
  重开 browser-lab 后 **右下角 Whale Widget 桌宠可见**；宿主侧 `.dshw-*.json` 已生成（含真实余额）。
- **`web` 非成员：PASS** —— 四个关键文件哈希与 prep 基线**逐一相同**，`web/package.json` 仍不含 whale。
- **唯一跨 profile 泄漏通道** `$DSH_HOME/cordis.patch.yml` 核实**仍不存在**；`profiles/node_modules` **不含** whale。
- **PARTIAL 的原因**：AFTER `--dump-config` 未采集（该命令会重写 profile 的 `cordis.yml` 且需新进程）。
- → `docs/07-profile-bundle-isolation.md`、`experiments/profile-isolation/2026-09-15-whale-widget-browser-lab-install-e2e.md`

### 7. DSH 安装 / 升级（**已恢复，知识已沉淀**）
- **事故**：全局 `npm install -g @deepseek-ai/dsh` 从 rc.1 升 rc.2 **失败**（Loader 报 `@deepseek-ai/dsh-sandbox-local could not be resolved`）→ 回滚 rc.1 **仍失败** → 升 **rc.3 恢复**。
- **[FACT] 关键教训**：`npm install -g <pkg>@<old>` 只固定**顶层版本**，仍会重新解析依赖范围 ⇒ **top-level rollback ≠ dependency-tree rollback**；全局安装**没有 lockfile**。
- **[FACT] 归因分层**：主因在 **global DSH installation / npm 依赖图**；Cordis 是**报错出口**；**profile 未涉及** —— `browser-lab` 与 `web` 的 profile 文件**逐项未变**，Whale 在 rc.3 上继续运行。
- **[FACT] 唯一跨 profile 泄漏通道** `$DSH_HOME/cordis.patch.yml` 仍**不存在**。
- 原始 npm 日志（不可再生）已归档：`evidence/logs/npm/`（三份原件 + 摘要）。
- → `docs/08-dsh-installation-and-upgrade.md`、`experiments/dsh-install/2026-09-23-dsh-global-upgrade-rc1-to-rc3-incident.md`

### 8. 官方 Desktop / mixed-version 兼容性（**CLOSED，2026-10-05**）
- **[FACT] 官方 Desktop** = Electron shell + desktop-host + **bundled DSH runtime** + updater；不引入新的 composition paradigm（仍是 `profile + bundles + Cordis patch stream`）。
- **[FACT] 第二 installation anchor**：全局 npm DSH（`0.1.5-rc.3`）与 Desktop bundled runtime（`0.2.0-rc.2`）**并存**、互不覆盖；两者**共享同一个 `$DSH_HOME`**。
- **[FACT] `[0.1.5 → 0.2.x version boundary]` 两个结构性断裂面**：
  1. **settings 模型** —— 0.2 把 legacy `settings.yaml` import 成 profile Cordis entry 并把文件 rename 为 `settings.yaml.imported`；0.1.5 不认识 `.imported` ⇒ 重新 bootstrap 最小 settings ⇒ 显式 locale override 丢失 ⇒ locale 交回 **browser language resolution**（**不是**"Desktop 把 en 改成了 zh"）。
  2. **session format** —— `SESSION_FORMAT_VERSION` 3 → 4；0.1.5 无 v4 codec，**文件系统层能枚举到 v4，但 host listing 静默过滤它**。
- **[FACT] E1 run3 最终分类：`NOT DISCOVERABLE`**（DISCOVERY FAIL；OPEN/RENDER/CONTINUE NOT REACHED；无破坏性破坏）。
- **[FACT] Control B（matched-version 对照）PASS**：隔离 home 中的 `0.2.0-rc.2` Web **可以** discover + 完整 render Desktop 创建的同一个 v4 session。
- **[CONCLUSION]** 观测到的互操作失败是 **runtime / session-format 版本边界**问题，**不是**泛化的 Desktop-vs-Web 不兼容。
- → `docs/09-dsh-desktop.md`、`docs/10-experiment-methodology.md`、`evidence/desktop/runtime/e1-run3-CLASSIFICATION-NOTE.md`、`evidence/desktop/runtime/controlB/CONTROL-B-RESULT.md`

### 9. Long-running Toolkit（**v0.2 已正式发布**；v0.1 Pilot 已冻结、未发布）
- **最新正式发布：v0.2（2026-10-09）** → [toolkit/long-running/v0.2/](toolkit/long-running/v0.2/)（**恰好八文件**）。
  发布记录见 [toolkit/long-running/RELEASES.md](toolkit/long-running/RELEASES.md)；验收与发布过程见
  [experiments/long-running/v0.2-work/RELEASE-REPORT.md](experiments/long-running/v0.2-work/RELEASE-REPORT.md)。
- **v0.1**：第一次 Pilot 产出的**已冻结实验候选**（六文件），位于 `D:\Projects\dsh-longloop-pilot\out\toolkit-v0.1\`；
  机制与实验记录在该 workspace 的 `evidence\`。**从未发布、HUMAN ACCEPTANCE 未授予**。
- **历史研发与证据**：`experiments/long-running/v0.2-work/`（**开发实验区，不是安装目录**）。权威候选八文件保留在
  `v0.2-work/candidate/long-running/`，作为可追溯的发布来源；rc.1/rc.2/rc.3 报告、验收规范、Evaluator 与失败记录全部保留。
- **采用到新项目**：读发布版的 `README.md` → `## Adoption procedure`（14 步，含人工批准门）；入口索引
  [experiments/long-running/v0.2-work/README.md](experiments/long-running/v0.2-work/README.md)。
- **发布门槛（三者齐备）**：`MECHANICAL PASS` + `ADOPTION DRY-RUN PASS` + `HUMAN CONTENT ACCEPTANCE` —— 三项均已成立。
- **发布后状态**：v0.2 研发线 **CLOSED / RELEASED**；正式发布目录不可变，新问题登记后由后续版本处理，不热修 v0.2 文件。

### 10. 跨版本知识审计：0.2.0-rc.2 → 0.2.1-rc.2（**CLOSED，2026-10-19**）
- **运行时事实**：全局 npm CLI 与当前 active session 均为 `0.2.1-rc.2`（`browser-lab` profile）；
  Desktop bundled runtime 仍为 `0.2.0-rc.2`。active session 的判别依据是 0.2.1 才有的 `working_directory`
  工具 + 所属 profile，不是 UI 版本号。
- **Toolkit v0.2**：只读复核结果 **COMPATIBLE WITH CAVEAT**；十项契约无 `INCOMPATIBLE`；八文件 SHA-256
  未变；**没有**做 Goal live test（`NOT RUN`）。
- **需要版本注记的机制变化**：0.2.1 的 goal driver 在开轮前等待子代理后代 settle、idle 时移除排队 round
  prompt；plan review dismiss 改为结束当前 turn；新增 `working_directory`（改 cwd ≠ 改 sandbox grant）；
  `{{cwd}}` prompt variable 被移除；PTC `mode` 只剩 `native` / `ptc`；插件侧的 `./invariant` 导出被移除
  （自定义 profile / 插件需自查，详见审计报告）。
- **模型**：selected ID 仍是 `deepseek-flash`；`DeepSeek-V4.1-Flash` / `1017` 是客户端展示，
  实际权重版本 `[UNKNOWN]`。
- **详细证据与 K01–K24 对照**：
  [experiments/dsh-version-audit/0.2.0-rc.2-to-0.2.1-rc.2/](experiments/dsh-version-audit/0.2.0-rc.2-to-0.2.1-rc.2/)
  （`FINAL-REPORT.md` / `KNOWLEDGE-DELTA.md` / `TOOLKIT-COMPATIBILITY.md`）。

### 11. 跨版本知识审计：0.2.1-rc.2 → 0.2.2-rc.1（**CLOSED，2026-11-08**）
- **运行时事实**：全局 npm CLI、安装 manifest、当前 active session 均为 `0.2.2-rc.1`
  （`latest`=`next`=`0.2.2-rc.1`，`alpha`=`0.2.2-alpha.3`）；Desktop bundled runtime **仍未升级**，
  `runtime.json` 与 exe FileVersion 都是 `0.2.0-rc.2`。Cordis 内核升到 Core `4.1.0` / Loader `1.1.0` /
  Include `1.1.0`；`0.2.2` 起最低 Node 为 **24.9**。
- **需要修正的旧认知（两条，最重要）**：
  1. **`fs-observation-policy` 在装配层未挂载，但"先读"守卫在运行期仍然生效** —— 两件事必须分开：
     该插件在 `dsh-base` 是 `disabled: true`，`dsh-web-app`、三个 preset、`browser-lab` 的 profile patch
     都没有重新挂载它；但本会话实测改未读文件仍被拒绝，说明守卫至少有相当部分来自 provider
     （`dsh-fs-local`）。⇒ **习惯不变：改前先 `read`**；但不要再把"policy 插件已启用"当作版本差异点，
     也不要把"插件关了"读成"没有护栏"。确切来源分支仍 `[UNKNOWN]`。
  2. **`AGENTS.md` 预算改为按链独立** —— user-global 与 project 各自受 `maxBytes`，双链消息**最多 2×**；
     project 指令**不再**挤掉全局指令，"最宽者先被丢弃"只在**同一条链内**成立。
- **需要限定的机制陈述**：`exit_plan_mode` 改为**渐进披露**（plan mode 首次进入时才 admit，更早调用返回
  `UNKNOWN_TOOL`），因此"plan mode 工具目录恒定"须收窄为**除它以外**的工具集。
- **工具执行平面重构**：`tools.mode` / `DSH_TOOLS_MODE` **已移除**（`mode` 与 `maxParallelSubCalls`
  在 `dsh-tools` 的 `Config` 里被声明为 **`z.never()`** ⇒ 留着旧键会**校验失败并报错**，不是静默忽略；
  `DSH_TOOLS_MODE` 在 `lib` 代码零命中），改为 `tool-executor-native` / `tool-executor-ptc` 两个
  Agent-scoped 插件（本机默认 native、ptc `disabled: true`）；并新增**按 step 条件启用**。
- **`apply_patch` 新增但默认关闭**（base 与 web 预设两层 `applyPatch: false`）；其 README 称已启用，
  与出厂 patch 冲突，记为 `DISCREPANCY`（以 patch 为准）。
- **未变**：`SESSION_FORMAT_VERSION` 仍 `4`、workspace 存储 unit 仍 `2`、goal 投影仍 `version 6` ⇒
  `0.2.0 → 0.2.2` **不在** `[v3 → v4]` 断裂面上。
- **Toolkit v0.2**：机制主张无需改写，维持 **COMPATIBLE WITH CAVEAT**；新增两条 caveat ——
  driver 新增 `disposed` 原因（Agent 销毁只 disarm，不 pause），以及 `update_goal` 对多余字段由"报错"
  改为"**忽略**"；另记：Web **goal bar** 可直接 resume 被 blocked 的 goal，但**已耗尽轮上限的仍需先提高上限**。
- **载体能力**：`dsh web` 新增 `--public-url`、原生 HTTPS（`--tls-cert`/`--tls-key`），`--host` 收紧为
  单个具体本地地址；远程 WebSocket 默认压缩；UI 新增 6 种 locale（共 8 种）。
- **规模**：npm 缓存逐文件对比 —— 294 个共有包、**+26 新包**、**−1 包**（`…-model-label-1017`）、
  1752 新增文件 / 52 删除 / 1609 修改。
- **详细证据与 K01–K45 对照**：
  [experiments/dsh-version-audit/0.2.1-rc.2-to-0.2.2-rc.1/](experiments/dsh-version-audit/0.2.1-rc.2-to-0.2.2-rc.1/)
  （`FINAL-REPORT.md` / `KNOWLEDGE-DELTA.md` / `RUNTIME-VERIFICATION.md`）。

---

## 当前最重要的已验证能力

1. **Instruction 原样承载（已 E2E）**：把 `CLAUDE.md` 放进 workspace 根（project 级），或把 `AGENTS.md` 放进 `$DSH_HOME`（**user-global** 级），DSH 都会在**首次 model request 之前**注入为 durable user-role instruction —— 无需格式转换、无需工具调用；**已存在的 session 也会在下一个 step 感知新增/修改**（不重启、不新建 session）。
2. **浏览器由 Agent 驱动（Interactive SPA E2E PASS）**：通过 `dsh-mcp-client` + Playwright MCP，Agent 能真的打开本机 Chrome、navigate、读取 accessibility tree、并**用 `[ref=eN]` 点击交互元素改变服务端结果集**（实测 `167 → 147`）。
3. **bundle 归属是 profile 私有的（P2 已实测）**：`dsh plugin --profile <name> add <bundle>` 只写目标 profile；第三方 bundle（`dsh-whale-widget@0.3.0`）能独立安装并运行在 `browser-lab` 上，而 `web` 的 profile 文件哈希**逐一无变化**。区分「package 可解析」与「bundle mounted」。
4. **全局安装与 profile-local 状态相互独立（升级事故实证）**：整个全局 DSH 安装被替换成 rc.3 后，`browser-lab` 的 `dsh.profile.bundles` 未变、Whale 仍在运行、`web` 未被触碰。⇒ 诊断故障时能先**定位层**（安装层 / profile 层 / 运行期层）。

---

## 下一步研究方向

1. **Browser MCP 的复杂交互边界**：navigate / snapshot / **click** 已验证；**更复杂交互**（搜索输入、多条件组合筛选、翻页、详情页深层导航、表单填写/提交）**尚未系统验证**；同一轮 console 出现的 `1 errors, 4–6 warnings` 也**未读取、未归因**。
2. **DSH browser workflow 的实用性**：多个 MCP server 共存、MCP 工具在不同 preset 下的可见性裁剪、`@playwright/mcp@latest` 的版本漂移风险。
3. **PJOS 迁移的 Phase 3.3+**：真实项目数据上的 write 安全、privacy 运行期验证、rollback 实测。
4. **profile / bundle 隔离（P2 已完成；full E2E = PARTIAL）**：命题「bundle 归属是 profile 私有的 —— 只加到 `web` 的 bundle 不应进入 `browser-lab` 的合成 Cordis 树」已由**源码 + 真实安装 + 运行**三方证实；
   `web` 非成员已逐文件哈希核对 PASS，但 **AFTER `--dump-config` 合成树未采集**（该命令会重写 profile 的 `cordis.yml` 且需新进程），故 full E2E 仍为 PARTIAL。
   剩余可做项：AFTER dump 补齐、**对称性实验**（给 `web` 装 bundle 验证 `browser-lab` 不受影响）、负向对照 N1（把 insert 写进 `$DSH_HOME/cordis.patch.yml` 验证其确实跨 profile 泄漏）、N3（装进只有 `dsh-base` 的 profile 验证 `inject: ['webServer']` 不满足时的表现）。
   → `docs/07-profile-bundle-isolation.md`、`experiments/profile-isolation/`
5. **DSH 安装 / 升级行为（已沉淀知识，边界仍 UNKNOWN）**：
   - [UNKNOWN] npm 对 **prerelease caret** 的完整匹配规则（本次只证明了**结果**，未证明规则）
   - [UNKNOWN] 导致 Loader 找不到 `dsh-sandbox-local` 的**具体依赖边 / 嵌套布局**
   - [UNKNOWN] rc.3 恢复的**决定性因素**（exact pin / manifest 修复 / layout / 版本线对齐，四者同时变化，无法拆分）
   - [UNKNOWN] `install-scripts blocked` 对 **PTY / native subprocess / sandbox / 未测 agent tools** 的影响
   - **[UNKNOWN] 独立研究线**：file read/write consistency guard（`file has not been read` / `file changed since it was read` / `file no longer exists`）与本次升级的**关系未验证** —— **不建立因果**，也不把 rc.3 正常写成"guard 已修复"
   → `docs/08-dsh-installation-and-upgrade.md` §10

---

## 快速索引

| 我想知道…… | 去哪 |
|---|---|
| DSH 概念 ↔ 本机路径 | `docs/00-dsh-local-filesystem.md` |
| Host / Agent 的层级关系 | `docs/01-host-composition.md` |
| patch / Root Include / `!!js` / 热更新 | `docs/02-root-include-and-patch-composition.md` |
| 研究上下文与阶段状态 | `docs/03-research-context-and-next-phase.md` |
| agent preset / `AGENTS.md` / instruction 注入 | `docs/04-agent-composition-and-instructions.md` |
| Browser MCP 链路与 E2E | `docs/05-browser-mcp.md` |
| 多进程 / runtime 一致性 | `docs/06-dsh-runtime-and-multiprocess.md` |
| Claude Code → DSH 迁移 | `docs/migration/` |
| 某结论的原始证据 | 各文档末尾的 **Evidence** 段 → `experiments/` / `evidence/` |
| 浏览器能力探测的原始数据 | `experiments/browser-probe/README.md` |
| profile / bundle 隔离（归属、写入面、共享层） | `docs/07-profile-bundle-isolation.md` · `experiments/profile-isolation/` |
| 安装 / 升级 / 依赖解析（三层模型、回滚语义） | `docs/08-dsh-installation-and-upgrade.md` · `experiments/dsh-install/` |
| 事故的原始 npm 日志 | `evidence/logs/npm/` |
| Long-running Toolkit（正式发布 / 历史研发 / 证据） | `toolkit/long-running/RELEASES.md` · `experiments/long-running/README.md` |

## 环境

- DSH：`@deepseek-ai/dsh@0.2.2-rc.1` · Node `v24.20.0` · npm `12.0.2` · Corepack `0.35.0` · pnpm `12.4.2`（`C:\Program Files\nodejs\`，由 Corepack 安装）
  > ★ **"当前版本"以 `docs/00-dsh-local-filesystem.md` §0.1 为唯一事实源**；本行只是概览。
  > 注：本行是**全局 npm 安装**的版本；当前正在服务的 Web session 运行在 **CLI/Web 的 `browser-lab` profile**
  > （`0.2.2-rc.1`）上，**不是** Desktop。Desktop bundled runtime 仍为 `0.2.0-rc.2`（见 `docs/09-dsh-desktop.md` §3.1）。
  > `0.2.2` 起 DSH 的**最低 Node 要求为 24.9**（本机 `v24.20.0` 满足）。
  > Cordis 内核（组合语义载体）：Core `4.1.0` · Loader `1.1.0` · Include `1.1.0`。
  > Long-running Toolkit v0.2 的机制主张仍**按 `0.2.0-rc.2` 核对**；2026-10-19 的 0.2.1 复核为
  > **COMPATIBLE WITH CAVEAT**（见 §10），2026-11-08 的 0.2.2 复核维持该判定并新增两条 caveat（见 §11）。
- `$DSH_HOME`：`C:\Users\user02\.dsh`
- 本 workspace：`D:\Projects\dsh-test`
- 研究 specimen：`D:\Projects\Personal Job Search OS`

> 本 workspace **不是 git 仓库**（`git rev-parse` 失败）——文件变更没有版本控制兜底，改动请谨慎。

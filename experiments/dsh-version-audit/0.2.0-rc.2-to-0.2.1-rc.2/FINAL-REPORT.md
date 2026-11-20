# FINAL REPORT — DSH 0.2.1-rc.2 Cross-Version Knowledge Audit

- 任务性质：RESEARCH / AUDIT（非开发、非 Toolkit 升级）
- 日期：2026-10-19
- 工作区：`D:\Projects\dsh-test`
- 审计对象：本仓库既有的 DSH 运行机制认知、实验结论、Long-running Toolkit v0.2
- 研究区：`experiments/dsh-version-audit/0.2.0-rc.2-to-0.2.1-rc.2/`
- 冻结状态：Toolkit、RELEASES.md、RELEASE-REPORT.md、v0.1 Pilot、旧证据**全部未修改**

---

## 1. Executive summary

1. **CLI 与 active session 都是 0.2.1-rc.2；Desktop 仍是 0.2.0-rc.2。** 当前 Web session 运行在
   `browser-lab` profile 的 0.2.1 CLI runtime 上，不是 Desktop bundled runtime。判别依据是 0.2.1-only 的
   `working_directory` 工具与安装锚点，而不是 UI 版本号。
2. **0.2.1 是一次大版本功能线，rc.2 只是小增量。** rc.1 汇总了自 0.2.0-rc.2 以来的大量变更；
   rc.2 只增加 DeepSeek-V4.1-Flash-1017 支持与 DeepSeek Search/Fetch API。
3. **Toolkit v0.2 的 10 项契约没有一条被直接否定。** 总体判定 **COMPATIBLE WITH CAVEAT**：goal/plan/budget/
   authority/session/skill/sandbox 的核心语义保持；但 driver 新增“等待子代理后再开轮”、plan review dismiss
   语义变化、`working_directory` 是新的独立机制、`{{cwd}}` prompt 变量被移除。
4. **“DeepSeek-V4.1-Flash-1017” 的 1017 是客户端展示，不是权重证明。** 模型 catalog 的请求 ID 仍是
   `deepseek-flash`，请求参数未变；实际 API 路由到的权重版本是 `UNKNOWN`。
5. **安装完整性 PASS / PARTIAL**：五个被 install-scripts 标记的包都存在且可加载，native prebuild 存在；
   唯一异常是 node-pty 的 ConPTY spawn 失败，根因 `UNKNOWN`，未证明是版本回归。
6. **没有做 Goal live test**（任务禁止）。所有 goal driver 结论是源码/官方文档级，不是运行时实证。

**结论：KNOWLEDGE AUDIT = COMPLETE（带明确 UNKNOWN）；TOOLKIT V0.2 = COMPATIBLE WITH CAVEAT。**

---

## 2. Verified runtime versions

| 项目 | 值 | 等级 | 说明 |
|---|---|---|---|
| CLI package version | `0.2.1-rc.2` | FACT | `dsh --version`；`package.json` |
| Active session runtime | `0.2.1-rc.2` | FACT | 0.2.1-only `working_directory` 工具 + 安装锚点 + profile 非 desktop |
| Desktop application runtime | `0.2.0-rc.2` | FACT | `runtime.json` → `desktopVersion` |
| Session | `session-32aa9e1e-…`，format v4 | FACT | session header |
| Profile | `browser-lab` | FACT | `DSH_PROFILE` |
| Workspace | `D:\Projects\dsh-test` | FACT | `pwd` / `working_directory` |
| Selected model ID | `deepseek-flash` | FACT | `request/header.config` |
| Provider | `deepseek-official` | FACT | 同上 |
| Reasoning effort | `low` | FACT | 同上 |
| Context window | `1,000,000` | FACT | `request/context` |
| Display name | `DeepSeek-V4.1-Flash` + `1017` badge | FACT（源码） | 客户端 plugin |
| Actual API-routed weight version | **UNKNOWN** | UNKNOWN | 本地无字段可证 |
| Permissions | `workspace-write` / `ask` | FACT | session events |
| Git repo | 无 | FACT | `.git` absent |
| Active Goal | 无 | FACT | `get_goal` → null |

### 2.1 版本层级拆分（任务要求）

| 层级 | 值 | 能否独立验证 |
|---|---|---|
| CLI package version | 0.2.1-rc.2 | 能 |
| Desktop application version | 0.2.0-rc.2（runtime.json） | 能（磁盘） |
| Active session runtime version | 0.2.1-rc.2 | 能（0.2.1-only 工具 + 锚点） |
| Selected model ID | `deepseek-flash` | 能 |
| Actual API-routed model version | UNKNOWN | **不能** |

---

## 3. Major changes (0.2.0-rc.2 → 0.2.1-rc.2)

### 3.1 官方记录（C 层）

rc.2 只有两项：V4.1-Flash-1017 支持、DeepSeek Search/Fetch API。其余变更来自 rc.1。
rc.1 的官方摘要包括：`working_directory` 工具、子代理等待目标轮次、移除 invariant 导出、
移除 `both` 工具模式、plan review dismiss 结束本轮、API key 优先级、gateway 授权/Peer 主体、
`--public-url`、Web 绑定地址/TLS、Azure provider 更名、SDK resume 等。

### 3.2 源码确认（B 层，逐文件对照）

| 领域 | 变化 | 证据 |
|---|---|---|
| Goal driver | 新增 `drivable()`；等子代理后代 settle 后才开轮；idle 时移除排队 round prompt；区分 pause/disarm；unload 处理 | `UP/changed/dsh-goal-round-driver/.../lib/index.js` |
| Goal domain | 四 phase、activation 不持久、256 默认、round-count only **未变**；invariant companion 删除 | `dsh-goal/README.md`；DIFF 删除 `lib/invariant.js` |
| Goal tool | authority 逻辑**字节相同**；blocked 仍需 ≥3 个 goal round | `dsh-tool-goal/lib/index.js` |
| Plan mode | dismiss 返回 `{approved:false}` 并结束 turn；提示词改为 “until exit_plan_mode succeeds…” | `dsh-plan-mode/lib/index.js` + `standard.patch.yml` |
| Skill discovery | roots/depth/frontmatter 未变；shared agents home 改用 `resolveAgentsHome` | `dsh-skill-filesystem` |
| Sandbox / approval | mode 与 policy 语义未变；invariant 删除 | `dsh-sandbox-policy` / `dsh-fs-sandbox` / `dsh-user-approval` |
| Working directory | **新机制/新工具**：可改 Session cwd，required user context；sandbox grant 独立 | `dsh-working-directory` / `dsh-tool-working-directory` |
| Session persistence | 格式仍 v4；实现改进：dispose 顺序、listConcurrency=3、worker 自然 exit 0、formatStatus | `dsh-session-persistence-jsonl` |
| Prompt assembly | 移除 `{{cwd}}` variable；新增 required/optional runtime context、`refreshContext` | `dsh-system-prompt` / `dsh-agent-loop` |
| Tools / PTC | `mode` 只剩 `native | ptc`；`run_code` 启动时捕获 cwd；PTC state 默认 fresh | `dsh-tools` |
| Model adapter | catalog name `V41`→`V4.1`；其余 model 字段未变；新增 catalog field validation、provider connect/admit | `dsh-llm-deepseek` |
| Web composition | 新增 time-context、tool-schedule、model-label、secret-mask、harness-dev-context | `dsh-web-app/cordis.patch.yml` |
| Remote/API | 新增 Peer principal + `dsh-api-remote-access`；gateway 每次调用需显式 peer | `dsh-api-gateway` / `dsh-api-remote-access` |

### 3.3 包级规模

- npm cache 中 306 个 `@deepseek-ai/*` 包、573 条版本记录，全部 integrity 可解析。
- 267 个包在 0.2.0-rc.2 与 0.2.1-rc.2 同时存在；其中 265 个有 README 变化、190 个新增 locale、
  161 个有 `lib/*.js` 字节变化。
- 变化文件合计：527 added / 188 removed / 1801 changed（含 bundle hash 文件名、locale、README 等构建噪音）。
- 11 个包只存在于 0.2.0（如 `dsh-invariants`、`dsh-hooks-*`、`dsh-subagent-in-process-driver`）；
  28 个包只存在于 0.2.1（如 `dsh-working-directory`、`dsh-tool-working-directory`、
  `dsh-client-ui-deepseek-model-label-1017`、`dsh-harness-dev-context`、`dsh-plugin-market`）。

> 注意：不能因为“267/267 都有变化”就声称“所有机制都变了”。大量变化是版本号、locale、README、
> bundle 文件名重建；语义结论以上表逐项阅读为准。

---

## 4. Unchanged assumptions

以下旧认知在 0.2.1 下仍成立（源码/文档级）：

1. `create_goal` / `edit` / `pause` / `resume` 需要 direct human；`complete` / `blocked` 可在当前 goal round。
2. `maxGoalRounds` 是唯一 HARD 预算；cap 处写 `round-limit` blocker；默认 256；省略 cap 会用默认值。
3. token / cost / wall-clock / tool-call 预算仍是 SOFT；driver 不做计量。
4. `READY FOR HUMAN REVIEW` 仍是状态报告，不停止 driver。
5. Goal 的 `activation` 仍是 process-local；resume/fork/restart 后 active goal 为 disarmed，需人类 re-arm。
6. Plan 与 Goal 是独立机制；plan approval 不创建/arm goal；plan mode 不限制工具面。
7. Session format 仍是 v4；goal/plan/state/evidence 持久。
8. Skill discovery 仍是 depth 1、`<root>/<name>/SKILL.md` 或 `<root>/<name>.md`、frontmatter 必需、
   project root 用最近 `.git` 祖先（否则 cwd）。
9. `workspace-write` 仍是真实文件围栏；`ask` 仍是交互闸门；两者正交。
10. 机械 evaluator ≠ 人工验收；模型不能自评通过。
11. Final Report 必须在 arm 前固定路径/owner，并从逐轮 evidence 生成。
12. Toolkit 文件是纯 Markdown + 外部 evaluator，不依赖任何被移除的插件 API。

---

## 5. Contradicted assumptions

没有“旧机制被新版本推翻”的条目。被**环境演进而取代**的有两条，均属于版本事实而非机制错误：

| 旧陈述 | 旧证据 | 现状 | 处理 |
|---|---|---|---|
| 全局 npm DSH = `0.1.5-rc.3` | `docs/00-dsh-local-filesystem.md:30-33`（2026-10-05） | 现为 `0.2.1-rc.2` | 保留旧记录 + 本报告新增版本注记 |
| 当前 Web session 跑在 Desktop bundled runtime `0.2.0-rc.2` | `README.md:154-155`（升级前） | 本 session 跑在 CLI 0.2.1-rc.2 的 `browser-lab` profile；Desktop 仍 0.2.0-rc.2 | 保留旧记录 + 本报告新增版本注记 |

另有两条**表述需要细化**，但不是矛盾：

- 旧 driver 描述“round 只在 whole-agent idle 时开始” → 0.2.1 还要求子代理后代 settle（若 subagents 已挂载）。
- 旧 plan review 描述“dismiss = failed call” → 0.2.1 dismiss 返回 `{approved:false}` 并结束 turn。

---

## 6. Unknowns and untested items

| 项目 | 状态 | 原因 |
|---|---|---|
| Goal live test（create/arm/round/cap/pause/resume） | **NOT RUN** | 任务明确禁止；`GOAL LIVE TEST: NOT RUN` |
| 越界写入被 sandbox 拒绝的运行时证据 | **NOT TESTED** | 任务禁止为验证权限而越界写 |
| v0.2 evaluator 四模式 live 重跑 | **NOT RUN** | 本轮只做只读审计；机械检查通过 ≠ harness 实测 |
| toolkit `SKILL.md` live discovery | **NOT TESTED** | 未安装到 skill root；当前 catalog 无该 skill |
| 真实 API 路由到的权重版本 | **UNKNOWN** | 本地无字段；UI 名称不是证明 |
| 当前使用的 credential 路径 | **UNKNOWN** | 未读取凭据（禁止暴露） |
| node-pty ConPTY 失败根因 | **UNKNOWN** | 环境限制 vs node-pty/ConPTY 兼容性无法拆分 |
| Desktop 与 CLI 的 v4 session 互操作 | **NOT RETESTED** | 本轮不启动 Desktop；旧结论保留 |
| 0.2.1 对 Agent 成功率的量化影响 | **UNKNOWN** | 无同模型/同任务/同条件对照实验 |

---

## 7. Model adaptation findings

### 7.1 事实

1. 官方 rc.2 明确写 “Add support for DeepSeek-V4.1-Flash-1017”。
2. `dsh-llm-deepseek` 的内置 catalog：
   - `id: "deepseek-flash"`；
   - `name: "DeepSeek-V41-Flash"` → `"DeepSeek-V4.1-Flash"`；
   - `contextWindow`、`inputModalities`、`systemPromptUpdate: "in-history"`、`toolUpdate: "addition-only"`
     在 0.2.0 与 0.2.1 **逐字相同**。
3. 新包 `dsh-client-ui-deepseek-model-label-1017` 只装饰 composer 的 label；README 明确：
   “fixed client presentation, **not a server capability assertion**”；不改变请求、不改变 cache。
4. 本 session 实际请求配置：provider `deepseek-official`、model `deepseek-flash`、reasoningEffort `low`、
   maxTokens `256000`、contextWindow `1,000,000`。
5. rc.1 的通用改动中，可能间接影响 Agent 效果的有：
   - 子代理等待/委派指引；
   - `systemPromptUpdate` / 动态 tool 更新的通用处理；
   - 空 assistant text block 被跳过（Messages 序列化）；
   - `{{cwd}}` 改为 working-directory required context；
   - plan review dismiss 不再多一次模型调用。
   这些**不是** V4.1 专属适配。

### 7.2 结论

- **FACT**：0.2.1-rc.2 让 “DeepSeek-V4.1-Flash” 在 catalog/UI 中可见且命名正确；请求 ID 仍是 `deepseek-flash`。
- **FACT**：没有发现 V4.1 专属的 tool-call 协议、请求参数或 prompt 分支。
- **INFERENCE**：因此“新版 DSH 专门改善了 V4.1 在 Agent 工作流中的表现”**不能从源码得到支持**；
  能支持的只是“模型可见性与展示层适配”。
- **UNKNOWN**：实际 API 路由到的权重版本；是否存在服务端灰度/别名映射。
- **禁止结论**：不得声称“成功率提升 X%”“性能显著提高”“旧 Harness 严重限制模型能力”。
  本轮没有同模型、同任务、同条件的对照实验。

### 7.3 模型服务端升级 vs Harness 升级

| 维度 | 本轮的证据 | 结论 |
|---|---|---|
| 模型服务端 | 只有本地 selected ID 与 catalog name | 权重版本 UNKNOWN |
| DSH Harness | 已安装源码 + 官方 release notes + 运行时工具面 | 0.2.1-rc.2，变更可列 |
| 二者交互 | 无对照实验 | 不可量化 |

---

## 8. Installation health

| 检查 | 结果 |
|---|---|
| 5 个被标记包存在 | PASS |
| 模块 import（subprocess-local / koffi / node-pty / @google/genai / protobufjs） | PASS |
| native binary（koffi.node、conpty prebuild、sharp） | PASS（存在） |
| 普通子进程执行 | PASS |
| `pwsh` 工具调用 | PASS |
| MCP bridge | PASS（30 个 playwright 工具） |
| node-pty ConPTY spawn | **FAIL — `Cannot launch conpty`** |

分类：**INSTALLATION / ENVIRONMENT ISSUE**，不是已证实的 VERSION REGRESSION。
没有执行 `npm rebuild` / `npm install` / `allow-scripts` / 下载 native binary；没有改全局安装文件。
本 profile 未挂 terminal 工具，因此该失败对本次审计无实际影响；若未来使用 Web terminal，应另开环境复测。

**INSTALLATION HEALTH = PARTIAL**（主体 PASS，PTY 一项 FAIL/根因 UNKNOWN）。

---

## 9. Toolkit compatibility

总体：**COMPATIBLE WITH CAVEAT**。逐项详见 `TOOLKIT-COMPATIBILITY.md`。

| # | 契约 | 判定 | 关键 caveat |
|---|---|---|---|
| 1 | 目标创建方式 | COMPATIBLE | 无 |
| 2 | Plan 审批方式 | COMPATIBLE WITH CAVEAT | dismiss 语义变化 |
| 3 | Round 预算语义 | COMPATIBLE WITH CAVEAT | 开轮前等子代理 |
| 4 | Driver 停止行为 | COMPATIBLE WITH CAVEAT | post-cancel 路径细分 |
| 5 | Skill 搜索与加载 | COMPATIBLE WITH CAVEAT | 未 live 验证 |
| 6 | workspace-write | COMPATIBLE WITH CAVEAT | 改 cwd ≠ 改 sandbox grant；越界拒绝未实测 |
| 7 | 人工批准门槛 | COMPATIBLE | blocked ≥3 轮是补充 |
| 8 | Session 恢复 | COMPATIBLE | 实现更严格 |
| 9 | Evaluator 执行 | COMPATIBLE | 未 live 重跑 |
| 10 | 最终报告证据规则 | COMPATIBLE | 纯方法论 |

**没有修改 v0.2 任何文件**；哈希 8/8 与发布记录一致。也没有创建 v0.3。

---

## 10. Recommendations

1. **写版本注记，不改冻结件。** 在未来的知识文档中明确：Toolkit v0.2 的验证基线是 0.2.0-rc.2；
   在 0.2.1-rc.2 上为 source-level compatible with caveat。
2. **优先做一次“Goal live test”对照**（需用户授权，另开轮次）：create with cap=2、观察 round 计数、
   cap blocker、pause/resume、以及子代理存在时的开轮时机。这是目前最大的证据缺口。
3. **补一次 skill discovery live test**：把 `SKILL.md` 放到 `.dsh/skills/long-running/SKILL.md`（或
   `.agents/skills`），确认 session catalog 出现该 skill，再记录 frontmatter/路径结果。
4. **不要基于 1017 badge 做模型能力结论。** 如需比较模型，必须固定 harness 版本、prompt、任务与评分器，
   做 A/B；否则只能报告 `UNKNOWN`。
5. **Windows PTY 问题单独归档。** 在非沙箱、挂 terminal 的 profile 中复测 `node-pty`；不要把本次
   `Cannot launch conpty` 写成 0.2.1 回归。
6. **检查自定义 profile 是否使用已移除接口**：`./invariant`、`tools.mode: both`、
   `persona` 中的 `{{cwd}}`、`agent-instructions` 的逐行 `dshHome`。本仓库 `browser-lab` 均未使用。
7. **Desktop 与 CLI 的版本差要保持可见。** CLI 0.2.1 / Desktop 0.2.0 共享 `$DSH_HOME`；在跨版本 session
   互操作上继续沿用旧的“版本边界”谨慎策略，不要把 CLI 升级当成 Desktop 升级。
8. **保持 `workspace-write` + `ask`。** 本轮没有证据支持放宽；也没有证据表明需要放宽。

---

## Appendix — 本轮安全边界遵守情况

| 约束 | 状态 |
|---|---|
| 只写新研究目录 | 是 |
| 不改 `toolkit/long-running/v0.2/` | 是（8/8 hash 未变） |
| 不改 RELEASES.md / RELEASE-REPORT.md | 是 |
| 不改 rc1/rc2/rc3 历史记录 | 是 |
| 不改 v0.1 Pilot（仓库外） | 是（未打开写入） |
| 不删除旧证据 | 是 |
| 不创建/arm/resume Goal | 是（`get_goal` 只读） |
| 不启动 Ralph | 是 |
| 不改 Profile / API Key / Provider | 是 |
| 不改 npm allowScripts / 不安装依赖 | 是 |
| 不申请 danger-full-access | 是 |
| 不访问真实业务项目 | 是 |
| 不发布新 Toolkit | 是 |

---

DSH VERSION:
0.2.1-rc.2

MODEL:
VERIFIED (selected ID `deepseek-flash` / provider `deepseek-official`; routed weights UNKNOWN)

KNOWLEDGE AUDIT:
COMPLETE

TOOLKIT V0.2 COMPATIBILITY:
COMPATIBLE WITH CAVEAT

INSTALLATION HEALTH:
PARTIAL

GOAL LIVE TEST:
NOT RUN

PUBLISHED TOOLKIT:
UNCHANGED

HISTORICAL EVIDENCE:
UNCHANGED

NEW TOOLKIT VERSION:
NOT CREATED

STOP FOR HUMAN REVIEW.

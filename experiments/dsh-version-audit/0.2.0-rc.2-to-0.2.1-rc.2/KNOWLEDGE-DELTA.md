# KNOWLEDGE-DELTA — 0.2.0-rc.2 → 0.2.1-rc.2

本文件逐条对照本仓库既有的 DSH 运行机制认知（K01–K21，另加 K22–K24）与当前 0.2.1-rc.2 的证据。

阅读规则：

- **旧版认知**一律保留其成立时的版本条件（0.2.0-rc.2，2026-10 上旬）。
- **不修改**旧文档；本文件只记录差异与建议。
- 每条给出 `FACT` / `INFERENCE` / `UNKNOWN`。`FACT` 仅用于本次直接读到的源码、文档原文或运行时观测。
- 建议处理方式仅取：`KEEP`、`ADD VERSION NOTE`、`RETEST`、`FUTURE REVISION`。

证据缩写：

- `UP/` = `experiments/dsh-version-audit/0.2.0-rc.2-to-0.2.1-rc.2/evidence/upstream/`
- `DIFF` = 同目录 `evidence/package-diff.json`
- `REL` = `evidence/official-release-notes.md`
- 旧版包源码 = npm cache 中的 `@deepseek-ai/*@0.2.0-rc.2` tarball；新版 = 本机已安装的 `0.2.1-rc.2`。

---

## K01 — Goal 创建与启动语义

- **旧版认知**：`create_goal` 必须来自 direct human turn（runtime-root agent）；创建即启动自动续轮；`max_goal_rounds` 应显式传入，省略即用部署默认值。
- **旧版证据**：`experiments/long-running/PILOT-SPEC-v0.1.md:137-140`；`experiments/long-running/RUNBOOK.md:87`；`toolkit/long-running/v0.2/README.md:289-298`。
- **新版证据**：`UP/changed/dsh-tool-goal/0.2.1-rc.2/package/lib/index.js` 中 `requireDirectHuman()` / `completionAuthority()`；该文件在 DIFF 中**不在** changed 列表（0.2.0 与 0.2.1 字节相同）。`dsh-goal/README.md` L12、L41-48 仍写 `defaultMaxGoalRounds: 256`。本会话 `get_goal` 返回 `{"goal":null}`，说明当前没有活动 Goal。
- **差异性质**：NO CHANGE（权威规则、创建即启动、默认 cap 全部保持）。
- **等级**：FACT（源码逐字节相同 + 当前运行时工具存在）。
- **建议处理方式**：KEEP。

## K02 — maxGoalRounds HARD cap

- **旧版认知**：`maxGoalRounds` 是唯一 HARD 预算；driver 在 cap 处写稳定的 `round-limit` blocker 并停止。
- **旧版证据**：`PILOT-SPEC-v0.1.md:86-96`；`toolkit/long-running/v0.2/METHODOLOGY.md:118-128`；`README.md:207-213`。
- **新版证据**：`UP/changed/dsh-goal-round-driver/0.2.1-rc.2/package/lib/index.js` 仍有
  `if (goal.roundsStarted >= goal.maxGoalRounds) { ctx.goals.block(... code: "round-limit" ...) }`；
  `dsh-goal/README.md` 的 “Round-count budget only — maxGoalRounds does not meter tokens, currency,
  wall time, or provider quotas” 未被删除。DIFF 显示该 README 仅删除 invariant 说明。
- **差异性质**：NO CHANGE。
- **等级**：FACT。
- **建议处理方式**：KEEP。

## K03 — token / cost / time 等 SOFT 预算

- **旧版认知**：除 round cap 外全部是 SOFT；没有 host 计量器，记录 `UNKNOWN` 而不是估算。
- **旧版证据**：`PILOT-SPEC-v0.1.md:87-96`；`toolkit/.../METHODOLOGY.md:118-128`；`README.md:207-222`。
- **新版证据**：`dsh-goal/README.md` L158 仍明确 “Round-count budget only”；`dsh-goal-round-driver`
  内没有任何 token/cost/time 计数逻辑（通读 `lib/index.js`，只有 round 计数）。`dsh-token-meter`
  在 DIFF 中有改动，但改动是 projection/breakdown 数据形状（`surface-fold`、`surface-projection`），
  不是预算执行器。
- **差异性质**：NO CHANGE（预算语义）；token meter 的**显示**有改动。
- **等级**：FACT（执行层无计量）；INFERENCE（“meter 只影响显示”基于改动文件与 README 职责）。
- **建议处理方式**：KEEP；如引用 token 数字，仍标 `UNKNOWN`/self-reported。

## K04 — Goal driver 的停止行为

- **旧版认知**：round 只在 whole-agent idle 时开始；completion / pause / blocking 抑制续轮；host pause 会中止正在运行的 turn；cap、durability 写失败、cancel、plugin unload 都会停止。
- **旧版证据**：`toolkit/.../METHODOLOGY.md:135-164`；`PILOT-SPEC-v0.1.md:98-108`。
- **新版证据（源码）**：`UP/changed/dsh-goal-round-driver/0.2.1-rc.2/package/lib/index.js` 新增：
  - `drivable(goal)` 判定 `phase === "active" && activation === "armed"`；
  - 当 `subagents` 服务存在时 `await Promise.race([subagents.waitForChildren(agent), unloading.promise])`，即**先等待子代理后代结束**再开始下一轮；
  - idle 时若 round prompt 仍在队列，`agent.inbox.remove(attempt.messageId)` 把它移除，避免后续人类输入排在它后面；
  - 区分 `pause`（cancel 属于本 goal 的 round）与仅 `disarm`（cancel 属于其他工作）；
  - unload 时 resolve `unloading` 并等待关闭。
  **官方发布说明**：`REL` 中 rc.1 “wait for running subtasks before starting another goal round” 与
  “fix new messages remaining queued after stopping, resuming, and stopping a goal-driven task again”。
- **差异性质**：ADDITIVE / REFINED。旧结论仍成立，但不再完整：旧版没有“等子代理”和“idle 移除排队 round prompt”这两条。
- **等级**：FACT（源码 + 官方说明 + DIFF）。
- **建议处理方式**：ADD VERSION NOTE。不要把这两条写进冻结的 v0.2；如未来做 v0.3，再纳入。

## K05 — READY FOR HUMAN REVIEW 的实际作用

- **旧版认知**：它只是状态报告，不停止 driver；只有 human pause、生命周期终止或 cap 才真正停止。
- **旧版证据**：`toolkit/.../METHODOLOGY.md:361-388`；`SKILL.md:352-384`。
- **新版证据**：0.2.1 的 driver 源码中没有对 `READY FOR HUMAN REVIEW` 或任何状态文件字符串的解析；
  `drivable()` 只看 `phase`/`activation`。`dsh-goal` 的 `activation` 仍是 process-local（README L99）。
  官方 rc.1 变更未提及该 marker。
- **差异性质**：NO CHANGE。
- **等级**：FACT（源码无反制）；INFERENCE（“没有反制”即“不停止”）。
- **建议处理方式**：KEEP。

## K06 — complete / blocked 的使用条件

- **旧版认知**：模型不能在自动轮中 pause/resume/re-arm；但在当前 goal round 中调用 `complete`/`blocked`
  是合法且会结束本轮与续轮；用它们当刹车是错误记录。
- **旧版证据**：`toolkit/.../METHODOLOGY.md:376-388`；`PILOT-SPEC-v0.1.md:137-142`。
- **新版证据**：`UP/changed/dsh-tool-goal/0.2.1-rc.2/package/lib/index.js`（与 0.2.0 相同）：
  `completionAuthority()` 允许 direct-human 或 matching goal round；
  `blocked` 在 goal-round 权威下要求 `roundsStarted >= blockedAfterConsecutiveRounds`（默认 3，`GOAL_TOOL_BLOCK_THRESHOLD`）；
  `complete`/`blocked` 后会注入 closing wrap-up context。
- **差异性质**：NO CHANGE；补充了一条旧 toolkit 未写明的定量门槛（blocked ≥3 轮）。
- **等级**：FACT。
- **建议处理方式**：ADD VERSION NOTE（把 “blocked 至少 3 个连续 goal round” 作为版本注记；不改 v0.2 正文）。

## K07 — Plan 与 Goal 的区别

- **旧版认知**：Plan 与 Goal 是独立官方机制；批准 plan 不创建/arm goal；plan mode 是 guidance，不限制工具。
- **旧版证据**：`PILOT-SPEC-v0.1.md:43-53`；`toolkit/.../METHODOLOGY.md:295-308`；`SKILL.md:129-147`。
- **新版证据**：`UP/changed/dsh-plan-mode/0.2.1-rc.2/package/README.md` 仍写“exit_plan_mode schema remains
  available in both states; execution outside plan mode fails”；`dsh-plan-mode` 的 index.js 差异只涉及
  审阅对话框的返回/渲染，不涉及 goal。
- **差异性质**：NO CHANGE。
- **等级**：FACT。
- **建议处理方式**：KEEP。

## K08 — Plan Approval 人工门槛

- **旧版认知**：`exit_plan_mode` 需要人类在 plan-review 问题中批准；拒绝会带反馈失败；plan approval 是设计评审，不是安全边界。
- **旧版证据**：`toolkit/.../SKILL.md:129-147`；`README.md:167-175`；`PILOT-SPEC-v0.1.md:45-49`。
- **新版证据（源码 + 官方）**：0.2.1 `dsh-plan-mode` 的 review 渲染改为
  `approved ? "Plan approved …" : "The user dismissed the plan review to reply in their own words; plan mode remains active."`；
  dismiss 时返回 `{ approved: false }` 并 `exec.concludeTurn()`，不再抛错。
  官方 rc.1：“End the current turn and wait for user feedback when a plan review is dismissed …
  avoiding an extra model call.”
  同时 `dsh-web-app/presets/standard.patch.yml` 的 plan-mode 提示词从
  “until the user approves your plan through exit_plan_mode” 改为
  “until exit_plan_mode succeeds or the user switches the session mode”，并强调“conversational agreement approves nothing”。
- **差异性质**：CHANGED（交互细节与提示词），但**人工门槛仍然存在**。
- **等级**：FACT。
- **建议处理方式**：ADD VERSION NOTE。

## K09 — Session 创建、复用和恢复

- **旧版认知**：goal/plan/state 持久；`activation` 是 process-local，resume/fork/restart 后 active goal 变 disarmed；session format 为 v4（0.2.0）。
- **旧版证据**：`PILOT-SPEC-v0.1.md:98-108`；`toolkit/.../METHODOLOGY.md:152-164`；`docs/06-dsh-runtime-and-multiprocess.md:30-52`。
- **新版证据**：`dsh-session` 的 `SESSION_FORMAT_VERSION = 4` 未变；`dsh-session-persistence-jsonl` 的
  README 仍描述 same zstd frames / per-append frame；`dsh-llm-deepseek` 的 delivery event 中
  `sessionFormatVersion: 4`。DIFF 显示 persistence 的实现改动集中在：dispose 顺序（先等 consumer unload）、
  `listConcurrency`、worker 必须自然 exit 0 才接受结果、`formatStatus` 物化快照。
  goal 的 `activation` 仍不持久（`dsh-goal/README.md` L99）。
- **差异性质**：NO CHANGE（对外契约/格式）；实现可靠性改进。
- **等级**：FACT。
- **建议处理方式**：KEEP。

## K10 — Skill Frontmatter

- **旧版认知**：YAML frontmatter 必须有 kebab-case `name` 与 `description`；缺失/非法会 drop with warning，模型侧无 per-skill 诊断。
- **旧版证据**：`toolkit/.../README.md:345-356`；`SKILL.md:47-57`。
- **新版证据**：`UP/changed/dsh-skill-filesystem/0.2.1-rc.2/package/README.md` L36、L85 原文未变；
  `lib/index.js` 中 `parseFrontmatter` / `frontmatter requires name and description` / `invalid YAML frontmatter` 仍在。
- **差异性质**：NO CHANGE。
- **等级**：FACT。
- **建议处理方式**：KEEP。

## K11 — Skill discovery roots

- **旧版认知**：`<projectRoot>/.dsh/skills`、`<projectRoot>/.agents/skills`、custom dirs，再到 `<DSH_HOME>/skills` 与 shared agents home；project root = 最近含 `.git` 的祖先，否则 cwd。
- **旧版证据**：`toolkit/.../README.md:350-356`。
- **新版证据**：`UP/changed/dsh-skill-filesystem/0.2.1-rc.2/package/README.md` L50-56 与旧版逐字相同；
  `lib/index.js` 差异只有 `agentsHome = resolveAgentsHome(config.agentsHome)`（旧版是
  `config.agentsHome ?? DSH_AGENTS_HOME ?? ~/.agents`），即 shared agents home 的解析统一到
  `dsh-home-paths`。本 workspace 无 `.git`，因此 project root 回退为 cwd `D:\Projects\dsh-test`（FACT，由 `.git` 缺失 + README 规则）。
- **差异性质**：ADDITIVE（shared agents home 解析路径），roots 列表不变。
- **等级**：FACT。
- **建议处理方式**：ADD VERSION NOTE（`DSH_AGENTS_HOME` 仍是解析输入；不要再手写 `~/.agents` 的推断）。

## K12 — Skill discovery depth

- **旧版认知**：depth 1；只认 `<root>/<name>/SKILL.md` 或 `<root>/<name>.md`；嵌套 `**/SKILL.md` 不发现。
- **旧版证据**：`toolkit/.../README.md:347-350`；`SKILL.md:48-53`。
- **新版证据**：新版 README L36 与 L113 仍写 “at the top level of a scanned root; nested `**/SKILL.md`
  files are deliberately not discovered”，watcher `depth: 1`（`lib/index.js` L374）。
- **差异性质**：NO CHANGE。
- **等级**：FACT。
- **建议处理方式**：KEEP。

## K13 — workspace-write 权限边界

- **旧版认知**：`workspace-write` 是真实文件系统围栏（不是仅 approval=ask）；允许写 session workspace root + 指定 temp，拒绝其余；`danger-full-access` 才是无围栏。
- **旧版证据**：`PILOT-SPEC-v0.1.md:152-173`；`docs/00-dsh-local-filesystem.md`；`toolkit/.../README.md:207-216`。
- **新版证据**：本会话 session events：`permission/preset = workspace-write`、`sandbox/mode = workspace-write`、
  `approval/policy = ask`；`dsh-sandbox-policy` / `dsh-fs-sandbox` 的 README 语义未变（DIFF 只删 invariant 说明）。
  **新增**：`dsh-working-directory` 允许改变 Session 的 working directory 并把它作为 required user context
  注入；它明确写 “Existing processes and sandbox grants keep their independent ownership”，即**改 cwd 不会自动
  重划已有 sandbox grant**。
- **差异性质**：ADDITIVE（新的 cwd 变更机制）+ NO CHANGE（mode 语义）。
- **等级**：FACT（源码/README + 会话事件）；“实际越界写入会被拒绝”本轮**未做 live 测试**（按任务禁止）。
- **建议处理方式**：ADD VERSION NOTE；实际拒绝行为标记 `NOT LIVE-TESTED IN THIS ROUND`。

## K14 — ask approval 的实际行为

- **旧版认知**：`ask` 是交互式闸门；它和 sandbox mode 是两个正交旋钮；默认 workspace-write 时 approval 为 ask。
- **旧版证据**：`PILOT-SPEC-v0.1.md:152-169`；`docs/migration/14-phase32-execution-verification.md:173`。
- **新版证据**：本会话事件 `approval/policy = ask`（FACT，配置层）。`dsh-user-approval` 的
  `lib/index.js` 无字节差异（DIFF 只有 README/package/locale/invariant 删除）。
- **差异性质**：NO CHANGE。
- **等级**：FACT（配置）；实际弹窗/批准路径未触发（本轮没有需要 approval 的操作）。
- **建议处理方式**：KEEP。

## K15 — 工具调用与子进程执行

- **旧版认知**：工具经 `dsh-tools` 暴露；`pwsh`/`bash` 经 `dsh-subprocess-local` 执行；普通工具失败不结束 turn；`run_code`/PTC 是可选呈现模式。
- **旧版证据**：`PILOT-SPEC-v0.1.md:129-145`；`docs/06`；本仓库早期 browser MCP 实验。
- **新版证据**：本会话 59 个工具可用（`evidence/tool-surface.txt`），`pwsh` 全程工作，MCP Playwright 30 个工具存在；
  `dsh-subprocess-local` 模块可加载，普通 `child_process.spawn(..., {stdio:'inherit'})` 成功。
  **变更**：`dsh-tools` 的 `mode` 从 `native | ptc | both` 改为 `native | ptc`（官方 rc.1 + README 原文）；
  `run_code` 现在在启动时捕获 Session 当前工作目录，程序内 `cd` 不影响已启动程序；PTC 的 `state` 默认每次 fresh。
  **环境限制**：node-pty ConPTY spawn 失败（`Cannot launch conpty`），但本 profile 未挂 terminal 工具。
- **差异性质**：CHANGED（PTC 模式枚举） + ADDITIVE（cwd capture） + ENVIRONMENT（PTY）。
- **等级**：FACT（工具面/源码/运行时）；PTY 根因 UNKNOWN。
- **建议处理方式**：ADD VERSION NOTE；PTY 相关用 `RETEST`（在非沙箱或挂 terminal 的 profile 中复测）。

## K16 — State 与 Recovery 的关系

- **旧版认知**：durable 的是 goal/plan/state/evidence/artifacts；不 durable 的是 `armed`；恢复要“检查而非假设”，中断的 tool call 结果未知。
- **旧版证据**：`toolkit/.../METHODOLOGY.md:57-82, 152-179, 436-453`。
- **新版证据**：`dsh-goal/README.md` L56-82、L99 仍是同一模型（四 phase + process-local activation）；
  `dsh-session-persistence-jsonl` 的实现改动提高了关闭/恢复的可靠性（consumer unload 顺序、worker 自然退出校验），
  但没有改变“activation 不持久”的语义。
- **差异性质**：NO CHANGE（契约）；可靠性改进。
- **等级**：FACT。
- **建议处理方式**：KEEP。

## K17 — Evaluator 与人工验收的区别

- **旧版认知**：机械 evaluator 只回答 artifact 结构；MECHANICAL PASS ≠ HUMAN ACCEPTANCE；模型自评不是验收。
- **旧版证据**：`toolkit/.../METHODOLOGY.md:83-115, 310-336`；`V0.2-ACCEPTANCE-SPEC.md` V1-V16。
- **新版证据**：这是**方法论层**的约定，DSH 0.2.1 没有对应运行时机制，也没有任何变更触及它；
  `dsh-plan-mode`/`dsh-goal` 都不读取 evaluator 结果。
- **差异性质**：NO CHANGE（且本来就不是 host 机制）。
- **等级**：FACT（“host 不提供该能力”由源码职责边界可证）。
- **建议处理方式**：KEEP。

## K18 — Final Report 与逐轮证据

- **旧版认知**：报告路径/owner 在 arm 前固定；报告在自动续轮停止后从逐轮 evidence 生成；未采集量写 `UNKNOWN`。
- **旧版证据**：`toolkit/.../METHODOLOGY.md:420-434`；`SKILL.md:415-433`；`templates/FINAL-REPORT.md`。
- **新版证据**：纯方法论约定，0.2.1 无对应运行时；driver 不生成报告。官方 rc.1 的 goal 变更只涉及 round 的排队/等待，不涉及报告。
- **差异性质**：NO CHANGE。
- **等级**：FACT。
- **建议处理方式**：KEEP。

## K19 — Desktop / Web UI 与 CLI 的关系

- **旧版认知**：存在两个 installation anchor：全局 npm DSH 与 Desktop bundled runtime；二者共享 `$DSH_HOME`；
  当时全局是 `0.1.5-rc.3`，Desktop 是 `0.2.0-rc.2`；Desktop 不是新的 composition paradigm。
- **旧版证据**：`README.md:77-86`；`docs/00-dsh-local-filesystem.md:26-51`；`docs/09-dsh-desktop.md:3`。
- **新版证据（本次实测）**：
  - 全局 npm：`0.2.1-rc.2`（`dsh --version` + `package.json`）；
  - Desktop：`resources/runtime/primary-runtime/runtime.json` 的 `desktopVersion = 0.2.0-rc.2`，**未随 CLI 升级**；
  - 当前 session：`DSH_PROFILE=browser-lab`（不是 `desktop`），工具面含 0.2.1-only 的 `working_directory`；
  - 因而当前 session **不是** Desktop bundled runtime，而是 0.2.1-rc.2 的 CLI/Web profile 运行时。
- **差异性质**：SUPERSEDED ENVIRONMENT FACT（全局 anchor 版本与“当前 Web session 运行在 Desktop 0.2.0”这一点）。
- **等级**：FACT。
- **建议处理方式**：ADD VERSION NOTE（只在**新**报告中记录；不要改 `docs/00` 的历史表，它记录的是 2026-10-05 的事实）。

## K20 — 模型 Provider 与认证路径

- **旧版认知**：provider 由 profile 的 `dsh-agent-default-model` 配置；Web/Desktop 使用已保存凭据；凭据文件在 `$DSH_HOME/.credentials.yaml`。
- **旧版证据**：`C:\Users\user02\.dsh\profiles\browser-lab\cordis.patch.yml`（agent-default-model）；`docs/00-dsh-local-filesystem.md:64`；`docs/09-dsh-desktop.md:115`。
- **新版证据（本次实测）**：session `request/header.config = { provider: "deepseek-official", model: "deepseek-flash",
  reasoningEffort: "low", maxTokens: 256000 }`；`request/context.contextWindow = 1000000`；profile patch 未变。
  官方 rc.1 变更：**API key precedence** 改为 Web/Desktop 优先已保存凭据，headless 默认 env/.env、不读 saved key。
  本轮未读取、未修改、未输出任何凭据。
- **差异性质**：CHANGED（认证优先级，仅 headless 有实际行为差异）；Provider/Model ID 未变。
- **等级**：FACT（配置 + 官方说明）；“当前实际用哪条 credential”= UNKNOWN（未读取凭据）。
- **建议处理方式**：ADD VERSION NOTE。

## K21 — 当前 DSH 版本的兼容性范围

- **旧版认知**：Toolkit v0.2 的机制主张**按 0.2.0-rc.2 核对**，且只在 package level 验证过；0.2.1 需重新确认。
- **旧版证据**：`toolkit/.../README.md:369-392`；`experiments/long-running/v0.2-work/RELEASE-REPORT.md:88-101`。
- **新版证据**：本次对 `dsh-goal`、`dsh-goal-round-driver`、`dsh-tool-goal`、`dsh-skill-filesystem`、`dsh-plan-mode`、
  `dsh-sandbox-policy`、`dsh-fs-sandbox`、`dsh-user-approval`、`dsh-session-persistence-jsonl`、`dsh-web-app` 的
  双版本源码/文档对照（`DIFF` + `UP/`）；10 项 toolkit 契约逐项结论见 `TOOLKIT-COMPATIBILITY.md`。
  结论：**contract-level 兼容，带 caveat**；但 driver 行为有新增、plan 交互有变、cwd 机制是新的。
- **差异性质**：CHANGED（兼容性边界需要加版本注记），不是“旧认知全部失效”。
- **等级**：INFERENCE（由源码/文档对照得出，未跑真实 goal）。
- **建议处理方式**：ADD VERSION NOTE + 对真实 driver 行为 `RETEST`。

---

## 新增条目

## K22 — “DeepSeek-V4.1-Flash-1017” 的可见名称不等于权重版本

- **旧版认知**：无此条（这是 0.2.1 新增的展示层机制）。
- **旧版证据**：无。
- **新版证据**：
  - 官方 rc.2 release notes：只写 “Add support for DeepSeek-V4.1-Flash-1017”（`REL`）。
  - `dsh-llm-deepseek` 的内置 catalog：`id: "deepseek-flash"` 的 `name` 从 `"DeepSeek-V41-Flash"` 改为
    `"DeepSeek-V4.1-Flash"`，其余字段（contextWindow、inputModalities、systemPromptUpdate、toolUpdate）逐字相同。
  - 新包 `dsh-client-ui-deepseek-model-label-1017` 明确写：“The `1017` marker is fixed client presentation,
    **not a server capability assertion**.” 它只在 provider ∈ {deepseek-official, deepseek-account}、
    model = `deepseek-flash`、catalog name 精确等于 `DeepSeek-V4.1-Flash` 时显示徽标，不改变请求。
- **差异性质**：ADDITIVE / PRESENTATION。
- **等级**：FACT（源码）；实际 API 路由到的权重版本 = UNKNOWN。
- **建议处理方式**：ADD VERSION NOTE（写入新报告；禁止把 UI 名称当权重证明）。

## K23 — 插件/扩展接口的破坏性变化

- **旧版认知**：无系统条目；旧仓库只记录了 0.1.5→0.2.x 的 settings/session-format 断裂面。
- **旧版证据**：`README.md:80-86`（历史断裂面）。
- **新版证据**：官方 rc.1 + DIFF：
  - 移除 runtime invariant 插件与各包 `./invariant` 导出；
  - 移除 `dsh-tools` 的 `both` 模式；
  - `dsh-agent-instructions` 移除逐行 `dshHome` 配置；
  - 子路径插件不再读取独立 `package.json`；插件兼容优先看 `engines.dsh`；
  - composer stats 扩展拆成 `activity` / `usage`；
  - Agent Team 移除 outbox/自动重试/去重；
  - Azure provider 名从 `azure-openai-responses` 改为 `azure`。
- **差异性质**：BREAKING（对插件作者/自定义 profile），对 Toolkit v0.2（纯 Markdown + 外部 evaluator）不适用。
- **等级**：FACT（官方 + DIFF：`invariant.js` 文件被删除、`mode` 枚举被改）。
- **建议处理方式**：FUTURE REVISION（若做 v0.3，在兼容性章节列明）。

## K24 — Prompt 变量 `{{cwd}}` 被移除

- **旧版认知**：`dsh-system-prompt`/`dsh-agent-loop` 给模板提供 `{{cwd}}`，profile 的 persona suffix 可用。
- **旧版证据**：0.2.0 `dsh-agent-loop/lib/index.js` L1566
  `ctx.systemPrompt.variable("cwd", ...)`；`dsh-web-app/presets/standard.patch.yml` 旧版
  `suffix: Your working directory is {{cwd}}.`。
- **新版证据**：0.2.1 的 `dsh-agent-loop/lib/index.js` 不再注册 `cwd` variable；
  `dsh-system-prompt/README.md` 明确写：“Custom persona templates must not depend on a built-in `{{cwd}}`
  variable: the loop does not register it, so unresolved references fail prompt assembly before any model request.”
  工作目录改由 `dsh-working-directory` 作为 required user-context 注入。
- **差异性质**：BREAKING（对使用 `{{cwd}}` 的 persona/profile）。
- **等级**：FACT（源码 + 文档）。
- **建议处理方式**：ADD VERSION NOTE（本仓库 `browser-lab` patch 未使用 `{{cwd}}`，因此当前未受影响；FACT：patch 中无 suffix）。

---

## 汇总

| 类别 | 条目 |
|---|---|
| NO CHANGE | K01, K02, K03, K05, K06（补充）, K07, K09, K10, K12, K14, K16, K17, K18 |
| ADDITIVE / REFINED | K04, K08, K11, K13, K19, K20, K21, K22 |
| BREAKING（仅插件/prompt 模板） | K23, K24 |

没有任何一条旧结论被“静默改写”。唯一被版本环境**取代**的是 K19 中“全局 npm = 0.1.5-rc.3、当前 Web session 跑在 Desktop 0.2.0”这两句；它们在其记录时点成立，现已不适用于当前运行时。

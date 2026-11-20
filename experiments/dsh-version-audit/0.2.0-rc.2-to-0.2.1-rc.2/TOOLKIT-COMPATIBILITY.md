# TOOLKIT-COMPATIBILITY — Long-running Toolkit v0.2 under DSH 0.2.1-rc.2

审计对象：`toolkit/long-running/v0.2/`（8 个文件，**只读**；本轮哈希 8/8 与发布记录一致，见
`evidence/frozen-toolkit-sha256.txt`）。

判定基准：0.2.1-rc.2 的已安装源码/README、本会话运行时观测、官方 release notes。
判定词：`COMPATIBLE` / `COMPATIBLE WITH CAVEAT` / `INCOMPATIBLE` / `UNKNOWN`。

**总体结论：COMPATIBLE WITH CAVEAT。**
Toolkit 的 10 项关键契约没有一条被 0.2.1 直接否定；但其中 4 项的行为细节有新增或变化，且全部
**未做真实 goal live test**。机械检查（CANDIDATE / HYGIENE / ADOPTION / READINESS）通过，不代表
Goal driver、pause/resume、round cap 已在 0.2.1 上实测。

---

## 1. 目标创建方式

- **v0.2 契约**：`create_goal` 必须来自 direct human request；`max_goal_rounds` 必须显式传入；创建即启动续轮。
- **0.2.1 证据**：`dsh-tool-goal/lib/index.js` 的 `requireDirectHuman()`；该文件与 0.2.0 **字节相同**
  （`evidence/package-diff.json` 未把 `lib/index.js` 列入 changed）。`dsh-goal/README.md` 仍写
  `defaultMaxGoalRounds: 256`。
- **判定**：**COMPATIBLE**。
- **Caveat**：无。若未来 DSH 改了 tool schema，需重新核对；本轮 live 工具面确认 `create_goal` 存在。

## 2. Plan 审批方式

- **v0.2 契约**：human 在 plan-review 中批准 `exit_plan_mode`；plan approval 不创建/arm goal；plan mode 不是安全边界。
- **0.2.1 证据**：`dsh-plan-mode` 的 review 交互改了：dismiss 返回 `{ approved: false }` 并结束当前 turn，
  不再把 dismiss 当成 failed call；`standard.patch.yml` 的 plan 提示词改为 “until exit_plan_mode succeeds
  or the user switches the session mode”。
- **判定**：**COMPATIBLE WITH CAVEAT**。
- **Caveat**：旧描述“dismiss 会得到带用户接管的失败调用”已不准确；toolkit 只依赖“人类批准是门槛”，这一点未变。
  审计时应按 0.2.1 的“dismiss 结束本轮”理解交互，不要把 dismiss 当成拒绝并期待模型自动重试。

## 3. Round 预算语义

- **v0.2 契约**：`maxGoalRounds` 是唯一 HARD 预算；cap 处写 `round-limit` blocker；其余 SOFT。
- **0.2.1 证据**：`dsh-goal-round-driver/lib/index.js` 的 cap 分支与 `round-limit` code 未变；
  `dsh-goal/README.md` L158 “Round-count budget only”。
- **判定**：**COMPATIBLE WITH CAVEAT**。
- **Caveat**：driver 现在在 `subagents` 服务存在时**先等子代理后代 settle** 再开始下一轮
  （`waitForChildren`）。因此“idle 后立刻进入下一轮”的时序假设不再成立；这不消耗额外 round，但会延后 round 的开始。
  Toolkit 不依赖具体时序，故不构成不兼容。

## 4. Driver 停止行为

- **v0.2 契约**：completion / pause / blocking 抑制续轮；cap / max tokens / durability 失败 / cancel / unload 都会停；
  cancel 后不会自动重启。
- **0.2.1 证据**：`drivable()` 仍是 `phase=active && activation=armed`；新增：
  - idle 时移除仍在 inbox 的 round prompt（避免后续人类输入排队等待）；
  - cancel 属于本 goal 时 `pause`，属于其他工作时仅 `disarm`；
  - unload 时 resolve `unloading`，并等待关闭。
  官方 rc.1：“fix new messages remaining queued after stopping, resuming, and stopping a goal-driven task again”。
- **判定**：**COMPATIBLE WITH CAVEAT**。
- **Caveat**：**post-cancel 的具体收敛路径有变化**。旧版说“cancelled round 会在下一个 idle 点 pause”，
  0.2.1 还区分“queued round prompt 被移除”和“其他工作的 cancel 仅 disarm”。如果 toolkit 的 STATE/evidence
  记录假设“取消后必然 pause”，需要按实际状态读取，而不是按旧叙述推断。

## 5. Skill 搜索与加载

- **v0.2 契约**：depth 1；目录 bundle `<name>/SKILL.md` 或平铺 `<name>.md`；frontmatter 必需；roots 顺序；
  project root = 最近含 `.git` 的祖先，否则 cwd。
- **0.2.1 证据**：`dsh-skill-filesystem` README L36/L50-56/L113 与 0.2.0 **逐字相同**；源码只有
  `agentsHome = resolveAgentsHome(...)` 的解析变化。
- **判定**：**COMPATIBLE WITH CAVEAT**。
- **Caveat**：本轮**未安装** toolkit 的 `SKILL.md`，也**未**在 live catalog 中观察它；当前 session 的
  skill catalog 只有内置的 `diagnose-windows-sandbox-acl`。因此“path 2 可用”仍是文档级结论，
  `NOT LIVE-TESTED IN THIS ROUND`。另外，本 workspace 无 `.git`，project root 回退为 cwd，这一点与 toolkit 的路径建议一致。

## 6. workspace-write 权限

- **v0.2 契约**：写范围必须与 GOAL.md 一致；越界写入是 HARD 拒绝；不要用 approval=ask 代替 sandbox。
- **0.2.1 证据**：本会话 `permission/preset=workspace-write`、`sandbox/mode=workspace-write`、`approval/policy=ask`；
  `dsh-sandbox-policy` 与 `dsh-fs-sandbox` 的语义未变。
- **判定**：**COMPATIBLE WITH CAVEAT**。
- **Caveat**：新增 `dsh-working-directory` 可以改变 Session 的当前目录，并把它作为 required user context 注入；
  但 “Existing processes and sandbox grants keep their independent ownership”——**改 cwd 不会自动扩大/重划
  sandbox 授权**。因此 GOAL.md 的写范围声明仍必须以 sandbox 实际 root 为准，不能以“当前 working directory”推断。
  另：本轮按任务要求**没有**做越界写入拒绝测试，拒绝行为标记 `NOT LIVE-TESTED IN THIS ROUND`。

## 7. 人工批准门槛

- **v0.2 契约**：create/edit/pause/resume 需要 direct human；complete/blocked 可在 goal round 中；plan approval 是人类动作。
- **0.2.1 证据**：`dsh-tool-goal` 的 authority 逻辑与 0.2.0 相同；`blocked` 在 goal-round 下要求
  `roundsStarted >= blockedAfterConsecutiveRounds`（默认 3）。
- **判定**：**COMPATIBLE**。
- **Caveat**：toolkit 没写 blocked 的“至少 3 轮”门槛；这是补充说明，不是冲突。真实门槛可按部署配置 `blockedAfterConsecutiveRounds` 改变。

## 8. Session 恢复

- **v0.2 契约**：goal/plan/state/evidence 持久；`armed` 不持久；resume/fork/restart 后必须由人类 re-arm。
- **0.2.1 证据**：`SESSION_FORMAT_VERSION = 4`；`dsh-goal/README.md` L99 “Activation is process-local”；
  persistence 实现改进了 dispose 顺序、listing 并发、worker 退出校验，但格式和 activation 语义未变。
- **判定**：**COMPATIBLE**。
- **Caveat**：实现层更严格（worker 必须自然 exit 0）；若未来出现 session 打开失败，应先看 persistence 日志，
  不要直接归因于 toolkit 的 STATE 文件。

## 9. Evaluator 执行

- **v0.2 契约**：read-only、exit 0/1/2、PASS/FAIL/ERROR 自测、freeze hash、run 期间不可编辑。
- **0.2.1 证据**：evaluator 是项目自带 PowerShell 脚本，经 `pwsh` 工具执行；`dsh-tool-pwsh` /
  `dsh-subprocess-local` 的普通子进程路径在本次审计中工作正常（多条 pwsh 命令成功）。
- **判定**：**COMPATIBLE**。
- **Caveat**：**本轮没有对 v0.2 evaluator 的四种模式做 live 重跑**（只做了 toolkit 文件哈希与源码级契约对照）。
  “机械检查通过”不能外推为 “harness 行为已实测”。

## 10. 最终报告的证据规则

- **v0.2 契约**：报告路径/owner 在 arm 前固定；报告从逐轮 evidence 生成；未采集量写 `UNKNOWN`。
- **0.2.1 证据**：纯方法论约定；0.2.1 没有改变 evidence/报告机制的 host 能力，driver 也不生成报告。
- **判定**：**COMPATIBLE**。
- **Caveat**：0.2.1 的 goal `complete`/`blocked` 会注入 closing wrap-up context，要求模型“只报告本 session
  已确立的事实”。这与 toolkit 的 UNKNOWN 纪律**一致**，可作为正面佐证，但不要把它当作 evaluator。

---

## 需要登记的 caveat（供未来 v0.3，不在本轮修改 v0.2）

1. **Driver 新增“等待子代理”语义**：round 开始条件是 whole-agent idle **且**（若 subagents 已挂载）后代 settle。
2. **Post-cancel 行为细分**：queued round prompt 在 idle 时被移除；非本 goal 的 cancel 只 disarm。
3. **Plan review dismiss 语义变化**：dismiss 返回 `{approved:false}` 并结束 turn，不是 failed call。
4. **working_directory 是新的独立机制**：改 cwd ≠ 改 sandbox grant；GOAL.md 的写范围声明需继续以 sandbox root 为准。
5. **`{{cwd}}` prompt 变量被移除**：任何把 `{{cwd}}` 写入 persona suffix 的 profile 会在 prompt assembly 阶段失败；
   toolkit 的 Markdown 本身不含该变量，故不受影响。
6. **Skill discovery 仍未 live 验证**：与 v0.2 发布时的 L1 限制相同，0.2.1 没有消除它。

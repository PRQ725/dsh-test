# FINAL-REPORT — `0.2.1-rc.2` → `0.2.2-rc.1`

审计日期：2026-11-08 · 基线 `0.2.1-rc.2` · 目标 `0.2.2-rc.1`（本机已安装并正在服务）

## 1. 判定

| 维度 | 判定 |
|---|---|
| 版本锚点一致性 | **CONSISTENT** — CLI / 安装 manifest / active session 均为 `0.2.2-rc.1`；Desktop 独立保持 `0.2.0-rc.2` |
| 长期笔记是否需要修改 | **YES** — 2 处 `CORRECT`（事实错误）+ 1 处机制陈述需限定 + 多处 `ADD` |
| `[0.1.5 → 0.2.x]` 断裂面 | **不适用** — `SESSION_FORMAT_VERSION` 仍为 4；settings 模型未再变 |
| Toolkit v0.2 机制前提 | **COMPATIBLE WITH CAVEAT**（见 §4） |
| 需要新实验才能定论 | **NO**（本轮的 `UNKNOWN` 都是"按边界未做"，不是"必须另开实验才能推进"） |

## 2. 必须修正的两处旧认知

### 2.1 `fs-observation-policy` 默认是**关闭**的

旧笔记（`docs/00` 早期结论 + 工具使用经验）把"先读后写 / 外部改动检测"当成默认行为。
0.2.2 本机 `dsh-base\cordis.patch.yml` L292-294 明确写着：

```yaml
- id: fs-observation-policy
  name: '@deepseek-ai/dsh-fs-observation-policy'
  disabled: true
```

⇒ **出厂组合下 `write` / `edit` / `apply_patch` 是无条件变更**；`FS_NOT_OBSERVED` /
`FS_STALE_VERSION` 只在**显式启用该行**后才可能出现。
官方发布块同一句："文件修改的先读和外部修改防护默认关闭，沙箱限制和 Review 保持不变"。

**影响**：任何把"DSH 会强制先读"当作安全前提的推理都不成立；`read-before-write` 从此是
**软纪律**（模型自觉）+ **可选配置**，不是默认护栏。

> ### ⚠️ 勘误（2026-11-08 追加，同轮复核）
>
> 上面"`write`/`edit` 无条件变更 / 不是默认护栏"的措辞**过度推论，已撤回**。三层必须分开：
>
> | 层 | 事实 | 等级 |
> |---|---|---|
> | 出厂装配（`dsh-base`） | `fs-observation-policy` 存在但 `disabled: true` | `FACT` |
> | 当前 profile 有效装配（`browser-lab`） | `dsh-web-app`、`presets/*.patch.yml`（含 `standard` / `ptc` / `minimal`）、`$DSH_HOME\profiles\browser-lab\cordis.patch.yml` **均未重新挂载**；全安装树无 js/yml 以 entry id 引用它 | `FACT` |
> | **实际运行行为（本 session）** | 改未读文件仍被拒，错误文本 `cannot modify "…": file has not been read — read the file, then retry`；改被外部改过的文件报 `cannot edit "…": file changed since it was read` | `FACT`（真实工具返回） |
>
> 这两句错误文本**只**由 `dsh-tool-fs` L477/478 产出（把 `FS_NOT_OBSERVED` / `FS_STALE_VERSION`
> 规范化）。既然 policy 插件未挂载，另一个能抛这两个码的来源是 **provider `dsh-fs-local`**
> （`FS_NOT_OBSERVED` L506/508/1025；`FS_STALE_VERSION` L937/939/1023/1024/1030/1032）。
> ⇒ **守卫至少有相当部分来自 provider 层**，`[INFERENCE]`；provider 在无 intent 时如何取得
> `expected` 的具体分支 **`[UNKNOWN]`**（需一次 temp 文件受控实测，本轮按边界未做）。
>
> **结论修正**：正确表述是 **"policy 插件默认不挂载" ≠ "没有先读守卫"**。
> 旧笔记"默认要求先读"的**行为观察是对的**，错的只是把它归因给 `fs-observation-policy` 这个插件。
> 实操上"改前先 `read`"的习惯**不需要改**。

### 2.2 `AGENTS.md` 预算是**按链独立**的

旧笔记："`maxBytes` 是**这条渲染消息**的总上限，超限时最宽的整份文件先被丢弃 ⇒ `$DSH_HOME/AGENTS.md`
第一个被丢"。

0.2.2 起：**user-global 链与 project 链各自**受 `maxBytes`；两条链同时在一条消息里时**最多 2×**；
链间**不共享**未用额度；两条都装得下时**不出现** budget 提示。

**影响**：project 指令**不再**能挤掉全局指令（这正是官方修复动机）；"最宽者先被丢弃"只在
**同一条链内**成立。任何以"全局 AGENTS.md 会被项目文件挤掉"为前提的结论都要改。

## 3. 必须限定的机制陈述

### `exit_plan_mode` 不再是"始终注册"

旧笔记（含 Toolkit 的 plan 契约推理）："plan mode 只改 prompt 段，**工具目录恒定**"。

0.2.2 起：`exit_plan_mode` **渐进披露** —— 从"选中 plan 状态为 active"的第一步起才被 admit，
之后整个 Session 保持；**更早调用返回 `UNKNOWN_TOOL`**；首次进入通过 route 的 **tool-update
协议新增**该工具（`in-history` / `addition-only` route 追加在缓存历史之后；不支持 tool update
的 route 重发一次声明列表）。离开 plan mode 后调用报"不可用"。

**影响**：对"请求缓存稳定性"的推论要收窄到**除 `exit_plan_mode` 之外**的工具集；
`UNKNOWN_TOOL` 不再只意味着"工具没挂载"，也可能是"plan mode 还没进过"。

## 4. Toolkit v0.2 的兼容性

| 契约 | 状态 | 依据 |
|---|---|---|
| Goal = 单一 durable objective，per-session | **HOLDS** | `dsh-goal` 投影与事件模型未变 |
| `create/edit/pause/resume` 需直接人类轮 | **HOLDS** | 0.2.2 `dsh-tool-goal` README 未变该段 |
| `maxGoalRounds` 是唯一 HARD 预算 | **HOLDS** | 未变 |
| `complete` / `blocked` 可由当前 goal 轮发起 | **HOLDS** | `completionAuthority` 未变 |
| blocked 需同一条件 ≥3 个 goal 轮 | **HOLDS** | 默认门槛未变 |
| driver 在 whole-agent idle 起轮、达上限 `round-limit` | **HOLDS** | 0.2.2 driver README 同文 |
| **取消/销毁语义** | **CAVEAT** | 新增 `disposed` 原因：Agent disposal（优雅关停 / 重载拥有该 Agent 的插件）→ **只 disarm**，goal 仍 active；user/parent/hook 取消 → **pause** |
| `update_goal` 对多余字段的容错 | **CAVEAT** | 由"报 `GOAL_TOOL_INVALID_UPDATE`"改为"**忽略**"——脚本若依赖该错误做校验会静默通过 |
| plan review dismiss → 结束本轮 | **HOLDS** | 未变 |
| plan mode 不强制限制工具 | **HOLDS（但披露机制变了）** | 仍是 prompt 级约束；但 `exit_plan_mode` 本身改为按需披露 |
| RESTART PERSISTENCE = 状态在 / 续轮不自动 | **HOLDS** | 0.2.2 未改 disarm 语义 |
| 恢复入口 | **EXPANDED** | Web **goal bar** 现在可直接 resume 被 blocked 的 goal；**已耗尽 round 上限的仍需先提高上限** |

⇒ 结论：**v0.2 的机制主张不需要改写**，但需要两处补充注记（`disposed` 语义、`update_goal` 容错），
以及一处"恢复入口变多"的说明。**未发布新 Toolkit 版本**；本轮不改 `toolkit/`。

## 5. 其它值得记录的版本事实

- **Node ≥ 24.9**（0.2.2 起）。本机 `v24.20.0` 满足；旧机器升级前需先升 Node。
- **Cordis Core 4.1.0 / Loader 1.1.0 / Include 1.1.0**：`applyEntryPatches` 语义未变，§D/§E 的组合结论仍成立。
- **工具执行平面重构**：executor 插件化 + 按 step 条件启用；`DSH_TOOLS_MODE` 全树零命中（**静默失效**）。
- **`apply_patch` 默认关闭**，且 `dsh-tool-fs` README 称 base/standard 已启用，与出厂 patch **冲突**（`DISCREPANCY`）。
- **session format 仍 v4**、**workspace 存储 unit 仍 v2**、**goal 投影仍 version 6**。
- **`1017` label 包已移除**；不能因 badge 消失反推权重版本变化（仍 `UNKNOWN`）。
- **Web 载体能力扩充**：`--public-url`、原生 HTTPS（`--tls-cert`/`--tls-key`）、`--host` 只接受具体本地地址、
  远程 WebSocket 默认压缩。
- **8 种 UI locale**（en/zh + ja/es/fr/de/ru/pt-BR）。
- **26 个新包 / 1 个移除包 / 261 个包有真实变更**（详见 `evidence/`）。

## 6. 结案时保留的 UNKNOWN

1. Goal / round driver 的 live 行为（create / arm / round / cap / pause / resume）—— **NOT RUN**。
2. 模型实际路由到的权重版本 —— `UNKNOWN`；0.2.2 无 1017 label 包可作旁证。
3. 越界写入是否被 sandbox 拒绝 —— **仍 NOT TESTED**（本 session `danger-full-access`）。
4. `--tls-cert`/`--tls-key`/`--public-url` 的实际监听行为 —— 只读 `--help`，未起第二个 host。
5. `apply_patch` 的真实执行（本机未启用）—— `UNKNOWN`。
6. 26 个新包在 `browser-lab` 中是否为**已挂载** bundle —— 只确认"已下载、在依赖图"，未逐个核对 profile 组合。
7. Session API snapshot/subscribe 拆分的运行期形状 —— 官方文档级。

## 7. 结案

- 本轮为**知识审计**：只做只读验证 + 笔记修正，未升级、未安装、未改配置、未创建 Goal。
- 需要上述 `UNKNOWN` 中的任何一项时，必须另开受控实验；本轮不继续研究。

**STOP FOR HUMAN REVIEW.**

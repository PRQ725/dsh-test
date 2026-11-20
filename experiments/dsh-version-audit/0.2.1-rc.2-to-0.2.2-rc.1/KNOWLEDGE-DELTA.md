# KNOWLEDGE-DELTA — `0.2.1-rc.2` → `0.2.2-rc.1`

审计日期：**2026-11-08**（本地 UTC+8）
基线：本仓库既有笔记的记录版本 `0.2.1-rc.2`（见 `docs/00` §0.1）
目标：本机已安装并正在服务的 `0.2.2-rc.1`

证据等级：
- `FACT` = 本机安装树源码/patch 逐行读到，或本机命令直接输出。
- `DOC` = 官方发布块 / 包 README 原文（文档级，未必等于本机生效值）。
- `DISCREPANCY` = 文档与本机 patch 不一致（以 patch 为准）。
- `INFERENCE` / `UNKNOWN` 同全库约定。

**处理列**：`KEEP`（旧记录仍正确）/ `CORRECT`（旧记录已过期，须改）/ `ADD`（新增，笔记里没有）/

---

## A. 版本与平台

| ID | 主题 | 0.2.2 事实 | 证据 | 处理 | 落点 |
|---|---|---|---|---|---|
| K01 | 全局 npm anchor 版本 | `0.2.2-rc.1`；dist-tags `latest`=`next`=`0.2.2-rc.1`，`alpha`=`0.2.2-alpha.3` | `FACT` | ADD（改版本号） | `docs/00` §0.1、根 `README.md` 环境段 |
| K02 | Node 最低版本 | **`0.2.2` 起最低 Node ≥ 24.9**；本机 `v24.20.0` 满足 | `DOC`+`FACT` | ADD | `docs/00` §0.1 |
| K03 | Cordis 内核版本 | 三个**不同包**、独立版本线：`@deepseek-ai/cordis` **4.1.0**（Core）· `@deepseek-ai/cordis-plugin-loader` **1.1.0**（Loader）· `@deepseek-ai/cordis-plugin-include` **1.1.0**（Include）；`@cordisjs/*` 作用域不存在（是 vendored 的 `@deepseek-ai` 包） | `FACT` | ADD | `docs/02` §K.1 |
| K04 | Desktop bundled runtime | **仍未升级**：`runtime.json.desktopVersion` = `0.2.0-rc.2`，exe FileVersion = `0.2.0-rc.2` | `FACT` | KEEP（复核） | `docs/00` §0.1、`docs/09` §3.1 |
| K05 | session format 版本 | `SESSION_FORMAT_VERSION` **仍为 4**；`dsh-session-format-v3-to-v4` 仍在 | `FACT` | KEEP（复核） | `docs/00` §7.5.2 |
| K06 | workspace 存储 unit | `version: 2` 不变 | `FACT` | KEEP | — |
| K07 | 1017 模型 label 包 | `dsh-client-ui-deepseek-model-label-1017` 在 0.2.2 **已移除**（`onlyV1` 唯一项） | `FACT`（cache diff） | CORRECT（加版本注记） | `docs/00` §0.1 模型层注记 |

## B. 工具执行平面（本版最大的结构变化）

| ID | 主题 | 0.2.2 事实 | 证据 | 处理 | 落点 |
|---|---|---|---|---|---|
| K08 | executor 拆分 | `dsh-tools` 的 `mode` 字段移除；改为 `tool-executor-native` / `tool-executor-ptc` 两个 **Agent-scoped** 插件；同 scope 内同 provider 重复即失败 | `FACT`（patch + 源码） | ADD | `docs/02` §K.2、`docs/00` §7.5.4 |
| K09 | `DSH_TOOLS_MODE` | **全安装树零命中** ⇒ env 开关彻底失效 | `FACT` | ADD | 同上 |
| K10 | 默认执行器 | 本机 `tool-executor-native` 启用，`tool-executor-ptc` **`disabled: true`** | `FACT` | ADD | 同上 |
| K11 | `maxParallelToolCalls` | 仍存在（默认 10），但**归 executor 拥有**；agent-loop 只把它作为 batch 参数传入并**优先于** executor 配置 | `FACT`（0.2.2 `dsh-agent-loop`/`dsh-tools` README） | CORRECT（归属变了） | `docs/00` §7.5.4 |
| K12 | 条件工具 | 新增 `register(def, { when })` + `resolve()` 得到 step-owned `ResolvedToolSet`；未解析集合下的条件调用返回 `UNKNOWN_TOOL` | `FACT`（README） | ADD | `docs/00` §7.5.4 |
| K13 | `fs-observation-policy` | **⚠️ 已勘误**：该插件在 `dsh-base` 是 `disabled: true`，且 web-app / 三个 preset / profile patch **都未重新挂载**（`FACT`）；但**运行期"先读"守卫仍生效**（本会话实测拒绝，`FACT`），来源至少部分在 **provider `dsh-fs-local`**（`INFERENCE`）。⇒ 正确表述是"policy 插件未挂载"≠"无守卫" | `FACT`+`INFERENCE`+`UNKNOWN` | **CORRECT（原判定过度）** | `docs/00` §7.5.4、`FINAL-REPORT` §2.1 勘误块 |
| K14 | `apply_patch` | 新增工具（Codex 风格 `*** Begin Patch` 多文件增删改移）；`applyPatch` **默认 `false`**，本机 base 与 web 预设**都是 false** | `FACT` + `DISCREPANCY` | ADD | `docs/00` §7.5.4 |
| K15 | `apply_patch` 提交语义 | 先整体 preflight（语法/hunk/缺文件），**拒绝则零改动**；一旦开始提交**不回滚**，首个失败即停，`unknown` 需重读 | `DOC`（`dsh-tool-fs` README） | ADD | `docs/00` §7.5.4 |
| K16 | `tool-fs` README 与 patch 冲突 | README 称 "`dsh-base` 和 Web `standard` preset enable `applyPatch`"，实际两层都是 `false` | `DISCREPANCY` | ADD（明确以 patch 为准） | `docs/00` §7.5.4 |

## C. Instruction / 系统提示

| ID | 主题 | 0.2.2 事实 | 证据 | 处理 | 落点 |
|---|---|---|---|---|---|
| K17 | AGENTS.md 预算模型 | 由"单条消息总量 ≤ maxBytes"改为 **user-global 链与 project 链各自**受 `maxBytes`，两条都装时消息**最多 2×**；链间**不共享**额度；两条都装下时**无** budget 提示 | `FACT`（0.2.2 README）+ `DOC`（官方 fix 条目） | **CORRECT** | `docs/04` §4.5 |
| K18 | "最宽者先被丢弃"的适用域 | 仍成立，但**只在同一条链内**；global 文件不再因 project 链变长而被丢 | `FACT` | CORRECT（限定） | `docs/04` §4.5 |
| K19 | 预算兜底 | 某链无 frame 且合并 frame 会超 `2×maxBytes` 时退化为**单链单预算**渲染（此时可能省略一条本可装下的 global 文件） | `DOC`（README） | ADD | `docs/04` §4.5 |
| K20 | 系统提示工具声明归属 | `system-prompt` 的 presentation waterfall **不再接收 tool 数组**；工具声明由 provider 拥有 | `FACT`（0.2.2 `dsh-system-prompt` README） | ADD | 审计报告（影响插件作者，不影响本库结论） |
| K21 | 模型按 step 固定 | agent-loop 在 prompt 组装与 `agent/pre-step` **之前**捕获 provider/model/effort；重试复用；**`agent/request` 不再允许改路由**，中途改路由会**拒绝该 step** | `DOC`（官方）+ `FACT`（README） | ADD | 审计报告 |
| K22 | 前缀缓存 | 系统提示未变化时**新一轮请求**可继续复用前缀（旧行为只在同一 request series 内保证） | `DOC` | ADD | 审计报告（不影响笔记结论） |

## D. Session / Projection / 权限

| ID | 主题 | 0.2.2 事实 | 证据 | 处理 | 落点 |
|---|---|---|---|---|---|
| K23 | Session projection 注册 | 改为**异步**；插件须在激活期 await 并**持有 handle**；旧 disposer / 按 key 读仍兼容但**弃用** | `FACT`（多个 0.2.2 README）+ `DOC` | ADD | `docs/00` §7.5.2 |
| K24 | Session API | 拆成**读快照**与**持续订阅**（event log / 运行状态 / projection 数据）两套独立接口 | `DOC` | ADD（标未 live 验证） | `docs/00` §7.5.2 |
| K25 | `stat`/`list` 快照 | 新增 `location: { kind: 'jsonl', path }` 指当前选中的物理 generation | `FACT`（README） | ADD | `docs/00` §7.5.2 |
| K26 | permission preset 钉扎时机 | 由 **session 创建**改为 **Agent 创建**（`agent/created`），额外依赖 Agent registry；reader 未就绪时 Agent 创建**回滚** | `FACT`（0.2.2 `dsh-permission-presets` README） | ADD | `docs/00` §7.5.3 |
| K27 | 审批文案 | 审批提示**显式说明本次是否在请求授权**，消除 `never` 策略歧义 | `DOC` | ADD | `docs/00` §7.5.3 |
| K28 | 整单元存储兼容读 | JSON/SQLite 可读"领域显式声明"的旧版本，但**以当前版本格式写入** | `DOC` | ADD | 审计报告 |

## E. Plan / Goal / Long-running（与本库 Toolkit 线直接相关）

| ID | 主题 | 0.2.2 事实 | 证据 | 处理 | 落点 |
|---|---|---|---|---|---|
| K29 | `exit_plan_mode` 披露方式 | 由"**始终注册**、进出 plan mode 只改 prompt 段"改为**渐进披露**：从"选中 plan 状态为 active"的第一步起才 admit，之后整个 Session 保持；**更早调用返回 `UNKNOWN_TOOL`**；离开后调用报不可用；首次进入通过 route 的 tool-update 协议**新增**该工具 | `FACT`（0.2.2 `dsh-plan-mode` README 逐行） | **CORRECT**（旧笔记"工具目录恒定"需限定） | `experiments/long-running/README.md` + 审计 |
| K30 | plan-mode 依赖 | 不再"可选注入" `sessionProjections`；改为**必需并在激活期 await 注册**；prompt 段先注册 | `FACT` | ADD | 审计报告 |
| K31 | plan review dismiss | `{approved:false}` + 结束本轮、**不再多发一次模型请求**（0.2.1 已如此，0.2.2 未变） | `FACT` | KEEP | — |
| K32 | goal-round-driver 新增 `disposed` | **Agent disposal**（优雅关停 / 重载拥有该 Agent 的插件）以 `disposed` 原因中止该轮并**只 disarm**（goal 仍 active，与 plugin unload 一致）；user/parent/hook 取消仍**pause** | `FACT`（0.2.2 driver README） | ADD | `experiments/long-running/README.md` + 审计 |
| K33 | `update_goal` 多余字段 | 不再报 `GOAL_TOOL_INVALID_UPDATE`：`objective`/`max_goal_rounds` 仅对 `edit` 生效、其余 action **被忽略**；`blocked_reason` 仅对 `blocked` 必需且非空，其余忽略 | `FACT`（0.2.2 `dsh-tool-goal` README） | CORRECT（错误语义 → 忽略语义） | `experiments/long-running/README.md` + 审计 |
| K34 | `create/edit/pause/resume` 权限 | **未变**：仍需 runtime-root agent 的直接人类轮（`requireDirectHuman`）；`resume` 对 durably paused goal 仍报 `GOAL_TOOL_RESUME_PAUSED` | `FACT` | KEEP | — |
| K35 | blocked goal 恢复入口 | Web **goal bar** 可直接 resume 被 blocked 的 goal；**已耗尽 round 上限的仍需先提高上限** | `DOC` | ADD | `experiments/long-running/README.md` |
| K36 | goal 投影版本 | `goal` projection host state **version 6**（未变）；client key 只并入 `SessionProjectionMap`（不再并 `SessionProjectionStateMap`） | `FACT` | ADD（实现细节） | 审计报告 |

## F. Web / 载体 / 其他

| ID | 主题 | 0.2.2 事实 | 证据 | 处理 | 落点 |
|---|---|---|---|---|---|
| K37 | `dsh web` 旗标 | 新增 `--public-url`、`--tls-cert`/`--tls-key`（原生 HTTPS）；`--host` 收紧为**单个具体本地地址，通配被拒** | `FACT`（本机 `--help`）+ `DOC` | CORRECT（"只有四个旗标"过期） | `docs/browser-mcp/02` §1.1(b) |
| K38 | WebSocket 压缩 | 远程连接**默认压缩**（`websocketCompression` 默认 `deflate`，可设 `none`） | `FACT`（`dsh-api-gateway` 源码） | ADD | 审计报告 |
| K39 | Web Fetch 网络范围 | **不再拒绝非公网地址**（可用于代理/内网）；部署须自行限制 | `DOC` | ADD（安全语义变化） | 审计报告 |
| K40 | UI locale | 新增 **ja / es / fr / de / ru / pt-BR** 六种，连原 en / zh 共 **8** 种 | `FACT`（locale 文件集）+ `DOC` | ADD | 审计报告 |
| K41 | 官方 bundle 清单 | 由 `@deepseek-ai/dsh-official-bundles` **导出数据**（profile 模板、默认关闭项、按需安装项、退休 bundle、插件管理器保护/隐藏/排序）；`dsh-app-boot` 直接 import | `FACT`（`app-boot` import）+ `DOC` | ADD | `docs/02` §K.3 |
| K42 | Skill root 失败隔离 | 某个 skill root 读失败**不再**隐藏其他 root；该 root 整体省略、下次 lookup 重试，并在 catalog 里标示"发现不完整" | `FACT`（0.2.2 `dsh-skill-filesystem` README）+ `DOC` | CORRECT（旧行为"保留 last-good"被替换） | 审计报告 |
| K43 | PTC 破坏性变化 | 控制通道改 **birpc**；**SSH 协议 2 → 3**；取消分类改 **`ABORTED`**；新增 VM Script mode | `DOC` | ADD（影响到自建 SSH/PTC 集成的读者） | 审计报告 |
| K44 | 小修（影响操作习惯） | `grep` 接受**空 `include`**；本地文件工具把**开头 `~`/`~/`** 展开为宿主 home（路径中间 `~` 保持字面） | `DOC` | ADD | 审计报告 |
| K45 | 权限值现状 | 本 session 仍 `danger-full-access` / `never`；与 0.2.1 审计时相同 | `FACT`（runtime context） | KEEP | `docs/00` §7.5.3 |

---

## 未整合进长期笔记的内容（及原因）

| 内容 | 原因 |
|---|---|
| K20/K21/K22/K28/K36/K38/K39/K40/K42/K43/K44 的完整细节 | 属实现/平台细节，或与本库既有结论无冲突；留在本审计目录，避免在 `docs/` 造平行体系 |
| `apply_patch` 的完整 schema、报告形状、`meta.diffs` 字段 | 工具尚未在本机启用（`applyPatch:false`），写进长期笔记会变成"未验证的 API 描述" |
| 六种新 locale 的具体文案 | 属 UI 资产，不是机制知识 |
| 0.2.2 的 alpha 线（`0.2.2-alpha.2/.3`）逐条差异 | 不是接受基线；结论已并入 rc.1 |
| Goal / Pilot 的 live 行为 | 本轮**未**创建/arm/resume Goal，按任务边界不做 live 验证 |
| 越界写入是否被拒 | 仍未实测（与 2026-10-19 审计一致，`UNKNOWN` 保持） |

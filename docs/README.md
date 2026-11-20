# docs/ — DSH 研究知识库导航

> 本目录只放**长期知识**（已提炼的结论）。实验过程在 `../experiments/`，原始证据在 `../evidence/`。
> 全部文档统一使用证据等级：`[FACT]` / `[INFERENCE]` / `[UNKNOWN]`。

## 证据等级规范

| 标记 | 含义 |
|---|---|
| `[FACT]` | 源码 / filesystem / registry / session forensic / **runtime experiment** 直接观察或验证到的事实 |
| `[INFERENCE]` | 由 FACT 推导，但**没有直接观察**到 |
| `[UNKNOWN]` | 当前没有足够证据 |
| `[STALE]` / `[CONTRADICTED]` | 曾正确但已被更新 / 与已验证事实冲突（须修正） |
| `[RECOMMENDATION]` | 建议，不是事实 |

> **纪律**：不得为了"看起来完整"把 `[UNKNOWN]` 猜成 `[FACT]`。重要结论应在文末给出 **Evidence** 相对路径，便于从知识回溯到 `experiments/` / `evidence/`。
>
> **路径约定**：本文档集中出现的 `experiments/…`、`evidence/…`、`archive/…` 均**相对于 workspace 根**（`D:\Projects\dsh-test\`）；
> 而 `docs/` 内部互相引用（如 `04-agent-composition-and-instructions.md`）用**同目录相对**写法，跨目录用 `../`（如 `../experiments/…`）。
>
> **★ 版本号约定**：**"当前 DSH 版本"以 `00-dsh-local-filesystem.md` §0.1 为唯一事实源。**
> 各文档正文/头部出现的版本号，一律是**该文档记录时**的环境（历史事实），**不要因为版本推进而"顺手改新"**。
> 例如 "`0.1.5-rc.1` 起 agent-presets 移到包内" 记录的是**哪个 release 引入的变更**，改成 rc.3 会变成错误陈述。
>
> **[2026-10-19 跨版本审计，CLOSED]** 已完成 `0.2.0-rc.2 → 0.2.1-rc.2` 的知识审计：Toolkit v0.2 为
> **COMPATIBLE WITH CAVEAT**，八文件未改；版本事实已更新到 `00` §0.1 / `09` §3.1。结论与 K01–K24 对照见
> `../experiments/dsh-version-audit/0.2.0-rc.2-to-0.2.1-rc.2/`。
>
> **[2026-11-08 跨版本审计，CLOSED]** 已完成 `0.2.1-rc.2 → 0.2.2-rc.1` 的知识审计。三条影响**已有结论**的
> 变化必须记住（其余见审计 K01–K45）：
> 1. **`fs-observation-policy` 装配层未挂载，但运行期"先读"守卫仍在**（两者不是一回事）——
>    该插件在 `dsh-base` 是 `disabled: true`，web-app / 三个 preset / `browser-lab` profile patch
>    都没有重新挂载它；但本会话实测改未读文件仍被拒（`file has not been read — read the file, then retry`），
>    守卫至少有相当部分来自 **provider（`dsh-fs-local`）**。习惯不变：改前先 `read`。（`00` §7.5.4）
> 2. **`AGENTS.md` 预算改为按链独立** ⇒ 项目指令不再挤掉全局指令，双链最多 `2× maxBytes`（`04` §4.5）。
> 3. **`exit_plan_mode` 改为渐进披露** ⇒ "plan mode 工具目录恒定"须限定为**除它以外**的工具集（`00` §7.5.4）。
> 审计目录：`../experiments/dsh-version-audit/0.2.1-rc.2-to-0.2.2-rc.1/`。

---

## 建议阅读顺序（逻辑组织）

| # | 主题 | 文档 | 它回答的问题 |
|---|---|---|---|
| 01 | **基础架构** | `00-dsh-local-filesystem.md` | 某个 DSH 概念/组件在本机对应哪个文件、目录或路径？`$DSH_HOME` / installation / profile / workspace / session log 在哪里？ |
| 02 | **Host Composition** | `01-host-composition.md` | composition 从哪来？bundle / profile / patch 各承担什么？**Host 与 Agent 的层级关系**是什么？ |
| 03 | **Profile / Bundle 隔离** | `07-profile-bundle-isolation.md` | bundle 到底属于哪个 profile？`dsh plugin --profile X add` 写了哪些文件？profile 之间会不会继承？"包在磁盘上"等不等于"profile 挂了它"？有哪些跨 profile 共享层？ |
| 04 | **Patch / Entry Tree 运行链** | `02-root-include-and-patch-composition.md` | 磁盘 `cordis.yml` → Root Include → EntryGroup → Entry → Fiber 怎么走？patch 算子（insert / override / disabled / `!!js`）什么语义？**两种 precedence 为何不矛盾**（§J）？ |
| 05 | **Agent Composition** | `01-host-composition.md` §五–§七 | agent preset 是什么？scope parentage 怎么工作？为什么 host dump 里 `tool-fs` 是 disabled 但 agent 仍能用？ |
| 06 | **Instruction System** | `04-agent-composition-and-instructions.md` | `dsh-agent-instructions`（plugin）与 `AGENTS.md`/`CLAUDE.md`（instruction source）分别是什么？`$DSH_HOME/AGENTS.md` 全局层？层级、budget、preset 差异？ |
| 07 | **Browser MCP** | `05-browser-mcp.md` + `browser-mcp/` | DSH Agent 如何通过 MCP 驱动本机 Chrome？E2E 验证了什么？UI 能不能配置 MCP？ |
| 08 | **Runtime / 多进程** | `06-dsh-runtime-and-multiprocess.md` | 持久层与进程内存如何分离？为什么两个 DSH 实例会看到不同的 workspace 归类？有什么风险？ |
| 09 | **研究上下文 / 阶段状态** | `03-research-context-and-next-phase.md` | 研究到哪了？三条研究线（PJOS 迁移 / Browser MCP / Profile 隔离）各自的阶段状态？ |
| 10 | **Migration（Claude Code → DSH）** | `migration/10`–`migration/14` | CC specimen 是什么？CC↔DSH 概念如何映射？迁移决策与设计？执行验证结果？ |
| 11 | **安装 / 升级** | `08-dsh-installation-and-upgrade.md` | DSH 程序本身装在哪、里面有什么？一个包从 npm 到 Cordis 要穿过哪几层？为什么"顶层版本对了"依赖树仍可能坏？升级会不会动我的 profile？回滚为什么不可靠？ |
| 12 | **官方 Desktop** | `09-dsh-desktop.md` | 官方 Desktop 是什么组成的？两个 installation anchor 怎么并存？0.1.5 与 0.2.x 共用 `$DSH_HOME` 时哪两个面结构性不兼容？mixed-version 兼容性最终结论？ |
| 13 | **实验方法论** | `10-experiment-methodology.md` | 什么才算真静止的 baseline？capture 如何 fail-closed？zero-diff 为什么合法？PowerShell 5.1 有哪些坑？ |

---

## 全部文档职责

| 文件 | 短标签 | 职责 |
|---|---|---|
| `00-dsh-local-filesystem.md` | **filesystem facts** | 概念 ↔ 真实文件/路径；含 §7.5 Workspace / Session / Sandbox |
| `01-host-composition.md` | **host & agent composition** | bundle/profile/patch 角色；**层级关系**；agent preset 与 scope |
| `02-root-include-and-patch-composition.md` | **runtime execution / Entry Tree** | Root Include、`applyEntryPatches`、`!!js`、热更新、telemetry、**两种 precedence 对比（§J）** |
| `03-research-context-and-next-phase.md` | **research context / phase status** | 阶段一结论、两条研究线的阶段状态、workspace 结构 |
| `04-agent-composition-and-instructions.md` | **instruction system** | instruction source 层级、`dsh-agent-instructions` 机制、preset 覆盖、注入产物、**多层级/子目录加载与 cwd 语义（§4.10）** |
| `05-browser-mcp.md` | **Browser MCP** | `dsh-mcp-client` / `@playwright/mcp` / E2E / 三平面 UI 覆盖度 |
| `06-dsh-runtime-and-multiprocess.md` | **runtime & multiprocess** | 持久层 vs 进程内存、stale view、双写风险、处理建议 |
| `07-profile-bundle-isolation.md` | **profile / bundle isolation** | bundle 归属的唯一权威来源、`dsh plugin` 写入面、无继承、package presence vs bundle membership、跨 profile 共享层清单、归属纪律 |
| `08-dsh-installation-and-upgrade.md` | **installation / upgrade** | 全局安装形态（安装树）、**三层解析模型**、prerelease 版本漂移、top-level rollback 语义、install-scripts/allowScripts、升级核对清单、global vs profile-local、共享 fallback 行为 |
| `09-dsh-desktop.md` | **official Desktop / mixed-version** | Desktop 组成（shell/host/bundled runtime/updater）、**第二 installation anchor**、四维边界、共享 `$DSH_HOME`、`[0.1.5 → 0.2.x]` settings 与 session-format 两个断裂面、Control B 结论、`session/end-seed` 取证纪律 |
| `10-experiment-methodology.md` | **experiment methodology** | quiescent baseline 的成立条件、fail-closed 取证、zero-diff 合法性、显式 baseline 绑定、PowerShell 5.1 陷阱、主机探测自匹配、隔离实验最小 scaffold |
| `browser-mcp/01-dsh-playwright-mcp-research.md` | **Browser MCP · 包与 schema** | `dsh-mcp-client` 的配置 schema、transport、字段约束 |
| `browser-mcp/02-dsh-web-ui-path-research.md` | **Browser MCP · UI 路径** | 三平面框架与各平面 UI 覆盖度 |
| `migration/10-claude-code-project-inventory.md` | **CC Step 1** | PJOS 项目清单 / Claude Code 边界面 |
| `migration/11-claude-code-dsh-concept-mapping.md` | **CC Step 2** | Claude Code ↔ DSH 概念映射 |
| `migration/12-migration-decision.md` | **decision record** | 资产分类（DIRECT-COPY / RE-HOST / RECREATE / DO-NOT-MIGRATE） |
| `migration/13-migration-plan.md` | **migration design** | 迁移设计、preflight、执行/验证/回滚计划 |
| `migration/14-phase32-execution-verification.md` | **execution & verification** | Phase 3.2 实际执行与取证（adopt + instruction 注入，PASS） |

---

## 四条研究线（**编号不要混用**）

- **PJOS 迁移线**：`Phase 1 → Phase 2 (10/11) → Phase 3.1 (13) → Phase 3.2 (14) → Phase 3.3+（未开始）`。
- **Browser MCP 线**：`B3.3 → B3.3b → B3.4 → B3.5（tool invocation）→ B3.6（Interactive SPA）`（见 `../experiments/browser-mcp/`）。
- **Profile 隔离线**：`P1（prep：read-only 基线 + 源码闭环）→ P2（browser-lab profile-local 安装 `dsh-whale-widget` + 运行 E2E）`（见 `../experiments/profile-isolation/`）。
- **DSH 安装 / 升级线**：`P-1（rc.1 → rc.2 失败 → rc.1 回滚失败 → rc.3 恢复）→ P-2（npm 日志归档）→ P-3（长期知识 `08`）`（见 `../experiments/dsh-install/`）。
- **官方 Desktop / mixed-version 线（CLOSED，2026-10-05）**：`P0 baseline → P1 官方 Desktop 考古 → P2 备份 → P13 取证工具链 → E1 run1/run2/run3 → Control B`（长期知识 `09`、方法论 `10`；原始取证 `../evidence/desktop/runtime/`）。
- **Instruction 线**：`$DSH_HOME/AGENTS.md` global instruction E2E + 永久 language policy（见 `../experiments/dsh-runtime/2026-09-12-global-agents-e2e.md`、`04` §6.1）。
  > 早期 Browser MCP 文档曾误用「Phase 3.3 / 3.4」与迁移线重名；重构后统一为 **B-prefix**。
- **跨版本知识审计线**（按版本对归档，**不是**实验线）：
  `0.2.0-rc.2 → 0.2.1-rc.2`（CLOSED 2026-10-19）→ `0.2.1-rc.2 → 0.2.2-rc.1`（CLOSED 2026-11-08）
  （见 `../experiments/dsh-version-audit/`）。

---

## 快速查询

| 我想知道…… | 查哪里 |
|---|---|
| 某概念在本机哪个路径 | `00` |
| `base.cordis.yml` / `web.cordis.yml` 是不是真实文件 | `00` §2.1 |
| workspace / session 存储在哪、为什么 `.jsonl.zstd` 解不开 | `00` §7.5 |
| sandbox / approval 边界值 | `00` §7.5.3 |
| Host 与 Agent 是不是平行层 | `01` §六 |
| agent preset 有哪几个、谁挂 `agent-instructions` | `04` §2 |
| `$DSH_HOME/AGENTS.md` 会不会被自动加载 | `04` §5 |
| `AGENTS.md` 是不是 plugin / Cordis Entry | `04` §0 |
| patch 的 precedence 与 instruction 的 precedence 为何不同 | `02` §J |
| `!!js` 什么时候求值 | `02` §G |
| profile patch 改了会不会热生效 | `02` §H |
| MCP 能不能从 Web UI 配置 | `05` §9 |
| Browser MCP 到底验证了什么 | `05` §7（tool invocation）+ §7.1（**Interactive SPA**）；`../experiments/browser-mcp/2026-09-12-B3.5-…`、`…-B3.6-…` |
| `$DSH_HOME/AGENTS.md` 是否真的生效 | `04` §6.1 + `../experiments/dsh-runtime/2026-09-12-global-agents-e2e.md` |
| 为什么两个 DSH 实例归类不一致 | `06` §1–§4 |
| 某个 bundle 属于哪个 profile | `07` §2 |
| `dsh plugin --profile X add <pkg>` 会改哪些文件 | `07` §3 |
| profile 之间会不会继承 | `07` §4 |
| "包在磁盘上" 算不算 "profile 挂了它" | `07` §5 |
| 有哪些跨 profile 共享层会破坏隔离 | `07` §6 |
| 401 / 404 能不能用来判断路由已注册 | `07` §7 |
| browser-lab 现在挂了哪些 bundle | `07` §9、`05` §4.1 |
| **当前 DSH 是什么版本** | `00` **§0.1**（★ 全库唯一版本事实源；注意有**两个 anchor**） |
| 0.2.1-rc.2 → 0.2.2-rc.1 有哪些机制变化、我的旧笔记哪几条要改 | `../experiments/dsh-version-audit/0.2.1-rc.2-to-0.2.2-rc.1/FINAL-REPORT.md`（先看这）、`…/KNOWLEDGE-DELTA.md`（K01–K45） |
| 0.2.0-rc.2 → 0.2.1-rc.2 有哪些机制变化、Toolkit 是否仍兼容 | `../experiments/dsh-version-audit/0.2.0-rc.2-to-0.2.1-rc.2/FINAL-REPORT.md`、`…/KNOWLEDGE-DELTA.md`、`…/TOOLKIT-COMPATIBILITY.md` |
| 为什么 `write` 前不强制先读（0.2.2 起） | `00` §7.5.4（`fs-observation-policy` 默认 `disabled: true`） |
| `tools.mode` / `DSH_TOOLS_MODE` 还能用吗 | `00` §7.5.4、`02` §K.2（0.2.2 起**已移除**，静默失效） |
| `apply_patch` 为什么用不了 | `00` §7.5.4（新增但 `applyPatch: false`，且 README 与 patch 冲突） |
| 全局与项目 `AGENTS.md` 的预算怎么算 | `04` §4.5（0.2.2 起**按链独立**，双链最多 2× `maxBytes`） |
| **项目根和子目录能不能各放一个 `AGENTS.md`** | `04` **§4.10.1**（能；父层累加、更具体优先；cwd 之下的层不在初始链上） |
| **进入子目录时会不会自动加载那里的指令** | `04` **§4.10.2**（"操作 → 是否加载 → 加载哪些 → 生效时机"对照表；`cd` **不触发**，`working_directory` 与 `read/write/edit` 才触发） |
| shell 里 `cd src` 为什么没让 Agent 读到 `src/AGENTS.md` | `04` §4.10.2（touch 只认 `read`/`write`/`edit` + `file_path`） |
| 回到父目录后子目录的指令会消失吗 | `04` §4.10.4（当前有效集有 `remove` 墓碑，**但旧正文仍在历史里**；且"兄弟同深度切换"可能残留） |
| 子目录 `AGENTS.md` 怎么布局最省心 | `04` §4.10.8（7 条实用建议） |
| 0.2.2 的 Cordis 内核版本 / 官方 bundle 清单在哪 | `02` §K.1、§K.3 |
| 官方 Desktop 是什么、和全局 DSH 什么关系 | `09` §1–§4 |
| 为什么旧 Web 看不到 Desktop 建的 v4 session | `09` §8 |
| 为什么 locale override 会"丢"（准确表述） | `09` §7 |
| `session/end-seed` 会不会破坏取证 | `09` §10 |
| 什么才算真正静止的 baseline | `10` §1 |
| capture 怎样才算 fail-closed | `10` §2 |
| zero-diff 为什么是合法结果 | `10` §3 |
| PowerShell 5.1 有哪些坑 | `10` §5 |
| DSH 程序本身装在哪、里面有什么 | `00` §1.3、`08` §1 |
| 一个包从 npm 到 Cordis 要穿过哪几层 | `08` §2（**三层解析模型**） |
| 为什么"顶层版本对了"依赖树仍可能坏 | `08` §3 |
| 为什么"装回旧版本"没把环境救回来 | `08` §4 |
| 升级 DSH 前后该核对什么 | `08` §7（核对清单） |
| 全局安装被替换会不会丢我的 profile 插件 | `08` §8、`07` §5 |
| `install-scripts blocked` 要不要管 | `08` §6 |
| 事故的原始 npm 日志在哪 | `../evidence/logs/npm/` |
| 某结论的原始证据在哪 | 各文档末尾 **Evidence** 段 |

---

*维护约定：正文只放"能回答某类问题的知识"；改动前先读对应文件；改动后在 **Evidence** 段登记来源路径。*

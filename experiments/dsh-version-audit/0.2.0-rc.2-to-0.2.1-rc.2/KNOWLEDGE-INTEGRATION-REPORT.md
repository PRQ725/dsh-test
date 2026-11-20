# KNOWLEDGE-INTEGRATION-REPORT — 0.2.0-rc.2 → 0.2.1-rc.2 审计知识整合

状态：**CLOSED（2026-10-19）**
类型：知识整合 / 结案；不是新实验，不是 Toolkit 版本升级。

---

## 1. 本轮范围与边界

- 输入：`experiments/dsh-version-audit/0.2.0-rc.2-to-0.2.1-rc.2/` 的 `KNOWLEDGE-DELTA.md`、
  `EVIDENCE-INDEX.md`、`FINAL-REPORT.md`、`TOOLKIT-COMPATIBILITY.md` 与 `evidence/`。
- 输出：只在**原有知识笔记**中做最小增补，不新建平行知识体系。
- 只修改 5 个既有知识/索引文件（另在审计目录内新增本报告并更新该目录 README 状态）；没有修改
  `toolkit/long-running/v0.2/`（8 文件哈希 8/8 未变）、
  `RELEASES.md`、`RELEASE-REPORT.md`、rc1/rc2/rc3 记录、冻结 Candidate、v0.1 Pilot、原始证据。
- 没有创建 Goal、没有 arm/resume、没有自动续轮、没有安装依赖、没有改 DSH 配置、没有做新实验。
- 没有发布新 Toolkit 版本，也没有提出 v0.3 计划。

### 1.1 运行时策略差异（如实记录）

本轮任务要求“保持 workspace-write / ask”，但进入本轮时 runtime context 已显示：

```text
Current DSH file policy: danger-full-access
Approval policy: never (changed by the user)
```

该变化由用户侧完成，**不是本 agent 修改的**；本 agent 没有修改 DSH 配置，也没有请求权限提升。
所有写操作仍然只发生在 `D:\Projects\dsh-test` 内的知识文件与审计目录中。
因此本轮**不能**声称“在 workspace-write / ask 下验证”；该事实与上一轮审计 session 的
`workspace-write` / `ask` 不同，已在 `docs/00` §7.5.3 记录为“边界值是 session 级配置”。

---

## 2. 修改文件及主要变化

本轮修改 **5 个既有知识/索引文件**；审计目录内新增本报告，并把该目录 `README.md` 的状态改为
`COMPLETE / CLOSED`、加入本报告入口（不属于通用知识笔记，也不改变审计结论）。

| # | 文件 | 主要变化 |
|---|---|---|
| 1 | `README.md` | 环境段：全局 npm 版本改为 `0.2.1-rc.2`，明确 active Web session 是 CLI/Web 的 `browser-lab` profile、Desktop 仍 `0.2.0-rc.2`；新增 §10“跨版本知识审计（CLOSED，2026-10-19）”及关键机制变化、模型说明、审计目录链接。 |
| 2 | `docs/00-dsh-local-filesystem.md` | §0.1：更新全局 npm anchor 为 `0.2.1-rc.2`（采集 2026-10-19），Desktop 保留 `0.2.0-rc.2` 并注明复核未变；新增 Active Web session runtime 行、模型层注记（`deepseek-flash` vs `V4.1-Flash` / `1017`）；版本演进追加 `0.2.0-rc.2 → 0.2.1-rc.2`；§7.5.2 增补 session format 仍 v4、`working_directory` 语义；§7.5.3 增补权限值是 session 级、可被用户改变。 |
| 3 | `docs/09-dsh-desktop.md` | 保留 §3 的 2026-10-05 版本表，新增 §3.1“2026-10-19 版本复核”：CLI 已升 0.2.1-rc.2、Desktop 仍 0.2.0-rc.2、当前 Web session 不是 Desktop；并说明 `[0.1.5 → 0.2.x]` 断裂面不能套到 `0.2.0 → 0.2.1`。 |
| 4 | `docs/README.md` | 版本约定段增加 2026-10-19 审计已 CLOSED 的注记；快速查询增加“0.2.0→0.2.1 机制变化 / Toolkit 是否兼容”条目与审计链接。 |
| 5 | `experiments/long-running/README.md` | 追加 “Post-release compatibility audit (2026-10-19)” 段：v0.2 在 0.2.1 下为 COMPATIBLE WITH CAVEAT、8/8 哈希未变、GOAL LIVE TEST NOT RUN，并列出需要版本注记的行为。 |

没有新增 `docs/` 文档，没有移动/重命名任何既有文件，没有调整目录结构。

---

## 3. K01–K24 处理结果

| ID | 处理 | 落点 / 说明 |
|---|---|---|
| K01 Goal 创建权威 | KEEP | 旧认知仍正确；未改文档。 |
| K02 maxGoalRounds HARD cap | KEEP | 未改文档。 |
| K03 SOFT 预算 | KEEP | 未改文档。 |
| K04 driver 停止/开轮行为 | ADD VERSION NOTE | `README.md` §10、`experiments/long-running/README.md`；完整机制留在审计报告（无独立 goal 章节可增补，且 toolkit 冻结）。 |
| K05 READY FOR HUMAN REVIEW | KEEP | 未改文档。 |
| K06 complete / blocked | KEEP | blocked ≥3 轮门槛留在审计报告；旧结论未变。 |
| K07 Plan vs Goal | KEEP | 未改文档。 |
| K08 Plan approval / dismiss | ADD VERSION NOTE | `README.md` §10 记 dismiss 语义；返回 shape 等实现细节留在审计报告。 |
| K09 Session 创建/恢复 | KEEP + 版本复核 | `docs/00` §7.5.2 记录 0.2.1 仍为 format v4；恢复语义未变。 |
| K10 Skill frontmatter | KEEP | 未变，未改文档。 |
| K11 Skill roots | KEEP | roots 未变；`resolveAgentsHome` 属实现细节，留在审计报告。 |
| K12 Skill depth | KEEP | 未变，未改文档。 |
| K13 workspace-write | ADD VERSION NOTE | `docs/00` §7.5.2（`working_directory` 不重划 sandbox grant）、§7.5.3；`README.md` §10。越界拒绝仍未实测。 |
| K14 ask approval | KEEP + 注记 | `docs/00` §7.5.3 记录权限值是 session 级；实际 approval 链路未 live 测试。 |
| K15 工具/子进程 | ADD VERSION NOTE | `README.md` §10 记 PTC `mode` 只剩 native/ptc；`run_code` cwd capture、PTC state 等细节留在审计报告。 |
| K16 State/Recovery | KEEP | 未改文档。 |
| K17 Evaluator vs 人工验收 | KEEP | 未改文档。 |
| K18 Final Report/证据 | KEEP | 未改文档。 |
| K19 Desktop/Web/CLI | ADD VERSION NOTE | `docs/00` §0.1、`docs/09` §3.1、`README.md` 环境段与 §10。 |
| K20 Provider/认证 | ADD VERSION NOTE（部分） | `docs/00` §0.1 记录 selected model ID 与 provider；API key precedence 因无独立认证章节，留在审计报告。 |
| K21 兼容性范围 | ADD VERSION NOTE | `README.md` §10、`docs/README.md`、`experiments/long-running/README.md`。 |
| K22 V4.1/1017 展示 | ADD VERSION NOTE | `docs/00` §0.1 模型注记、`README.md` §10；明确权重版本 UNKNOWN。 |
| K23 插件接口破坏性变化 | ADD VERSION NOTE（摘要） | `README.md` §10 提到 `./invariant` 移除；完整清单（`both`、dshHome、stats、Azure 等）留在审计报告。 |
| K24 `{{cwd}}` 移除 | ADD VERSION NOTE | `README.md` §10；完整 prompt-assembly 细节留在审计报告。 |

---

## 4. 修改前后 SHA256

| 文件 | 修改前 | 修改后 |
|---|---|---|
| `README.md` | `9B2312B1DEB18292EB219CA46731685EADA731162F8E54997E9ED338B8D0C30F` | `0A119C038F16FEDABC635C75FE9C5D09AB9D4B8AF7F3DAD2FF756AF7A1CDDA12` |
| `docs/00-dsh-local-filesystem.md` | `4D6568D98484DC0B1067E53D382A8C7124DFB5B4B7A5585CD724B9D0B43E8532` | `FF4EF6FC6F0D57A3EB85EBC160AFCBF6824CEA3289AC5A1B88731AEDFC5B8B97` |
| `docs/09-dsh-desktop.md` | `3C2249D3D8F3BE683A61ACF747CA30236CFFF98D63B2444166EFA7A3F14EAFB4` | `08FDF17337B76A02D5B8B83448FB9DFBBD8E64A80BA4ADBB6B2586A7F0996DFE` |
| `docs/README.md` | `9CE863E613687616EFCB57F33705988E6209572D020D0455B78C35667C7E028A` | `B8FBD9A96BB8DFAF7AA85974A637E5D0D2C70DA65AB2BA4DEAE76C598222D8AE` |
| `experiments/long-running/README.md` | `940E357B97BDB40B90622D3E3AC2A2F6F170C26966F88B198F6E854445F8AF63` | `85A364DC28B86C6D45F331694262102B6CF23122C9C2C43080A2562D98408BF6` |

---

## 5. 未整合的内容及原因

| 内容 | 未整合原因 |
|---|---|
| Goal driver 的 `drivable()`、`waitForChildren()`、queued prompt removal 等逐行机制 | 没有独立的 Goal 机制章节；Toolkit v0.2 已冻结，不能改。摘要进 `README.md` §10，细节留在审计报告。 |
| `blocked` 至少 3 个 goal round 的默认门槛 | 同上；属 Toolkit 契约的补充说明，未修改 v0.2。 |
| Plan review dismiss 的返回值 shape | 属交互实现细节；通用笔记只记录“dismiss 结束本轮”这一语义。 |
| `resolveAgentsHome` / `DSH_AGENTS_HOME` 解析变化 | roots/depth 未变，属实现细节；留在审计报告 K11。 |
| `working_directory` 的 projection/persistence 细节 | `docs/00` 只记录“可改 Session cwd、不重划 sandbox grant”的语义；实现细节留在审计报告。 |
| `run_code` 捕获 cwd、PTC state 默认 fresh | 实现细节；`README.md` §10 只记 `mode` 枚举变化。 |
| API key precedence（Web/Desktop vs headless） | 没有独立认证知识章节；留在审计报告 K20，避免新建平行体系。 |
| `./invariant` 移除的完整清单、`both`、Agent Team outbox、Azure 更名等 | 完整破坏性清单属版本迁移细节；`README.md` §10 只做摘要，详表在审计报告 K23。 |
| model catalog field validation、provider connect/admit、image pricing | 纯实现细节；留在审计报告。 |
| session persistence 的 dispose 顺序、listConcurrency、worker exit 校验 | 实现可靠性改进，不改对外契约；留在审计报告 K09/K16。 |
| Gateway Peer principal / remote access / Web Search API / public-url | 与本仓库长期知识线无直接对应章节；留在审计报告的 “major changes”。 |
| Desktop 应用内部结构、Electron 版本 | 属 `docs/09` 既有范围，本轮只更新版本锚点，不重复考古。 |
| Skill discovery 的 live 验证 | 本轮禁止新实验；仍为 `NOT LIVE-TESTED`，未改写为事实。 |

---

## 6. 验证结果

| 验证项 | 结果 |
|---|---|
| 更新内容与审计证据一致 | PASS：K04/K08/K13/K15/K19/K20/K21/K22/K23/K24 均对应审计文件的源码/官方/运行时证据 |
| 旧版事实与版本边界保留 | PASS：`docs/09` §3 的 2026-10-05 版本表保留，新增 §3.1 复核；`docs/00` 保留版本演进与历史说明；未改写 `[0.1.5 → 0.2.x]` 结论 |
| Markdown 链接有效 | PASS：`README.md` → 审计目录；`docs/00` / `docs/09` / `docs/README` → `../experiments/...`；`experiments/long-running/README.md` → `../dsh-version-audit/...`，目标均存在 |
| Toolkit v0.2 八文件哈希未变化 | PASS：8/8 与 `RELEASES.md` 一致（`METHODOLOGY.md`、`README.md`、`SKILL.md`、`templates/*`） |
| 无无关文件修改 | PASS：21:20 之后除审计目录外，仅上述 5 个文件被修改 |
| 未创建新知识体系 | PASS：未新增 `docs/` 文件；只在既有章节增补 |
| 未改冻结/历史材料 | PASS：Toolkit、RELEASES、RELEASE-REPORT、rc 记录、Pilot、原始证据均未动 |
| 无新实验 / 无 Goal / 无安装 | PASS |
| 权限策略与任务要求一致 | **不一致，如实记录**：本轮实际为 `danger-full-access` / `never`（用户修改），未由本 agent 改动，也未请求提升；写入仍限于 workspace |

---

## 7. 剩余 UNKNOWN（结案时保留）

1. Goal live test（create/arm/round/cap/pause/resume）—— `NOT RUN`。
2. 实际 API 路由到的模型权重版本 —— `UNKNOWN`；1017 仅为客户端展示。
3. 当前使用的 credential 路径 —— `UNKNOWN`（未读取凭据）。
4. node-pty ConPTY `Cannot launch conpty` 的根因 —— `UNKNOWN`。
5. Toolkit `SKILL.md` 的 live discovery —— `NOT TESTED`。
6. 越界写入被 sandbox 拒绝的运行时证据 —— `NOT TESTED`（本轮亦未做）。
7. Desktop 0.2.0 与 CLI 0.2.1 的 v4 session 互操作 —— `NOT RETESTED`。

---

## 8. 结案

- 本轮知识整合完成，跨版本审计线标记为 **CLOSED（2026-10-19）**。
- Toolkit v0.2 保持发布态不变；没有新版本、没有新开发计划。
- 后续如需要验证上述 UNKNOWN，必须另开受控实验；本轮不继续研究。

**STOP FOR HUMAN REVIEW.**

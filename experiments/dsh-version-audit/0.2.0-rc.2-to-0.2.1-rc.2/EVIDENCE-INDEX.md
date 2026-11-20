# EVIDENCE-INDEX — sources, acquisition, and limits

审计日期：2026-10-19
范围：0.2.0-rc.2 → 0.2.1-rc.2 的跨版本知识审计；不含开发、不含 Toolkit 升级。

证据优先级（与任务定义一致）：

| 层 | 含义 | 本审计中的来源 |
|---|---|---|
| **A** | 当前 0.2.1-rc.2 运行时可观察行为 | 本 session 的工具面、session events、`get_goal`、`working_directory`、`pwsh` 执行结果 |
| **B** | 与当前安装版本一致的官方源码/类型/内置文档/帮助 | 已安装 `@deepseek-ai/dsh@0.2.1-rc.2` 及其 shipped `node_modules`；CLI `--help`；`README.md` |
| **C** | 官方发布说明与版本差异 | GitHub releases `dsh-v0.2.1-rc.1` / `dsh-v0.2.1-rc.2`；npm cache 中的 tarball metadata/integrity |
| **D** | 旧版 0.2.0-rc.2 的冻结实验记录 | `toolkit/long-running/v0.2/`、`PILOT-SPEC-v0.1.md`、`RUNBOOK.md`、`RELEASE-REPORT.md`、`RELEASES.md`、`docs/00`、`docs/06`、`docs/09` |
| **E** | 未经验证的历史推断 | 旧 README 的“下一步研究方向”中标记 `[UNKNOWN]` 的条目；未被本轮复现的旧叙述 |

---

## 1. 实际阅读的文件（按层）

### A — 运行时（本次生成）

| 文件 | 说明 |
|---|---|
| `evidence/session-current.jsonl.txt` | 当前 session 的 134 个 zstd frame 解码后的 JSONL（231 events），用于提取 header/permissions/goal/tool surface |
| `evidence/session-facts.json` | 从上述 JSONL 抽出的 model、permissions、tool 数、goal 状态 |
| `evidence/tool-surface.txt` | 59 个工具的完整列表 |
| `evidence/runtime-identity.txt` | workspace/CLI/Desktop/profile/session 身份链 |
| `evidence/frozen-toolkit-sha256.txt` | v0.2 八个文件的当前哈希，与发布记录逐一比对 |
| `evidence/install-health.txt` | 五个被标记包的版本、native artifacts、import/PTY 结果 |
| `evidence/official-release-notes.md` | 官方 release notes 的原文摘录与 URL |

### B — 当前安装（0.2.1-rc.2）

根：`C:\Users\user02\AppData\Roaming\npm\node_modules\@deepseek-ai\dsh`

| 文件/包 | 用于 |
|---|---|
| `package.json` | CLI 版本、依赖树（全部 pin 到 0.2.1-rc.2） |
| `README.md` | profile/launcher 语义、desktop 保留名 |
| `node_modules/@deepseek-ai/dsh-goal/README.md`、`lib/typert.host.js` | goal 四 phase、activation、256 default、round-count only |
| `node_modules/@deepseek-ai/dsh-goal-round-driver/lib/index.js`、`README.md` | round cap、round-limit、subagent wait、queued prompt removal |
| `node_modules/@deepseek-ai/dsh-tool-goal/lib/index.js` | direct-human / goal-round authority、blocked 门槛 |
| `node_modules/@deepseek-ai/dsh-skill-filesystem/lib/index.js`、`README.md` | roots、depth 1、frontmatter |
| `node_modules/@deepseek-ai/dsh-plan-mode/lib/index.js`、`README.md` | plan review approve/dismiss 语义 |
| `node_modules/@deepseek-ai/dsh-llm-deepseek/lib/index.js`、`README.md` | catalog、请求参数、toolUpdate/systemPromptUpdate |
| `node_modules/@deepseek-ai/dsh-session/lib/index.js` | `SESSION_FORMAT_VERSION = 4` |
| `node_modules/@deepseek-ai/dsh-session-persistence-jsonl/lib/index.js`、`README.md` | zstd frame、dispose 顺序、formatStatus |
| `node_modules/@deepseek-ai/dsh-system-prompt/lib/index.js`、`README.md` | `{{cwd}}` 移除、required context |
| `node_modules/@deepseek-ai/dsh-agent-loop/lib/index.js`、`README.md` | prompt 组装、working-directory context |
| `node_modules/@deepseek-ai/dsh-tools/README.md` | `native | ptc`（`both` 已移除）、run_code cwd |
| `node_modules/@deepseek-ai/dsh-web-app/presets/standard.patch.yml`、`cordis.patch.yml` | 0.2.1 新增 time-context/tool-schedule/model-label/secret-mask |
| `node_modules/@deepseek-ai/dsh-working-directory/README.md`（新包） | cwd 变更语义、sandbox grant 独立性 |
| `node_modules/@deepseek-ai/dsh-client-ui-deepseek-model-label-1017/README.md`（新包） | 1017 badge 是 presentation，不是能力断言 |
| `C:\Users\user02\.dsh\profiles\browser-lab\cordis.patch.yml` | provider/model/reasoningEffort、MCP 挂载、locale |
| `C:\Users\user02\.dsh\profiles\browser-lab\package.json` | profile bundles |
| `C:\Users\user02\AppData\Local\Programs\DeepSeek Harness\resources\runtime\primary-runtime\runtime.json` | Desktop `desktopVersion = 0.2.0-rc.2` |

### C — 官方发布与包来源

| 来源 | 内容 |
|---|---|
| `https://api.github.com/repos/deepseek-ai/deepseek-harness/releases?per_page=5` | rc.1（2026-10-17T05:22:10Z）、rc.2（2026-10-17T08:16:33Z）的 release body |
| `https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.1-rc.1` | rc.1 全量变更摘要 |
| `https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.1-rc.2` | rc.2 delta：V4.1-Flash-1017 + DeepSeek Search/Fetch |
| 本地 npm cache `index-v5` + `content-v2` | 306 个 `@deepseek-ai/*` 包的 0.2.0/0.2.1 双版本 tarball；573 条 cached entry，integrity 逐一解析 |

### D — 旧版冻结记录（只读）

| 文件 | 用于 |
|---|---|
| `toolkit/long-running/v0.2/README.md` | K01-K03、K05、K10-K13、K21 的旧结论 |
| `toolkit/long-running/v0.2/SKILL.md` | K04、K08、K10-K12、K14-K18 |
| `toolkit/long-running/v0.2/METHODOLOGY.md` | K03-K07、K16-K18 的推理 |
| `toolkit/long-running/v0.2/templates/*.md` | 报告/验收契约（GOAL/PLAN/STATE/EVALUATION/FINAL-REPORT） |
| `toolkit/long-running/RELEASES.md` | 8 文件哈希、发布门槛、未验证项 |
| `experiments/long-running/v0.2-work/RELEASE-REPORT.md` | L1-L7 已知限制、未测机制清单 |
| `experiments/long-running/v0.2-work/V0.2-ACCEPTANCE-SPEC.md` | V1-V16 / R1-R3（用于确认“机械检查 ≠ harness 实测”） |
| `experiments/long-running/v0.2-work/CHANGE-LIST.md` | 旧结论的来源线索（引用了第一 pilot） |
| `experiments/long-running/PILOT-SPEC-v0.1.md` | K01-K08、K13-K15 的最早机制记录 |
| `experiments/long-running/RUNBOOK.md` | cap=5、`/goal` 操作、默认 256 的警告 |
| `experiments/long-running/README.md` | v0.1/v0.2 的 bucket 与状态 |
| `README.md`（仓库根） | 当前进度、两个 installation anchor、K19 |
| `docs/00-dsh-local-filesystem.md`（§0.1、§1） | 旧版本表、`$DSH_HOME` 路径、credentials |
| `docs/06-dsh-runtime-and-multiprocess.md`（§2-§4） | session v3/v4、持久层 vs 运行时层、双写风险 |
| `docs/09-dsh-desktop.md`（§5-§7） | shared state、凭据路径、settings 断裂面 |
| `docs/migration/14-phase32-execution-verification.md`（grep 命中 L173） | 旧 session 的 workspace-write/ask 记录 |

### E — 未验证的旧推断（未当作证据使用）

- 旧 README 的 `[UNKNOWN]` 列表：npm prerelease caret 规则、rc.3 恢复的决定性因素、
  `install-scripts blocked` 对 PTY/native 的全部影响。
- v0.1 pilot 的第一手 evidence 位于仓库外 `D:\Projects\dsh-longloop-pilot\`，本轮**未读取**，只引用仓库内的
  PILOT-SPEC / RUNBOOK / RELEASE-REPORT 转述。
- `docs/06` 中“双写可能覆盖 workspace.json”是 `[INFERENCE]`，本轮未复现。

---

## 2. 生成的分析产物

| 文件 | 方法 | 用途 |
|---|---|---|
| `evidence/cache-inventory.json` | 扫描 `_cacache/index-v5`，解析 key/integrity，定位 `content-v2` | 306 个包、573 条版本记录 |
| `evidence/package-diff.json` | 解压双版本 tarball，逐文件 SHA-256 对比 | 267 个双方都存在的包全部有改动；527 added / 188 removed / 1801 changed files |
| `evidence/upstream/changed/<pkg>/{0.2.0-rc.2,0.2.1-rc.2}/` | 仅保留本次审计引用的 13 个关键包 | 源码级引用 |
| `evidence/upstream/added/<pkg>/0.2.1-rc.2/` | 仅保留 0.2.1 新包中的 3 个 | `working_directory`、model label |
| `evidence/decode-session.mjs` | 按 zstd magic 切 frame，逐帧解压 | 读取 `session.v4.jsonl.zstd` |
| `evidence/extract-session-facts.mjs` | 解析 JSONL，抽 model/permissions/tools/goal | 生成 `session-facts.json` |
| `evidence/analyze-diff.mjs` / `extract-tgz.mjs` / `extract-selected.mjs` / `cache-inventory.mjs` | 只读 tarball 处理 | 可复现 |

未保留全部 267 个包的解压副本（约 109 MB、8,986 文件），只保留：
**完整 diff JSON** + **关键包源码**。完整 tarball 仍在 npm cache 中，integrity 见 `cache-inventory.json`，
可按需重新解压。

---

## 3. 复现方式

```powershell
# 1) 版本
dsh --version
(Get-Content "$env:APPDATA\npm\node_modules\@deepseek-ai\dsh\package.json" -Raw | ConvertFrom-Json).version

# 2) Desktop bundled runtime
(Get-Content "$env:LOCALAPPDATA\Programs\DeepSeek Harness\resources\runtime\primary-runtime\runtime.json" -Raw | ConvertFrom-Json).desktopVersion

# 3) session 解码（只读）
node evidence\decode-session.mjs `
  "$env:USERPROFILE\.dsh\sessions\--D-Projects-dsh-test--\session-32aa9e1e-a677-4f88-8682-f9c639f0b48c\session.v4.jsonl.zstd" `
  evidence\session-current.jsonl.txt
node evidence\extract-session-facts.mjs evidence\session-current.jsonl.txt evidence\session-facts.json

# 4) 双版本包 diff（只读 npm cache）
node evidence\cache-inventory.mjs "$env:LOCALAPPDATA\npm-cache" evidence\cache-inventory.json 0.2.0-rc.2 0.2.1-rc.2
node evidence\analyze-diff.mjs evidence\cache-inventory.json "$env:TEMP\dsh-audit-upstream" evidence\package-diff.json ""

# 5) toolkit 完整性
Get-ChildItem toolkit\long-running\v0.2 -Recurse -File | Get-FileHash -Algorithm SHA256
```

---

## 4. 局限与偏差

1. **只比了包，不比整个 monorepo 的 git 历史。** 双版本 tarball 是 npm 发布产物；构建 hash 重命名会让
   “changed file”数量偏大（每个包都至少有 bundle 文件名/README/locale 改动）。
2. **没有旧版 0.2.0 的运行时实例。** 0.2.0 的行为只能从 tarball 源码/README 与旧实验记录读取，
   不能在本机做同条件对照。
3. **没有 Goal live test。** 所有 goal driver 结论都是 SOURCE-CODE CONFIRMED 或 OFFICIAL DOCUMENTED，
   不是 RUNTIME-OBSERVED。`GOAL LIVE TEST: NOT RUN`。
4. **模型权重版本不可本地验证。** 只验证了 selected model ID 和显示名；“实际 API 路由到的版本”是 `UNKNOWN`。
5. **PTY 失败根因未定。** 只记录现象与包完整性，不归因于 0.2.1。
6. **旧 pilot 的第一手 evidence 在仓库外**，本轮未打开；引用的是仓库内转述。若需要第一手对照，
   应另开只读审计，不改动该 workspace。
7. **官方 release notes 是外部数据**，已按 C 层引用；其中的“support”措辞不被扩张解释为性能提升。

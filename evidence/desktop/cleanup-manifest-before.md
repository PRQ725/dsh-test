# Calibration manifest — BEFORE cleanup (Desktop / mixed-version 研究副产物)

Recorded 2026-10-05 (local, UTC+8). Phase 2 pre-flight.
Scope: byproducts of the **Desktop / mixed-version compatibility** research line only.
其他研究线（browser-mcp / browser-probe / profile-isolation / dsh-install / migration）的产物
**不在本次清理范围**，保持原状。

## 0. 总量

| 集合 | 文件数 | 大小 |
|---|---:|---:|
| `evidence\desktop\runtime\` 合计（清理前） | 990 | 2,025,170 B |
| ├─ DELETE-SAFE | 769 | 910,636 B |
| ├─ KEEP-ARCHIVE（原始 stage 取证 → zip） | 214 | 1,039,685 B |
| └─ KEEP-LONG-TERM（松散保留） | 22 | 110,956 B |
| `scripts\` 合计 | 21 | 249,818 B |
| `evidence\desktop\before\` | 5 | 121,692 B |
| `evidence\logs\`（他线，不动） | 6 | 2,771,903 B |
| `experiments\`（他线，不动） | 51 | 18,956,159 B |
| `archive\`（他线，不动） | 8 | 6,048,964 B |

---

## 1. DELETE-SAFE（直接删除）

| # | path | type | size | files | reason | disposition | 结论是否已被覆盖 |
|---|---|---|---:|---:|---|---|---|
| D1 | `evidence\desktop\runtime\_selftest-r2\` | scratch | 881,526 B | 755 | 自测 / binding 测试 / zero-diff 回归 / plumbing 的 **每轮 run-\<timestamp\> scratch**（含 mock fixtures、stub tools、cmp-case*、cap-*、gate-test*） | **DELETE** | ✅ 结论已入 `docs/10-experiment-methodology.md` §2–§4；测试脚本本身保留，可随时重跑再现 |
| D2 | `D:\Projects\dsh-desktop-controlB-home\` | isolated runtime state | 28,744 B | 11 | Control B 隔离 home（含被 0.2.0 改写后的 v4 副本、草稿 session、生成的 profile 与 credentials scaffold） | **DELETE** | ✅ 结论已入 `evidence\desktop\runtime\controlB\CONTROL-B-RESULT.md`（含 size/sha 与 append 事件原文）；真实 home 的源 session 未变，可重新构造 |
| D3 | `D:\Projects\dsh-desktop-runtime-test\` | transient workspace | 122 B | 1 | run1 隔离 workspace（仅 AGENTS.md fixture） | **DELETE** | ✅ run1 baseline 已被判定 CONTAMINATED 并在 `docs/09` / `e1-BASE` 注释中记录；fixture 可重建 |
| D4 | `D:\Projects\dsh-desktop-runtime-test-2\` | transient workspace | 122 B | 1 | run2 隔离 workspace（仅 AGENTS.md fixture） | **DELETE** | ✅ run2 结论已入 `e1-run2-A\RUN2-CONTAMINATION-NOTE.md`；fixture 可重建 |
| D5 | `D:\Projects\dsh-desktop-runtime-test-3\` | transient workspace | 122 B | 1 | run3 隔离 workspace（仅 AGENTS.md fixture） | **DELETE** | ✅ run3 结论已入 `e1-run3-CLASSIFICATION-NOTE.md`；fixture 可重建 |

**小计：769 files / 910,636 B**

> 备注：D3–D5 删除后，`e1-run3.metadata.json` / `e1-run3.session.lock.json` 中的
> `WorkspacePath` 会变成**悬空引用**。这两个文件作为历史记录保留；悬空是预期的，
> 因为 run3 已 CLOSED，且真实 session 数据仍在 `$DSH_HOME` 中。

## 2. KEEP-ARCHIVE（压缩进 zip 后删除原目录）

目标：`evidence\desktop\archive\2026-10-05-desktop-research-final.zip`

| # | path | type | size | files |
|---|---|---|---:|---:|
| A1 | `runtime\e1-A\` | stage capture | 59,949 B | 19 |
| A2 | `runtime\e1-BASE\` | stage capture (contaminated) | 57,931 B | 20 |
| A3 | `runtime\e1-BASE-A-compare\` | compare output | 18,807 B | 3 |
| A4 | `runtime\e1-run2-A\` | stage capture | 113,989 B | 21 |
| A5 | `runtime\e1-run3-A\` | stage capture | 107,023 B | 20 |
| A6 | `runtime\e1-run3-B\` | stage capture | 115,413 B | 20 |
| A7 | `runtime\e1-run3-A-B-compare\` | compare output | 13,022 B | 3 |
| A8 | `runtime\e1-run3-BASELINE-A-compare\` | compare output | 11,587 B | 3 |
| A9 | `runtime\e1-BASE-QUIESCENT-R2\` | sealed baseline | 98,560 B | 19 |
| A10 | `runtime\e1-BASE-QUIESCENT-R2-VERIFY\` | baseline verify | 98,683 B | 19 |
| A11 | `runtime\e1-BASE-QUIESCENT-R2-compare\` | compare output | 5,429 B | 3 |
| A12 | `runtime\e1-BASE-QUIESCENT-R2-compare-revalidated\` | compare output | 5,429 B | 3 |
| A13 | `runtime\e1-BASE-QUIESCENT-R3\` | sealed baseline | 97,938 B | 20 |
| A14 | `runtime\e1-BASE-QUIESCENT-R3-VERIFY\` | baseline verify | 96,862 B | 19 |
| A15 | `runtime\e1-BASE-QUIESCENT-R3-compare\` | compare output | 5,429 B | 3 |
| A16 | `runtime\_forensic\` | decoded session forensic | 58,644 B | 3 |
| A17 | `runtime\controlB-REAL-HOME-BEFORE\` | real-home fingerprint | 35,906 B | 7 |
| A18 | `runtime\controlB-REAL-HOME-AFTER\` | real-home fingerprint | 35,905 B | 7 |
| A19 | `runtime\controlB-REAL-HOME-COMPARE\` | before/after diff | 3,179 B | 2 |

**小计：214 files / 1,039,685 B**

删除原目录**前置条件**：zip 创建成功、可读、条目数一致，并记录 SHA-256。
理由：这些是**有审计价值但日常不需要**的 raw evidence；同一结论已由 KEEP-LONG-TERM 中的
final reports / verdicts / fingerprints 承载体。

## 3. KEEP-LONG-TERM（松散保留，不压缩）

### 3.1 final reports / notes（**在任何情况下不删除**）

| path | size | 承载的结论 |
|---|---:|---|
| `runtime\e1-run3-FORENSIC-v4-DISCOVERY.md` | 24,355 B | 0.1.5 vs 0.2.0 session discovery / codec / listing 全链路 |
| `runtime\e1-run3-CLASSIFICATION-NOTE.md` | 11,233 B | E1 run3 最终分类 `NOT DISCOVERABLE` + 破坏性副作用审查 |
| `runtime\controlB\CONTROL-B-RESULT.md` | 5,539 B | matched-version Control B 结论 |
| `runtime\controlB\controlB-prep-report.txt` | 1,905 B | 隔离 home 构造取证 |
| `runtime\controlB\controlB-before-ui.json` | 503 B | UI 前基线快照 |
| `runtime\e1-run3-BASELINE-PRECONDITIONS.md` | 8,836 B | settings 边界 + Option A 决策 |
| `runtime\e1-BASE-QUIESCENT-INVALID-NOTE.md` | 10,420 B | R1 FALSE PASS 根因与 INVALID 隔离 |
| `runtime\e1-BASE-QUIESCENT-R2-VALIDATOR-NOTE.md` | 9,249 B | R2 FALSE FAIL 根因与修正判据 |
| `runtime\e1-run2-A\RUN2-CONTAMINATION-NOTE.md` | 6,997 B | run2 归因污染定性 |

### 3.2 minimal reproducible evidence / verdicts

| path | size | 作用 |
|---|---:|---|
| `runtime\e1-BASE-QUIESCENT-VERDICT.txt` | 2,141 B | **R1 FALSE PASS 原始产物**（INVALID-NOTE 按 SHA 引用） |
| `runtime\e1-BASE-QUIESCENT-compare\` (3 files) | 5,256 B | R1 compare 原始产物（同上，按 SHA 引用） |
| `runtime\e1-BASE-QUIESCENT-ATTEMPT-FAILED.txt` | 962 B | gate 拒绝记录 |
| `runtime\e1-BASE-QUIESCENT-R2-VERDICT.txt` | 2,944 B | R2 原始 FALSE FAIL verdict（历史） |
| `runtime\e1-BASE-QUIESCENT-R2-REVALIDATED-VERDICT.txt` | 4,259 B | R2 重验 PASS verdict |
| `runtime\e1-BASE-QUIESCENT-R2-CAPTURE-FINGERPRINTS.txt` | 5,788 B | R2 两份 capture 的逐文件 SHA-256 |
| `runtime\e1-BASE-QUIESCENT-R3-VERDICT.txt` | 5,051 B | R3 封印 baseline verdict |
| `runtime\e1-run3.metadata.json` | 2,440 B | 显式 baseline binding 的实例 |
| `runtime\e1-run3.session.lock.json` | 917 B | exact session lock 实例 |
| `runtime\e1-run2.session.lock.json` | 624 B | run2 lock（历史） |
| `runtime\e1-run3-BINDING-REFUSED.txt` | 1,537 B | 绑定门禁拒绝记录（含读者说明） |

**小计：22 files / 110,956 B**

### 3.3 scripts

| 处置 | 文件 | 理由 |
|---|---|---|
| **KEEP** | `scripts\read-asar.mjs` | 真正通用：解任何 ASAR，无需 Electron、不解包。`docs/09` 引用它 |
| **KEEP** | `scripts\decode-session-log.mjs`、`scripts\analyze-session-record.mjs` | 通用 session log 取证工具 |
| **KEEP** | `scripts\desktop-runtime-experiment\session-summary.mjs` | 通用 session 摘要（事件直方图） |
| **KEEP** | `scripts\desktop-runtime-experiment\capture-shared-state.ps1` | 通用 `$DSH_HOME` 状态指纹（可复用于任何 DSH 研究） |
| **KEEP** | `scripts\desktop-runtime-experiment\compare-captures.ps1` | 通用 capture 差异比较 |
| **KEEP** | `scripts\desktop-runtime-experiment\capture-guard.ps1` | **fail-closed 取证的通用实现**（`docs/10` §2 的方法论实物） |
| **DELETE** | `scripts\desktop-runtime-experiment\e5-capture.ps1` | E5 从未执行、研究已 CLOSED、无长期价值 |
| **KEEP** | 其余 E1 orchestrator / runbook / selftest 脚本（`e1-capture.ps1`、`capture-e1-quiescent-baseline.ps1`、`new-e1-run.ps1`、`capture-run-config.ps1`、`e1-run3-runbook.md`、`e1-binding.selftest.ps1`、`compare-validator.regression.ps1`、`revalidate-e1-quiescent-baseline.ps1`、`capture-guard.selftest.ps1`、`control-b-prep.ps1`、`control-b-runbook.md`、`capture-desktop-runtime.ps1`、`detect-runtime-test-session.ps1`） | 小体积（合计约 200 KB）、是保留证据的**可复现来源**，且 `docs/10` 的方法论正是它们的抽象。**有疑问 → 保留，不冒险** |

## 4. DO-NOT-TOUCH

| 项 | 理由 |
|---|---|
| `C:\Users\user02\.dsh`（真实 `$DSH_HOME`） | 生产状态：sessions / storages / profiles / settings / credentials |
| `D:\Projects\Personal Job Search OS`（PJOS） | 生产项目 |
| `evidence\logs\`、`evidence\install-snapshots\`、`evidence\config-dumps\` | 他线（安装事故 / profile 隔离）的不可再生证据 |
| `experiments\browser-mcp\`、`browser-probe\`、`profile-isolation\`、`dsh-install\`、`dsh-runtime\` | 他线实验记录 |
| `evidence\desktop\before\` | Desktop 安装前备份取证 |
| `archive\` | 历史归档 |
| `docs\` | 长期知识库 |

---

## 5. 清理后预期

| 指标 | before | after（预期） |
|---|---:|---:|
| `evidence\desktop\runtime\` 大小 | 2,025,170 B | ≈ 110,956 B + zip ≈ 250–350 KB |
| `evidence\desktop\runtime\` 文件数 | 990 | 22 + 1 zip |
| `evidence\desktop\runtime\` 顶层目录数 | 22 | 2（`controlB\`、`e1-BASE-QUIESCENT-compare\`） |
| `D:\Projects` 下 runtime-test / controlB-home 目录 | 4 | 0 |
| `scripts\` 文件数 | 21 | 20 |
| 预期释放 | — | ≈ 1,570,000 B（删除 910,636 + 归档净省 ≈ 700,000） |

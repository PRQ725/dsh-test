# Calibration manifest — AFTER cleanup (Desktop / mixed-version 研究副产物)

Executed 2026-10-05 (local, UTC+8). Phase 2 completed.

## 1. 删除了什么

### 1.1 已归档后删除原目录（19 个目录 / 214 files）

原内容已完整进入
`evidence\desktop\archive\2026-10-05-desktop-research-final.zip`
（**326,297 B**，**214 entries**，SHA-256 `8974B6FA6A590A7851AE4CCFE1AE1E6E33FBB77CCDADFB7089882CAF233A959E`，已验证可读）。

`e1-A/`、`e1-BASE/`、`e1-BASE-A-compare/`、`e1-run2-A/`、`e1-run3-A/`、`e1-run3-B/`、
`e1-run3-A-B-compare/`、`e1-run3-BASELINE-A-compare/`、`e1-BASE-QUIESCENT-R2/`、
`e1-BASE-QUIESCENT-R2-VERIFY/`、`e1-BASE-QUIESCENT-R2-compare/`、
`e1-BASE-QUIESCENT-R2-compare-revalidated/`、`e1-BASE-QUIESCENT-R3/`、
`e1-BASE-QUIESCENT-R3-VERIFY/`、`e1-BASE-QUIESCENT-R3-compare/`、`_forensic/`、
`controlB-REAL-HOME-BEFORE/`、`controlB-REAL-HOME-AFTER/`、`controlB-REAL-HOME-COMPARE/`

### 1.2 直接删除（无归档价值）

| path | files | 理由 |
|---|---:|---|
| `evidence\desktop\runtime\_selftest-r2\` | **755** | 自测 / binding / zero-diff / plumbing 的每轮 scratch（mock fixtures、stub tools、gate-test、cmp-case*）。结论已在 `docs/10`；测试脚本保留可重跑 |
| `D:\Projects\dsh-desktop-controlB-home\` | 11 | Control B 隔离 home（运行时状态）。结论已在 `controlB\CONTROL-B-RESULT.md` |
| `D:\Projects\dsh-desktop-runtime-test\` | 1 | run1 隔离 workspace（仅 fixture） |
| `D:\Projects\dsh-desktop-runtime-test-2\` | 1 | run2 隔离 workspace（仅 fixture） |
| `D:\Projects\dsh-desktop-runtime-test-3\` | 1 | run3 隔离 workspace（仅 fixture） |
| `scripts\desktop-runtime-experiment\e5-capture.ps1` | 1 | **E5 从未执行**，研究支线已 CLOSED，无长期价值 |

## 2. 释放的空间

| 指标 | before | after | 变化 |
|---|---:|---:|---:|
| `evidence\desktop\runtime\` 大小 | 2,025,170 B | **103,959 B**（含松散 21 文件） | **−1,921,211 B** |
| 归档 zip | — | 326,297 B | +326,297 B |
| **净释放** | — | — | **≈ 1,594,914 B（1.52 MB）** |
| `runtime\` 文件数 | 990 | 21 + zip | −969 |
| `runtime\` 顶层目录数 | 22 | **2** | −20 |
| `D:\Projects` 下 `dsh-desktop-runtime-test*` / `dsh-desktop-controlB-home` 目录 | 4 | **0** | −4 |
| `scripts\` 文件数 | 21 | 20 | −1 |

## 3. 保留了哪些 evidence（松散可见）

### 3.1 final reports / notes（9 份，全部在任何情况下保留）

```
runtime\e1-run3-FORENSIC-v4-DISCOVERY.md          24,355 B   session discovery / codec / listing 全链路
runtime\e1-run3-CLASSIFICATION-NOTE.md            11,233 B   E1 run3 最终分类 NOT DISCOVERABLE
runtime\e1-BASE-QUIESCENT-INVALID-NOTE.md         10,420 B   R1 FALSE PASS 根因 + INVALID 隔离
runtime\e1-BASE-QUIESCENT-R2-VALIDATOR-NOTE.md     9,249 B   R2 FALSE FAIL 根因 + 修正判据
runtime\e1-run3-BASELINE-PRECONDITIONS.md          8,836 B   settings 边界 + Option A 决策
runtime\e1-run2-A\RUN2-CONTAMINATION-NOTE.md       6,997 B   run2 归因污染定性
runtime\controlB\CONTROL-B-RESULT.md               5,539 B   matched-version Control B 结论
runtime\controlB\controlB-prep-report.txt          1,905 B   隔离 home 构造取证
runtime\controlB\controlB-before-ui.json             503 B   UI 前基线快照
```

### 3.2 minimal reproducible evidence（12 项）

```
runtime\e1-BASE-QUIESCENT-VERDICT.txt              2,141 B   R1 FALSE PASS 原始 verdict
runtime\e1-BASE-QUIESCENT-compare\ (3 files)       5,256 B   R1 compare 原始产物
runtime\e1-BASE-QUIESCENT-ATTEMPT-FAILED.txt         962 B   gate 拒绝记录
runtime\e1-BASE-QUIESCENT-R2-VERDICT.txt           2,944 B   R2 原始 FALSE FAIL verdict
runtime\e1-BASE-QUIESCENT-R2-REVALIDATED-VERDICT.txt 4,259 B R2 重验 PASS verdict
runtime\e1-BASE-QUIESCENT-R2-CAPTURE-FINGERPRINTS.txt 5,788 B R2 逐文件 SHA-256
runtime\e1-BASE-QUIESCENT-R3-VERDICT.txt           5,051 B   R3 封印 baseline verdict
runtime\e1-run3.metadata.json                      2,440 B   显式 baseline binding 实例
runtime\e1-run3.session.lock.json                    917 B   exact session lock 实例
runtime\e1-run2.session.lock.json                    624 B   run2 lock（历史）
runtime\e1-run3-BINDING-REFUSED.txt                1,537 B   绑定门禁拒绝记录
```

另：`evidence\desktop\before\`（5 files / 121,692 B，Desktop 安装前取证）与
`evidence\desktop\archive\*.sha256.txt` 一并保留。

### 3.3 仍然保留的脚本

**通用 helper（长期价值）**

```
scripts\read-asar.mjs                                   5,279 B   解 ASAR（无需 Electron、不解包）
scripts\decode-session-log.mjs                          2,237 B   session log 解码
scripts\analyze-session-record.mjs                      2,197 B   session 记录分析
scripts\desktop-runtime-experiment\session-summary.mjs  2,231 B   session 事件直方图
scripts\desktop-runtime-experiment\capture-shared-state.ps1 13,023 B  $DSH_HOME 状态指纹
scripts\desktop-runtime-experiment\compare-captures.ps1  7,737 B   capture 差异比较
scripts\desktop-runtime-experiment\capture-guard.ps1    22,414 B   fail-closed 取证（docs/10 §2 的实现）
```

**E1 / Control B orchestrator + runbook + selftest（保留为可复现来源）**

```
capture-desktop-runtime.ps1、detect-runtime-test-session.ps1、capture-run-config.ps1、
e1-capture.ps1、capture-e1-quiescent-baseline.ps1、new-e1-run.ps1、
revalidate-e1-quiescent-baseline.ps1、control-b-prep.ps1、
capture-guard.selftest.ps1、e1-binding.selftest.ps1、compare-validator.regression.ps1、
e1-run3-runbook.md、control-b-runbook.md
```

删除的只有 `e5-capture.ps1`（E5 从未执行）。

## 4. 全部长期文档仍有效

| 文档 | 状态 |
|---|---|
| `docs\00`–`docs\10` | 全部有效；`00` §0.1 已更新为**双 anchor 版本表**；新增 `09`（Desktop）、`10`（方法论） |
| `docs\README.md` | 索引已加入 09 / 10，并新增"快速查询"条目 |
| `README.md`（根） | 新增第 8 节"官方 Desktop / mixed-version 兼容性（CLOSED）" |
| `docs\03` §11.5 | 新增 Desktop 线阶段表与 3 条长期结论 |
| `docs\07` §10 / `docs\08` §11 | 新增 Desktop 视角的交叉引用（不重复正文） |
| `docs\09` §Evidence | 已更新：原始 stage 取证的指针改为**归档 zip** |

**唯一的引用变化**：`docs\09` 的"原始 stage 取证"由逐个目录改为指向归档 zip；
其余文档引用的都是**松散保留**的文件，指针未断。

## 5. real `$DSH_HOME` 未因清理被修改

[FACT] 清理只作用于 `D:\Projects\dsh-test\evidence\`、`D:\Projects\dsh-test\scripts\` 与
`D:\Projects\dsh-desktop-*` 目录；`C:\Users\user02\.dsh` **未被任何删除命令触及**。

验证（清理后即时读取）：

| 项 | 值 |
|---|---|
| `settings.yaml` | 52 B |
| `settings.yaml.imported` | 52 B，mtime `2026-10-05 12:29:50`（未变） |
| `storages\workspace.json` | 3681 B，mtime `2026-10-05 16:00:07`（未变） |
| run3 v4 session | 16364 B `64B4257A37C14035792E0806679A86EC19C683D0E2A9A477060E6621D5777EDB`（未变） |
| 研究会话 | `session-665e3202…`（本会话自身，清理期间继续增长，属预期） |

## 6. 仍然存在的（有意保留，不属于本次清理范围）

* `evidence\logs\`（2.7 MB，npm 事故日志，**不可再生**）
* `evidence\install-snapshots\`、`evidence\config-dumps\`
* `experiments\`（18.9 MB，他线实验记录，其中 `browser-probe\captures\` 占多数）
* `archive\`（6.0 MB）
* `evidence\desktop\before\`（Desktop 安装前取证）

> 这些属于**其他研究线**，本轮不动。若将来要清理，应各自单独出 manifest。

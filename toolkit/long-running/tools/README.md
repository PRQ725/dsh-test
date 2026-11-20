# tools/ — Long-running 结构检查器（T1）

> 只读检查器：**不写任何文件**（除 stdout/stderr），只验证「结构 / 必需字段 / 内部引用」，
> **不**验证业务正确性，也**不**构成人类验收。
> 契约来源：`v0.2/README.md`（Step 10.5/10.6）、`v0.2/SKILL.md`、`v0.2/templates/*.md`。

## 1. 快速自测（安装后第一件事）

```bash
node tools/check-longrunning.mjs --self-test
# 期望：T1 self-test: 30 passed, 0 failed
```

## 2. 对一个实例跑检查

```bash
# 完整就绪检查（读实例根目录下的 GOAL.md 及其引用产物）
node tools/check-longrunning.mjs --instance-root <实例目录>

# 只按 GOAL 契约检查（等价于 --instance-root，但显式指定 GOAL.md）
node tools/check-longrunning.mjs --goal-contract <实例目录>/GOAL.md

# 弱检查：只验目录结构，不读 GOAL.md（会打印 CONTRACT NOT CHECKED）
node tools/check-longrunning.mjs --instance-hygiene <实例目录>

# 机器可读输出
node tools/check-longrunning.mjs --instance-root <实例目录> --json
```

退出码固定：**0 = PASS（机械项全过）· 1 = FAIL（逐条打印理由）· 2 = ERROR（调用不可用）**。
`UNKNOWN` 与 `PENDING`/`POLICY` 属于**非 PASS**，不得被当作通过。

## 3. 接入你自己的项目（三步）

1. **放置**：把整个 `long-running/` 目录复制到项目里（例如 `<repo>/tools/long-running/`）。
2. **改根路径**：编辑 `tools/check-longrunning.mjs` 顶部的
   `export const REPO_ROOT = path.resolve(HERE, '..');` ——
   改为**项目根**（例如 `path.resolve(HERE, '..', '..', '..')`）。实例的 `Instance root` / `Report path`
   都是相对这个根的路径。
3. **建实例**：新建一个实例目录，从 `v0.2/templates/` 复制 `GOAL.md` / `PLAN.md` / `STATE.md` / `EVALUATION.md` / `FINAL-REPORT.md`，
   填满 `UNFILLED` 字段后再跑 `--instance-root`。**未填完就不要跑**——检查器会如实报 FAIL。

## 4. 检查器会查什么

- GOAL/PLAN/STATE/FINAL-REPORT 的**字段齐全**与 `UNFILLED` 残留；
- `Budget` 语义：Native `maxGoalRounds` 是唯一 `HARD`；逻辑预算必须是 `SOFT logical: N`（**禁止** `HARD N logical`）；
- 授权字段：Planning Authorization / Execution Authorization 的取值合法；
- 终态字段：FINAL-REPORT 不得是 `DRAFT`；`Acceptance status` 只能是 `pending|accepted|rejected`；
- 内部引用（Evaluator 路径、报告归属、实例根路径）可解析。

## 5. 它**不**会查什么（必须由人类或上游流程负责）

- 目标是否值得做、计划是否合理、证据是否真实；
- 权限边界（是否越界写入）、计划批准、预算是否被真正执行；
- 业务正确性、代码质量、验收结论。

> 记住 v0.2 的原话：机械通过只证明「结构成立」，是**必要而非充分**条件；人类门永远输出 `PENDING`/`POLICY`。

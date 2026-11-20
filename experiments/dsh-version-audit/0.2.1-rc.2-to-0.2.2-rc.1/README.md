# DSH `0.2.1-rc.2` → `0.2.2-rc.1` — Cross-Version Knowledge Audit

**状态：COMPLETE（2026-11-08），带明确 UNKNOWN**
**类型：RESEARCH / AUDIT** — 不是开发，不是 Toolkit 升级，不是新实验。

本目录把本仓库既有 DSH 运行机制认知、Long-running Toolkit v0.2 的机制前提，与**本机已安装并
正在服务的 `0.2.2-rc.1`** 做一次对照审计，并把需要修正的地方回流到长期笔记。

基线是 **`0.2.1-rc.2`**（本仓库 2026-10-19 审计的记录版本），不是上一版 changelog 的起点。

---

## 先读什么

| 想了解 | 读 |
|---|---|
| 结论与最终判定 | [`FINAL-REPORT.md`](FINAL-REPORT.md) |
| K01–K45 逐条差异与落点 | [`KNOWLEDGE-DELTA.md`](KNOWLEDGE-DELTA.md) |
| 实际跑了哪些只读检查、哪些没验证 | [`RUNTIME-VERIFICATION.md`](RUNTIME-VERIFICATION.md) |
| 官方发布原文（含 rc.3/rc.4/rc.5） | [`evidence/official-release-notes.md`](evidence/official-release-notes.md) |
| 运行时身份与机制常量 | [`evidence/runtime-identity.txt`](evidence/runtime-identity.txt) |
| 机器可复现的包差异 | [`evidence/package-diff.json`](evidence/package-diff.json) · [`evidence/diff-summary.json`](evidence/diff-summary.json) |

---

## 核心结论（一句话版）

- **全局 npm CLI 与当前 active session = `0.2.2-rc.1`；Desktop bundled runtime 仍 `0.2.0-rc.2`，未升级。**
- **`exit_plan_mode` 改为渐进披露** —— 这是唯一直接推翻旧笔记机制陈述的变化（"工具目录恒定"须限定）。
- **两处 `CORRECT` 级别的事实错误**：`fs-observation-policy` **默认关闭**（不是"默认要求先读"）、
  `AGENTS.md` 预算改为**按链独立**（不是单条消息单预算）。
- **工具执行平面重构**：`tools.mode` / `DSH_TOOLS_MODE` 彻底移除，改为 executor 插件 + 按 step 条件启用。
- **`apply_patch` 新增但默认关闭**；且其 README 与出厂 patch **互相矛盾**（记为 `DISCREPANCY`）。
- **session format 仍为 v4**，`0.2.0 → 0.2.2` **不在** `[v3 → v4]` 断裂面上。
- **Goal / round driver = NOT RUN**（按任务边界不创建、不 arm）；所有 driver 结论是源码/官方文档级。

---

## 安全边界（本轮实际遵守）

- 只写 `experiments/dsh-version-audit/0.2.1-rc.2-to-0.2.2-rc.1/` 与本轮明确要更新的既有笔记。
- 不升级、不降级、不安装、不改 `browser-lab` profile、不改全局配置、不动 `toolkit/long-running/v0.2/`。
- **不创建 / 不 arm / 不 resume Goal**；不启动自动续轮；不启 Ralph。
- 不启动第二个 host；不重启当前 host。
- 未做破坏性操作；未做 token-heavy 实验。
- 本轮 runtime 策略：`danger-full-access` / `never`（**用户侧设定**，本 agent 未修改、未请求提权）；
  所有写入仍限于本 workspace。

---

## 证据等级约定

- `FACT`：本次直接读到的源码/patch 原文，或本机命令实际输出。
- `DOC`：官方发布块 / 包 README 原文（文档级，未必等于本机生效值）。
- `DISCREPANCY`：文档与本机 patch 冲突；**以 patch 为准**。
- `INFERENCE` / `UNKNOWN`：同全库约定。
- `NOT RUN`：需要运行期才能验证，但按任务边界本轮未执行。

---

## 目录内容

```text
.
├── README.md                  this file
├── KNOWLEDGE-DELTA.md         K01-K45, per-item delta + 落点
├── RUNTIME-VERIFICATION.md    只读检查清单 + 未验证项
├── FINAL-REPORT.md            审计结论
└── evidence/
    ├── official-release-notes.md   rc.3 / rc.4 / rc.5 / 0.2.2-rc.1 原文摘录
    ├── runtime-identity.txt        anchor / Cordis / node / 机制常量
    ├── cache-inventory.json        npm 缓存两版本清单（321 包）
    ├── package-diff.json           逐文件 sha256 差异
    ├── diff-summary.json           去噪后的真实变更
    ├── cache-inventory.mjs         只读：扫 npm cache index-v5
    ├── analyze-diff.mjs            只读：解 tarball + 逐文件 hash 对比
    ├── summarize-diff.mjs          只读：剔除 package.json 版本噪声
    ├── show-doc-diff.mjs           只读：逐包 README 行级 diff
    └── extract-tgz.mjs             只读：单 tarball 解包
```

> `evidence/work/`（≈169 MB，294 个包 × 2 个版本的解包树）是可再生的中间产物，
> 体积大且**不是证据本身**（证据是 `package-diff.json` 的 hash 对比）。需要复现时按
> `RUNTIME-VERIFICATION.md` §3 重跑即可；若本目录需要瘦身，可先删 `work/`。

---

**STOP FOR HUMAN REVIEW.**

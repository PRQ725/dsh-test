# DSH 0.2.0-rc.2 → 0.2.1-rc.2 — Cross-Version Knowledge Audit

**状态：COMPLETE / CLOSED（2026-10-19，带明确 UNKNOWN）**
**类型：RESEARCH / AUDIT** — 不是开发，不是 Toolkit 升级。

本目录是对本仓库既有 DSH 运行机制认知、实验结论与 Long-running Toolkit v0.2 的一次跨版本兼容性审计。
审计基线是 0.2.0-rc.2 的冻结记录，验证环境是当前 0.2.1-rc.2 安装。

---

## 先读什么

| 想了解 | 读 |
|---|---|
| 结论与最终判定 | [`FINAL-REPORT.md`](FINAL-REPORT.md) |
| K01–K24 逐条差异 | [`KNOWLEDGE-DELTA.md`](KNOWLEDGE-DELTA.md) |
| 知识整合与结案记录（改了哪些旧笔记） | [`KNOWLEDGE-INTEGRATION-REPORT.md`](KNOWLEDGE-INTEGRATION-REPORT.md) |
| 实际运行环境、工具、安全测试 | [`RUNTIME-VERIFICATION.md`](RUNTIME-VERIFICATION.md) |
| v0.2 十项契约的兼容状态 | [`TOOLKIT-COMPATIBILITY.md`](TOOLKIT-COMPATIBILITY.md) |
| 读了哪些文件、证据等级与局限 | [`EVIDENCE-INDEX.md`](EVIDENCE-INDEX.md) |
| 原始数据与可复现脚本 | [`evidence/`](evidence/) |

---

## 核心结论（一句话版）

- **CLI 与 active session = 0.2.1-rc.2；Desktop = 0.2.0-rc.2，未升级。**
- **0.2.1 是 rc.1 的大功能线 + rc.2 的 V4.1 展示适配。**
- **Toolkit v0.2 = COMPATIBLE WITH CAVEAT**，10 项契约均未被直接否定。
- **1017 badge 是客户端展示，不是模型权重证明；实际路由版本 = UNKNOWN。**
- **Goal live test = NOT RUN**（按任务禁止）；所有 driver 结论是源码/官方文档级。
- **安装完整性 = PARTIAL**：包齐全、可加载；node-pty ConPTY spawn 失败，根因 UNKNOWN。

---

## 安全边界（本轮实际遵守）

- 只写 `experiments/dsh-version-audit/0.2.0-rc.2-to-0.2.1-rc.2/`。
- 不修改 `toolkit/long-running/v0.2/`（哈希 8/8 未变）、`RELEASES.md`、`RELEASE-REPORT.md`、
  rc1/rc2/rc3 记录、v0.1 Pilot、任何旧证据。
- 不创建 / arm / resume Goal；不启动 Ralph；不自动续轮。
- 不修改 Profile / Provider / API Key / PATH / npm 安装；不申请 `danger-full-access`；不安装依赖。
- 文件权限维持 `workspace-write`，审批维持 `ask`。

---

## 证据等级约定

- `FACT`：本次直接读到的源码/文档原文，或当前运行时实际观测。
- `INFERENCE`：由事实推导，推理步骤可能错。
- `UNKNOWN`：无法独立验证；不猜。
- `NOT LIVE-TESTED IN THIS ROUND`：需要运行时才能验证，但本轮按约束未执行。

---

## 目录内容

```text
.
├── README.md                     this file
├── KNOWLEDGE-DELTA.md            K01-K24, per-item delta
├── RUNTIME-VERIFICATION.md       live environment + safety probes
├── TOOLKIT-COMPATIBILITY.md      10 contracts vs 0.2.1
├── EVIDENCE-INDEX.md             sources, layers, limits, reproduction
├── FINAL-REPORT.md               final audit report
└── evidence/
    ├── runtime-identity.txt
    ├── session-facts.json
    ├── session-current.jsonl.txt
    ├── tool-surface.txt
    ├── frozen-toolkit-sha256.txt
    ├── install-health.txt
    ├── official-release-notes.md
    ├── cache-inventory.json
    ├── package-diff.json
    ├── *.mjs                     read-only extraction/diff scripts
    └── upstream/                 key 0.2.0 / 0.2.1 package sources
```

---

## 复现

见 [`EVIDENCE-INDEX.md`](EVIDENCE-INDEX.md) §3。所有脚本只读；npm cache 中的 tarball 通过 integrity
定位，无需联网、无需安装。

---

**STOP FOR HUMAN REVIEW.**

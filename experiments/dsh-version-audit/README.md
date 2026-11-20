# experiments/dsh-version-audit — 跨版本知识审计线

这里的每个子目录是**一次按版本对的只读知识审计**：把本仓库既有的 DSH 机制认知、实验结论与
Long-running Toolkit 的机制前提，对照**本机实际安装/运行的某个 DSH 版本**做一次核对，并把需要
修正的地方回流到 `docs/` 与根 `README.md`。

**它不是实验线**（没有 hypothesis / run / 产物），也**不是 Toolkit 版本**（不发布、不升级）。
审计自己的产出只有：差异清单、只读验证记录、结论、以及 `evidence/` 里机器可复现的对比数据。

| 版本对 | 状态 | 结论 | 入口 |
|---|---|---|---|
| `0.2.0-rc.2` → `0.2.1-rc.2` | CLOSED（2026-10-19） | Toolkit v0.2 **COMPATIBLE WITH CAVEAT**；K01–K24 | [`0.2.0-rc.2-to-0.2.1-rc.2/`](0.2.0-rc.2-to-0.2.1-rc.2/README.md) |
| `0.2.1-rc.2` → `0.2.2-rc.1` | CLOSED（2026-11-08） | 同上，新增 2 条 caveat；K01–K45 | [`0.2.1-rc.2-to-0.2.2-rc.1/`](0.2.1-rc.2-to-0.2.2-rc.1/README.md) |

## 每个审计目录的固定形状

```text
<from>-to-<to>/
├── README.md                 范围、安全边界、证据等级、目录说明
├── FINAL-REPORT.md           判定 + 必须修正项 + 保留的 UNKNOWN
├── KNOWLEDGE-DELTA.md        K01..Kn 逐条差异 + "处理" + "落点"
├── RUNTIME-VERIFICATION.md   实际跑了的只读检查 / 明确没验证的项
├── TOOLKIT-COMPATIBILITY.md  （0.2.1 审计有；0.2.2 的对应内容并入 FINAL-REPORT §4）
└── evidence/                 官方发布原文、运行时身份、包对比数据、只读脚本
```

## 纪律

- **只读**：审计不改安装、不改 profile、不改全局配置；不改 Toolkit 发布目录。
- **不做 live 机制测试**：需要运行时才能定的（Goal 生命周期、越界写拒绝等）标
  `NOT RUN` / `UNKNOWN`，**不用推断冒充事实**。
- **版本对必须串起来读**：官方 changelog 常写"自上一个 rc 以来"，中间 rc 的条目会被跳过。
  `0.2.1-rc.2 → 0.2.2-rc.1` 就必须同时读 `rc.3` / `rc.4` / `rc.5`。
- **落点写回既有笔记**：审计目录不复制 `docs/` 的正文，只在 `KNOWLEDGE-DELTA.md` 里指明改哪里。
- **物理体积**：`evidence/work/` 是解包中间产物（可删可重生），**不是证据本身**；
  证据是 `package-diff.json` 里的逐文件 SHA-256 对比。

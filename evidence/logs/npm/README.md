# evidence/logs/npm — 2026-09-23 DSH 全局升级事故的 npm 原始日志

> **本目录存放原始、不可再生的 evidence。**
> 这些文件是 npm 的 debug log **原件拷贝**，**未被改写、未被"整理"、未被二次加工**。
> 任何摘要、解读、结论都**不属于本目录**，应放在 `experiments/` 或 `docs/`。

---

## 1. 归档了什么

| 文件（保留 npm 原文件名） | 对应阶段 | 大小 | SHA-256 |
|---|---|---|---|
| `2026-09-23T04_00_54_627Z-debug-0.log` | **第一次升级：rc.1 → rc.2** 的 `npm install -g` | 1,211,451 B | `BE2910A84EABDCEC2561D27F7077F5381A5E9BD1E72978A2D4B8A98C552D913E` |
| `2026-09-23T04_38_36_190Z-debug-0.log` | **回滚尝试：安装 rc.1**（失败） | 1,084,688 B | `225D598E8C71C22586A210AEEC844752540CE313FD17C79FC81C0EDFA7181293` |
| `2026-09-23T05_11_08_017Z-debug-0.log` | **最终恢复：安装 rc.3**（成功） | 452,415 B | `9736C6C2216AE315460A29044F19C24613E85F7CDF064A12E77E7C2F3E8B793D` |

每份日志的自身标识（`verbose title` / `verbose argv`）：

```text
2026-09-23T04_00_54_627Z-debug-0.log
  6 verbose title npm install @deepseek-ai/dsh@0.1.5-rc.2
  7 verbose argv "install" "--global" "@deepseek-ai/dsh@0.1.5-rc.2"

2026-09-23T04_38_36_190Z-debug-0.log
  6 verbose title npm install @deepseek-ai/dsh@0.1.5-rc.1
  7 verbose argv "install" "--global" "@deepseek-ai/dsh@0.1.5-rc.1"

2026-09-23T05_11_08_017Z-debug-0.log
  6 verbose title npm install @deepseek-ai/dsh@0.1.5-rc.3
  7 verbose argv "install" "--global" "@deepseek-ai/dsh@0.1.5-rc.3"
```

**注意**：文件名中的时间戳是 **UTC**（`Z`），本机为 **UTC+8**。
`04_00_54Z` = 本地 `2026-09-23 12:00:54`；`04_38_36Z` = 本地 `12:38:36`；`05_11_08Z` = 本地 `13:11:08`。

---

## 2. 来源路径

```
C:\Users\user02\AppData\Local\npm-cache\_logs\<原文件名>
```

即 npm 的 `cache/_logs` 目录（`npm config get cache` → `C:\Users\user02\AppData\Local\npm-cache`）。

复制方式：**纯文件系统 `Copy-Item`**，未执行任何 npm 命令，未改写内容。复制后源/目标 SHA-256 已逐一比对一致。

---

## 3. 为什么必须归档（不可再生 + 随时可能被删除）

### 3.1 不可再生

故障期的**安装树已被 rc.3 覆盖**：

- `…\npm\node_modules\@deepseek-ai\dsh` 的 `CreationTime` = `2026/9/23 13:11:25`，即 rc.3 安装时刻。
- 全局 npm 安装**不产生 lockfile**（`node_modules\package-lock.json` 与 `.package-lock.json` 均不存在），因此**没有第二份依赖图记录**。

⇒ rc.1 / rc.2 时期的真实依赖树**已无任何其它副本**。这三份日志是**唯一**的第一手证据。

### 3.2 随时可能被 npm 自动裁剪

```
npm config get logs-max   →  10
_logs 目录实际文件数       →  13
```

npm 的日志保留上限是 **10**，而实际已有 **13** 个文件（超出 3 个）。
**下一次任何 `npm` 命令都可能按时间顺序删除最旧的文件**——而最旧的正是 `2026-09-23T04_00_54_627Z-debug-0.log`（rc.2 首次升级日志）。

这就是本轮归档的首要原因：**在裁剪发生前把原件移出风险区**。

> [RECOMMENDATION] 归档副本在知识库内是**只读历史证据**；不要因为"现在 rc.3 已经好了"就删除。

---

## 4. 哪些结论来自这些日志

只有以下事实**直接**来自本目录的日志（其余均属推论，见 `EXCERPTS-2026-09-23.md` 与 incident 记录）：

| 结论 | 出处 |
|---|---|
| 三次安装的**精确命令与目标版本** | 三份日志的 `verbose argv` |
| rc.1 顶层声明 sibling 为 `^0.1.5-rc.1`；rc.2 为 `^0.1.5-rc.2`；rc.3 为 `^0.1.5-rc.3` | `placeDep … want: …` 行 |
| rc.1 / rc.2 的 `^0.1.5-rc.1` / `^0.1.5-rc.2` **实际解析到 `0.1.5-rc.3`** | `placeDep … CONFLICT for: … want: ^0.1.5-rc.1` + placed `@0.1.5-rc.3` |
| rc.1 / rc.2 的**厂商包 caret 也向更高版本解析**（`cordis ^4.0.2→4.0.4`、`hmr ^1.0.17→1.0.19`、`include ^1.0.7→1.0.9`、`js-yaml ^4.2.0→4.3.2`） | `placeDep … OK for: … want: …` 行 |
| rc.3 改为**精确锁**（`cordis 4.0.2`、`hmr 1.0.17`、`include 1.0.7`） | rc.3 日志 `want: 4.0.2` 等 |
| ERESOLVE 真实冲突**事件数 280**（rc.1 / rc.2 各），rc.3 = **0** | `warn ERESOLVE overriding peer dependency` 计数 |
| 冲突类型为 **peer dependency**，对象 `@deepseek-ai/cordis`，`spec: '4.0.2'`，`error: 'INVALID'` | ERESOLVE 块正文 |
| npm 12 **阻止 lifecycle scripts**：rc.1 回滚 6 条（5 个唯一包）/ rc.3 5 条 | `warn install-scripts` 块 |

**不来自**这些日志的（属推论或另证）：故障的直接解析路径、Loader 为何找不到 `dsh-sandbox-local`、rc.3 恢复的**决定性**因素。

---

## 5. 阅读与检索建议（不要通读 2.7 MB）

```powershell
# 只要关键行 → 直接看提炼版
Get-Content .\EXCERPTS-2026-09-23.md

# 在原件里定位（示例）
$E = 'D:\Projects\dsh-test\evidence\logs\npm'
Select-String -Path "$E\2026-09-23T04_38_36_190Z-debug-0.log" -Pattern 'ERESOLVE overriding peer dependency' |
  Select-Object -First 1
Select-String -Path "$E\2026-09-23T04_38_36_190Z-debug-0.log" -Pattern 'want: \^0\.1\.5-rc\.1'
Select-String -Path "$E\2026-09-23T05_11_08_017Z-debug-0.log" -Pattern 'warn install-scripts'
```

**计数口径提醒**：日志中带 `ERESOLVE` 字样的**行数**是 12600，但真实冲突**事件数**是 280（每个事件块 45 行）。
引用时**必须写清是哪一个口径**，否则会夸大 45 倍。

---

## 6. 纪律

1. 本目录文件**不得改写、不得重排、不得"整理成更易读的日志"**。要解读请写进 `experiments/` 或 `docs/`。
2. 本目录**不是**结论存放处。结论的权威位置是 `experiments/dsh-install/2026-09-23-dsh-global-upgrade-rc1-to-rc3-incident.md` 与 `docs/08-dsh-installation-and-upgrade.md`。
3. 引用时请连同 **SHA-256** 一起引用，便于确认引用的是同一份原件。

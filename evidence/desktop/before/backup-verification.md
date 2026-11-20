# P2 备份验证记录 —— Desktop 安装前完整备份

- **执行时间**：2026-10-04 20:19:10 – 20:19:23（本地）
- **源**：`C:\Users\user02\.dsh`（`$DSH_HOME`）
- **备份根**：`C:\Users\user02\dsh-desktop-preinstall-backup-20261004-201910`
- **内容落点**：`<backup>\dsh-home\`（镜像 `$DSH_HOME`）+ `<backup>\MANIFEST.md`

---

## 1. 规模

| | 文件数 | 字节 |
|---|---|---|
| 源 `$DSH_HOME` | 226 | 161,026,172 |
| 备份 `<backup>\dsh-home` | 226 | 161,026,172 |
| 备份根（含 MANIFEST） | 227 | 161,069,291 |

**逐文件相对路径覆盖率核对：源有而备份缺 = 0** ✅

---

## 2. 方法

```powershell
robocopy "C:\Users\user02\.dsh" "<backup>\dsh-home" /E /XJ /COPY:DAT /R:1 /W:1
```

- `robocopy exit code = 1` → **成功**（0/1/2/3 均为成功码）。
- **`/XJ` 是关键**：排除 junction。`$DSH_HOME\profiles\node_modules`（244 个 `@deepseek-ai/*` junction）指向**全局 DSH 安装**（222 MB）；
  若不排除，备份会被动把整个 global install 复制一份，且造成"备份含安装"的语义混淆，并使后续 filesystem diff 失真。
- `/COPY:DAT`：复制 Data + Attributes + Timestamps（**不复制 ACL**）。

---

## 3. 完整性验证

### 3.1 关键文件 SHA-256（源 = 备份）

| 文件 | 判定 | SHA-256 |
|---|---|---|
| `AGENTS.md` | **MATCH** | `DFBC51358430BDC0091658C62925BFA9385621F6E07197BFADDC7B19A043872C` |
| `settings.yaml` | **MATCH** | `7A7CCB3CD8576239B788504A80EB5821140B52CC0FBEBDA3692B3CBE47685D52` |
| `.credentials.yaml` | **MATCH** | `C28BC57922E515EE7185746D08197FF5EA4B13BC6DC77C81AD8E9DBFB0C91385` |
| `.anonymous-user-id` | **MATCH** | `71A598EF01C8D25F0D28CD2E0531F65C87174F45773A72EE033849FDBF7B049C` |

> ⚠️ `.credentials.yaml` **已复制进本机私有备份目录**。**其内容从未、也不会写进知识库**；此处只登记 size / mtime / hash。

### 3.2 全量哈希校验（226 个文件逐一比对）

```
已校验 = 226   不一致 = 2
```

**两个不一致的文件**：

| 文件 | 源 size / mtime | 备份 size / mtime |
|---|---|---|
| `sessions\--D-Projects-dsh-test--\session-665e3202-…\session.v3.jsonl.zstd` | 3,751,160 B / `20:19:23.019` | 3,739,912 B / `20:19:10.558` |
| `storages\session_projcache\sessions\session-665e3202-….json` | 55,811 B / `20:19:21.657` | 55,222 B / `20:19:04.053` |

### 3.3 原因：**活文件**（不是备份失败）

- 这两个文件都属于 **`session-665e3202-…`，即执行本次备份时的"当前会话"自身**。
- 备份窗口内它们**持续被追加**（13 秒内 session log 增长 11,248 B），因此源永远比快照新。
- 同一窗口内还有 `.dshw-usage.json`（Whale 账本，`20:18:37`）被写入。
- **判定：这是"非原子快照"的固有结果，不是复制错误。** 除这两个活文件外，**224 / 224 个静态文件哈希完全一致**。

---

## 4. ★ 由此得出的强制建议：P3 之后必须补一次 **P2b quiescent re-backup**

理由：本次备份是在 **browser-lab 仍在运行**时做的，因此：

1. 活文件（当前 session log + 投影缓存 + whale 账本）**在备份完成后仍在变化**。
2. 若安装 Desktop 前后要做 **filesystem diff**，就必须有一个**静止状态**的基线，否则：
   - diff 会把"本会话自己继续写入"误判为"Desktop 改了 session"；
   - 结论不可归因。

**P2b 步骤（必须在 P3 停掉全部 DSH 之后执行）**：

```powershell
# 1. 确认 3080 无监听、无 dsh/MCP 进程
# 2. 再取一份静止快照
robocopy "$DSH_HOME" "<new-backup>\dsh-home-quiescent" /E /XJ /COPY:DAT /R:1 /W:1
# 3. 对全部文件做 SHA-256 并与本次基线比对，生成"差异=0"的证明
```

> **P2 本身仍然有效且必要**：它已捕获**除当前会话活文件之外的全部状态**，可作为灾难恢复的起点。
> 它**不足**以充当 diff 基线 —— 这一点必须写清，不能含混。

---

## 5. 备份覆盖清单（[FACT] backup verified）

| 目标 | 覆盖 |
|---|---|
| `$DSH_HOME/AGENTS.md` | ✅ |
| `$DSH_HOME/settings.yaml` | ✅ |
| `$DSH_HOME/profiles/`（含 `browser-lab` / `web` 全文件；`node_modules` 因 `/XJ` 只保留目录结构） | ✅ |
| `$DSH_HOME/storages/` | ✅ |
| `$DSH_HOME/sessions/`（133 MB） | ✅ |
| `$DSH_HOME/.credentials.yaml` | ✅（仅本机私有备份目录） |
| `$DSH_HOME/.anonymous-user-id` | ✅ |
| `$DSH_HOME` 根 Whale 状态（`.dshw-*.json`、`whale-audio/`、`whale-bubble-imgs/`、`whale-roles/`） | ✅ |
| `$DSH_HOME/attachments/`（19.6 MB） | ✅ |
| `$DSH_HOME/llm-deepseek/` | ✅ |
| **`profiles/node_modules` 的 junction 目标内容** | ❌ **刻意排除**（见 §2，指向 global install） |

**证据等级**：**[FACT] backup verified**（含逐文件覆盖率核对 + 224/224 静态文件哈希一致 + 2 个活文件已定位原因）。

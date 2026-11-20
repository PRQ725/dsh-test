# 10 — 实验方法论（quiet baseline · fail-closed 取证 · PowerShell 5.1 陷阱）

> 本文只放**跨项目可复用的实验/工具方法论**。
> 产品架构结论在 `09-dsh-desktop.md` 等文档；本文**不重复**产品结论。
>
> 来源：2026-10-05 Desktop / mixed-version 研究支线（E1 run1–run3 + Control B）。
> 这些教训是"踩过一次"得来的，属于**长期知识**。

---

## §1 Quiet baseline：什么时候才算真的"静止"

[FACT] 一个可用于**严格单变量归因**的 quiescent baseline，必须同时满足：

1. Desktop **OFF**（含托盘 / 后台）；
2. CLI / Web host **OFF**；
3. MCP server 进程 **OFF**；
4. 相关端口空闲（本项目用 3080 / 3180）；
5. **研究 session 自身也不能继续写**。

第 5 条最容易被忽略，而它恰恰是本项目第一次翻车的原因。

[FACT] 实证：R2 baseline 采完后研究 host 被重启并继续对话，随后 Desktop 才启动。
分类器记录到 `--D-Projects-dsh-test--\session-665e3202…` events 4793 → 5059。
于是 baseline → Stage A 区间内**不止 Desktop 一个自变量**，该 stage 的归因作废。

> 结论：**baseline 一旦采完，任何"继续用同一个研究 session 聊天"的行为都会让它
> 不再适用于严格单变量归因。** 这不是 bug，是实验设计的硬约束。

[RECOMMENDATION] 若要严格归因，把 baseline 与 stage 之间的人工动作放在**同一个外部
PowerShell 窗口**里连续做完，期间不重启任何 host、不重开 Web UI。

## §2 Fail-closed 取证

[FACT] capture wrapper 必须把下列情况**一律判为不可用**，绝不能解释成 clean：

| 情况 | 必须的处置 |
|---|---|
| child script throw / 未运行 | FAIL，不产出结论 |
| sentinel artifact 缺失或为空 | FAIL |
| section 被 SKIPPED（manifest 缺失） | diff INVALID |
| diff 不完整（section 缺失、计数块不全） | diff INVALID |
| 关键 sanity 为 0（0 sessions / 0 tracked rows） | FATAL |
| 只有 exit code 0 而没有任何产物校验 | **不算通过** |

[FACT] 反面教材（本项目 R1）：wrapper 把子进程输出重定向到一个**尚未创建**的目录，
重定向目标打不开 ⇒ **子进程根本没运行**；wrapper 仍无条件打印
`[PASS] capture written`；compare 找不到 manifest ⇒ 每节 SKIPPED ⇒ 空 diff ⇒
verdict 把"无数据"读成"无变化" ⇒ **FALSE PASS**。

[FACT] 修法要点：

* 任何 redirection 之前**先创建目标目录**；
* 子进程调用包在局部 `$ErrorActionPreference='Stop'` 里并捕获异常；
* 校验 redirection log 本身是否存在（它证明 child 真的跑过）；
* 校验每个 sentinel 存在且非空；
* 出错时**不要创建 stage 目录**，改写一个明确的 refusal 记录，避免半成品被误读为证据。

## §3 Zero-diff 是合法结果

[FACT] `compare-detail.csv` 只记录**发生变化的条目**，因此"零差异"时它是
**BOM-only 空文件**（Excel/CSV 一条表头都没有）。

[FACT] 反面教材（本项目 R2）：validator 用"文件为空"直接判 diff INVALID ⇒
**FALSE FAIL**，把"环境确实静止"这一最想要的结果判成失败。

[RECOMMENDATION] 正确判据是**一致性检查**，而不是"文件空不空"：

```
expectedDetailRows = Σ 所有必需 section 的
                     (ADDED + DELETED + CONTENT-CHANGED + MTIME-ONLY)
要求 detailRows == expectedDetailRows
```

两个方向都要查：计数 > 0 而 detail 为空 ⇒ INVALID；计数全 0 而 detail 有行 ⇒ INVALID。

[FACT] 测试陷阱：当时 selftest 的 stub **手写了一个 CSV 表头行**，于是"0 行"这条断言
在**真实 producer 从不产出的文件形态**上通过了。**validator 测试必须跑真实 producer 的
真实输出**，不要用手写的近似产物替代。

## §4 显式绑定优于推导

[FACT] 反面教材（本项目 run2）：脚本把 Stage A 的前序目录**推导**为
`e1-<RunName>-BASE`（该目录从不存在），而同一脚本的变化分类器却用另一个真实 baseline
⇒ 同一份报告里出现**两个不同的 baseline**，diff 从未真正执行。

[RECOMMENDATION]：

* 一个 run 的路径只在**一处**声明（run metadata 文件），所有 stage 从它读取；
* baseline 必须**显式绑定**，并且"缺失 / 未封印 / 属于别的 run / 封印后被改动"**都 STOP**；
* 不允许任何 `e1-<RunName>-BASE` 式的隐式推导。

## §5 PowerShell 5.1 陷阱（本项目实际踩到）

| # | 陷阱 | 后果 | 对策 |
|---|---|---|---|
| 1 | 变量名**大小写不敏感** | `$CMP`（路径）被 `$cmp`（结果对象）覆盖；`$H` 被 `$h` 覆盖，产生假 ABSENT | 避免只靠大小写区分；命名加语义后缀 |
| 2 | 自动变量**只读** | `$home = …` 静默失败，sanity 去读了 `C:\Users\user02` | 不要用 `$home`/`$host`/`$input`/`$error`/`$pid` 等；用 `$homeFp` 之类 |
| 3 | `Set-Content -Encoding UTF8` **写 BOM** | 运行时用裸 `JSON.parse` 读 `workspace.json` ⇒ `Unexpected token '\uFEFF'`，registry/controller 全部 `pending` | 给机器读的 JSON 必须**无 BOM**（`UTF8Encoding($false)`）；本项目真实文件本来也无 BOM |
| 4 | `*>` 重定向目标目录**必须预先存在** | 目录不存在 ⇒ 异常、child 未运行（见 §2） | 先 mkdir，再重定向 |
| 5 | 非终止错误默认**不中断** | fail-open | 局部 `$ErrorActionPreference='Stop'` + try/catch |
| 6 | 命令参数模式下 `expr.Count -gt 0` 被拆成多个参数 | 断言实际只测了 `.Count` | 把整个比较包进 `@(...)`，或用 helper 函数 |
| 7 | 无 BOM 的 `.ps1` 被按 ANSI 解析 | 非 ASCII（如 `—`）变 mojibake | 脚本内容保持纯 ASCII，或带 BOM 保存 |
| 8 | `Format-*` / `Select-Object` 混用管道 | `[exit code: 1]` 假失败 | 输出统一 `| Out-Host` |

## §6 主机探测不要自匹配

[FACT] 用 `CommandLine -match '<pattern>'` 探测"某 host 是否在运行"时，
**执行探测的那条命令自身**如果命令行里包含该 pattern，就会匹配到自己。
本项目实测出现过 `desktop = 2` 而真值为 `0`。

[RECOMMENDATION]：

* 对 **CommandLine 型**探测（如 `dsh-desktop-host`）排除自身与祖先进程；
* 对**身份型**探测（如 `node.exe` + `dsh/lib/bin.js`）**不要**排除祖先 ——
  服务当前研究 session 的 host 往往正是祖先，排除它会把 gate 变成**假 PASS**。
  **假 STOP 可接受，假 PASS 不可接受。**

## §7 隔离实验的最小 scaffold

[FACT] 用一个**隔离 `$DSH_HOME`** 跑新版本 runtime 时，只需要注入被测对象所需的最小内容
（本项目：session 副本 + 其 projcache + 一份最小 `storages\workspace.json`），
**不要**复制 credentials / token / 无关 session / 其他 profile / 设置历史。

[FACT] 隔离是否真的生效，要用"真实 home BEFORE/AFTER 内容 diff"来证明，而不是靠假设。
要求 `ADDED = 0`、`DELETED = 0`、`CONTENT-CHANGED = 0`。

[FACT] **观察者效应要单独说明**：如果测试是从一个运行中的研究 session 发起，
那么该 session 自身在窗口期内必然增长（本项目实测 host session
6,754,254 → 6,861,165 B）。把它与"隔离失败"区分开的方法是：
列出真实 home 在测试时间窗内**被写过的所有文件**，逐个归因。

## §8 证据分级纪律（复述，见 `docs/README.md`）

[FACT] 不要把"UI 看不到 X"直接写成"该版本完全不能处理 X"。
本项目正是如此：0.1.5 **文件系统层能枚举到 v4**，只是 **host listing 层**静默过滤了它。
差一层，结论就从"不支持该格式"变成"完全看不见该文件"——后者是错的。

[FACT] 同理，"某字段没了"与"某字段被改成另一个值"是两件事。
本项目 settings/locale 的正确表述是"**override 被移走 + 接收方不认识移走后的形态**"，
不是"值被改写"。

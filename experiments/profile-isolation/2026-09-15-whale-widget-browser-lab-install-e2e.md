# Whale Widget 在 browser-lab 上的正式安装与运行验证（Install + E2E）

> **Follow-up**：本文是 `2026-09-15-whale-widget-profile-isolation-prep.md`（read-only prep）的正式后续执行记录。
> prep 文档**未被覆盖或改写**，仍作为前置研究保留。
> 建立：2026-09-15（核对窗口 20:52–21:00）· DSH `0.1.5-rc.1` · Node `v24.20.0`

---

## 1. Objective

把 prep 阶段"**源码闭环 + 干净基线**"的静态结论，推进到 **profile-local 真实安装 + 真实运行**：

1. 补齐 `dsh plugin` 的 pnpm 前置；
2. 在 **`browser-lab`**（而非 `web`）profile 上安装 `dsh-whale-widget`；
3. 验证安装的**归属写入面**是否严格限定在该 profile；
4. 验证 **`web` 是否保持未挂载**；
5. 取得 runtime / UI 层面的端到端证据；
6. 用这次真实实践去**检验** prep 提出的 profile isolation 命题。

**非目标**：不验证 whale 的功能完备性；不研究 Browser MCP；不重做安装。

---

## 2. Preconditions

| 项 | prep 记录状态 | 本轮（follow-up）核对状态 |
|---|---|---|
| Node | `v24.20.0` | `v24.20.0` [FACT，本轮实测] |
| npm | `12.0.2` | `12.0.2` [FACT，本轮实测] |
| Corepack | 未记录 | `0.35.0` [FACT，本轮实测] |
| pnpm | **NOT FOUND** | **`12.4.2`** [FACT，本轮实测] |
| `browser-lab` bundles | `[dsh-base, dsh-web-app]` | **含 `dsh-whale-widget`** [FACT] |
| `web` bundles | `[dsh-base, dsh-web-app]` | **不含 whale**（哈希未变）[FACT] |
| `$DSH_HOME/cordis.patch.yml` | 不存在 | **仍不存在** [FACT] |

---

## 3. pnpm bootstrap

**人工执行**（本轮未重跑，仅记录 [FACT：命令输出证据]）：

```powershell
corepack enable
corepack install --global pnpm@latest
```

**本轮只读核对结果** [FACT：filesystem + 命令输出]：

```
pnpm --version        → 12.4.2
corepack --version    → 0.35.0
where.exe pnpm        → C:\Program Files\nodejs\pnpm
                        C:\Program Files\nodejs\pnpm.CMD
Get-Command pnpm      → C:\Program Files\nodejs\pnpm.ps1
```

> **[FACT] DSH plugin workflow 的 pnpm 前置已补齐。**
> 这解除了 prep §2.8 / §7.1 记录的唯一工具链阻塞（当时 `runPlugin` 会走 `ENOENT` 分支返回 127）。

**层级纪律（重要）**：

- **Corepack / pnpm 属于「工具链层」**：位于 `C:\Program Files\nodejs\`，是 Node 发行版级别的全局工具。
- **`dsh plugin` 的 profile 变更属于「DSH profile 层」**：位于 `$DSH_HOME/profiles/<name>/`。
- 两者**不是同一层**，本轮记录不得混写。pnpm 的安装**没有**改动任何 profile；profile 的改动**没有**依赖 Corepack 的常驻状态。
- 注：`corepack install --global pnpm@latest` 的产物落在 Node 安装目录（`C:\Program Files\nodejs\`），**不在** `$DSH_HOME` 内 [FACT：`where.exe` 输出]。

---

## 4. First install —— 裸包名解析到 `0.2.10`

**人工执行**（在关闭 DSH 进程后）：

```powershell
dsh plugin --profile browser-lab add dsh-whale-widget
```

**命令输出**（[FACT：人工命令输出证据]）：

```
Packages are hard linked from the content-addressable store to the virtual store.
Content-addressable store is at: C:\Users\user02\AppData\Local\pnpm\store\v11
Virtual store is at:             node_modules/.pnpm
Packages: +1
+
Progress: resolved 1, reused 0, downloaded 1, added 1, done

dependencies:
+ dsh-whale-widget ^0.2.10

Done in 1.5s using pnpm v12.4.2
```

### 4.1 ⚠️ 证据边界（必须说清）

- 这一段的 **`^0.2.10`** 只有**命令输出证据**。
- **磁盘上已不存在**任何能回溯到 0.2.10 的痕迹：`pnpm-lock.yaml` 现在只含 `0.3.0`（§5），`package.json` 现在是 `^0.3.0`，`node_modules` 里只有 0.3.0。
  → **中间态不可从当前 filesystem 复原**。这是本记录的证据边界，不得把 0.2.10 阶段写成"文件证据"。
- 可能的 mtime 残留线索（见 §5.4）只能支持"确有两次 above-store 物化"，**不能**证明哪一次是哪个版本。

---

## 5. Explicit upgrade to `0.3.0`

**人工执行**：

```powershell
dsh plugin --profile browser-lab add dsh-whale-widget@0.3.0
```

**命令输出**（[FACT：人工命令输出证据]）：

```
✓ Lockfile passes supply-chain policies (verified 2m ago)
Added 1 entry to minimumReleaseAgeExclude in pnpm-workspace.yaml (set minimumReleaseAgeStrict to true to gate these updates with a prompt):
  dsh-whale-widget@0.3.0
Packages: +1
+
Progress: resolved 1, reused 0, downloaded 1, added 1, done
Done in 1.4s using pnpm v12.4.2
```

### 5.1 最终状态核对 —— dependency range vs lock version（**分开记录，不混写**）

| 载体 | 值 | 证据等级 |
|---|---|---|
| `browser-lab/package.json` → `dependencies["dsh-whale-widget"]` | **`^0.3.0`**（range） | [FACT，本轮 filesystem 直读] |
| `browser-lab/pnpm-lock.yaml` → `importers.".".dependencies["dsh-whale-widget"]` | `specifier: ^0.3.0` / `version: 0.3.0` | [FACT] |
| `browser-lab/node_modules/dsh-whale-widget/package.json` → `version` | **`0.3.0`**（实际安装版本） | [FACT] |
| `browser-lab/node_modules/.pnpm/lock.yaml` | `specifier: ^0.3.0` / `version: 0.3.0` | [FACT] |

**结论**：
- **[FACT] 显式指定 `dsh-whale-widget@0.3.0` 安装成功。**
- **[FACT] dependency range（`^0.3.0`）与实际安装/lock 版本（`0.3.0`）当前一致**——因为 registry 上不存在更高的 `0.3.x`。
  （若日后发布 `0.3.1`，`^0.3.0` 会在下次 install 时漂移；这是 range 语义，不是本次的观测。）
- **[FACT] 裸包名与显式版本安装结果不同**（§4 vs §5），原因见 §11。

### 5.2 pnpm supply-chain policy 实际触发（[FACT]）

**持久化产物**——`browser-lab/pnpm-workspace.yaml` **被 pnpm 自动改写**：

```yaml
packages:
  - .

nodeLinker: hoisted
autoInstallPeers: false
minimumReleaseAgeExclude:
  - dsh-whale-widget@0.3.0
```

| 文件 | prep 基线 (BEFORE) | 现在 (AFTER) |
|---|---|---|
| `browser-lab/pnpm-workspace.yaml` | 61 B，sha `AE7C5B68E2F157528E62885804E69E88583897B775E03C86FCBE52FEAF498ABA` | **114 B**，sha `AAB600C54042C51BE168789E5D22CABDB8731A009BF9E8D53A0C6180CAAD8228`，mtime `2026-09-15 20:41:41` |

**[FACT] pnpm 的 supply-chain policy / minimumReleaseAge 机制在这次安装中实际触发**，并在**该 profile 的 `pnpm-workspace.yaml`** 留下了一条 `minimumReleaseAgeExclude` 条目。

**纪律**：

- 上表两条事实（policy 触发 + 写入了 exclude 条目）是**直接观察**。
- **不推断其内部机制**（什么年龄阈值、何时判定、store 复用与否）——本机源码/配置未直接证明这些，标为 `[UNKNOWN]`（§12）。
- 注意：该写入发生在**目标 profile 目录内**（`$DSH_HOME/profiles/browser-lab/`），**不是** `$DSH_HOME` 根，也不是 `web`。**它仍然是 profile-local 的。**

### 5.3 安装物完整性与形态（[FACT]）

```
browser-lab/node_modules/
├─ .pnpm/                        ← 仅含 lock.yaml
├─ dsh-whale-widget/             ← 真实目录（LinkType 为空，NOT junction/symlink）
├─ .modules.yaml
└─ .pnpm-workspace-state-v1.json
```

| 文件 | 大小 | sha |
|---|---|---|
| `dsh-whale-widget/package.json` | 1020 | `45AAB721B70C90449FEFA8B72F443644BD0211A285101FF6EBCFBC56AADA9AA9` |
| `dsh-whale-widget/cordis.patch.yml` | 719 | `86DD2BDB919D8E98A63FB7B9AD44B5EA38EF0A86994B87060B0B6CA3C38E6EF1` |
| `dsh-whale-widget/lib/index.js` | 152701 | `F2922FC155B18C487CB7376D1662B857A49DC75B33FC87E0FE53DA93DC467B1C` |
| `dsh-whale-widget/assets/whale-widget.js` | 650618 | `AFF529688466FB9DEEFB2FFBE7EDD08DA115F71A7415AA73271F73B8D7DDE14F` |

- `assets/` 含 13 个文件，与 prep 抓取的 GitHub `main` 清单**逐一对应**（DSniang1.png / DSniang02.png / DSH2.png / rua.gif / bubble-petpet.gif / bubble-money1.gif / Ya1.mp3 / Ya2.mp3 / D1.mp3 / D2.mp3 / minecraft-exp-orb.wav / task-end-a.wav / whale-widget.js）[FACT：文件名与字节数一致]。
- **`whale-widget-prompt.md` 不在安装物中** [FACT] —— 与 `package.json` 的 `files: ["lib","assets","cordis.patch.yml","README.md"]` 一致，符合预期，不是缺陷。
- 安装版 `cordis.patch.yml` 内容与仓库 `main` 完全一致（`- insert: / - id: dsh-whale-widget / name: dsh-whale-widget`）[FACT]。
- `lib/index.js` / `assets/whale-widget.js` / `package.json` 的**字节数与 GitHub `main` 完全相同** [FACT：size 相同]。
  → 但本轮**未对远端文件做 sha256**，因此只能写"字节数一致 + 版本号一致"，**不能**写"字节级同一"（`[INFERENCE]`，见 §12）。
- `.modules.yaml` 记录：`nodeLinker: hoisted`、`packageManager: pnpm@12.4.2`、`storeDir: C:\Users\user02\AppData\Local\pnpm\store\v11`、`hoistedLocations: {"dsh-whale-widget@0.3.0": ["node_modules/dsh-whale-widget"]}` [FACT]。
  → 证实 pnpm 把包**提升到了 profile 自己的 `node_modules/`**，与 `pnpm-workspace.yaml` 的 `packages: [.]`（workspace root = profile 目录）一致。

### 5.4 时间线（两个安装时刻的间接痕迹）

| 时刻（本地） | 事件 | 证据 |
|---|---|---|
| `20:39:23` | pnpm store 物化（`.modules.yaml.prunedAt` = `Tue, 15 Sep 2026 12:39:23 GMT`；whale `cordis.patch.yml` mtime 同秒） | [FACT：mtime] |
| `20:41:41` | `browser-lab/pnpm-workspace.yaml` 被写入 `minimumReleaseAgeExclude` | [FACT：mtime] |
| `20:41:43` | `browser-lab/package.json` / `pnpm-lock.yaml` / `node_modules` 最终 mtime | [FACT：mtime] |
| `20:42:38` | 新 DSH 进程 PID 39332 启动；`browser-lab/cordis.yml` 被 `prepareProfile` 重写 | [FACT] |

- **[INFERENCE]**：`20:39:23` 与 `20:41:43` 两个不同的物化时刻，与"两次安装"的人工叙述一致；`cordis.patch.yml` 因两版内容相同而复用了 20:39:23 的 store blob，故 mtime 停留在较早时刻。
  该解释涉及 pnpm content-addressable store + hard link 的 mtime 语义，**本机源码未直接证明**，故标为 INFERENCE 而非 FACT。

---

## 6. browser-lab profile manifest 变更（BEFORE → AFTER）

### 6.1 `package.json` [FACT]

**BEFORE**（prep 记录，sha `8D5D531DAFD910789DDEFA66DFDBF5132342FFB8A02E1AF7DA3903A2398A7A67`，244 B）：

```json
{
  "name": "dsh-profile-browser-lab",
  "private": true,
  "dependencies": {},
  "dsh": { "profile": {
    "bundles": ["@deepseek-ai/dsh-base", "@deepseek-ai/dsh-web-app"],
    "patchReload": "live"
  } }
}
```

**AFTER**（本轮直读，sha `A225D87A466F586DA6AF9A3615AECD21C48FC0038BC1322700BD3B4F8A92C39B`，308 B）：

```json
{
  "name": "dsh-profile-browser-lab",
  "private": true,
  "dependencies": {
    "dsh-whale-widget": "^0.3.0"
  },
  "dsh": {
    "profile": {
      "bundles": [
        "@deepseek-ai/dsh-base",
        "@deepseek-ai/dsh-web-app",
        "dsh-whale-widget"
      ],
      "patchReload": "live"
    }
  }
}
```

**[FACT] 这一步证明（全部为直接文件证据）**：

1. `dsh-whale-widget` 被加入 **browser-lab 的 `dependencies`**；
2. `dsh-whale-widget` 被加入 **browser-lab 的 `dsh.profile.bundles`**；
3. 因此 **bundle membership 是 profile-local 的**（写入只发生在 `$DSH_HOME/profiles/browser-lab/`）；
4. **`web` profile 本轮没有被主动安装 whale**（见 §7）。

> 这与 prep §4.2 从源码 `reconcilePlugins()` 推出的行为**完全一致**：
> `exportsPatch()` 命中 `dsh.bundle.patch` → 追加进 `dsh.profile.bundles`。

### 6.2 其他 profile 文件变更

| 文件 | BEFORE sha | AFTER sha | 变化 |
|---|---|---|---|
| `package.json` | `8D5D531DAF…` (244 B) | `A225D87A46…` (308 B) | ✅ 变更（§6.1） |
| `pnpm-workspace.yaml` | `AE7C5B68E2…` (61 B) | `AAB600C540…` (114 B) | ✅ 变更（§5.2，supply-chain exclusion） |
| `pnpm-lock.yaml` | 不存在 | `5843424E4C…` (408 B) | ✅ 新增（首次安装产生） |
| `node_modules/` | 空目录 | 含 `dsh-whale-widget` + `.pnpm` + `.modules.yaml` | ✅ 变更 |
| `cordis.patch.yml` | `EFBE0E95CB…` (925 B) | `EFBE0E95CB…` (925 B) | ❌ **未变**（MCP 条目原样） |
| `cordis.yml` | `C300DCF2EB…` | `C300DCF2EB…` | ❌ 内容未变，**mtime 变**（20:42:38，boot 重写，见 §8.1） |

---

## 7. `web` profile 非成员核对 —— **PASS** [FACT]

本轮对 `web` 做了与 prep §2.2 **逐文件哈希比对**（这就是真正的 web BEFORE/AFTER 对照）：

| 文件 | prep 基线 (BEFORE) | 本轮 (AFTER) | 判定 |
|---|---|---|---|
| `web/package.json` | `B07F71CBA5C341F6BD6EBF1316573588817E3A15629A86F11D34D4A01A82C94B` | **同左** | ❌ 未变 |
| `web/pnpm-workspace.yaml` | `AE7C5B68E2F157528E62885804E69E88583897B775E03C86FCBE52FEAF498ABA` | **同左** | ❌ 未变 |
| `web/cordis.patch.yml` | `EF189A8C27DB6D63930AA3046A3040482E952EAFCB7487C644D508E8D461F027` | **同左** | ❌ 未变 |
| `web/cordis.yml` | `C300DCF2EBC5F02062D6591268D29D3DB6FE45E0CB138F5467276FE2BA06076E` | **同左** | ❌ 未变 |

并且：

- `web/package.json` 的 `dsh.profile.bundles` **仍为 `["@deepseek-ai/dsh-base", "@deepseek-ai/dsh-web-app"]`**，`dependencies` 仍为 `{}` [FACT]。
- `web/pnpm-workspace.yaml` **仍为 61 B**，**没有** `minimumReleaseAgeExclude` 条目 [FACT]。
- `web/cordis.yml` 的 mtime 仍是 `2026-09-12 16:18:42` → **`web` profile 自那时起从未被 boot 过** [FACT]。
- `web/node_modules/` 仍是**空目录** [FACT]。

**[FACT] 结论：`web` profile 在上一次实践及本轮核对中完全保持未挂载 whale，且未被任何安装动作触碰。**

---

## 8. Runtime startup

### 8.1 进程状态（本轮只读观察，未干预）

| 项 | 值 |
|---|---|
| PID | **39332**（prep 时的 13800 已不存在） |
| 命令行 | `node …\@deepseek-ai\dsh\lib\bin.js --profile browser-lab` |
| 启动时刻 | `2026-09-15 20:42:38` |
| 监听 | `127.0.0.1:3080` |
| MCP 子进程 | 39212 (`npx -y @playwright/mcp@latest --browser=chrome`)、39980 (`cli.js --browser=chrome`) |

- [FACT] `browser-lab/cordis.yml` 的 mtime = `20:42:38`，与新进程启动同一秒。
  → 这是 prep §3.4「`prepareProfile` 每次加载无条件重写 `cordis.yml`」的**第二次 live 确认**（第一次是 13:34:43 / PID 13800）。内容哈希未变（`C300DCF2EB…`），符合"重写为同一常量"。

### 8.2 `$DSH_HOME` 运行时产物（whale 宿主侧活动的文件证据）[FACT]

prep 基线中这些**全部不存在**；现在全部存在：

| 路径 | 大小 | mtime |
|---|---|---|
| `$DSH_HOME/whale-audio/` | (dir) | 2026-09-15 20:42:46 |
| `$DSH_HOME/whale-bubble-imgs/` | (dir) | 2026-09-15 20:44:26 |
| `$DSH_HOME/whale-roles/` | (dir) | 2026-09-15 20:46:44 |
| `$DSH_HOME/.dshw-bubble.json` | 17875 | 2026-09-15 20:47:53 |
| `$DSH_HOME/.dshw-size.json` | 249 | 2026-09-15 20:52:16 |
| `$DSH_HOME/.dshw-usage.json` | 435 | 2026-09-15 20:52:26 |

**`.dshw-usage.json` 内容** [FACT]（原文，未改）：

```json
{"date":"2026-09-15","lastBalance":54.57,"todayUsage":0,"history":{},"dayStart":54.57,"settings":{...}}
```

**`.dshw-size.json` 内容** [FACT]（原文，未改）：

```json
{"scale":0.7,"sound":true,"vol":0.5,"soundSet":"duck","usageMode":"ledger","peakMode":"default","bubbleOn":true,"turnCostOn":true,"turnCostCloseMs":5000,"scrollGapOn":false,"scrollGapPx":17,"menuBtnHide":false,"updatedAt":"2026-09-15T12:52:16.797Z"}
```

**这些文件为什么重要**（它不是"桌宠出现了"的同义反复）：

- 这些文件**只可能由 whale 的宿主侧路由写入**，且 prep 基线确认它们此前不存在 ⇒ **归属无歧义**。
- `.dshw-usage.json` 含 **`lastBalance: 54.57`** ⇒ 宿主侧成功完成了一次 DeepSeek 余额观测：
  - ⇒ `GET /dsh-whale/balance.json` 被执行；
  - ⇒ `credentials` 服务解析 `DEEPSEEK_API_KEY` 成功；
  - ⇒ 出网调用 `https://api.deepseek.com/user/balance` 成功返回。
- `.dshw-size.json` 含 **用户改过的值**（`scale:0.7`、`turnCostCloseMs:5000`）与 `updatedAt` ⇒ `PUT /dsh-whale/size.json` 被执行过（人工在菜单里改过设置）。
- `whale-audio/`、`whale-bubble-imgs/`、`whale-roles/` 的建立时刻（20:42:46 起，即 boot 后 8 秒内）⇒ 资源管理路由在运行。

> ⚠️ **注意 HOME 级共享**：这些文件在 `$DSH_HOME` **根**，**不按 profile 分目录**。本轮只挂了 `browser-lab`，所以无冲突；但若 `web` 也挂 whale，两者会共享同一份状态。这是 profile isolation 的**边界事实**（见 §10.3）。

### 8.3 运行中进程的端点鉴别（**本轮新增的 runtime 证据**）

对运行中的 browser-lab（PID 39332）做**只读 GET**（无 PUT、无状态变更、未重启）：

| 请求 | 结果 |
|---|---|
| `GET /dsh-whale/widget.js` | **HTTP 401**, bytes=0 |
| `GET /dsh-whale/balance.json` | **HTTP 401**, bytes=0 |
| `GET /__dsh_no_such_route__`（**对照**） | **HTTP 404**, bytes=0 |
| `GET /` | **HTTP 401**, bytes=68 |

**鉴别结论 [FACT]**：

- **未注册路径 → 404**；**已注册路径 → 401**（缺会话凭据被 DSH 浏览器信任栅栏 `connection.requestRejection` 拒绝）。
- 因此 **401 ≠ 404 可用于判定路由是否注册**。
- `/dsh-whale/widget.js` 与 `/dsh-whale/balance.json` 返回 **401 而非 404** ⇒
  **[FACT] whale 的宿主侧路由确实已注册在正在运行的 browser-lab 进程上。**
- 结合 §8.2 的状态文件 ⇒ **whale 插件在 browser-lab 进程中确实完成了 apply 并对外服务。**

> 这正是 prep §7.5 预先写下的归属纪律（"不得把 401/403 写成插件失败，也不得与 404 混为一谈"）在真实数据上的兑现。
> 注意：401 是**预期行为**（信任栅栏在工作），**不是**安装失败。

---

## 9. 可见 Whale Widget UI 结果

**人工观察** [FACT：人工 UI 观察证据]：

> **browser-lab Web UI 右下角出现 Whale Widget 桌宠。**

**Whale Widget on browser-lab: E2E PASS**

---

## 10. Profile isolation 结论

### 10.1 完整链路（**分级标注，不冒充新 trace**）

```
browser-lab profile
 → dsh.profile.bundles includes dsh-whale-widget        [FACT · 文件证据 §6.1]
 → whale bundle patch participates in browser-lab composition   [INFERENCE · 源码支持 §10.2]
 → Cordis entry/plugin starts                            [INFERENCE · 源码支持；由 §8.2/§8.3 的结果反推]
 → required webServer/credentials dependencies satisfied [FACT（结果侧）；INFERENCE（机制侧）]
 → frontend asset injection becomes effective            [FACT · §8.3 路由已注册 + §9 页面可见]
 → Whale Widget is visibly rendered in browser-lab Web UI [FACT · 人工 UI 观察 §9]
```

**逐段归因纪律**：

| 环节 | 可用证据 | 等级 |
|---|---|---|
| bundle membership | `package.json` 直接文件证据 | **[FACT]** |
| install success | 命令输出 + lockfile + 安装物 manifest | **[FACT]** |
| 插件已 apply / 路由已注册 / 凭据已解析 / 出网成功 | `.dshw-*.json` 内容 + 401/404 鉴别 | **[FACT]**（结果侧） |
| Cordis entry 启动、`inject` 满足的**机制** | 本机源码（`loadProfileDirectory` → layer → patch）+ 上述结果 | **[INFERENCE]（源码支持的强推论）** |
| UI 渲染 | 人工可见观察 | **[FACT · 人工观察]** |

**明确不宣称**：

- 本轮**没有**新增 Cordis runtime event / log / trace 来直接观测 entry 启动与 `inject` 解析过程。
- 因此"entry 启动 → inject 满足"这条**中间链路**不得写成新的 runtime FACT，只能写成**由既有源码 + 成功结果支持的强推论**。

### 10.2 与 prep 命题的对照

| prep 的子句 | prep 判定 | 本轮实践后的判定 |
|---|---|---|
| bundle 归属记录在 profile 的 `dsh.profile.bundles` | ✅（源码） | ✅ **已被真实写入证实** |
| 该记录是 layer 的唯一输入 | ✅（源码） | ✅ 未受挑战 |
| 不存在 profile→profile 继承 | ✅（源码） | ✅ 未受挑战（`web` 哈希全未变） |
| 装进 A profile 不会写进 B profile 的 bundles | ✅（源码推论） | ✅ **已被真实执行证实（双向）** |
| 装进 A 不会进 B 的合成树 | ✅（推论） | **PARTIAL** —— 见下 |
| `package 在磁盘上存在` ≠ `profile 拥有 bundle` | ❌ 否定 | ✅ 未受挑战 |

**关于"合成树"这一子句**：

- 本轮**没有**采集 `browser-lab` 或 `web` 的**新** `--dump-config`（`--dump-config` 会重写目标 profile 的 `cordis.yml` 且需新进程，本轮禁止）。
- 因此：
  - `browser-lab` AFTER 合成树 = 153 entries（MCP）+ whale 一行 ⇒ **未实测**。
  - `web` AFTER 合成树 ⇒ **未实测**，但输入（bundle 列表 + 空 patch 层 + 无 home 层）**逐文件哈希未变** ⇒ 合成树不变的推论强度很高。
- ⇒ **full profile-isolation E2E = PARTIAL**（缺 AFTER dump 这一格）。

### 10.3 ⚠️ 边界（不得过度泛化）

1. **`$DSH_HOME/cordis.patch.yml` 仍是跨 profile shared layer**，本轮核实**仍不存在** [FACT]。
   它一旦被写入 `insert`，会让**所有** profile 拿到 whale —— 这与本轮"profile-local install"是**两个不同概念**，必须分开表述。
2. `$DSH_HOME` 根级的 `.dshw-*.json` / `whale-*/` 是 **HOME 级共享状态**，"profile 隔离"命题**不覆盖**它们。
3. `profiles/node_modules/`（共享 module fallback）本轮核实**仍不含 whale** [FACT] ⇒ prep 的 **U2 已消解**：pnpm 未把包写进共享层。
4. 本轮是**单向**验证（只装 `browser-lab`）。"对称性"（装 `web` 不影响 `browser-lab`）由"无继承 + 写入面唯一"覆盖，但**未做**实测。

### 10.4 package presence vs bundle membership（复述提醒）

- `browser-lab/node_modules/dsh-whale-widget/` 存在 ⇒ 只说明**包可解析**（package presence）。
- `browser-lab/package.json` 的 `dsh.profile.bundles` 含 `dsh-whale-widget` ⇒ 才是**bundle membership**。
- **两者在本轮恰好同时为真，所以必须分开陈述**：若只有前者，合成树**不会有** whale 的 entry。
- 反例提醒：`profiles/node_modules/` 里能解析到某包，**不等于**任何 profile 拥有它（本轮它连解析都做不到，因为 pnpm 没写那里）。

---

## 11. 版本 0.2.10 → 0.3.0

### 11.1 [FACT]

1. 裸包名 `dsh-whale-widget` 安装 → 输出 `+ dsh-whale-widget ^0.2.10`。
2. 显式 `dsh-whale-widget@0.3.0` 安装 → 成功，最终 `package.json` 为 `^0.3.0`，lock 与安装物均为 `0.3.0`。
3. **裸包名与显式版本安装结果不同。**
4. pnpm supply-chain policy 在本轮触发，并在 profile 内写入 `minimumReleaseAgeExclude: - dsh-whale-widget@0.3.0`。
5. `pnpm-workspace.yaml` 的 mtime（`20:41:41`）比 `package.json`/lock 的 mtime（`20:41:43`）早 2 秒。

### 11.2 [UNKNOWN] —— 原因**未定**

裸包名为何解析到 `0.2.10` 而不是最新的 `0.3.0`，本轮**不能断言**，可能涉及（**均无直接证据**）：

- npm registry propagation 时序（新版本刚发布、`latest` dist-tag 尚未切换）；
- 包自身的 dist-tag 布局（`latest` vs 其他 tag）；
- pnpm 本地 metadata cache / store 复用（本机 `storeDir: …\pnpm\store\v11`）；
- `minimumReleaseAge` 一类的发布时间门限 policy 在**裸包名解析阶段**的介入方式；
- 以上若干项的组合。

**可以收窄到什么程度**：只能确认"存在**两次不同的 store 物化时刻**"（§5.4，[INFERENCE]），以及"第二次显式指定版本时 policy 明确打印了 exclude 条目"。**policy 与裸包名解析结果之间是否存在因果，本轮无法证明。**

**本轮禁止的取证方式（未做）**：未联网查询 registry metadata、未重跑安装、未重触发 policy、未清 cache。

---

## 12. FACT / INFERENCE / UNKNOWN 汇总

### [FACT]

- pnpm `12.4.2` 已装（`C:\Program Files\nodejs\pnpm.ps1` / `pnpm` / `pnpm.CMD`），Corepack `0.35.0`；**DSH plugin workflow 的 pnpm 前置已补齐**。
- `dsh-whale-widget@0.3.0` 安装成功；`browser-lab` 的 `dependencies` 为 `^0.3.0`，lock 与安装物为 `0.3.0`。
- `browser-lab` 的 `dsh.profile.bundles` 现为 `[dsh-base, dsh-web-app, dsh-whale-widget]`。
- `browser-lab/pnpm-workspace.yaml` 被 pnpm 写入 `minimumReleaseAgeExclude: [dsh-whale-widget@0.3.0]` ⇒ supply-chain policy 实际触发。
- `web` profile 四个关键文件哈希与 prep 基线**逐一相同** ⇒ **web non-membership：PASS**。
- `browser-lab/cordis.patch.yml` **未变**（仍是 MCP 那 925 B）。
- `browser-lab/cordis.yml` 内容未变、mtime 变为 boot 时刻（`prepareProfile` 重写的第二次 live 确认）。
- `$DSH_HOME` 下 whale 状态文件/目录已生成，其中 `.dshw-usage.json` 含真实余额 `54.57`。
- `GET /dsh-whale/widget.js` 与 `/dsh-whale/balance.json` 在运行中的 browser-lab 上返回 **401**，未注册路径返回 **404**。
- `$DSH_HOME/cordis.patch.yml` 仍不存在。
- `profiles/node_modules/dsh-whale-widget` 不存在（pnpm 未写共享 fallback）。
- 人工可见：browser-lab Web UI 右下角出现 Whale Widget 桌宠。
- 安装物 `assets/` 13 个文件、`lib/index.js`(152701 B)、`assets/whale-widget.js`(650618 B) 与 GitHub `main` 清单/字节数一致。

### [INFERENCE]

- whale bundle patch 已参与 browser-lab 合成；Cordis entry 已启动；`inject: ['webServer','credentials']` 已满足 —— **由"路由已注册 + 状态文件已写入"的结果反推，机制由本机源码支持，但本轮无新增 runtime trace**。
- `20:39:23` 与 `20:41:43` 两次物化对应两次安装（涉及 pnpm store/hard-link mtime 语义，未由源码直接证明）。
- `web` 的合成树在 AFTER 仍与 BEFORE 相同（输入逐文件哈希未变 ⇒ 输出不变）。
- 安装物与 GitHub `main` 字节级相同（仅 size + version 相等为 FACT）。

### [UNKNOWN]

- 裸包名解析到 `0.2.10` 的**确切原因**（registry propagation / dist-tag / pnpm cache / minimumReleaseAge / 组合）。
- pnpm supply-chain policy 的**内部判定机制**（阈值、时机、与 store 复用的交互）——本机配置只能证明"它触发了并写了 exclude"，不能证明"它怎么判定的"。
- `.modules.yaml.prunedAt = 12:39:23Z` 与最终安装时刻（12:41:43Z）之间的 prune 语义。
- `browser-lab` / `web` 的 **AFTER `--dump-config`** 未采集。
- whale 若同时挂到两个 profile，`.dshw-*` 的并发写行为。
- 本轮为单向验证；"装 `web` 不影响 `browser-lab`"的对称性未实测。

---

## 13. Version-resolution caveat（单独留存）

> **裸包名与显式版本安装结果不同**（`^0.2.10` vs 成功安装 `0.3.0`）。
>
> - 这是 **FACT**（有命令输出支持）。
> - **原因未知**（`[UNKNOWN]`）。不得仅凭此现象断言归因于 registry propagation、dist-tag、pnpm cache 或 minimum release age policy 中的任何一项。
> - 已知**相关但不构成因果**的观察：显式指定 `@0.3.0` 时 pnpm 明确打印了 supply-chain policy 通过与 `minimumReleaseAgeExclude` 写入。
> - **实践建议 [RECOMMENDATION]**：安装具版本敏感性的 bundle 时，**显式指定版本号**，并在安装后核对 `package.json` 的 range、`pnpm-lock.yaml` 的 `version`、以及 `node_modules/<pkg>/package.json` 的 `version` 三处一致。

---

## 14. Follow-up questions

1. **AFTER dump 缺口**：能否在不与 3080 冲突、且接受 `cordis.yml` mtime 变更的前提下，采一次 `browser-lab` 与 `web` 的 `--dump-config`，把 `web` 与 `browser-lab` 的 AFTER 合成树补齐（当前 full E2E = PARTIAL）？
2. **对称性实验**：给 `web` 装一个 bundle，验证 `browser-lab` 不受影响（本轮只做了 browser-lab→web 方向）。
3. **负向对照 N1**（prep §7.3 已设计，未执行）：把 whale 的 `insert` 放进 `$DSH_HOME/cordis.patch.yml`，确认它**确实**会跨 profile 泄漏——用来证明"隔离不是自动化保证"。
4. **负向对照 N3**：把 whale 加到只有 `dsh-base` 的 profile（如 `headless`），验证 `inject: ['webServer']` 不满足时的确切表现。
5. **HOME 级状态共享**：两个 profile 都挂 whale 时 `.dshw-*` 的行为。
6. **版本漂移**：`^0.3.0` 在 registry 发布 `0.3.1` 后是否会静默升级；以及 pnpm 是否会为 `0.3.1` 追加新的 `minimumReleaseAgeExclude` 条目。
7. **卸载路径**：`dsh plugin --profile browser-lab remove dsh-whale-widget` 后，`dsh.profile.bundles` 与 `pnpm-workspace.yaml` 的 `minimumReleaseAgeExclude` 是否残留（prep 已记录 `reconcilePlugins` 会移除 bundle，但未覆盖 pnpm 配置残留）。

---

## 15. 一句话结论

> **Profile-local bundle install: PASS** ·
> **browser-lab Whale Widget runtime: PASS** ·
> **web non-membership: PASS（逐文件哈希比对）** ·
> **full profile-isolation E2E: PARTIAL（缺 AFTER dump 这一格）**
>
> prep 的源码闭环结论在真实实践中**未被推翻**，且安装的写入面确实只落在 `browser-lab`。
> 唯一真正的跨 profile 泄漏通道（`$DSH_HOME/cordis.patch.yml`）本轮核实**仍关闭**。

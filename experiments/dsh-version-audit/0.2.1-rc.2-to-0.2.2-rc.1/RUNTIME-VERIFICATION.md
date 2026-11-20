# RUNTIME-VERIFICATION — `0.2.2-rc.1`

采集时间：**2026-11-08 12:39–12:55 (+08:00)**
性质：**只读**。未升级、未安装、未改 profile / 全局配置、未创建 Session、未创建或 arm Goal、
未启动第二个 host、未做破坏性操作、未做 token-heavy 实验。

## 1. 实际执行过的检查

| # | 检查 | 命令 / 方式 | 结果 |
|---|---|---|---|
| 1 | CLI 版本 | `dsh --version` | `0.2.2-rc.1` |
| 2 | anchor 位置 | `where dsh` | `…\npm\dsh` / `…\npm\dsh.cmd`（仍是全局 npm anchor，未跳到 Desktop bundled CLI） |
| 3 | 安装 manifest | 读 `package.json` | `0.2.2-rc.1`，mtime `2026-11-08 12:35:48` |
| 4 | 官方 tag | `npm view @deepseek-ai/dsh dist-tags` | `latest`=`next`=`0.2.2-rc.1`，`alpha`=`0.2.2-alpha.3` |
| 5 | 运行时身份 | `DSH_*` 环境变量 | `DSH_PROFILE=browser-lab`、`DSH_HOME=…\.dsh`、`DSH_WEB_URL=…:3080` |
| 6 | 活跃 host | `Win32_Process` 过滤 `dsh/lib/bin.js` + 端口 | 1 个 host（pid 8248，`2026-11-08 12:39:43` 启动），3080 在听 |
| 7 | Desktop anchor | 读 `runtime.json` + exe FileVersion | `0.2.0-rc.2` / `0.2.0-rc.2` ⇒ **Desktop 未升级** |
| 8 | Cordis 版本 | 各包 `package.json` | Core `4.1.0`、Loader `1.1.0`、Include `1.1.0` |
| 9 | Node / npm | `node --version` / `npm --version` | `v24.20.0` / `12.0.2`（满足 0.2.2 的 ≥ 24.9） |
| 10 | session format | grep `SESSION_FORMAT_VERSION` | `4`；`dsh-session-format-v3-to-v4` 存在 |
| 11 | workspace 存储 | grep `dsh-workspace` unit | `version: 2` |
| 12 | 执行器默认值 | 读 `dsh-base/cordis.patch.yml` | `tool-executor-native` 启用；`tool-executor-ptc` `disabled: true` |
| 13 | 旧工具模式残留 | grep `DSH_TOOLS_MODE` / `mode: ptc` / `mode: native` | **零命中** ⇒ 已彻底移除 |
| 14 | fs 观察策略 | 读 `dsh-base` L292-300 | `fs-observation-policy: disabled: true`；`tool-fs.config.applyPatch: false` |
| 15 | web 预设 | 读 `dsh-web-app/presets/*.patch.yml` | 同 `applyPatch: false`；`tool-fs`/`tool-fs-search`/`plan-mode` 在 web 层 disabled、按 preset 重插 |
| 16 | web CLI 面 | `dsh --profile web --help` | 新增 `--public-url`、`--tls-cert`、`--tls-key`；`--host` 只接受单个具体本地地址 |
| 17 | WS 压缩 | grep `websocketCompression` | 存在，`z.union(["none","deflate"]).default("deflate")` |
| 18 | studio bundles 导出 | grep `dsh-app-boot` import | 从 `@deepseek-ai/dsh-official-bundles` 导入 `PROFILE_TEMPLATES` 等三组 |
| 19 | locale 集合 | 扫描 `*/locale/*.json` | `de, en, es, fr, ja, pt, ru, zh`（8 种） |
| 20 | 包集合差异 | npm cache inventory + tarball 逐文件 diff | 294 共有 / **+26 新包** / **−1 包** / 1752 added files / 52 removed / 1609 changed |
| 21 | 官方发布记录 | GitHub REST `/releases?per_page=8` | 取得 rc.3 / rc.4 / rc.5 / 0.2.2-rc.1（+2 个 alpha） |

## 2. 包级差异（机器可复现）

```
evidence/cache-inventory.json   651 条缓存条目 → 321 个包（两版本合计）
evidence/package-diff.json      294 个共有包逐文件 sha256 对比 + 26 新增 + 1 移除
evidence/diff-summary.json      过滤掉纯 package.json 版本号噪声后的真实变更
```

- **新增 26 个包**（全部 0.2.2-only）：`dsh-action-cards`、`dsh-client-ui-action-cards`、
  `dsh-client-ui-context-menu`、`dsh-client-ui-creation-recommendations`、
  `dsh-creation-recommendations`、`dsh-personalized-recommendations`、
  `dsh-client-ui-entry-customization`、`dsh-client-ui-file-actions`、`dsh-client-ui-file-drag`、
  `dsh-plugin-recommendations`、`dsh-client-ui-plugin-recommendations`、`dsh-plugin-detail`、
  `dsh-deliverable-file-references`、`dsh-message-quotes`、`dsh-fs-patch`、
  `dsh-official-bundles`、`dsh-tool-executor-native`、`dsh-tool-executor-ptc`、
  `dsh-experimental-forge`(+`-bundle`/`-github`/`-session`)、`dsh-experimental-client-ui-forge`、
  `dsh-experimental-client-ui-stats`、`dsh-experimental-liveshare`(+`-protocol`)。
- **移除 1 个包**：`dsh-client-ui-deepseek-model-label-1017`。
- **真实变更 261 个包**（已剔除仅 `package.json` 版本号变化的 33 个）。
  变更最大的几个（+新增/−删除/~改动文件数）：
  `dsh-api-session-controller` (+18/−2/~34)、`dsh-client-ui-chat` (+11/~33)、
  `dsh-plugin-manager` (+20/~20)、`dsh-client-ui-schedule` (+15/−1/~22)、
  `dsh-tools` (+18/−12/~8)、`dsh-ptc-runtime-node` (+17/−2/~15)、
  `dsh-tool-fs` (+14/~8)、`dsh-agent-preset` (+18/~5)。

## 3. 复现方式

```powershell
# 1) 缓存清单（只读，不联网、不安装）
node evidence/cache-inventory.mjs "$env:LOCALAPPDATA\npm-cache" `
     evidence/cache-inventory.json 0.2.1-rc.2 0.2.2-rc.1

# 2) 逐文件差异（copyRoot 传 '-' 表示不复制；PowerShell 会吞掉空字符串参数）
node evidence/analyze-diff.mjs evidence/cache-inventory.json evidence/work `
     evidence/package-diff.json - 0.2.1-rc.2 0.2.2-rc.1

# 3) 去掉版本号噪声
node evidence/summarize-diff.mjs evidence/package-diff.json evidence/diff-summary.json

# 4) 逐包 README 差异
node evidence/show-doc-diff.mjs evidence/work dsh-goal,dsh-plan-mode 0.2.1-rc.2 0.2.2-rc.1
```

> ⚠️ 复现坑（已踩）：**PowerShell 向原生命令传空字符串参数会丢参数**。第一次跑
> `analyze-diff` 时 `copyRoot` 为空 → `argv` 前移 → 两版本都解成 `0.2.2-rc.1` →
> 输出 `compared:320 / changed:0` 的假"无差异"。用 `-` 作为哨兵后数值才正确。
> 同时那次误把 294 个包 ×2 复制到了 `D:\Projects\dsh-test\-`（164 MB），已删除。

## 4. 明确**未**验证的项

| 项 | 状态 |
|---|---|
| `--tls-cert` / `--tls-key` / `--public-url` 的**实际监听行为** | `UNKNOWN`（只读了 `--help`，未起第二个 host） |
| Session API 的 snapshot/subscribe 拆分在运行期的具体形状 | `UNKNOWN`（只有官方发布块 + 包源码级） |
| `apply_patch` 的实际执行（本机未启用该工具） | `UNKNOWN`（未把 `applyPatch` 改成 true） |
| Goal / round driver 的 live 行为（create/arm/round/cap/pause/resume） | **NOT RUN**（任务边界：不创建、不 arm Goal） |
| 越界写入是否被 sandbox 拒绝 | **仍 `UNKNOWN`**（与 2026-10-19 审计一致；本 session 是 `danger-full-access`） |
| 模型实际路由到的权重版本 | `UNKNOWN`（0.2.2 已无 1017 label 包，不能反推） |
| 26 个新包在 `browser-lab` 里是否都**已挂载** | 只确认"已下载 + 在依赖图中"；`browser-lab` 的 bundles 仍是 `dsh-base` + `dsh-web-app` + `dsh-whale-widget`，新包里多数是实验/按需插件 ⇒ **不应**假定它们已启用 |

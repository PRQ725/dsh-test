# 01 — Host Composition（Bundle / Profile / Host-Agent 归属与层级）

> 长期维护研究笔记。证据等级：`[FACT]`=文件/源码/实际行为可确认；`[INFERENCE]`=多事实推导；`[UNKNOWN]`=当前无法确认。
> 更新：2026-09-01（建立）

> ### 环境归属说明（迁移后必读）
> 本文锚点的具体用户名绝对路径是**第一阶段源码考古所用机器（原机器）**的历史实例，不是当前机器路径。[FACT]
> - 原第一阶段考古机器：`$DSH_HOME = C:\Users\12699\.dsh`；DSH 安装根 = `C:\Users\12699\AppData\Roaming\npm\node_modules\@deepseek-ai\dsh`（下文以 `<DSH>` 代指）。
> - 当前机器（本仓库现所在）：`$DSH_HOME = C:\Users\user02\.dsh`；workspace = `D:\Projects\dsh-test`。
> - 本文的**架构性结论**（bundle/profile/host/agent 组合与归属）与具体安装位置无关；凡出现 `12699` 的具体路径均指原机器历史事实，勿当作当前环境。

---

## 一、Bundle 与 Profile 的实际文件与定位

### 实际文件（均为真实存在，除标注外）

| 文件 | 定位 / 作用 | 证据 |
|---|---|---|
| `<DSH>\node_modules\@deepseek-ai\dsh-base\package.json` | **Bundle（npm package）自身 manifest**。声明 `dsh.bundle.patch` 指向自己的 patch，并声明其插件依赖 | [FACT] |
| `<DSH>\node_modules\@deepseek-ai\dsh-base\cordis.patch.yml` | dsh-base 的 **bundle patch**（450 行） | [FACT] |
| `<DSH>\node_modules\@deepseek-ai\dsh-web-app\package.json` | **Bundle（npm package）自身 manifest** | [FACT] |
| `<DSH>\node_modules\@deepseek-ai\dsh-web-app\cordis.patch.yml` | dsh-web-app 的 **bundle patch**（445 行） | [FACT] |
| `$DSH_HOME\profiles\web\package.json` | **Profile manifest**（profile 目录内），声明 `dsh.profile.bundles` 有序列表 | [FACT] |
| `$DSH_HOME\profiles\web\cordis.yml` | Profile root（空 `[]`，Loader baseUrl 锚点） | [FACT] |
| `$DSH_HOME\profiles\web\cordis.patch.yml` | Profile user layer（空 `[]`） | [FACT] |
| `$DSH_HOME\cordis.patch.yml` | Home user layer —— **当前不存在**（2026-09-15 两次核对仍为不存在） | [FACT] |

### 归属：bundle 属于哪个 profile

`dsh.profile.bundles` 是 **profile-local** 的。`dsh plugin --profile <name> add <bundle>` 的写入面**只落在** `$DSH_HOME/profiles/<name>/`（`package.json` / `pnpm-lock.yaml` / `pnpm-workspace.yaml` / `node_modules/`），**不会**写其他 profile，也**不会**写 `$DSH_HOME` 根。[FACT]
**profile 之间不存在继承**（源码注释原文：*no inheritance metadata is persisted*）。[FACT]
⇒ 具体机制、共享层风险与归属纪律见 **`07-profile-bundle-isolation.md`**；本文只负责 composition 机制本身。

### 核心区分：Bundle 内部 package.json vs Profile 的 package.json
- **Bundle 内部 `package.json`**：npm package / bundle 自身的 manifest。属于那个**可安装的 npm 包**，含 `name/version/dependencies/exports` 等，还带一个非标准字段 `dsh.bundle.patch`。[FACT]
- **Profile 的 `package.json`**：profile manifest，位于 profile 目录。作用是**声明 bundles 及其顺序**（`dsh.profile.bundles`）与树外插件依赖；它本身不是 npm 发布包的主清单，而是 DSH 的 profile 描述文件。[FACT]
- 二者命名相同（都叫 `package.json`）但**语义与职责不同**：Bundle 清单声明"这个 npm 包是什么、它带什么 patch"；Profile 清单声明"这个 profile 由哪些 bundle、按什么顺序叠加"。依据源码 `loadProfile`（`@deepseek-ai/dsh-app-boot\lib\index.js` L539-556）只读 Bundle 的 `dsh.bundle.patch`、只读 Profile 的 `dsh.profile.bundles`。[FACT]

### `dsh.bundle.patch` 如何指向 bundle 自己的 patch
`loadProfile`（L546-556）对每个 `dsh.profile.bundles` 名称：
1. `resolveBundleDir` 解析到该 npm 包目录；
2. 读该包 `package.json` 的 `dsh.bundle.patch`（L548，如 `"./cordis.patch.yml"`）；
3. `join(packageDir, declared)` 拼出 patch 绝对路径，`loadOverlayPatches` 解析（L550/555）。
即 **`dsh.bundle.patch` 是 Bundle package.json 到其 patch 文件路径的相对引用**；若无此字段则该 bundle 被命名却报错（fail loud），不会静默当"无 patch"。[FACT]

---

## 二、Bundle cordis.patch.yml 的准确语义

**它不是"该 bundle 的默认运行配置"，而是"该 bundle 对最终 composition 提供的一组 entry contribution / patch 操作集合"。** [FACT]

- patch 文件本身不是最终配置；它是一组**操作**（`insert` 列表、按 id 的 config 覆盖 / `disabled` 等），在**最终 composition 时作为一条有序 patch stream 的一部分**被 `applyEntryPatches` 应用到 entry 列表上。[FACT]
- patch **并不修改另一个 patch 文件**——它作用于由空 profile root 及之前层逐步构建的 entry 列表。[FACT]（`applyEntryPatches` 见 `@deepseek-ai/cordis-plugin-include\src\index.ts` L58。）

### dsh-base 的结构（主要贡献 entries）
`<DSH>\node_modules\@deepseek-ai\dsh-base\cordis.patch.yml` 顶部为 **1 个顶层 `- insert:`**，内含 78 个 `- id:`（timer/hmr/llm/session/agent/...）。作用：在空 root 上**一次性插入基础插件行**。[FACT]
> 注意：dsh-base 的 insert 命名的是 `@deepseek-ai/dsh-agent` 等**插件包**，**不含 dsh-base 自己**；且 `dsh-base/lib/index.js` 内容为 `export {}`（无插件导出）。所以 dsh-base 包自身是**纯 patch 容器**。[FACT]

### dsh-web-app 的结构（主要修改前层 entries）
`...\dsh-web-app\cordis.patch.yml` 为 **27 个顶层 `- id:` override** + **2 个 `- insert:`** + **24 处 `disabled:`**。它按 id **覆盖/禁用** base 已插入的行（如 `system-prompt` 的 config、`hmr`/`tool-fs`/`tool-pwsh` 的 `disabled:true`），也通过 insert 追加 web 特有行（其中 L138 命名 `@deepseek-ai/dsh-web-app`，把它自己的运行时 glue 插件挂进树）。[FACT]

---

## 三、如果 bundle 的 patch 是空 `[]` 会发生什么

- **bundle 是否仍会被加载？** 是。`loadProfile` 对声明的每个 bundle 都执行"解析目录 → 读 `dsh.bundle.patch` → `loadOverlayPatches`"。若 patch 文件为 `[]`，`loadOverlayPatches` 返回 `[]`，该 bundle 层**被读取/解析但贡献 0 个 patch**。[FACT]
- **对 Host Composition 的 entry contribution？** 空 patch ⇒ 摊平后该层**不插入任何 entry、不改任何已有 entry**，即对该 composition 的贡献为**零**。[FACT]
- **不能轻率说"bundle 能力默认启动"**。区分：
  - **bundle 中存在代码/插件实现**（其 `dependencies` 与自身 `lib`）与
  - **这些插件是否被纳入当前 Cordis composition tree**（由 patch 行命名它们才进入）。
  - bundle 包本身不会被自动挂载为 Cordis entry：boot 路径里唯一的 `ctx.plugin(...)` 是 `ctx.plugin(Loader)`（`dsh-app-boot\lib\index.js` L1173）；dsh-base 的 `lib/index.js = export {}`。[FACT]
- **结论**：空 patch 的 bundle = "被声明的层但贡献空"。它依赖里的插件**不会**仅因 bundle 在 profile 中而被自动挂载。[FACT]
- **[UNKNOWN]**：除 patch 之外是否存在任何其它机制自动注册 bundle 内插件（在本任务读到的 profile-boot/boot/dump 路径中未见；但未穷尽全库每个调用方，故全局存在性无法排除）。

---

## 四、Host Composition 如何形成

Host plane 的组合由 `@deepseek-ai/dsh-app-boot` 的 include 机制单次摊平 `applyEntryPatches` 完成。真实文件与调用链：

```
空 root:  $DSH_HOME\profiles\web\cordis.yml  (空 [])
   ← bundle patch ①: <DSH>\node_modules\@deepseek-ai\dsh-base\cordis.patch.yml
   ← bundle patch ②: <DSH>\node_modules\@deepseek-ai\dsh-web-app\cordis.patch.yml
   ← profile patch:  $DSH_HOME\profiles\web\cordis.patch.yml
   ← home patch:     $DSH_HOME\cordis.patch.yml   (【不存在】=> 空层)
   ← --patch overlay: (CLI 参数，本次未传)
```
源码调用链（均在本机安装源码）：
```
dsh\lib\bin.js L136  runProfile({profile:'web', patchFiles})
  → dsh\lib\profile-boot-DG5t9aNs.js L220 runProfile
       L166 composeProfile（bundle→profile→home→overlays，+ agent-presets roots + telemetry）
       L241 composeLive  /  L147 allPatches（同序）
       L247 boot(NAME, rootConfig, allPatches)
  → @deepseek-ai/dsh-app-boot\lib\index.js L1167 boot
       → L1176 mountRootInclude → Include.applyPatches(L198) → applyEntryPatches
```
`applyEntryPatches`（`@deepseek-ai/cordis-plugin-include\src\index.ts` L58）把这些 patch **按出现顺序单次应用**到空列表上，形成 Host plane 的 entry 树。[FACT]

---

## 五、Agent Composition

> **[UPDATED 2026-09]** preset 文件位置在 `0.1.5-rc.1` 已变更：不再位于 `<DSH>\config\agent-presets\`，
> 而是由 `@deepseek-ai/dsh-agent-presets` 包自带，位于
> `<DSH>\node_modules\@deepseek-ai\dsh-agent-presets\presets\<id>\agent.cordis.yml`。
> 另：用户自定义 preset 放在 **`$DSH_HOME\.agent-presets\<id>\agent.cordis.yml`**。[FACT]

- **shipped preset roster（0.1.5-rc.1）**：`standard`、`cordis`、`ptc`、`minimal`（旧的 `code` 已不在 roster 中）。[FACT]
- **`standard\agent.cordis.yml`**（`<DSH>\node_modules\@deepseek-ai\dsh-agent-presets\presets\standard\agent.cordis.yml`）：agent preset 组合文件，定义会话所见模型工具（`tool-fs`/`tool-pwsh`/`tool-fs-search`/`tool-jobs`/...）与 prompt 片段。[FACT]
- **`@deepseek-ai/dsh-agent-presets`**：负责 preset 词汇、文件系统发现与受保护的 standing mount 的插件。host 组合里的行 `- id: agent-presets \n config: { default: standard }` 挂载它（默认值来自 `dsh-web-app\cordis.patch.yml`）。[FACT]
- **mount**：roster 把 preset 在**每进程挂载一次**于一个 standing scope；命名该 preset 的会话通过 **scope parentage** 加入（`agent → preset → global` 视图解析）。[FACT]
- **触发点**：会话创建路径中由 agent factory 的 `setup(agentCtx)` 钩子调用 `agentPresets.mount(agentCtx, id)`；子 agent 用 `composeFrom(parentCtx)` **绑定**到父的 standing composition。[FACT]

### Agent Composition vs Host Composition 的区别
- **Host Composition**：进程级、由 profile bundle patch 组合而成；持有注册表、sandbox/approval、持久化、模型路由、web 服务等**跨会话共享/基础设施**。[FACT]
- **Agent Composition**：由 preset `agent.cordis.yml` 定义、挂载进 **agent scope**；决定**该 agent 的模型可见工具与 prompt**。[FACT]
- 二者 **scope 不同**：host 组合在进程启动时一次组合；agent 组合随 preset 在 **standing scope** 上挂载，会话按 parentage 加入，可因 preset 不同而异。[FACT]

---

## 六、层级关系：Host Composition 与 Agent Composition **不是平行的 sibling**

> **[UPDATED 2026-09]** 早期表述把 Host / Agent 说成"两个 plane"，容易被读成**平行**的两层。
> 更准确的是**包含/实例化的层级**：Host Composition 定义的是**进程级基础设施**（DSH Runtime），
> Agent Composition 是**运行在该 runtime 之内**、由 agent 选用的组合。二者的 precedence 语义也因此不同（见 `02` §J）。[INFERENCE]

```
Host Composition          （profile bundles 的 patch 组合：注册表 / sandbox / persistence / model route / web）
   ↓  定义并启动
DSH Runtime               （进程级：加载 entry 树、提供 services/registries）
   ↓  承载
Agent Runtime             （DSH 内的 agent 子系统：agent 工厂、scope、inbox、loop）
   ↓  由 preset 定义
Agent Composition         （agent.cordis.yml：模型可见工具 + prompt 段；挂载于 standing scope）
   ↓  会话加入（scope parentage）
Agent Session             （一个 agent 的一次会话：header {cwd, agentPreset, …} + event log）
   ↓  逐步
Model requests            （每个 step 组装并发送给 provider 的请求）
```
- 上图是**层级/包含关系**，不是"两个并列配置层"。Host 提供 runtime；Agent Composition 在 runtime 内定义 agent。[INFERENCE]
- 实证支撑：`tool-fs`/`tool-pwsh` 在 **host dump 里 disabled**，却在 **agent 侧可用**（§七）——若二者是同一层的覆盖关系就会矛盾；按层级解释则自然。[FACT]

- **Host Plane 职责**：进程级基础设施与共享注册表——sandbox/approval、fs 服务、持久化、模型路由、tools/skill/subagents 等注册表、web 服务。它**一次组合、跨会话复用**。[FACT（部分由源码注释确认）]
- **Agent Plane 职责**：把"哪个 agent 长什么样"做成**会话可选**的预设——模型可见工具集、prompt 片段、plan/compaction/delegation 行为。[INFERENCE]
- **一个 Host 多 Session、各自选 preset**：因为 agent composition 是"每会话加入 preset 的 standing mount"（scope parentage），Host 只需一份基础设施，多个 session 各自选 preset。这正是 `dsh-agent-presets` 文档"one preset per session"的设计。[FACT/INFERENCE]
- **为什么 tool-fs/tool-pwsh 等模型可见工具放 Agent 侧而非全放 Host**：这类工具的"注册结果"（read/write/edit schema 与 prompt）应随**agent 的 scope**归属；放 Host 全局会令不同 preset/agent 彼此冲突或无法按会话裁剪（源码注释：预设工具经 scope realm 隔离、注册进 host tools registry 而 schema 随 scope 可见）。[INFERENCE]

```
Host  (进程级，profile bundle composition：注册表/sandbox/persistence/model-route/web)
 ├── Session A ──→ agent preset standard ──→ 工具 tool-fs/tool-pwsh ...
 ├── Session B ──→ agent preset ptc
 └── Session C ──→ agent preset minimal / 自定义
```
[FACT]

---

## 七、重要纠正：tool-fs/tool-pwsh "disabled" 之谜

- 现象：早期 `web-config.txt`（0.1.1 时代的 host 平面 dump；**2026-09 已归档到 `../archive/0.1.1-era/web-composed-tree-0.1.1-2026-08-29.txt`**）里 `tool-fs`/`tool-pwsh` 等 `disabled: true`；实际 session 却可用 read/write/edit/pwsh。[FACT]
  > 当前版本的等价 dump 见 `../evidence/config-dumps/browser-lab-composed-tree-BEFORE-mcp.yml`。
- **结论**：这不是"同一个 entry 先 disabled 后重新 enabled"，而是 **Host Plane 与 Agent Plane 存在不同 scope 的 entry/configuration**：
  - Host Plane：`dsh-web-app\cordis.patch.yml` 把 `tool-fs`/`tool-pwsh` 等行 `disabled:true` ⇒ 这些行在 **host 树**里不激活。[FACT]
  - Agent Plane：`standard\agent.cordis.yml` 把同名同插件的 `tool-fs`/`tool-pwsh` 以 **active** 状态注册进 **agent scope** ⇒ agent 树里可用。[FACT]
- 二者是不同的行、不同的 scope/平面，彼此独立；不是"重新 enable"而是"另一平面独立注册"。[FACT]

---

## 八、概念 → 实际文件 → Plane → 生命周期 总表

> ⚠️ 下表「实际文件/目录」列中的 `C:\Users\12699\…` 是**原第一阶段考古机器**的历史实例，**不是当前机器路径**（当前为 `$DSH_HOME = C:\Users\user02\.dsh`）。[FACT]

| 概念 | 实际文件/目录 | Plane | 生命周期 | 证据 |
|---|---|---|---|---|
| DSH_HOME | `C:\Users\12699\.dsh` | — | 进程常驻 | [FACT] |
| profile | `C:\Users\12699\.dsh\profiles\web` | — | — | [FACT] |
| profile manifest | `C:\Users\12699\.dsh\profiles\web\package.json` | host | 声明 bundles | [FACT] |
| profile root | `C:\Users\12699\.dsh\profiles\web\cordis.yml` | host | boot 时重写 | [FACT] |
| profile user layer | `C:\Users\12699\.dsh\profiles\web\cordis.patch.yml` | host | 组合时读取 | [FACT] |
| bundle | `<DSH>\node_modules\@deepseek-ai\dsh-base` / `...\dsh-web-app` | host | 安装时存在 | [FACT] |
| bundle patch | 每个 bundle 的 `cordis.patch.yml` | host | 组合时读取 | [FACT] |
| home user layer | `C:\Users\12699\.dsh\cordis.patch.yml`（**不存在**） | host | 空层 | [FACT] |
| CLI --patch overlay | 无文件（CLI 参数） | host | 组合时读取 | [FACT] |
| agent preset | `<DSH>\node_modules\@deepseek-ai\dsh-agent-presets\presets\<id>\agent.cordis.yml` 等（0.1.5-rc.1；**旧版**为 `config\agent-presets\`） | **agent** | 每进程 standing mount，会话按 parentage 加入 | [FACT] |
| host plane | 无单独文件（= bundle patch 组合） | host | 进程启动一次 | [FACT]/[INFERENCE] |
| agent plane | 无单独文件（= preset 组合） | agent | 每会话挂载/随会话结束 | [FACT]/[INFERENCE] |

（注：全部使用本机绝对路径或 `<DSH>`/`$DSH_HOME` 根路径；不使用 `base.cordis.yml`/`web.cordis.yml` 作为实际文件名——它们只是注释中的概念简称，真实载体是各 bundle 的 `cordis.patch.yml`。）

## 附：需修正的旧认知
1. `base.cordis.yml` / `web.cordis.yml` **非真实文件**，只是 agent-preset 注释概念简称；host 实际由各 bundle 的 `cordis.patch.yml` 组合。
2. bundle patch 是 **entry contribution / patch 操作集**，不是"默认运行配置"。
3. 空 `[]` patch 的 bundle 只是"被读取但贡献零 entry"；其依赖插件不会自动挂载（boot 路径仅 `ctx.plugin(Loader)`）。

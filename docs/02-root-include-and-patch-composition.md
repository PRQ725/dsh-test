# Root Include / cordis.yml / Patch Composition

> 长期研究笔记 · 聚焦"磁盘 cordis.yml → Root Include → Entry Tree"的运行链与 `applyEntryPatches` 语义。
> 证据等级：`[FACT]`=源码/文件/实验直接证明；`[INFERENCE]`=多事实推导；`[UNKNOWN]`=未追到源码。
> 更新：2026-09-01（建立）。相关：`00-dsh-local-filesystem.md`（文件地图）、`01-host-composition.md`（Host/Agent composition）、`04-agent-composition-and-instructions.md`（instruction 机制）。

> ### 环境归属说明（迁移后必读）
> 本文锚点的具体用户名绝对路径是**第一阶段源码考古所用机器（原机器）**的历史实例，不是当前机器路径。[FACT]
> - 原第一阶段考古机器：`$DSH_HOME=C:\Users\12699\.dsh`；`<DSH>=C:\Users\12699\AppData\Roaming\npm\node_modules\@deepseek-ai\dsh`；权威源码 `<DSH>\node_modules\@deepseek-ai\cordis-plugin-include\src\index.ts`。
> - 当前机器（本仓库现所在）：`$DSH_HOME=C:\Users\user02\.dsh`；workspace = `D:\Projects\dsh-test`。
> - 本文的**运行链与 patch 语义结论**与具体安装位置无关；凡出现 `12699` 的具体路径均指原机器历史事实，勿当作当前环境。

---

## A. DSH Web Profile 的 Root

- `PROFILE_ROOT_FILENAME = "cordis.yml"`：`dsh\lib\profile-boot-DG5t9aNs.js` L108。[FACT]
- `profiles/web/cordis.yml` 是 **Root Include 的实际配置文件**，当前内容为 `[]`（`PROFILE_ROOT_CONFIG` 是注释 + `[]`，见 profile-boot L102-106）。[FACT]
- **不要把 `cordis.yml` 说成 Entry Tree 本身**：Entry Tree 是内存中由 Loader 根据 `root.update(data)` 构建的子结构；`cordis.yml` 只是被读取的**数据基座文件**。[FACT]
- **也不要把 `cordis.yml` 说成"只是磁盘空占位符"**：它的**内容会被 `Include.read()` 读出并作为 `applyEntryPatches` 的 `data` 起点**（见 §B）。它同时兼任 baseUrl 锚点（其所在目录），但不止是锚点。[FACT]

## B. Root Include 的实际运行链

```
profiles/web/cordis.yml  (磁盘，内容 [])
   ↓  rootConfig = join(profile.dir, PROFILE_ROOT_FILENAME)
[dsh\lib\profile-boot-DG5t9aNs.js] L240 / L247  boot(NAME, rootConfig, allPatches(composed))
   ↓
[dsh-app-boot\lib\index.js] boot L1167
   └─ mountRootInclude L964-991
        rootInclude = { id:'include', name:'cordis:include',
                        config:{ path: URL(cordis.yml).href, patches:[...] } }   (L977-983)
        ctx.loader.create(rootInclude)                                          (L985)
   ↓
[@deepseek-ai/cordis-plugin-include\src\index.ts]  Include（EntryTree 子类）
   ├─ 构造 L194-204：filename = fileURLToPath(URL(config.path))；ctx.baseUrl = 文件所在目录
   ├─ [Service.init] L273-289 → read(true)
   │     read() L240-265：readFile(cordis.yml) → yaml.load(content,{schema}) → data = []
   ├─ _apply L315-321
   │     L316  data = applyEntryPatches(candidate.data=[] , config.patches)   ← cordis.yml 内容为 data 起点
   │     L317  await root.update(data)                                        ← 手交 Loader
   └─ Loader 依打补丁后的 entry 列表创建/移除子 entry 与插件 fiber → 内存 Entry Tree
```

关键点（均可溯源）：
- **Include 是 file-backed 的配置来源**：`Include` 是 `@deepseek-ai/cordis-plugin-loader` 的 `EntryTree` 子类，从 `config.path` 指的文件读取数据基座。[FACT]
- **Include 支持 `.yml` / `.yaml` / `.json`**：`writable={'.json','.yaml','.yml'}`、`supported=new Set(keys)`（src L27-33），构造器据此按扩展名选类型（L198-202）。`.yml/.yaml`→`yaml.load`；`.json`→`JSON.parse`。[FACT]
- **YAML 文件顶层必须解析成数组**：`read()` 强制 `Array.isArray(data)`，否则抛 `ConfigFileError('validate','config file must be a top-level array')`（L261-263）。[FACT]
- **`[]` 是合法的空 Root 数据**：`yaml.load('[]')`→`[]`，通过校验，是 profile 根的实际形态。[FACT]
- **空的 0-byte 文件并不等价于 `[]`**：`yaml.load('')`→`undefined`→非数组→校验失败。[FACT]
- **文件名 `cordis.yml` 不是 Include 插件强制协议**：Include 只校验扩展名、从不检查 basename；`config.path` 指向任意 `.yml/.yaml/.json` 文件都可用（见 `00` 笔记 §4/`cordis-plugin-include`）。[FACT]
- **`root.update(data)` 之后（本轮已追到）**：
  - `Include.root` = **`EntryGroup`**（`EntryTree.root` 声明 L12、构造 L17；`Include extends EntryTree`）。[FACT]
  - `root.update(data)` = **`EntryGroup.update(config)`**（`cordis-plugin-loader\src\config\group.ts` L59-106）——按 id 差分 reconcile：校验去重 → `config.map(o => this.create(o))`（L71）→ 逐条 `EntryGroup.create`（L20-40，复用 `store[id]` 或 `new Entry`）→ 消失的 id `remove(…,true)`（L81-83）；失败事务回滚（L85-105）。[FACT]
  - `EntryGroup.create` → `entry.update(options, create=true)`（entry.ts L142）→ 无 fiber 走 `init()`/`_init()`（L259-289）→ `tree.import(options.name)`（L280）→ `_start(plugin)`（L291-302）→ `ctx.registry.plugin(plugin, options.config)` → `new Fiber(...)`（`@deepseek-ai/cordis\src\registry.ts` L316/L330）。[FACT]
  - Loader 观察：`internal/plugin` 设 `fiber.entry` 回链 + `loader/*` 事件 + `EntryTree.await`（loader/src/index.ts L117-157 / tree.ts L46-64）。[FACT]
  - **仍未追完（保留）**：Cordis `Fiber` 启动后的完整 effect/依赖注入时序；`internal.ts` 的 `ModuleLoader` 动态导入细节。[UNKNOWN]

## C. 为什么 DSH 的 profile root cordis.yml 是 []

- DSH 的 profile 启动逻辑 `prepareProfile` **每次 boot 把 profile root `cordis.yml` 重写为 `[]`**：`profile-boot-DG5t9aNs.js` L140-144 `writeFileSync(join(profile.dir, PROFILE_ROOT_FILENAME), PROFILE_ROOT_CONFIG)`。[FACT]
- 源码注释明说目的：整棵组合都是 patch 层；vendored Loader 的树写回（插件自销毁时持久化当前树）会把组合行"烤进"该文件，从而下一次启动时让每个 bundle insert **重复叠加**。所以每次启动前把 root 重置为 `[]`。[FACT]
- **不要把"每次 root 都必须是 `[]`"描述成 Cordis Include 的通用规则**：Include 允许**任意非空 `EntryOptions[]` 作为 base data**（顶层数组即可）；DSH 把根置 `[]` 是 **profile 层策略**，不是 Include 约束。[FACT]

## D. Patch Composition 顺序

对 web profile，实际组合顺序（由 `profile-boot\lib\profile-boot-DG5t9aNs.js` `composeProfile` L166-198、`allPatches` L147、`composeLive` L241 固定）：

```
空 root data（profiles/web/cordis.yml = []）
   ← bundle layer ①  <DSH>\node_modules\@deepseek-ai\dsh-base\cordis.patch.yml    (1×insert, 78 rows)
   ← bundle layer ②  <DSH>\node_modules\@deepseek-ai\dsh-web-app\cordis.patch.yml (27 override+2 insert+24 disabled)
   ← profile patch    $DSH_HOME\profiles\web\cordis.patch.yml  (空 [])
   ← home patch       $DSH_HOME\cordis.patch.yml               （当前不存在）
   ← CLI --patch overlay                                       （本次未传）
   ← runtime 额外注入的 host overlays（agent-presets roots 注入、telemetry 行）——仅运行时 boot，dump 不注入
```

重要说明：
- **composition 不是简单把几个最终 config object 做 merge**：每个 patch 层都是一份 `PatchOptions[]`（操作集，不是配置对象快照）。[FACT]
- **最终把 layers flatten 成一个有序 patch 数组，经 `applyEntryPatches` 一次应用到 base data**：`composeEntries(layers)` = `applyEntryPatches([], structuredClone(layers.flat()), warn)`（`dsh-app-boot\lib\index.js` L575-580）；运行时由 `Include.applyPatches`→`applyEntryPatches`（cordis-plugin-include/src L267-271）。[FACT]
- **later patch 对同一 key 的修改具有后写覆盖效果**：同一列表按序应用，后 op 对已存在行的已命名键覆盖前 op。[FACT]

## E. `applyEntryPatches` 关键语义（权威源码 `cordis-plugin-include\src\index.ts` L58-128）

- **`id`**：定位已存在的 entry。[FACT]
- **`name` 主要是 guard**：patch 的 `name` 若给出且与目标 `target.name` 不符则跳过；`name` 被解构出去，**不会**作为覆盖字段写回（L78/L116-119）。[FACT]
- **`config` 是 whole-key replacement，不是 deep/浅 merge**：`target[key]=value`（L121-124），写 `config` 即整对象替换。[FACT]
- **`disabled` 是普通 last-write-wins**：只是普通键，后写覆盖。[FACT]
- **`insert`**：加入新 entry；`buildMap(insert)` 重新索引，使**之后**的 patch 能定位刚插入的 entry（L80-103）。[FACT]
- **不存在通用 remove/delete patch**：`applyEntryPatches` 无 remove/delete 分支；`disabled:true` 只是禁用，不是删除（行仍保留）。[FACT]
- **对不存在的 id 做 override 会 warning 并跳过**：`entry not found` → warn → continue（L110-114）。[FACT]

> **[0.1.5 → 0.2.x version boundary]** profile 的 user patch layer（`profiles\<profile>\cordis.patch.yml`）
> 不只承载 composition：**user settings 在 0.2.x 中就以 `- id: <entry-id> / config:` 形式 materialize 在这里**。
> 即同一个 patch 层里 `insert:` 表示 activation、`id:`+`config:` 表示 config override。
> 见 `09-dsh-desktop.md` §7。

## F. Host Plane vs Agent Plane（就本轮结论）

- **Host composition 与 Agent composition 是两个不同的 scope/plane**：host=profile boot 组合（root realm，进程级）；agent=每会话把选中 preset 挂进 agent scope。[FACT]
- **`--dump-config` 主要反映 host-plane composition**：`dsh\lib\dump-config-D-jtgwY3.js` `runDumpConfig` 只组合并打印，不创建 session、不 mount preset。[FACT]
- **session 创建后，selected agent preset 被 mount 到 agent scope**：`dsh-host-apiproxy\lib\types\api-proxy.js` L938-952 调 `presets.mount(agentCtx, resolvedPreset)` → `dsh-agent-presets\lib\index.js` L707 `mountPreset`。[FACT]
- **`standard\agent.cordis.yml`**（0.1.5-rc.1 路径：`<DSH>\node_modules\@deepseek-ai\dsh-agent-presets\presets\standard\agent.cordis.yml`；旧版为 `config\agent-presets\`）**中存在 active 的 `tool-fs`、`tool-fs-search`、`tool-pwsh`**（tool-pwsh 在非 win32 才 disabled；本机 win32 为 active）。[FACT]
- **因此不能因 host dump 中某个 `tool-fs` entry 是 disabled，就断言最终 model-facing tool 也 disabled**：agent 工具来自 agent plane 的 preset，与 host 行无关。[FACT]
- **这里不是"同一个 entry 先 disabled 后 re-enabled"，而是不同 scope 中的不同 entry**：host 树的行与 agent 树的行是两条独立注册，跨 plane 无覆盖关系。[FACT]

## G. `!!js` 表达式（YAML tag）

- **`!!js` 是 Include 的 entry-list YAML dialect 中的自定义 tag**：`new yaml.Type("tag:yaml.org,2002:js", { construct: (data) => ({ __jsExpr: data }), predicate: isJsExpr, represent: (data) => data["__jsExpr"] })`；`entryListSchema = yaml.JSON_SCHEMA.extend(JsExpr)`（`cordis-plugin-include\lib\index.js` L15-28）。[FACT]
- **往返**：`!!js` 标量读出为表达式节点 `{ __jsExpr: '<expr>' }`，写回时仍还原为 `!!js` 形式。[FACT]
- **求值时机**：Loader 在**激活/配置应用阶段**对 config 递归 `interpolate(ctx, value)`（`cordis-plugin-loader\lib\index.js` L285-294、调用点 L679），用 `evaluate = new Function('ctx','expr', 'with(ctx){ return eval(expr) }')` 针对**该 entry 自己的 loader context**求值。[FACT]
- **`disabled` 中的 `!!js`**：`Entry.disabledOf(options)` 对 `!!js` 表达式求值（`Boolean(...)`）；raw 节点保留在 options 中，写回不失形式（同文件 L364-368）。[FACT]
- 因此 `!!js process.platform === 'win32'`（preset 行）与 `!!js dshHomePath('sessions')`（host 行 config）都是在**激活期按运行环境**求值，而非加载文本时静态替换。[FACT]
- 注意：`dsh-agent-presets` 的 preset 健康检查会用 Loader 自己的 dialect（含 `!!js`）解析 `agent.cordis.yml`；解析失败 ⇒ 该 preset 标记 `broken`。[FACT]

## H. Profile user layer 的热更新（`watchUserPatches`）

- 长驻 surface（web 等）会 `watchUserPatches(ctx, { filename, compose })` 监听**用户在 profile 层的 patch 文件**（`$DSH_HOME\profiles\<name>\cordis.patch.yml`）与 **home 层**（`$DSH_HOME\cordis.patch.yml`）。[FACT]
- 实现：要求存在 Cordis **HMR 服务**与 root Include entry；通过 `hmr.registerConfig(filename, cb)` 注册；文件变化时重新读取 patch 并 `entry.update({ config: { ...includeConfig, patches } })` —— 即**把新的 patch 层热应用到 root Include entry，无需重启进程**。[FACT]
- 若 HMR effect 不活跃（`INACTIVE_EFFECT`）则退化为 no-op；缺 HMR 或缺 root Include entry 会抛错（要求 watch）。（`dsh-app-boot\lib\index.js` `watchUserPatches`）[FACT]
- `loadOptionalPatches` 语义：文件不存在 = **无该层**；存在但不可读/不可解析/非顶层数组 ⇒ **抛错 fail loud**（配置错误必须启动即暴露，绝不静默跳过）。[FACT]

## I. Telemetry 开关 patch

- profile boot 会在组合末尾**按需追加一条 host overlay** 来关闭遥测行（`dsh\lib\profile-boot-DG5t9aNs.js` L99-126、L189-190）：[FACT]
  - `TELEMETRY_ROW_ID = "session-telemetry-otel"`；
  - `resolveTelemetryPatch(disabledEnv, hasRow)`：当 `DSH_TELEMETRY_DISABLED` **非空**（**任意非空值都算禁用，包括 `'0'`/`'false'`**——隐私开关宁可误关）**且**组合中确实存在该 row 时，返回 `{ id: TELEMETRY_ROW_ID, disabled: true }`；否则返回 `undefined`（不生成 patch）。
  - 不含 telemetry 行的自定义 composition 因此天然满足该开关，无需额外 patch。[FACT]

## J. Host patch precedence vs Agent instruction specificity（两种 precedence，语义不同）

> 一处**极易混淆**的地方：同一个 `$DSH_HOME` 在 Host Composition 中**优先级很高**，但在 Agent instruction 中**最宽泛（优先级最低）**。二者并不矛盾 —— 它们是**两套不同的 composition 机制**。[FACT/INFERENCE]
> 相关：`04-agent-composition-and-instructions.md`。

### J.1 Host Composition 的 precedence：later patch **wins**
应用顺序（见 §D）：
```
空 root ([] )
  ← base bundle patch
  ← web-app bundle patch
  ← profile user patch        profiles/<name>/cordis.patch.yml
  ← home user patch           $DSH_HOME/cordis.patch.yml
  ← CLI --patch overlay
```
- 机制：**同一条有序 patch stream 按序应用**；同一 key/行 **后写覆盖先写**（`config` 为 whole-key replacement，`disabled` 为 last-write-wins）。[FACT]
- 因此 **home patch 排在 profile patch 之后 ⇒ 优先级更高**（机器级偏好覆盖单 profile 偏好）。[FACT]

### J.2 Agent instruction 的 precedence：broad → specific，**more specific wins**
加载与保留顺序（见 `04`）：
```
$DSH_HOME/AGENTS.md          （user-global，最宽）
  → <projectRoot>/AGENTS.md / CLAUDE.md
  → … 逐级子目录 …
  → <cwd> 的 AGENTS.local.md / CLAUDE.local.md   （最具体）
```
- 机制：**不是覆盖**，而是按 broad→specific **拼进同一条 `<system-reminder>` 消息**；文本声明 "More specific instructions take precedence over broader ones"，越具体越靠后。[FACT]
- byte budget 裁剪时，**从最宽的整份文件开始丢弃**，最后才截断最具体的文件。[FACT]

### J.3 为什么不矛盾

| | Host Composition | Agent Instruction |
|---|---|---|
| 单位 | patch **operation** / entry 行 | instruction **文本** |
| 组合方式 | 同一 stream 顺序应用（**后写覆盖**） | 多份文本顺序拼接（**不覆盖**） |
| 优先级来源 | **层的位置越靠后越高** | **作用域越具体越高** |
| `$DSH_HOME` 的角色 | home patch = **最靠后的用户层** ⇒ 高优先 | `$DSH_HOME/AGENTS.md` = **user-global，最宽** ⇒ 低优先 |
| 冲突结果 | 前一层被**替换/禁用** | 两份都注入，由模型按提示取舍 |

> 一句话：**Host 层是「配置合成」（后覆盖前）；Agent instruction 是「上下文叠加」（具体优先）。** 同一目录在两种机制里的"位置"含义不同，故 `$DSH_HOME` 可同时是"Host 的高优先层"与"Agent instruction 的最宽层"。[INFERENCE]
> [UNKNOWN] "具体优先"目前是**提示词层面**约定，DSH **没有**在代码层按 specificity 强制覆盖 instruction 文本。

---

## K. `[2026-11-08]` 0.2.2 的组合层变化（Cordis 4.1.0 / 执行器拆分）

> 适用版本：**`0.2.2-rc.1`**。本节只记"影响 patch 层怎么读"的部分，不重复官方 changelog。
> 审计：`../experiments/dsh-version-audit/0.2.1-rc.2-to-0.2.2-rc.1/`。

**K.1 Cordis 内核版本（本机实测）**

| 包 | 0.2.2-rc.1 实测 | 说明 |
|---|---|---|
| `cordis`（Core） | `4.1.0` | 0.2.2 由 4.0.0-rc.x 线正式到 4.1.0 |
| `cordis-plugin-loader` | `1.1.0` | |
| `cordis-plugin-include` | `1.1.0` | 本笔记 §E 引用的 `applyEntryPatches` 源码仍在；语义未变 |

[FACT] 发布块对应句："同步 Cordis Core 至 4.1.0、Loader 至 1.1.0、Include 至 1.1.0，统一配置访问、
条目变更和持久化行为"。§D/§E 的**组合顺序与 patch 语义结论仍然成立**；但"配置访问"层新增了
Fiber 的统一视图（原始配置 / 候选解析 / 生效配置），所以**设置编辑与热更新读同一份生效配置**——
这解释了为什么 0.2.2 的 profile patch 仍然可以既是"settings 落点"又是"hot-reload 输入"。

**K.2 `tools` 行不再是"一个带 `mode` 的行"**

| | ≤ `0.2.1` | `0.2.2` |
|---|---|---|
| 呈现模式 | `- id: tools` 的 `config.mode: native \| ptc` | **两个独立 entry**：`tool-executor-native` / `tool-executor-ptc`（择近 scope 生效，同 scope 内同 provider 重复即失败） |
| 环境变量 | `DSH_TOOLS_MODE` | **已移除** |
| 启用 PTC | 改 `mode` / 设 env | 用**配置 overlay** 改挂哪一行（`tool-executor-ptc` 在 `dsh-base` 里是 `disabled: true`） |

[FACT] 本机 `dsh-base`：`tool-executor-native` 启用、`tool-executor-ptc` **`disabled: true`**。
[FACT] `dsh-tools` 的 `Config` 把两个旧键声明成 **`z.never()`**：
`mode: z.never().description('Removed. Mount a native or PTC tool executor instead.')`、
`maxParallelSubCalls: z.never().description('Moved to the PTC tool executor configuration.')`。
⇒ 旧的 `- id: tools / config: { mode: native }` 这类行**不会静默失效，而是触发 schema 校验失败**
（具体是整条 entry 失败还是该 plugin 启动失败取决于 Loader 的错误策略；本机未实测该失败形态）。`[FACT]` + `[UNKNOWN]`
[FACT] `DSH_TOOLS_MODE` 在 `lib` 代码中**零命中**；全安装树仅剩 2 处**文档**提及（`dsh-sdk-app` 的迁移说明）。
⇒ 之前"全树零命中"的表述过宽：**代码零命中**成立，**全树零命中**不成立（文档里有）。

**K.3 新增 `dsh-official-bundles`：组合清单不再是硬编码**

[FACT] `dsh-app-boot` 现在从 `@deepseek-ai/dsh-official-bundles` 导入
`PROFILE_TEMPLATES` / `INSTALLATION_OWNED_PROFILE_TUPLES` / `RETIRED_BUNDLES`。
该包**只含数据**（各 shipped profile 起始 bundle、默认关闭的 bundle、按需安装的官方 bundle、
早期发布曾分发而现被 profile 丢弃的 bundle、以及插件管理器的保护/隐藏/排序/实验标记）。

⇒ **本笔记 §D 的"bundle layer ①/②"描述方式仍成立**，但"哪些 bundle 属于哪个 shipped profile"
现在有一个**权威数据源**可查，不必再逐个 dump profile patch 去反推。
自定义集成若曾从 `app-boot` 读这些列表，需改 import（0.2.2 破坏性变更）。

---

## 待补（[UNKNOWN]/[INFERENCE]）
1. ~~`root.update`/`EntryTree` 内部~~ —— 已追到（见 §B：`EntryGroup.update` → `Entry` → `registry.plugin` → `new Fiber`）。仍保留：[UNKNOWN] Cordis `Fiber` 启动后的完整 effect/依赖注入时序；`internal.ts` 的 `ModuleLoader` 动态导入细节。
2. ~~`agent-presets` 行 `default: standard` 由哪个具体 bundle patch 行产生~~ —— **[RESOLVED 2026-09]**：来自 `@deepseek-ai/dsh-web-app\cordis.patch.yml` 的 `- id: agent-presets / config: { default: standard }` 行（本机 0.1.5-rc.1 实测）。[FACT]
3. 除 patch 之外是否存在其它自动注册 bundle 内插件的全局机制（当前路径未见）。

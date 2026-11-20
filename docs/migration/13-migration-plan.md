# Migration Plan — Personal Job Search OS → DSH

> 本文是 **Phase 3.1 Migration Design** 产出：一份可指导下一阶段执行的 migration design document。本文**不是** migration 执行本身，也不写未经 source-verified 的具体 CLI 命令。
> 依赖基线：`10-claude-code-project-inventory.md`（CC Step 1）、`11-claude-code-dsh-concept-mapping.md`（CC↔DSH mapping）、`12-migration-decision.md`（Decision Record，READY WITH CAVEATS）。
> 证据等级：`[FACT]` / `[INFERENCE]` / `[UNKNOWN]`。
> 建立：2026-09。

> ### 状态声明
> **Phase 3.1 = design only**。本阶段禁止实际 migration；Personal Job Search OS 保持 READ-ONLY。本文只写计划与验证任务，凡未经验证的执行细节一律标 [UNKNOWN] 并转入 Phase 3.2 验证任务。

---

## 1. Purpose and Scope

**本 migration 要迁移什么**：[FACT/INFERENCE]
- Personal Job Search OS 的 **Project Knowledge**（README、docs/、模块 README、schema、templates、structured Markdown data、CLAUDE.md 文件本体）。
- Personal Job Search OS 的 **Project-scoped Agent Instructions**（CLAUDE.md 的 instruction/constraint 职能），重新承载到 DSH Agent Runtime。

**不迁移什么**：[FACT]
- Claude Code session/context、Claude Code runtime state。
- machine/environment state（`$DSH_HOME`、credentials、DSH installation、node_modules、cache、runtime Fiber）。
- `.claude/skills/job-search/`（skeleton，未来 RECREATE，本轮不迁）。
- `candidate/raw/` 私人原始资料的**暴露/迁移语义**不变（只随项目目录存在，不被引入研究/文档层、不被复制出隐私边界）。

**migration 目标不是「复制 Claude Code」**：而是把 Personal Job Search OS 的 Project Knowledge + Project-scoped Agent Instructions 重新承载到 DSH Agent Runtime，使 DSH Agent 能在该 workspace 上理解并遵守原项目规则。[INFERENCE]

> **Phase 3.1 = design only；本文不授权执行。**

---

## 2. Source and Target

### Source
[FACT] `D:\Projects\Personal Job Search OS`（用户真实项目，本地 git，无 remote）。

### Target
**推荐形态：让 Personal Job Search OS 本身直接成为 DSH workspace，而不是额外复制一层目录。**
- 依据：DSH `workspace.create({ path })` **adopts an existing canonical directory**（`dsh-host-apiproxy` README L45）。[FACT] 即 DSH workspace 是对一个现存目录的**注册/采用**，不需要把源复制到另一棵树。
- 推论：把 `D:\Projects\Personal Job Search OS` 直接登记为 workspace，是符合 DSH 模型且最小侵入的方案。[INFERENCE]

**未确定项（**已于 Phase 3.2 验证** —— 见 `14-phase32-execution-verification.md`）**：
- 登记方式：**已确认** —— 经 DSH web/UI 面调 RPC `workspace.create`（`ensureWorkspace` → `workspaceRegistry.create`）；无 CLI 子命令。源目录**可**处于使用中，**可**含 `.git` + 私人子目录。[FACT，`14` §A]
- profile：当前用 shipped `web` profile（standard preset）即可；是否需专用 profile 仍 [UNKNOWN]（非阻塞）。
- 「PJOS 直接当 workspace」**已实测生效**：workspace ID `92030ae8-…` 注册成功，项目零副作用。[FACT，`14` §B]

> 关键判断：**不**人为把 Personal Job Search OS 领域目录重构进某套「DSH 目录规范」，除非存在明确 DSH 技术要求（当前未发现）。[INFERENCE]

---

## 3. Migration Principles

1. **Preserve project structure** — 不重构源领域目录（模块/对象/版本目录布局尽量原样）。[RECOMMENDATION]
2. **Minimize semantic transformation** — 尽量少改内容语义；文件直迁，重承载只在必须处（CLAUDE.md instruction）。[RECOMMENDATION]
3. **Project knowledge stays project knowledge** — docs/、README、模块 README、schema、data 仍是 workspace 文件知识，不上升为 profile/bundle 内容。[RECOMMENDATION]
4. **Project instructions stay project-scoped** — CLAUDE.md 的指令随项目(workspace)加载，不放入机器级/agent-preset 全局。[RECOMMENDATION]
5. **Runtime state is not migrated** — CC session/runtime 不迁。[RECOMMENDATION]
6. **Machine state is not migrated** — `$DSH_HOME`、credentials、install、cache 不迁。[RECOMMENDATION]
7. **Privacy boundary is preserved** — `candidate/raw/` 等私人资料不暴露到研究/文档层，不因 DSH 引入而变化。[RECOMMENDATION]
8. **First migration is minimal** — 第一批只迁 project knowledge + project instruction loading（§7）。[RECOMMENDATION]
9. **Validate before using real project data** — 先用非破坏性验证，再碰真实 Job Search 数据。[RECOMMENDATION]
10. **Reversible / rollback-friendly** — 迁移为增量/可回滚；源项目永不被 DSH 运行失败破坏。[RECOMMENDATION]

---

## 4. Asset Migration Matrix

> 分类沿用 Phase 2 术语。注意：**不迁 Git 作为 DSH mechanism ≠ 删除/丢弃 Git**；Git 继续作为项目资产存在。

| Asset / Source | Category | Action | Reason | Phase | Validation |
|---|---|---|---|---|---|
| README.md | Project documentation | DIRECT-COPY | workspace 内 markdown，原样保留 | 3.3 | 文件存在、可读、路径正确 |
| CLAUDE.md | Project knowledge + Agent instruction | DIRECT-COPY（文件）+ RE-HOST（instruction 职能经 dsh-agent-instructions） | 文件本体直迁；指令由 DSH 原生读 CLAUDE.md 承载 | 3.3 | 见 §6 / §10 |
| .gitignore | Version/privacy scope | DIRECT-COPY | 延续隐私/版本边界声明 | 3.3 | 文件在，ignore 语义保留 |
| docs/ | Project knowledge (schema/design) | DIRECT-COPY | workspace 内 markdown | 3.3 | 目录结构、文件可读 |
| module READMEs | Project knowledge (module role) | DIRECT-COPY | 各模块 `README.md` | 3.3 | 每模块 README 在 |
| schemas | Project knowledge (data contract) | DIRECT-COPY | `docs/*-MODEL.md`、各 `_templates` | 3.3 | 可读、引用完整 |
| templates | Project knowledge (schema) | DIRECT-COPY | 各模块 `_templates/*.md` | 3.3 | 可读 |
| structured Markdown data | Project data | DIRECT-COPY | 模块真实实例（candidate 结构化知识/jobs/match/resumes/discovery/…） | 3.3 | 数据可读、引用 ID 完整 |
| candidate/raw/ | Private source input | **DO-NOT-MIGRATE-as-exposure / COPY-as-dir-only** | 私人原始资料；只随项目目录存在，**不暴露**到研究/文档层，不复制出隐私边界 | 3.3（目录随迁但内容不进入研究/文档） | 隐私边界验证 §10 |
| `.claude/skills/job-search/` | CC Skill skeleton | RECREATE (later) | 未实现骨架，第一轮不机械复制；未来按 DSH skill 语义重建 | 3.5 | 不需在 3.3 验证 |
| `.git/` | Project persistence | **保留为项目资产，不迁为 DSH mechanism** | Git 是源项目自身版控，非 DSH runtime mechanism；不删除 | 3.3（保持不动） | git 状态不变 |
| Claude Code session/context | CC runtime state | DO-NOT-MIGRATE | 平台侧运行态，非项目资产 | — | 不迁 |
| Claude Code runtime state | CC runtime state | DO-NOT-MIGRATE | 同上 | — | 不迁 |
| machine/environment state | Machine state | DO-NOT-MIGRATE | `$DSH_HOME`/install/cache | — | 不迁 |
| credentials | Machine state | DO-NOT-MIGRATE | 旧机凭据不跨机 | — | 不迁 |
| DSH `$DSH_HOME` | Machine state | DO-NOT-MIGRATE | 本机 DSH 状态，与源项目不同系统 | — | 不迁 |
| DSH installation | Machine state | DO-NOT-MIGRATE | 已安装即用，不复制 | — | 不迁 |
| node_modules | Machine state | DO-NOT-MIGRATE | 不复制 | — | 不迁 |
| caches | Machine state | DO-NOT-MIGRATE | 不复制 | — | 不迁 |

> 补充：本项目无 source code / package.json（见 inventory §2），故无「代码迁移」一栏。[FACT]

---

## 5. Recommended Target Workspace Layout

**推荐：`D:\Projects\Personal Job Search OS` 直接作为 DSH workspace。**（依据 §2 `workspace.create` adopts existing canonical directory。[FACT]）

推荐布局 = **保持源目录原样**，不新增 DSH 专用包装层、不把 Personal Job Search OS 领域目录移进别处。[INFERENCE]

```
D:\Projects\Personal Job Search OS        ← DSH workspace（采用既有目录，不复制）
├── CLAUDE.md                             ← 由 dsh-agent-instructions 读作 project instruction
├── README.md / .gitignore
├── docs/  candidate/  discovery/  jobs/  resumes/  match/  applications/  interviews/  analytics/
└── (git 仓库保持原状；candidate/raw 隐私边界不变)
```

**未验证的约束（标 [UNKNOWN]，提出验证任务）**：
- DSH 能否直接采用一个「已含 `.git` + 大体积 + 私人子目录 + 当前被使用」的目录作为 workspace，而不触发副作用。[UNKNOWN]
- 是否需要对源目录做任何只读探针/权限处理才能被 adopt。[UNKNOWN]
- 目标 session 用哪个 profile / 是否需新建专用 profile。[UNKNOWN]（当前 `web` 为 shipped 模板。）

> 这些不阻塞「设计」，但写入 Phase 3.2 验证任务，确认前不执行 adopt。[RECOMMENDATION]

---

## 6. CLAUDE.md Migration Design

**明确区分 A（文件本体）与 B（Agent-instruction function）。**

**推荐第一版**：
```
CLAUDE.md
    ↓
dsh-agent-instructions
    ↓
DSH Agent
```
而不是第一版就把整个 CLAUDE.md 拆解进 agent preset。

**为什么**：
1. CLAUDE.md 是 **project-scoped**（随项目/workspace 生效）。[FACT（CC 侧）/INFERENCE]
2. agent preset 更接近 **agent-scoped behavior/persona**（DSH 侧 preset 定义「agent 是什么」）。[FACT]
3. 直接使用 `dsh-agent-instructions` **减少 semantic transformation**：该机制原生按项目根读 `AGENTS.md`/`CLAUDE.md`（默认候选含 `CLAUDE.md`，root marker `.git`，root→cwd 加载）[FACT]，CLAUDE.md 文件几乎可原样承载 instruction。[INFERENCE]
4. one-to-many 内容（constraint/navigation/current-state/knowledge）**可暂时保持原文件 + instruction loading**，不必第一轮就拆解进 preset。[INFERENCE]

**关于 agent preset**：agent preset 是否承载 CLAUDE.md 中部分 persona/behavior，是**未来可研究的优化项**，**不是第一轮 migration blocker**。[RECOMMENDATION/INFERENCE]

**关键 caveat（写实，非伪装事实）**：[INFERENCE]
- `dsh-agent-instructions` **读取** CLAUDE.md 并注入 instruction baseline（机制已确认）；但它**不解析** navigation/current-state 为结构化对象，也**无声明式 rule schema** 硬执行 constraint。因此第一轮通过它承载「instruction 职能」，而 navigation/state/constraint 的「精确还原」仍是内容层承载，需在 validation（§10）确认 instruction 是否**实际影响行为**。

---

## 7. First Migration Scope

**最小可工作 migration（第一批）**：
- Project files（目录结构）
- README.md
- CLAUDE.md
- .gitignore
- docs/
- structured project Markdown（模块真实实例）
- templates / indexes / module READMEs

**暂不做**：
- skill recreation
- Claude session migration
- runtime migration
- machine state migration
- DSH-specific optimization

**candidate/raw/ 的处理**：[FACT/INFERENCE]
- candidate/raw/ 作为项目目录**随 workspace 存在**（因为采用既有目录），但：
  - **不**把其 PII 内容复制/引入任何研究/文档层。
  - **不**擅自决定把私人 raw data 暴露给任何新运行环境；其 privacy boundary 必须原样保留。
  - 是否「把 candidate/raw 实际纳入首批可写范围」取决于用户是否允许 DSH 访问私人数据 → 这是 **operational/privacy decision**，不是默认动作。[RECOMMENDATION]
- 若存在 privacy/operational 依赖，明确：第一批只**读**结构化知识 + 规则，不触碰 raw PII；raw 的可写/暴露授权单列，由用户决定。

---

## 8. Preflight / Dry Run

> 实际 migration 前必须执行的只读检查。**Preflight 不修改源项目。**

### Source integrity
- project path 存在且为期望目录。[FACT 基线]
- file inventory（模块/对象/模板/索引）可列出。
- CLAUDE.md / README.md / .gitignore 存在。
- `.claude` 结构（仅 job-search skeleton）。
- Git status（记录当前 `M CLAUDE.md` + untracked resume 实例为基线，证明未被我方改动）。
- privacy-sensitive paths 清单（`candidate/raw/` 等）标记为不读正文。

### Target readiness
- DSH installation 可用（本机 `@deepseek-ai/dsh@0.1.1-rc.2`）。[FACT]
- target profile：当前 `web` shipped 模板 profile 存在；是否够用/需专用 profile → 验证。[UNKNOWN]
- workspace：`workspace.create({ path })` adopt 既有目录这一语义**实测验证**。[UNKNOWN→验证]
- `dsh-agent-instructions` 可用性：确认其在目标 profile/agent 组合中已挂载（standard preset 有 `agent-instructions` 行）。[FACT/待实测]
- tool 可用性：tool-fs / tool-pwsh / read 等在 agent 组合中可用。[待实测]
- sandbox/write scope：确认写入边界与隐私。

### Boundary checks
- no credentials copied。
- no `$DSH_HOME` copied。
- no session/runtime copied。
- candidate/raw privacy boundary preserved（只读、不进研究层）。

---

## 9. Migration Execution Plan

> **只设计步骤，不执行**。每步给 Input / Action / Expected result / Validation / Rollback。未验证的具体 DSH CLI 命令不写死；如需，标 [UNKNOWN] 并在 3.2/3.3 实测。

**Step 1 — Prepare target DSH workspace**
- Input：源 project path（`D:\Projects\Personal Job Search OS`）、目标 profile 决定。
- Action：确认采用既有目录为 workspace 的方式与 profile；必要时只读校验目录 adopt 可行性。具体命令 [UNKNOWN]。
- Expected：workspace 被 DSH 采用/可见，源目录未改动。
- Validation：`workspace` 登记成功；源 git/文件未变。
- Rollback：若采用只是注册（不复制/不移动），则删除注册即回滚（源目录不动）。[INFERENCE]

**Step 2 — Copy project files（若采用纯 adopt 则可能为 no-op / 仅确认）**
- Input：源目录文件。
- Action：若目标方案要求复制才复制；首选 adopt 则跳过复制（源即目标）。[INFERENCE]
- Expected：目标 workspace 中可见全部项目文件。
- Validation：文件清单与源一致；hash/计数核对。
- Rollback：未复制 = 无回滚负担；已复制则删除副本。

**Step 3 — Ensure CLAUDE.md is available to dsh-agent-instructions**
- Input：CLAUDE.md 位于 workspace 根（含 `.git` root marker）。
- Action：确认 `dsh-agent-instructions` 会把它作为 project candidate 读取（默认候选含 CLAUDE.md）。[FACT]
- Expected：CLAUDE.md 内容进入 agent instruction baseline。
- Validation：在 session 中验证 instruction 注入（见 §10 instruction recognition）。
- Rollback：不修改 CLAUDE.md；只需切换 workspace/停用即可脱离。

**Step 4 — Start a fresh DSH session**（不迁旧 session）
- Input：目标 workspace + 选定 profile + 空 session。
- Action：开新 session；**不**尝试迁移/恢复任何 Claude Code 或旧 DSH session。
- Expected：全新 session，cwd 指向 workspace。
- Validation：session header 正确；无旧上下文污染。
- Rollback：结束/丢弃该 session 即可，无副作用。

**Step 5 — Validate project understanding**
- Input：项目文件。
- Action：让 Agent 只读叙述项目 identity/modules/core objects/architecture。
- Expected：Agent 正确识别（见 §10 project recognition）。
- Validation：问答/摘要与源文档一致。
- Rollback：无写操作，自然可重来。

**Step 6 — Validate instruction enforcement**
- Input：CLAUDE.md 规则。
- Action：用只读问答验证关键规则是否被遵守（不要求背诵，看行为）。
- Expected：行为体现 Fact/Evidence/Claim、DATA_GAP vs SKILL_GAP 等规则。
- Validation：见 §10 instruction recognition。
- Rollback：无写操作。

**Step 7 — Validate privacy boundaries**
- Input：candidate/raw 等。
- Action：确认 Agent 不读取/不输出 raw PII；确认研究/文档层无 PII。
- Expected：隐私边界成立。
- Validation：见 §10 privacy validation。
- Rollback：无写操作。

**Step 8 — Validate safe read/write behavior**
- Input：workspace。
- Action：在**安全测试位置**做最小只读/写测试，不碰真实 Job Search 数据。
- Expected：read/edit/write 边界正确；写操作限制在测试位置。
- Validation：见 §10 filesystem validation。
- Rollback：删除测试产物即可。

**Step 9 — Only then consider real work**
- Input：前述全部通过。
- Action：才评估是否允许 Agent 在真实项目数据上工作。
- Expected：在有明确授权前提下才进入真实使用。
- Validation：用户显式授权。
- Rollback：不授权则不进入。

> 注：Step 9 之前全部为验证性质；真实数据使用必须获得明确授权，且不在本 migration plan 默认动作内。

---

## 10. Validation Plan

### Project recognition
DSH Agent 能正确识别：project identity、modules、core objects（16 个）、architecture。验证方式：只读问答/摘要与源文档对照。

### Instruction recognition
能正确体现 CLAUDE.md 关键规则（不要求背诵全文，验证**是否实际影响行为**）：
- Fact / Evidence / Claim boundary
- DATA_GAP vs SKILL_GAP（不自动升级）
- Match Analysis 不修改 Candidate Fact
- Resume ≠ Fact Source
- privacy rules
验证方式：构造只读场景询问/约束测试，观察 Agent 决策是否符合规则。

### File-system validation
验证 read / edit / write / workspace boundary。
- 第一次真实写入必须选择**安全测试位置**（临时/脱敏目录），**不能**直接修改真实 Job Search 数据。
- 验证写入被限制在允许的 workspace 范围、sandbox 生效。

### Privacy validation
验证 `candidate/raw/` 等私人数据边界：Agent 不读取/不回显 PII；研究/文档层无 PII；测试用 synthetic/redacted data（呼应源项目 Privacy Rule + DSH 纪律）。

---

## 11. Rollback Plan

核心原则：
- **Source project untouched**：源项目永不被 DSH 运行失败破坏。
- **migration is additive / reversible**：首选 adopt（不复制/不移动）使「撤销」= 移除 workspace 注册即可，源目录不动。[INFERENCE]
- **DSH runtime failure must not corrupt source project**。
- **不需要恢复 Claude Code runtime**（本就未迁）。
- **不需要恢复 DSH `$DSH_HOME`**（本就未迁/未改）。

未验证项：
- 实际 rollback 的**确切执行机制**（如何移除一个 adopt 的 workspace 注册、是否会触碰源目录）[UNKNOWN]，写入 3.2/3.3 验证。

---

## 12. Git Strategy

- Git **不迁移为 DSH mechanism**。[FACT/INFERENCE]
- 但 Personal Job Search OS 的 Git repository 仍是项目本身的 **version-control asset**，保留。[FACT]
- 第一轮 migration：**不执行 git write、不 commit、不改变 remote、不改变 branch**。
- 之后是否继续原 Git workflow：列为 **operational decision**（用户后续决定），**不是 migration prerequisite**。[RECOMMENDATION]

---

## 13. Skill Strategy

```
.claude/skills/job-search/
    ↓
RECREATE later
```
第一轮**不重建**。原因：
- 当前只是 skeleton（未实现逻辑）。[FACT]
- 没有成熟行为值得直接转换。[FACT]
- 应等基础 migration 成功、真实使用场景出现后再设计 DSH skill。[RECOMMENDATION]

---

## 14. Migration Phases

- **Phase 3.1 — Design**：生成本文件 `13-migration-plan.md`。[FACT]
- **Phase 3.2 — Preflight / actual adoption / runtime injection verification**：**已执行**（Step 1 源码、Step 1B adopt 验收、Step 2A 源码、Step 2B runtime 取证）→ **全部 PASS**。结果见 `14-phase32-execution-verification.md`。[FACT]
- **Phase 3.3 — Minimal Migration**：迁移 project knowledge + project instruction loading（§7 第一批）。**未开始**。
- **Phase 3.4 — Validation**：验证 agent understanding / instruction / privacy / filesystem（§10）。**未开始**。
- **Phase 3.5 — Optional Recreate**：按实际需要重建 skill / DSH-specific automation（§13）。**未开始**。

> **[UPDATED 2026-09]** 实际执行顺序比本文原计划更细：Phase 3.2 拆成 Step 1（源码）/1B（adopt 验收）/2A（instruction 源码）/2B（runtime 注入取证），全部 PASS。

---

## 15. Remaining UNKNOWNs

> 只列仍未确认且与 migration execution 有关者。区分 BLOCKING / NON-BLOCKING。不把已解决项重列为 UNKNOWN。
> **[UPDATED 2026-09]** 原两个 BLOCKING 已由 Phase 3.2 解决 → 标 **RESOLVED**（保留行以便追溯）。

| UNKNOWN | 相关 Phase | 状态 |
|---|---|---|
| ~~`workspace.create({path})` adopt 既有含 `.git`+大目录+私人子目录项目是否无副作用/能否实测成功~~ | 3.2 | **RESOLVED** — Step 1 源码（§A）+ Step 1B 实测（§B）：可 adopt、项目零副作用。见 `14` §A/§B。[FACT] |
| ~~`dsh-agent-instructions` 在目标 workspace 下的实际加载验证（CLAUDE.md 是否真被注入）~~ | 3.2 | **RESOLVED** — Step 2A 源码（§C）+ Step 2B runtime 取证（§D）：确实注入。见 `14` §C/§D。[FACT] |
| target workspace/profile 的具体初始化流程 | 3.2/3.3 | **部分 RESOLVED** — workspace 登记路径已实测（web 面 `workspace.create`）；「是否需专用 profile」仍 [UNKNOWN]（当前用 shipped `web` 即可）。 |
| agent preset 是否需额外承担 CLAUDE.md 某些职责 | 3.5（优化） | **NON-BLOCKING**（当前 `dsh-agent-instructions` 已够用；属优化项） |
| `candidate/raw/` 的最终 operational placement（是否授权 DSH 可写/可读范围） | 3.3（授权） | **NON-BLOCKING**（隐私/运营决策，非技术 blocker） |
| rollback 的具体执行方式（如何移除 adopt 注册而不触源） | 3.3 | **NON-BLOCKING** — 机制已确认「`delete` 只删注册、不动目录」（`14` §A.2）；**实测**移除待 Phase 3.3。 |
| 迁移后写入 sandbox 的确切边界配置 | 3.3/3.4 | **NON-BLOCKING**（当前观测值 `sandbox/mode=workspace-write`、`approval=ask`；验证时确定） |
| server 端最终请求 payload 的字节级组装（注入消息 → 模型输入最后一跳） | 3.4 | **NON-BLOCKING**（注入到 step 1 durable message 已实证；末跳为 INFERENCE） |

> 注：Phase 2 已解决（如「CLAUDE.md 机制存在」「session 不迁」「machine state 不迁」「Git 保留为资产」）**不**在此重列。

---

## 16. Migration Readiness

## READY WITH CAVEATS

- **Phase 3.2 已执行完毕且全部 PASS**（adopt + instruction 承载已端到端证实）；原两个 BLOCKING UNKNOWN 均已 RESOLVED。
- 当前已足以进入 **Phase 3.3 Minimal Migration**（真实项目数据使用 / 写入安全 / privacy 运行期验证），但**尚未执行**，且必须等明确指令。
- Caveats：① CLAUDE.md 仍是 one-to-many（指令由 `dsh-agent-instructions` 承载；约束无声明式 schema）；② `candidate/raw` 的授权范围与 privacy 运行期验证未做；③ rollback 的**实测**未做；④ skill 重建未做；⑤ 宿主端最终 prompt 组装末跳未被直接观察（INFERENCE）。
- 详见 `12-migration-decision.md` §9 的 caveats 与 `14-phase32-execution-verification.md` §D.11/§E。

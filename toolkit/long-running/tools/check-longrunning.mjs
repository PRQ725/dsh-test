// check-longrunning.mjs — T1：只读 Evaluator（严格依据 Long-running v0.2 正式就绪条件）
// =============================================================================
// 契约来源：已发布 `91-tools/long-running/v0.2/`
//   · `README.md` Step 10.5 / Step 10.6（12 项初始化就绪 + 四个裁决不得混用）
//   · `SKILL.md`「Guarantee scope of each check」/「Initialization readiness」
//   · `templates/GOAL.md` / `templates/STATE.md` / `templates/EVALUATION.md`（字段清单）
//
// 本程序的性质（v0.2 §B 的硬要求）：
//   · **只读**：不写任何文件（除 stdout/stderr）；
//   · **只看产物**：**不读**任何模型自述的完成声明；
//   · **固定退出码**：0 = PASS（机械项全过）；1 = FAIL（打印逐条理由）；2 = ERROR（调用不可用）。
//
// ⚠️ **它不是验收**。v0.2 明载：机械通过只证明「结构 / 必需字段 / 内部引用」成立，
//    **必要而非充分**。人类门（权限边界、计划批准、evaluator 测试充分性）**永远**报 `PENDING`/`POLICY`。
//
// 用法：
//   node toolkit/long-running/tools/check-longrunning.mjs --instance-root <dir> [--json]
//   node toolkit/long-running/tools/check-longrunning.mjs --goal-contract <dir>/GOAL.md [--json]
//   node toolkit/long-running/tools/check-longrunning.mjs --instance-hygiene <dir>   # 弱检查：只验目录
//   node toolkit/long-running/tools/check-longrunning.mjs --self-test
//
// `--goal-contract` 与 `--instance-root` 等价（`--instance-root` 内部即读其 `GOAL.md`）。
// **缺 contract 时，本程序拒绝降级**：`--instance-hygiene` 是**唯一**不做 contract 校验的模式，
// 且其输出**显式**打印 `CONTRACT NOT CHECKED`（v0.2 §A.3「Refuse, do not downgrade」）。
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const EXIT = Object.freeze({ PASS: 0, FAIL: 1, ERROR: 2 });
export const VERDICT = Object.freeze({
  PASS: 'PASS', POLICY: 'POLICY', PENDING: 'PENDING', FAIL: 'FAIL', NA: 'N/A',
  // ── 2026-10-14 修复（G9）────────────────────────────────────────────────────
  // 缺陷：本表**缺 `UNKNOWN`**，但 `checkReadiness` 第 5 项在无法解析 evaluator 路径时
  //   返回 `VERDICT.UNKNOWN` ⇒ 得到 `undefined` ⇒ `renderText` 的 `it.verdict.padEnd(7)`
  //   抛 `TypeError`，**整个检查器崩溃**，连"哪一项不达标"都无法报告。
  // 纪律：`UNKNOWN` **不等于** `PASS`；它计入 `mechanicalUnknown`，且 `ok` 判定未把它当通过。
  UNKNOWN: 'UNKNOWN', ERROR: 'ERROR',
});

const HERE = path.dirname(fileURLToPath(import.meta.url));
/** repo root = prep/ → long-running/ → 91-tools/ → <root> */
export const REPO_ROOT = path.resolve(HERE, '..');  // toolkit/long-running（本 toolkit 的根）

const sha16 = (t) => crypto.createHash('sha256').update(t, 'utf8').digest('hex').slice(0, 16);
const read = (p) => fs.readFileSync(p, 'utf8');
const stripMd = (s) => String(s ?? '').replace(/`/g, '').replace(/\*\*/g, '').trim();

/** v0.2 `templates/GOAL.md` 的字段清单（顺序即模板顺序） */
export const GOAL_FIELDS = Object.freeze([
  'Objective', 'Success criteria', 'Scope boundaries', 'Non-goals', 'Evidence requirements',
  'Budget', 'Stop conditions', 'Human escalation', 'Instance root', 'Report path',
  'Report owner', 'Acceptance authority', 'Evaluator location', 'Version assumptions',
  'Recovery expectations',
]);
/** v0.2 `templates/STATE.md` 的字段清单 */
export const STATE_FIELDS = Object.freeze([
  'Round', 'Completed', 'Verified facts', 'Open questions', 'Next step', 'Artifacts',
  'Evidence', 'Budget used', 'Recovery also needs',
]);
/** v0.2 `templates/EVALUATION.md` 的字段清单 */
export const EVALUATION_FIELDS = Object.freeze([
  'Evaluation contract', 'Machine checks', 'Evidence quality', 'Human review',
  'Evaluator implementation', 'How the evaluator is authored', 'Frozen', 'Test cases',
  'Tamper check', 'Independence', "Guarantee scope of this project's checks",
  'Initialization readiness',
]);

const UNFILLED = /UNFILLED/;
/**
 * 「字段**未填**」的判定。
 * ⚠️ 不能用裸 `/UNFILLED/`：v0.2 模板在字段体内会**解释该标记本身**
 *   （如 EVALUATION.md 的 `Test cases:` 段含「The `UNFILLED` marker means…」）
 *   ⇒ 裸匹配会把**已填字段**误判为空白（曾致假 FAIL）。
 * 只认「字段体内**独立成行**的 UNFILLED 说明块」或「紧贴字段名后的 UNFILLED」。
 */
const unfilledInField = (body) => String(body ?? '')
  .split(/\r?\n/)
  .some((l) => /^\s*UNFILLED\b/.test(l));
const PLACEHOLDER = /\[(?:project|NAME|NAME\]|path|date|…|\.\.\.)\]|<[a-z-]+>|TODO|TBD|XXX/i;

/**
 * 解析「`Field:` 后跟内容直到下一个已知 `Field:`」的字段块。
 * @returns {Map<string,string>} 字段名 → 内容（未去空行）
 */
export function parseFieldBlocks(text, fields) {
  const lines = String(text ?? '').split(/\r?\n/);
  const heads = new Map();
  for (const f of fields) {
    const re = new RegExp(`^${f.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*:\\s*(.*)$`);
    for (let i = 0; i < lines.length; i += 1) {
      const m = re.exec(lines[i].trim());
      if (m) { heads.set(f, { i, inline: m[1] ?? '' }); break; }
    }
  }
  const ordered = [...heads.entries()].sort((a, b) => a[1].i - b[1].i);
  const out = new Map();
  for (let k = 0; k < ordered.length; k += 1) {
    const [f, { i, inline }] = ordered[k];
    const end = k + 1 < ordered.length ? ordered[k + 1][1].i : lines.length;
    const body = [inline, ...lines.slice(i + 1, end)].join('\n').trim();
    out.set(f, body);
  }
  return out;
}

/** 归一化路径用于「声明 vs 实际」比较（v0.2 要求：归一化比较，非肉眼） */
export function normalizeRel(p, base = REPO_ROOT) {
  if (p === null || p === undefined) return null;
  let s = String(p).trim().replace(/^["'`]|["'`]$/g, '');
  if (!s) return null;
  s = s.replace(/\\/g, '/');
  const abs = path.isAbsolute(s) ? path.resolve(s) : path.resolve(base, s);
  let rel = path.relative(base, abs).replace(/\\/g, '/');
  if (rel === '') rel = '.';
  return rel.replace(/\/+$/, '').toLowerCase();
}

/** 收集 `Artifacts:` 等段落里的路径字面量 */
export function pathsIn(text) {
  const out = [];
  for (const m of String(text ?? '').matchAll(/`([^`\n]+)`/g)) out.push(m[1]);
  for (const m of String(text ?? '').matchAll(/(?:^|\s)((?:[A-Za-z]:\\|\/|\.\/)?[\w./\\()\u4e00-\u9fa5 -]+\.[A-Za-z0-9]{1,6})/g)) out.push(m[1]);
  return [...new Set(out.map((x) => x.trim()).filter(Boolean))];
}

/** 目录基本卫生（v0.2 的 INSTANCE HYGIENE，**弱检查**） */
export function checkHygiene(instanceRoot) {
  const items = [];
  const exists = fs.existsSync(instanceRoot) && fs.statSync(instanceRoot).isDirectory();
  items.push({ id: 'H1', claim: 'instance 目录可达且为目录', verdict: exists ? VERDICT.PASS : VERDICT.FAIL, detail: instanceRoot });
  if (!exists) return { ok: false, items };
  const files = fs.readdirSync(instanceRoot);
  // 「不是 toolkit 自己的 templates/」：templates/ 只有 5 个模板且都是 UNFILLED
  const isToolkitTemplates = files.includes('GOAL.md') && files.includes('PLAN.md') && files.includes('STATE.md')
    && files.includes('EVALUATION.md') && files.includes('FINAL-REPORT.md')
    && files.every((f) => f.endsWith('.md'));
  items.push({
    id: 'H2', claim: '不是 toolkit 自身的 templates/（未被就地填写）',
    verdict: isToolkitTemplates ? VERDICT.FAIL : VERDICT.PASS,
    detail: isToolkitTemplates ? '疑似 toolkit templates 目录本身' : 'ok',
  });
  const markers = [];
  for (const f of ['GOAL.md', 'PLAN.md', 'STATE.md', 'EVALUATION.md']) {
    const p = path.join(instanceRoot, f);
    if (fs.existsSync(p) && read(p).split(/\r?\n/).some((l) => /^\s*UNFILLED\b/.test(l))) markers.push(f);
  }
  items.push({
    id: 'H3', claim: '存在真实实例文档且**无** UNFILLED 空白表单标记',
    verdict: markers.length === 0 ? VERDICT.PASS : VERDICT.FAIL,
    detail: markers.length ? `仍含 UNFILLED: ${markers.join(', ')}` : '无 UNFILLED',
  });
  return { ok: items.every((x) => x.verdict === VERDICT.PASS), items };
}

/**
 * 12 项初始化就绪（v0.2 Step 10.5 契约，**逐项**给裁决）。
 * 人类门恒为 `PENDING`/`POLICY`，**永不** `PASS`。
 */
export function checkReadiness(instanceRoot) {
  const items = [];
  const P = (n, claim, verdict, kind, detail) => items.push({ id: String(n), claim, verdict, kind, detail });
  const gPath = path.join(instanceRoot, 'GOAL.md');
  const pPath = path.join(instanceRoot, 'PLAN.md');
  const sPath = path.join(instanceRoot, 'STATE.md');
  const ePath = path.join(instanceRoot, 'EVALUATION.md');

  const has = (p) => fs.existsSync(p);
  const goal = has(gPath) ? read(gPath) : '';
  const goalFields = goal ? parseFieldBlocks(goal, GOAL_FIELDS) : new Map();
  const goalMissing = GOAL_FIELDS.filter((f) => !goalFields.has(f));
  const goalBlank = GOAL_FIELDS.filter((f) => goalFields.has(f) && (unfilledInField(goalFields.get(f)) || !goalFields.get(f).trim()));
  const goalPlaceholder = GOAL_FIELDS.filter((f) => goalFields.has(f) && PLACEHOLDER.test(goalFields.get(f)));

  // 1 GOAL.md exists and is filled
  P(1, 'GOAL.md 存在且已填充', has(gPath) && goalMissing.length === 0 && goalBlank.length === 0 ? VERDICT.PASS : VERDICT.FAIL, 'mechanical',
    !has(gPath) ? '缺文件' : [goalMissing.length ? `缺字段: ${goalMissing.join(', ')}` : '', goalBlank.length ? `空/UNFILLED: ${goalBlank.join(', ')}` : '', goalPlaceholder.length ? `疑似占位符: ${goalPlaceholder.join(', ')}` : ''].filter(Boolean).join(' | ') || 'ok');

  // 2 PLAN.md exists with an approval record — record=mechanical, approval=HUMAN GATE
  const plan = has(pPath) ? read(pPath) : '';
  const hasApprovalRecord = /approv/i.test(plan);
  P(2, 'PLAN.md 存在且含批准记录', has(pPath) && hasApprovalRecord && !unfilledInField(plan) ? VERDICT.PASS : VERDICT.FAIL, 'mechanical',
    !has(pPath) ? '缺文件' : (!hasApprovalRecord ? '未找到批准记录' : (unfilledInField(plan) ? '仍含 UNFILLED' : 'ok')));
  P('2h', 'PLAN.md 的批准**本身**是人工门（记录存在 ≠ 有人批准）', VERDICT.PENDING, 'human-gate',
    'v0.2：finding「approved by」只证明记录存在，不证明有人批准');

  // 3 STATE.md initialized
  const state = has(sPath) ? read(sPath) : '';
  const stateFields = state ? parseFieldBlocks(state, STATE_FIELDS) : new Map();
  const stateMissing = STATE_FIELDS.filter((f) => !stateFields.has(f));
  const stateBlank = STATE_FIELDS.filter((f) => stateFields.has(f) && unfilledInField(stateFields.get(f)));
  P(3, 'STATE.md 已初始化', has(sPath) && stateMissing.length === 0 && stateBlank.length === 0 ? VERDICT.PASS : VERDICT.FAIL, 'mechanical',
    !has(sPath) ? '缺文件' : [stateMissing.length ? `缺字段: ${stateMissing.join(', ')}` : '', stateBlank.length ? `UNFILLED: ${stateBlank.join(', ')}` : ''].filter(Boolean).join(' | ') || 'ok');

  // 4 EVALUATION.md exists and is filled
  const ev = has(ePath) ? read(ePath) : '';
  const evFields = ev ? parseFieldBlocks(ev, EVALUATION_FIELDS) : new Map();
  const evMissing = EVALUATION_FIELDS.filter((f) => !evFields.has(f));
  const evBlank = EVALUATION_FIELDS.filter((f) => evFields.has(f) && unfilledInField(evFields.get(f)));
  P(4, 'EVALUATION.md 存在且已填充', has(ePath) && evMissing.length === 0 && evBlank.length === 0 ? VERDICT.PASS : VERDICT.FAIL, 'mechanical',
    !has(ePath) ? '缺文件' : [evMissing.length ? `缺字段: ${evMissing.join(', ')}` : '', evBlank.length ? `UNFILLED: ${evBlank.join(', ')}` : ''].filter(Boolean).join(' | ') || 'ok');

  // 5 a project-specific evaluator exists
  const evLoc = goalFields.get('Evaluator location') ?? '';
  let evPath = null;
  let evHashRecorded = false;
  const pathLike = pathsIn(evLoc).filter((x) => /\.(mjs|js|cjs|ps1|py|sh|ts)$/i.test(x));
  if (pathLike.length) {
    const cand = pathLike.map((x) => (path.isAbsolute(x) ? x : path.join(REPO_ROOT, x))).find((x) => fs.existsSync(x));
    if (cand) { evPath = cand; evHashRecorded = /[0-9a-f]{16,}/i.test(evLoc); }
  }
  P(5, '存在项目专属 evaluator（且其路径可解析）', evPath ? VERDICT.PASS : VERDICT.UNKNOWN, 'mechanical',
    evPath ? path.relative(REPO_ROOT, evPath).replace(/\\/g, '/') : `Evaluator location 未给出可解析的可执行路径（原值: ${stripMd(evLoc).slice(0, 100) || '(空)'}）`);

  // 6 evaluator has PASS/FAIL/ERROR test evidence — record=mechanical; ADEQUACY=human gate
  const tc = evFields.get('Test cases') ?? '';
  const has3 = /exit\s*0|PASS/i.test(tc) && /exit\s*1|FAIL/i.test(tc) && /exit\s*2|ERROR/i.test(tc);
  P(6, 'evaluator 的 PASS/FAIL/ERROR 测试证据已记录', has3 ? VERDICT.PASS : VERDICT.FAIL, 'mechanical',
    has3 ? '三态均有记录' : '未同时记录 PASS/FAIL/ERROR 三态');
  P('6h', 'evaluator 测试是否**充分**属人工判断', VERDICT.POLICY, 'human-gate', 'v0.2：adequacy is a human judgement');

  // 7 freeze baseline (hash) recorded
  const frozen = evFields.get('Frozen') ?? '';
  const hashOk = /[0-9a-f]{16,}/i.test(frozen) || evHashRecorded;
  P(7, 'evaluator 冻结基线（SHA256）已记录', hashOk ? VERDICT.PASS : VERDICT.FAIL, 'mechanical',
    hashOk ? '找到 hash' : 'Frozen 段与 Evaluator location 均未见 hash');

  // 8 budget and stop conditions stated
  const bud = goalFields.get('Budget') ?? '';
  const stop = goalFields.get('Stop conditions') ?? '';
  const budOk = /HARD/.test(bud) && /SOFT/.test(bud) && /\d/.test(bud);
  const stopOk = /HARD/.test(stop) && /SOFT/.test(stop);
  P(8, '预算与停止条件已声明（含 HARD/SOFT 标注）', budOk && stopOk ? VERDICT.PASS : VERDICT.FAIL, 'mechanical',
    [!budOk ? 'Budget 需含 HARD/SOFT 与轮次数字' : '', !stopOk ? 'Stop conditions 需含 HARD/SOFT' : ''].filter(Boolean).join(' | ') || 'ok');

  // 9 workspace & permission boundary verified — HUMAN GATE
  P(9, '工作区与权限边界已被确认', VERDICT.PENDING, 'human-gate', 'v0.2：no mechanical proof of what a person accepted');

  // 10 instance-root consistency (normalized comparison)
  const declared = stripMd(goalFields.get('Instance root') ?? '');
  const declaredPath = (/^[A-Za-z]:[\\/]|^\//.test(declared) ? declared : path.join(REPO_ROOT, declared));
  const a = normalizeRel(declared, REPO_ROOT);
  const b = normalizeRel(instanceRoot, REPO_ROOT);
  const consistent = declared ? a === b : false;
  P(10, 'instance-root 一致性（归一化比较）', consistent ? VERDICT.PASS : (declared ? VERDICT.FAIL : VERDICT.FAIL), 'mechanical',
    `声明=${a ?? '(缺)'} | 实际=${b}`);

  // 11 required human approvals recorded — HUMAN GATE
  P(11, '所需人工批准已记录', VERDICT.PENDING, 'human-gate', 'v0.2：recorded approval is POLICY, not PASS');

  // 12 report path and owner determined
  const rp = stripMd(goalFields.get('Report path') ?? '');
  const ro = stripMd(goalFields.get('Report owner') ?? '');
  P(12, '最终报告路径与 owner 已确定', rp && ro && !UNFILLED.test(rp + ro) ? VERDICT.PASS : VERDICT.FAIL, 'mechanical',
    [!rp ? 'Report path 空' : '', !ro ? 'Report owner 空' : ''].filter(Boolean).join(' | ') || `path=${rp.slice(0, 60)} owner=${ro.slice(0, 40)}`);

  // 13 FINAL-REPORT 终态（若已生成）：必须声明五态之一，且不得是 DRAFT
  const frAbs = rp ? path.resolve(REPO_ROOT, rp) : null;
  let frVerdict = VERDICT.PASS;
  let frDetail = 'FINAL-REPORT 尚未生成（就绪检查不要求；Goal 结束时必须为终态）';
  if (frAbs && fs.existsSync(frAbs)) {
    const fr = read(frAbs);
    const m = /Terminal status:\s*`?([A-Z_]+)`?/i.exec(fr);
    if (!/Terminal status:/i.test(fr)) {
      frVerdict = VERDICT.PASS;
      frDetail = 'legacy report（无 Terminal status 字段，按兼容放行）';
    } else {
      const status = (m?.[1] ?? '').toUpperCase();
      const ok = ['COMPLETE', 'COMPLETE_WITH_EXCEPTIONS', 'BLOCKED', 'PAUSED_FOR_HUMAN', 'FAILED'].includes(status) && !/\bDRAFT\b/.test(fr);
      frVerdict = ok ? VERDICT.PASS : VERDICT.FAIL;
      frDetail = ok ? `Terminal status=${status}` : `非法 Terminal status 或包含 DRAFT（当前=${status || '缺省'}）`;
    }
  }
  P(13, 'FINAL-REPORT 终态声明（若存在）', frVerdict, 'mechanical', frDetail);

  // 14 授权模式（若声明）：Planning 不得 UNFILLED；Execution 必须 PENDING_HUMAN/GRANTED
  const goalText = goal;
  const pa = /^Planning authorization:\\s*(.+)$/mi.exec(goalText);
  const ea = /^Execution authorization:\\s*(.+)$/mi.exec(goalText);
  let authVerdict = VERDICT.PASS; let authDetail = 'legacy（未声明授权模式字段）';
  if (pa || ea) {
    const paOk = pa && !/UNFILLED/i.test(pa[1]);
    const eaOk = ea && /^(PENDING_HUMAN|GRANTED)\\b/i.test(ea[1].trim());
    authVerdict = paOk && eaOk ? VERDICT.PASS : VERDICT.FAIL;
    authDetail = authVerdict === VERDICT.PASS ? 'Planning complete; Execution=' + ea[1].trim() : 'Planning 未完成或 Execution 非 PENDING_HUMAN/GRANTED';
  }
  P(14, '授权模式声明（若存在）', authVerdict, 'mechanical', authDetail);

  // 15 预算语义：只有 maxGoalRounds 可标 HARD；逻辑轮数不得标 HARD
  const budgetText = goalFields.get('Budget') ?? '';
  const hardLogical = /HARD[^\n]{0,60}logical/i.test(budgetText);
  P(15, '逻辑预算未标 HARD', hardLogical ? VERDICT.FAIL : VERDICT.PASS, 'mechanical',
    hardLogical ? 'Budget 将 logical 标为 HARD；应改为 SOFT logical + Native maxGoalRounds HARD' : 'ok');

  const mechanical = items.filter((x) => x.kind === 'mechanical');
  const mechanicalFail = mechanical.filter((x) => x.verdict === VERDICT.FAIL);
  const mechanicalUnknown = mechanical.filter((x) => x.verdict === VERDICT.UNKNOWN);
  // G9 修复：结构性缺陷（缺 verdict / 非法 verdict）必须可诊断，且**不得**当作通过
  const structural = items.filter((x) => typeof x.verdict !== 'string' || !x.verdict.trim());
  return {
    ok: mechanicalFail.length === 0 && mechanicalUnknown.length === 0 && structural.length === 0,
    items,
    mechanicalTotal: mechanical.length,
    mechanicalFail: mechanicalFail.length,
    mechanicalUnknown: mechanicalUnknown.length,
    structural: structural.map((x) => String(x.id ?? '(no-id)')),
    humanGates: items.filter((x) => x.kind === 'human-gate').map((x) => x.id),
    hashes: { goal: goal ? sha16(goal) : null, plan: plan ? sha16(plan) : null, state: state ? sha16(state) : null, evaluation: ev ? sha16(ev) : null },
    declaredInstanceRoot: a,
  };
}

// ------------------------------------------------------------------ CLI
export function renderText(res) {
  const L = [];
  L.push(`Long-running instance check  (mode=${res.mode})`);
  L.push(`  instance root : ${res.instanceRoot}`);
  if (res.mode === 'hygiene') L.push('  *** CONTRACT NOT CHECKED ***  （hygiene 模式不读 GOAL.md，不能主张 adoption/readiness）');
  L.push('');
  for (const it of res.items) {
    // G9 修复：缺失 verdict 一律**结构化降级**为 ERROR（**绝不**当作 PASS，也绝不崩溃）
    const raw = it && typeof it.verdict === 'string' && it.verdict.trim() ? it.verdict : null;
    const tag = (raw ?? VERDICT.ERROR).padEnd(7);
    const idTxt = it.id === undefined || it.id === null || it.id === '' ? '(no-id)' : String(it.id);
    L.push(`  [${tag}] ${idTxt.padStart(2)}. ${it.claim ?? '(no-claim)'}${it.kind === 'human-gate' ? '  ‹human gate›' : ''}`);
    if (!raw) L.push('            ⚠ STRUCTURAL: 该项未提供合法 verdict ⇒ 按 ERROR 处理（不计入通过）');
    if (it.detail) L.push(`            ${it.detail}`);
  }
  L.push('');
  if (res.mode !== 'hygiene') {
    L.push(`  机械项: ${res.mechanicalTotal - res.mechanicalFail - (res.mechanicalUnknown ?? 0)}/${res.mechanicalTotal} 通过 · 失败 ${res.mechanicalFail} · UNKNOWN ${res.mechanicalUnknown ?? 0}`);
    if ((res.structural ?? []).length) L.push(`  ⚠ 结构性缺陷（缺 verdict ⇒ 计 ERROR，**不算通过**）: ${res.structural.join(', ')}`);
    L.push(`  人工门（恒为 PENDING/POLICY，本程序**不**能使其通过）: ${res.humanGates.join(', ')}`);
  }
  L.push('');
  L.push(`  VERDICT: ${res.ok ? (res.mode === 'hygiene' ? 'HYGIENE PASS (CONTRACT NOT CHECKED)' : 'MECHANICAL PASS') : (res.mode === 'hygiene' ? 'HYGIENE FAIL' : 'MECHANICAL FAIL')}`);
  L.push('  ⚠️ 机械通过**必要而非充分**；它**不**证明：人类批准、权限边界被接受、验收');
  L.push('     —— v0.2：a readiness report is NOT acceptance and arms nothing.');
  return L.join('\n');
}

export function evaluate({ mode, instanceRoot }) {
  if (mode === 'hygiene') {
    const h = checkHygiene(instanceRoot);
    return { mode, instanceRoot, ok: h.ok, items: h.items, mechanicalTotal: h.items.length, mechanicalFail: h.items.filter((x) => x.verdict === VERDICT.FAIL).length, humanGates: [] };
  }
  const r = checkReadiness(instanceRoot);
  return { mode, instanceRoot, ...r };
}

async function main(argv) {
  const val = (f) => { const i = argv.indexOf(f); return i >= 0 ? argv[i + 1] : null; };
  const has = (f) => argv.includes(f);
  const json = has('--json');

  if (has('--self-test')) {
    const { runSelfTest } = await import('./check-longrunning.selftest.mjs');
    process.exit(runSelfTest());
  }

  const hygiene = has('--instance-hygiene');
  const contractFlag = val('--goal-contract');
  const rootFlag = val('--instance-root');
  let instanceRoot = null;
  let mode = 'readiness';

  if (hygiene) {
    instanceRoot = val('--instance-hygiene') || rootFlag;
    mode = 'hygiene';
    if (!instanceRoot) { console.error('usage: --instance-hygiene <dir>'); process.exit(EXIT.ERROR); }
  } else if (contractFlag) {
    const gc = path.isAbsolute(contractFlag) ? contractFlag : path.join(REPO_ROOT, contractFlag);
    if (!fs.existsSync(gc)) { console.error(`ERROR: goal contract not found: ${contractFlag}`); process.exit(EXIT.ERROR); }
    instanceRoot = path.dirname(gc);
  } else if (rootFlag) {
    instanceRoot = rootFlag;
  } else {
    console.error('usage: node check-longrunning.mjs --instance-root <dir> | --goal-contract <dir>/GOAL.md | --instance-hygiene <dir> | --self-test');
    console.error('  note: 本程序**拒绝降级** —— 想只验目录请显式用 --instance-hygiene，其输出含 CONTRACT NOT CHECKED');
    process.exit(EXIT.ERROR);
  }

  const abs = path.isAbsolute(instanceRoot) ? instanceRoot : path.join(REPO_ROOT, instanceRoot);
  if (!fs.existsSync(abs)) { console.error(`ERROR: instance root not reachable: ${instanceRoot}`); process.exit(EXIT.ERROR); }

  const res = evaluate({ mode, instanceRoot: abs });
  if (json) console.log(JSON.stringify(res, null, 2));
  else console.log(renderText(res));
  process.exit(res.ok ? EXIT.PASS : EXIT.FAIL);
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))) {
  main(process.argv.slice(2));
}

export default { EXIT, VERDICT, GOAL_FIELDS, STATE_FIELDS, EVALUATION_FIELDS, parseFieldBlocks, normalizeRel, checkHygiene, checkReadiness, evaluate, REPO_ROOT };

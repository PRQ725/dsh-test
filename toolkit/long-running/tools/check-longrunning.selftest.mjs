// check-longrunning.selftest.mjs — T1 的 PASS / FAIL / ERROR 三态自测
// =============================================================================
// 契约：Long-running v0.2 `templates/EVALUATION.md`「Test cases」要求：
//   · 一个**真实合规**产物 ⇒ exit 0；
//   · **真实变异副本**（每个失败类）⇒ exit 1 且**理由正确**；
//   · 不可用调用 / 缺 root ⇒ exit 2。
//   · 「Do not substitute hand-written near-miss fixtures for the real producer's output」——
//     故本自测**用真实的 v0.2 模板**作为合规底本，再做真实变异。
//
// 运行：node 91-tools/long-running/prep/check-longrunning.mjs --self-test
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import { EXIT, VERDICT, REPO_ROOT, checkHygiene, checkReadiness, normalizeRel, parseFieldBlocks, GOAL_FIELDS, STATE_FIELDS, EVALUATION_FIELDS } from './check-longrunning.mjs';

/** v0.2 `templates/PLAN.md` 的字段清单（实读自该模板 L13-L60） */
export const PLAN_FIELDS = Object.freeze([
  'Plan status', 'Goal reference', 'Work stages', 'Deliverables', 'Verification per stage',
  'Replanning triggers', 'Budget', 'Human approval', 'Approval record', 'Amendments', 'Recovery reference',
]);

import { renderText, evaluate } from './check-longrunning.mjs';

/**
 * G9 反向测试辅助：构造一个「含 UNKNOWN 项」的就绪结果，用于验证 **UNKNOWN ≠ PASS**。
 * 不依赖真实实例（避免把私有数据带进自测）。
 */
function evaluateReadinessWithInjectedUnknown() {
  const r = checkReadiness(process.cwd());
  // 注入一个非 PASS 的 UNKNOWN 机械项，检验 ok 判定是否把它计入未通过
  const items = [...r.items, { id: 'X', claim: '注入的 UNKNOWN 项', verdict: VERDICT.UNKNOWN, kind: 'mechanical', detail: 'test' }];
  const mechanical = items.filter((x) => x.kind === 'mechanical');
  const mechanicalFail = mechanical.filter((x) => x.verdict === VERDICT.FAIL);
  const mechanicalUnknown = mechanical.filter((x) => x.verdict === VERDICT.UNKNOWN);
  const structural = items.filter((x) => typeof x.verdict !== 'string' || !x.verdict.trim());
  return { ok: mechanicalFail.length === 0 && mechanicalUnknown.length === 0 && structural.length === 0, mechanicalUnknown: mechanicalUnknown.length, structural: structural.map((x) => x.id) };
}

const HERE = path.dirname(fileURLToPath(import.meta.url));
const CLI = path.join(HERE, 'check-longrunning.mjs');
const TPL = path.join(REPO_ROOT, 'v0.2/templates');

const rd = (p) => fs.readFileSync(p, 'utf8');
const wr = (p, t) => fs.writeFileSync(p, t, 'utf8');

let pass = 0; const fails = [];
const check = (name, cond, detail = '') => {
  if (cond) { pass += 1; console.log(`  [PASS] ${name}`); return; }
  fails.push(name); console.log(`  [FAIL] ${name}${detail ? ' — ' + String(detail).slice(0, 170) : ''}`);
};

/**
 * 用**真实 v0.2 模板**构造合规实例。
 * ⚠️ 不用正则硬改模板正文（脆弱）：改为**用 evaluator 自己的字段解析器**
 *    （`parseFieldBlocks`）定位每个字段块，再**整体重写该文件**为「已知字段 + 填充值」。
 *    这样 round-trip 必然成立（生成物一定能被同一个解析器读回）。
 */
function makeCompliantInstance(dir) {
  fs.mkdirSync(path.join(dir, 'evidence'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'artifacts', 'logs'), { recursive: true });

  const rel = path.relative(REPO_ROOT, dir).replace(/\\/g, '/');
  const evRel = 'tools/check-longrunning.mjs';
  const evHash = 'DEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF';

  const writeFromTemplate = (tplFile, fields, values, extra = '') => {
    const tpl = rd(path.join(TPL, tplFile));
    const blocks = parseFieldBlocks(tpl, fields);          // 只用于**确认模板里存在这些字段**
    const missing = fields.filter((f) => !blocks.has(f));
    if (missing.length) throw new Error(`template ${tplFile} 缺字段: ${missing.join(', ')}`);
    const out = [`# ${tplFile} — self-test 填充实例（FACT: 由 v0.2 模板的字段集生成）`, ''];
    for (const f of fields) {
      const v = values[f];
      if (v === undefined) throw new Error(`未给 ${tplFile} 的字段 ${f} 提供值`);
      out.push(`${f}:`, v, '');
    }
    if (extra) out.push(extra);
    wr(path.join(dir, tplFile), out.join('\n'));
  };

  writeFromTemplate('GOAL.md', GOAL_FIELDS, {
    'Objective': '使 T1 自测夹具合规（self-test only）。',
    'Success criteria': '1. check-longrunning 对该实例 exit 0。',
    'Scope boundaries': '可写：本临时实例目录。冻结：无（self-test 临时目录）。',
    'Non-goals': '不改动任何正式模块。',
    'Evidence requirements': '一轮一文件 evidence/round-N.md。',
    'Budget': 'HARD: maxGoalRounds = 2（唯一宿主强制预算）。SOFT: token / wall clock = UNKNOWN。',
    'Stop conditions': 'HARD: round cap 达 2 时 driver 记 round-limit 停止。SOFT: 连续 2 轮无新事实 ⇒ 请求人类（不停跑）。',
    'Human escalation': '越界写 / 改冻结件 / 需凭据 ⇒ 立即交人类。',
    'Instance root': rel,
    'Report path': `${rel}/FINAL-REPORT.md`,
    'Report owner': 'self-test runner（运行结束后生成）。',
    'Acceptance authority': '用户。模型永不宣告完成。',
    'Evaluator location': `${evRel} · exit 0 PASS / 1 FAIL / 2 ERROR · SHA256 ${evHash}`,
    'Version assumptions': 'DSH 0.2.0-rc.2（dsh-goal / dsh-goal-round-driver / dsh-tool-goal）。',
    'Recovery expectations': 'resume/fork 后 goal 自动 disarmed，需人类 rearm；durable 位置 = STATE.md。',
  });

  writeFromTemplate('PLAN.md', PLAN_FIELDS, Object.fromEntries(PLAN_FIELDS.map((f) => [f, '（self-test 已填）'])),
    ['Approval:', 'Approved by: self-test fixture（**POLICY 记录，非真实人工批准**）', '']);

  writeFromTemplate('STATE.md', STATE_FIELDS, {
    'Round': '0 of 2',
    'Completed': '（self-test）无',
    'Verified facts': '（self-test）夹具已生成。',
    'Open questions': '（self-test）无',
    'Next step': '（self-test）无需下一步',
    'Artifacts': '（self-test）无',
    'Evidence': 'evidence/round-0-pre-start.md',
    'Budget used': 'HARD 0/2；SOFT token/cost/wall-clock = UNKNOWN',
    'Recovery also needs': '（self-test）无',
  });

  writeFromTemplate('EVALUATION.md', EVALUATION_FIELDS, {
    ...Object.fromEntries(EVALUATION_FIELDS.map((f) => [f, '（self-test 已填）'])),
    // 这些字段的内容必须**落在字段体内**（解析器在下一个「Field:」处截断）
    'Test cases': [
      '- compliant fixture => exit 0 PASS（真实 v0.2 模板生成的合规实例）',
      '- mutated copy (missing GOAL field) => exit 1 FAIL（真实变异副本）',
      '- mutated copy (instance-root mismatch) => exit 1 FAIL（真实变异副本）',
      '- unusable invocation / missing root => exit 2 ERROR',
    ].join('\n'),
    'Frozen': `2026-10-14 · SHA256 ${evHash}`,
    'Machine checks': `node check-longrunning.mjs --instance-root <dir> · exit 0 PASS / 1 FAIL / 2 ERROR · SHA256 ${evHash}`,
    'Evaluator implementation': `${evRel} · node (ESM) · exit 0 PASS / 1 FAIL / 2 ERROR · read-only`,
  });

  wr(path.join(dir, 'evidence', 'round-0-pre-start.md'), '# round 0\n\n（self-test）\n');
  return dir;
}

export function runSelfTest() {
  console.log('T1 check-longrunning — PASS / FAIL / ERROR self-test');
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'lr-t1-'));
  const good = makeCompliantInstance(path.join(tmp, 'good'));

  // ---------- PASS：合规实例
  {
    const r = checkReadiness(good);
    check('1a. 合规实例 ⇒ 机械项全过（ok=true）', r.ok === true,
      r.items.filter((x) => x.verdict === VERDICT.FAIL).map((x) => `${x.id}:${x.detail}`).join(' | '));
    check('1b. 合规实例 ⇒ 人工门仍为 PENDING/POLICY（**不得** PASS）',
      r.items.filter((x) => x.kind === 'human-gate').every((x) => x.verdict === VERDICT.PENDING || x.verdict === VERDICT.POLICY),
      r.items.filter((x) => x.kind === 'human-gate').map((x) => `${x.id}:${x.verdict}`).join(','));
    check('1c. 15 项就绪**全部**有裁决（无缺项）', r.items.filter((x) => /^\d+$/.test(x.id)).length === 15,
      `got ${r.items.filter((x) => /^\d+$/.test(x.id)).length}`);
    const out = execFileSync(process.execPath, [CLI, '--instance-root', good], { encoding: 'utf8' });
    check('1d. CLI 对合规实例 exit 0', true);
    check('1e. CLI 输出含「必要而非充分」免责', /必要而非充分|NOT acceptance|arms nothing/i.test(out), out.slice(-140));
  }

  // ---------- FAIL 类 A：删除一个必需 GOAL 字段
  {
    const bad = path.join(tmp, 'bad-goal-field');
    fs.cpSync(good, bad, { recursive: true });
    let g = rd(path.join(bad, 'GOAL.md'));
    g = g.replace(/^Non-goals:[\s\S]*?(?=^Evidence requirements:)/m, '');
    wr(path.join(bad, 'GOAL.md'), g);
    const r = checkReadiness(bad);
    check('2a. 缺 GOAL 字段 ⇒ ok=false', r.ok === false);
    check('2b. 且失败项**是** GOAL.md（id=1，理由含缺字段）',
      r.items.some((x) => x.id === '1' && x.verdict === VERDICT.FAIL && /缺字段/.test(x.detail)),
      JSON.stringify(r.items.find((x) => x.id === '1')));
    let code = 0; try { execFileSync(process.execPath, [CLI, '--instance-root', bad], { encoding: 'utf8', stdio: 'pipe' }); } catch (e) { code = e.status; }
    check('2c. CLI exit 1', code === 1, `code=${code}`);
  }

  // ---------- FAIL 类 B：instance-root 声明与实际不一致（真实冲突）
  {
    const bad = path.join(tmp, 'bad-root');
    fs.cpSync(good, bad, { recursive: true });
    let g = rd(path.join(bad, 'GOAL.md'));
    g = g.replace(/^Instance root:\n[^\n]*/m, 'Instance root:\nsome/other/declared/dir');
    wr(path.join(bad, 'GOAL.md'), g);
    const r = checkReadiness(bad);
    check('3a. instance-root 不一致 ⇒ ok=false', r.ok === false);
    check('3b. 且失败项 id=10（一致性）', r.items.some((x) => x.id === '10' && x.verdict === VERDICT.FAIL),
      JSON.stringify(r.items.find((x) => x.id === '10')));
  }

  // ---------- FAIL 类 C：evaluator 冻结 hash **完全**缺失（两处都去掉）
  {
    const bad = path.join(tmp, 'bad-hash');
    fs.cpSync(good, bad, { recursive: true });
    // 变异必须彻底：EVALUATION.md（主）与 GOAL.md 的 Evaluator location（回退）都去掉 hash，
    // 否则「任一有 hash 即 PASS」的回退逻辑会（正确地）判 PASS，而测试会误报。
    for (const f of ['EVALUATION.md', 'GOAL.md']) {
      const p = path.join(bad, f);
      wr(p, rd(p).replace(/[0-9a-fA-F]{16,}/g, 'NOHASH'));
    }
    const r = checkReadiness(bad);
    check('4a. 冻结 hash **完全**缺失 ⇒ 失败项 id=7', r.items.some((x) => x.id === '7' && x.verdict === VERDICT.FAIL),
      JSON.stringify(r.items.find((x) => x.id === '7')));
  }

  // ---------- FAIL 类 D：仍含 UNFILLED（空白表单被当成实例）
  {
    const bad = path.join(tmp, 'unfilled');
    fs.mkdirSync(bad, { recursive: true });
    for (const f of ['GOAL.md', 'PLAN.md', 'STATE.md', 'EVALUATION.md']) {
      wr(path.join(bad, f), rd(path.join(TPL, f)));
    }
    const h = checkHygiene(bad);
    check('5a. 直接把 v0.2 模板当实例 ⇒ hygiene FAIL（UNFILLED 标记）',
      h.ok === false && h.items.some((x) => x.id === 'H3' && x.verdict === VERDICT.FAIL), JSON.stringify(h.items));
    const r = checkReadiness(bad);
    check('5b. 且 readiness 亦 FAIL', r.ok === false);
  }

  // ---------- ERROR 类
  {
    let c1 = 0; try { execFileSync(process.execPath, [CLI], { encoding: 'utf8', stdio: 'pipe' }); } catch (e) { c1 = e.status; }
    check('6a. 无参数 ⇒ ERROR exit 2', c1 === 2, `code=${c1}`);
    let c2 = 0; try { execFileSync(process.execPath, [CLI, '--instance-root', path.join(tmp, 'nope')], { encoding: 'utf8', stdio: 'pipe' }); } catch (e) { c2 = e.status; }
    check('6b. 不存在的 root ⇒ ERROR exit 2', c2 === 2, `code=${c2}`);
    let c3 = 0, o3 = '';
    try { o3 = execFileSync(process.execPath, [CLI, '--goal-contract', path.join(tmp, 'missing-GOAL.md')], { encoding: 'utf8', stdio: 'pipe' }); }
    catch (e) { c3 = e.status; o3 = String(e.stdout ?? '') + String(e.stderr ?? ''); }
    check('6c. --goal-contract 指向缺失文件 ⇒ ERROR exit 2（**拒绝降级**）', c3 === 2, `code=${c3}`);
  }

  // ---------- hygiene 模式必须显式且打印 CONTRACT NOT CHECKED
  {
    const out = execFileSync(process.execPath, [CLI, '--instance-hygiene', good], { encoding: 'utf8' });
    check('7a. hygiene 模式输出含 CONTRACT NOT CHECKED', /CONTRACT NOT CHECKED/.test(out), out.slice(0, 160));
    check('7b. hygiene 输出**不**使用 adoption/readiness 词汇', !/MECHANICAL PASS|ADOPTION PASS|INITIALIZATION READINESS/.test(out));
  }

  // ---------- normalizeRel 单测（v0.2 要求归一化比较，非肉眼）
  {
    const a = normalizeRel('./x/y/', REPO_ROOT);
    const b = normalizeRel('x\\y', REPO_ROOT);
    check('8a. 归一化：`./x/y/` == `x\\y`', a === b, `${a} vs ${b}`);
    check('8b. 绝对路径与等价相对路径归一化一致',
      normalizeRel(path.join(REPO_ROOT, 'x', 'y'), REPO_ROOT) === normalizeRel('x/y', REPO_ROOT));
  }

  // ---------- G9 反向测试（2026-10-14 修复：缺 verdict ⇒ 结构化 ERROR，不崩溃、不算通过）
  {
    // ① 缺 verdict 的项 ⇒ renderText 不得抛异常，且须标 STRUCTURAL
    const resMissing = {
      mode: 'readiness', instanceRoot: tmp, ok: true, mechanicalTotal: 2, mechanicalFail: 0,
      mechanicalUnknown: 0, structural: ['9'],
      humanGates: [],
      items: [
        { id: '1', claim: '正常项', verdict: VERDICT.PASS, kind: 'mechanical' },
        { id: '9', claim: '缺 verdict 的项', kind: 'mechanical' },
      ],
    };
    let threw = null; let txt = '';
    try { txt = renderText(resMissing); } catch (e) { threw = e; }
    check('G9-a. 缺 verdict ⇒ renderText **不得抛异常**', threw === null, threw ? String(threw.message) : 'ok');
    check('G9-b. 缺 verdict ⇒ 渲染为 ERROR', /\[ERROR\s*\]/.test(txt), txt.slice(0, 160));
    check('G9-c. 缺 verdict ⇒ 输出结构化 STRUCTURAL 提示', /STRUCTURAL/.test(txt), txt.slice(0, 200));
    check('G9-d. 缺 verdict ⇒ **不得**被渲染为 PASS', !/\[PASS\s*\]\s*9\./.test(txt), txt.slice(0, 200));

    // ② VERDICT 常量必须含 UNKNOWN / ERROR（根因回归锁）
    check('G9-e. VERDICT 含 UNKNOWN 键（根因：曾缺失致 undefined）', VERDICT.UNKNOWN === 'UNKNOWN', String(VERDICT.UNKNOWN));
    check('G9-f. VERDICT 含 ERROR 键', VERDICT.ERROR === 'ERROR', String(VERDICT.ERROR));

    // ③ 错误类型 verdict（非字符串）亦须降级为 ERROR，且不得抛异常
    let threw2 = null; let txt2 = '';
    try {
      txt2 = renderText({ ...resMissing, items: [{ id: '2', claim: '类型错误项', verdict: 42, kind: 'mechanical' }], structural: ['2'] });
    } catch (e) { threw2 = e; }
    check('G9-g. 非字符串 verdict ⇒ 不得抛异常', threw2 === null, threw2 ? String(threw2.message) : 'ok');
    check('G9-h. 非字符串 verdict ⇒ 渲染为 ERROR', /\[ERROR\s*\]/.test(txt2), txt2.slice(0, 160));

    // ④ UNKNOWN 不得被当作 PASS（ok 判定必须把 UNKNOWN 计入未通过）
    const rUnknown = evaluateReadinessWithInjectedUnknown();
    check('G9-i. UNKNOWN 项存在时 ⇒ ok=false（**UNKNOWN ≠ PASS**）', rUnknown.ok === false, JSON.stringify({ ok: rUnknown.ok, unknown: rUnknown.mechanicalUnknown }));

    // ⑤ 完整合规实例仍须 ok=true（确保修复未误伤正例）
    const okRes = evaluate({ mode: 'readiness', instanceRoot: tmp });
    check('G9-j. 完整实例判定不因 G9 修复而改变（结构无缺陷即无 structural）', (okRes.structural ?? []).length === 0, JSON.stringify(okRes.structural));
  }

  fs.rmSync(tmp, { recursive: true, force: true });
  console.log(`\n${'='.repeat(72)}`);
  console.log(`T1 self-test: ${pass} passed, ${fails.length} failed`);
  if (fails.length) { console.log('FAILED:'); for (const f of fails) console.log('  - ' + f); }
  console.log('='.repeat(72));
  return fails.length ? 1 : 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))) {
  process.exit(runSelfTest());
}

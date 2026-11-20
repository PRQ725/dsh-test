# RC2 CHANGE REPORT - Long-running Toolkit v0.2-rc.2 pre-release contract repair

Status: **FROZEN at v0.2-rc.2** - all three repairs are implemented, all targeted regression ran,
and the final hashes are in section 6. This report was last edited to record its own freeze; no
candidate file, evaluator or specification changed after those values were read. Earlier sections
are updated in place and never rewritten, and no failed run was erased.

Target: **Long-running Toolkit v0.2-rc.2**. `rc.2` is a revision candidate marker. Publication
remains unauthorized and `HUMAN CONTENT ACCEPTANCE` remains pending.

Authorized by direct human instruction this round. Scope: three contract repairs found by an
independent content review, plus the acceptance-spec amendment and the targeted regression that
covers them. The eight-file architecture is preserved; no new delivery template is added.

Out of scope: the first pilot workspace (read-only), the v0.1 frozen assets, all rc1 evidence, any
new goal or automatic round, Ralph, a new stop controller, dependency installs, global DSH /
profile / sandbox changes, real business projects, network research, publication.

---

## 1. RC1 FROZEN BASELINE

Confirmed read-only **before** any modification. Every digest below was re-read and compared
against the freeze record in `RC1-CHANGE-REPORT.md` section 6.

| Check | Result |
|---|---|
| workspace | `D:\Projects\dsh-test` |
| file policy / approval | `workspace-write` / `ask` |
| eight candidate files present | yes |
| `RC1-CHANGE-REPORT.md`, `V0.2-ACCEPTANCE-SPEC.md`, evaluator, selftest present | yes |
| current digests vs RC1 freeze record | **0 mismatches** |
| goal state | no goal exists in this session; nothing to continue, nothing armed |
| `toolkit/` publication target | absent |
| stray top-level directories | none (`archive, docs, evidence, experiments, scripts, README.md`) |

### 1.1 Frozen candidate (8 files) at rc.1

| File | Bytes | SHA256 |
|---|---|---|
| `README.md` | 17428 | `94DF0DDE01C8D1DEBCA07CD1968BA2C45B72BCE43BE8083FE5C99B3BEC35F477` |
| `SKILL.md` | 20089 | `0FD81EABD666FF8EE7C636EDC3036934BC25F8D9E10D8DA7103CC7449C6C2D0B` |
| `METHODOLOGY.md` | 22930 | `6EAACC526DA2E2D9E94460309948C7F07B3A11AA8232040C4614119B9A429475` |
| `templates/GOAL.md` | 4680 | `5B73229926FD1F22A866528AACBF00B8DDCA3BD1D5521D44A72453799B9FE314` |
| `templates/PLAN.md` | 2669 | `27DA9A6034A97F52433F6B312AAA9C712B83CECDC705AD67166CB221192A4F8F` |
| `templates/STATE.md` | 2327 | `8895BA4EA4364F8F4F4D0C2AE5B0E5BDB6C19FC715EA310864ACCDDACB0306AC` |
| `templates/EVALUATION.md` | 3832 | `5BA7F1F2E45D9FE351F400E2E96D3F9068A054EC276656643243AE56CC256D16` |
| `templates/FINAL-REPORT.md` | 5302 | `4F6F252D0DE32E7F838343C46AEF51336B584B2D7B0FD62BB9CD00E6ABBA8AB5` |

### 1.2 Frozen judge and baseline at rc.1

| Artifact | Bytes | SHA256 |
|---|---|---|
| `evaluator/check-v0.2.ps1` | 35010 | `2A96D3C404A8695633D24E78A57E526BFB2C5F628FAD6AD2B35C61641C98FF58` |
| `evaluator/check-v0.2.selftest.ps1` | 28279 | `E7E53A38C807794ACA9BC3E8D2664139835FA96F925A9B29698FFB54482027D2` |
| `V0.2-ACCEPTANCE-SPEC.md` | 19492 | `A3AA9A56BBE683F0A5612D707AEDF5CEA432006278D9930DE4D9DD1070A5B6CD` |

`RC1-CHANGE-REPORT.md` and every rc1 log are left untouched. New logs for this round go to
`evidence/rc2/`.

---

## 2. REVIEW FINDINGS

Three contract defects, each with the artifact it was found in and why it matters.

**F1 - the round-execution rule is stated as an absolute.**

- Where: `SKILL.md` "Round execution", step 3 and the following discipline paragraph:
  "**One round, one increment**; a round that tries to finish everything verifies nothing."
- Why it is wrong: the first pilot's own evidence contradicts it as a rule. Round 1 produced all
  six deliverables, ran the frozen evaluator, recorded the first FAIL, fixed it, re-ran to PASS,
  wrote its evidence, and satisfied G1-G4 - i.e. one round completed the whole objective with
  full verification. Rounds 2-5 then had no content work left, which the pilot's final report
  records as its main negative finding. The rule as written would label what actually happened
  as a violation, and it pushes an agent toward**splitting work to fit the sentence**.
- Consequence if unfixed: guidance that conflicts with observed behaviour teaches the reader to
  distrust the document, and "one increment per round" can be read as a licence to pad rounds.

**F2 - the instance-root declaration can be silently overridden.**

- Where: `SKILL.md` "Goal design" (added at rc.1) said: "If this field and the directory on disk
  disagree, **the directory wins** and you record the disagreement." `templates/GOAL.md` repeated
  the same rule.
- Why it is wrong: it lets the current filesystem layout, or the model's own reading of it,
  override a **frozen, human-approved** project contract. "The directory wins" is safe for a
  state file's factual content; it is unsafe for an authorization record. It also makes the
  evaluator's `-InstanceRoot` parameter a way to silently evaluate a *different* directory than
  the project declared, and to report PASS for it.
- Consequence if unfixed: an adoption can be declared PASS while the project's declared instance
  root points somewhere else entirely - exactly the class of silent substitution the toolkit
  exists to prevent.

**F3 - instance hygiene is presented as if it were initialization readiness.**

- Where: `V0.2-ACCEPTANCE-SPEC.md` V12, `README.md` (Step 3/7), `SKILL.md`, and
  `templates/EVALUATION.md`, all of which let a green adoption check read as "the project is
  ready to start a goal".
- Why it is wrong: V12 proves only that the instance root exists, holds at least one `.md`, holds
  no `UNFILLED`, and is not the toolkit's own templates. A directory can satisfy all of that with
  a single filled `GOAL.md` and still lack `PLAN.md`, an approved plan, an initialized `STATE.md`,
  a filled evaluation contract, a project evaluator, evaluator test evidence, a frozen evaluator
  hash, declared budget and stop conditions, a verified permission boundary, instance-root
  consistency, human approval records, and a final-report owner.
- Consequence if unfixed: the strongest statement the toolkit makes ("ready") would rest on the
  weakest check it performs, and the missing prerequisites would be discovered only after a goal
  had already been armed and was consuming rounds.

---

## 3. APPROVED MODIFICATIONS

| # | Change | Addresses | Bound |
|---|---|---|---|
| M1 | Correct the round-execution rule across `SKILL.md`, `METHODOLOGY.md` and `README.md`: allow bounded multi-increment rounds, allow a round to complete the objective, forbid splitting work to consume budget, and keep the real driver stop semantics intact | F1 | wording only, no new rule that contradicts the driver |
| M2 | Make the instance-root declaration authoritative: the evaluator gains a minimal read-only consistency check between the **declared** root and the **actual** root it was told to inspect, normalized before comparison; any conflict is fail-closed, never a silent switch to another directory | F2 | additive parameter + additive check; no unrelated check relaxed |
| M3 | Separate **INSTANCE HYGIENE** from **INITIALIZATION READINESS** in the spec, the three prose files and `templates/EVALUATION.md`; the evaluator gains a readiness mode that reports per-item `PASS` / `POLICY` / `PENDING` / `FAIL` and never claims a human gate is mechanically proven | F3 | a new contract plus a reporting mode; no claim of building a goal-start controller |
| M4 | Spec amendment **A4** recording F1-F3, which checks changed, which did not, and what stays a human judgement | F1-F3 | append-only; A1-A3 untouched |
| M5 | Targeted regression: new selftest cases and the R2-T1..T12 matrix, all under `evidence/rc2/` | M1-M3 | evidence only; rc1 logs untouched |

Explicitly **not** proposed: a new delivery template, a stop controller, a goal-start
controller, directory restructuring, or any change to the v0.1 assets.

---

## 4. ACTUAL CHANGES

### 4.1 F1 - round-execution semantics (M1)

| File | Change | Bytes |
|---|---|---|
| `SKILL.md` | "Round execution" rewritten: the output line is "the increments this round actually completed"; step 3 is now "do the work the objective still needs" and says a round **may complete several related increments** and **may complete the objective itself**; step 4 requires each increment to be **verified in the round that produced it**; a five-point statement of what makes a round good replaces the size rule; `never split work across rounds` and "a round allowance is a ceiling, not a work plan" added; finishing early is stated as normal, with the explicit note that the review marker does not stop the driver. | 20089 -> 25308 |
| `METHODOLOGY.md` | New opening section `## 0 A round allowance is a ceiling, not a work plan` that quotes the retired absolute, states why the pilot refutes it, and lists the four things a round must not do. | 22930 -> 26974 |
| `README.md` | New paragraph before "When to use it" stating the ceiling rule, that one round may complete the objective, and that stretching work to use the allowance buys nothing; Step 9 repeats it next to the budget. | |

The retired wording is not quoted in `SKILL.md`; it is quoted once in `METHODOLOGY.md` as the
thing being corrected, which is the honest place for it.

### 4.2 F2 - instance-root consistency (M2)

| Artifact | Change |
|---|---|
| `evaluator/check-v0.2.ps1` | New `-GoalContract` and `-InstanceRootDeclared` parameters; new helpers `Get-FieldValue`, `Get-NormalizedPath`, `Test-SamePath`, `Test-Unrecorded`, `Test-HashLike`; new check **V13**: when a declared root is available the inspected root must be the same directory after normalization (absolute form, `/` vs `\`, case-insensitive, trailing separators ignored, relative resolved against the project root). Mismatch, unfilled field, absent field or unreadable contract → FAIL. The evaluator never substitutes another directory and never edits the contract. |
| `SKILL.md` | "Goal design" now presents the three objects in a table (declaration / argument / filesystem) and states the declaration is authoritative; a conflict is reported for a human, not resolved by the model. |
| `templates/GOAL.md` | The `Instance root:` field no longer says "the directory wins"; it now states the declaration is authoritative and lists what is forbidden (editing the frozen field, overriding by filesystem reading, silently inspecting another directory) and what is not a conflict (equivalent spellings). |

### 4.3 F3 - hygiene vs readiness (M3)

| Artifact | Change |
|---|---|
| `evaluator/check-v0.2.ps1` | The V12 block is renamed in comments and output as **INSTANCE HYGIENE**; a new `-Mode Readiness` reports the twelve-item `INITIALIZATION READINESS` contract with per-item `PASS` / `POLICY` / `PENDING` / `FAIL`, plus a `NOT CLAIMED` paragraph naming what stays a human judgement. Exit code **3** is added and means "not ready"; readiness returns 0 only when every checkable prerequisite passed and no human gate is open. Adoption/readiness success output no longer implies readiness. |
| `SKILL.md` | New section `## Initialization readiness` with the twelve-item table, an explicit statement that only the human makes the goal-arming decision, and the three reporting rules (a record is `POLICY` not `PASS`; an unperformed gate is `PENDING`; a readiness report is not acceptance and arms nothing). "Adoption-mode output must not be described as proving readiness" is stated in the section. |
| `METHODOLOGY.md` | New subsection `## A.2 Instance hygiene is not initialization readiness`, with the two-verdict table, why the gap hurts, the four-verdict vocabulary, and the conflict rule for the declared instance root. |
| `README.md` | Step 3 distinguishes the two verdicts; new **Step 10.5** states the twelve-item readiness contract, the four verdicts, and that a readiness report arms nothing; Step 7's cross-reference now names the evaluation template that carries the contract. |
| `templates/EVALUATION.md` | New `## C. Initialization readiness` block with the `Initialization readiness:` field, the twelve items with their verdict kinds, and the three reporting rules. |
| `templates/PLAN.md` | New additive `Approval record:` field, because a readiness item that asks whether a plan was approved needs a field that answers it rather than prose to be searched. |

### 4.4 Spec amendment A4 (M4)

`V0.2-ACCEPTANCE-SPEC.md`: interface line documents `-Mode Readiness`, `-GoalContract` and
`-InstanceRootDeclared`, and codes 0/1/2/3; V12 restated as instance hygiene; **new V13**
(instance-root consistency), **V14** (round-execution semantics) and **V15** (hygiene/readiness
separation); §3 field lists extended with the two additive fields and the new heading; §6 gains
T31-T36 and the R2-T1..T12 matrix rows; §7 gains **A4**, including what changes, what does not,
the effect on previous results and what stays a human judgement. A1-A3 are untouched.
19492 -> 28466 bytes.

### 4.5 Files not changed

`templates/STATE.md` and `templates/FINAL-REPORT.md` are unchanged from rc.1. No new delivery
template was added: the eight-file structure is intact. `RC1-CHANGE-REPORT.md` and every rc1
scenario and log are unchanged except for the one incident recorded in §5.1.

---

## 5. REGRESSION RESULTS AND INCIDENTS

Full detail, logs and the scenario inventory: `evidence/RC2-DRY-RUN-EVIDENCE.md`.

### 5.1 Regression summary

| Run | Result |
|---|---|
| `-Mode Candidate` on the candidate | **exit 0**, `all V1-V15 and R1-R3 checks satisfied` |
| `-Mode Adoption`, default layout (no declaration) | **exit 0**, prints `instance root (default)` |
| `-Mode Adoption`, declared custom layout + `-GoalContract` | **exit 0**, prints both roots and `instance-root consistency: PASS` |
| `-Mode Adoption`, equivalent path spellings | **exit 0** (no false conflict) |
| `-Mode Adoption`, declaration/argument conflict | **exit 1**, `V13 instance-root conflict …` |
| `-Mode Adoption`, unfilled declaration | **exit 1**, `… is not recorded` |
| `-Mode Readiness`, complete project with open gates | **exit 3**, `NOT READY PENDING HUMAN GATE (2 items)` naming R09 and R11 |
| `-Mode Readiness`, `GOAL.md` only | **exit 3**, eight `FAIL` items |
| `-Mode Readiness`, plan not approved | **exit 3**, `R02 PENDING` |
| `-Mode Readiness`, no evaluator evidence | **exit 3**, `R06 FAIL` |
| Selftest | **PASS, 35 cases, 0 failures** |
| R2 matrix | **11/11 as expected** |

### 5.2 Incidents (kept in the record, not erased)

1. **One rc1 log was rewritten.** `evidence/rc1/baseline-candidate.log` and
   `baseline-adoption.log` were re-generated when the rc.2 baseline was captured, instead of
   writing to `rc2/`. The outputs are byte-identical to the rc1 records and the inputs were
   unchanged, so no information was lost — but the rc1 directory should not have been written at
   all. Every other rc1 artifact, including `RC1-CHANGE-REPORT.md`, the rc1 scenario logs, the
   rc2 scenarios and `evidence/rc1/selftest-scratch/`, is untouched.
2. **Two selftest failures on the way.** T12-T16 initially shared one real copy, and case T11
   (or T14) edited that copy's instance file, so a later adoption run failed copy integrity for a
   reason unrelated to the case under test. Both were fixed by giving each adoption case its own
   fresh `New-RealCopy`. Harness defect, not evaluator defect.
3. **The baseline capture initially omitted `-Proposal`**, producing a copy-integrity failure
   that had nothing to do with the case. Corrected and re-run.
4. **A throwaway matrix script swallowed its return values** (`| Out-Null`), reporting empty exit
   codes for every row. Corrected; the harness was never affected.

### 5.3 Immutability and boundary checks

| Check | Result |
|---|---|
| candidate tree unchanged by the selftest | verified in-harness (T28) |
| whole scratch base unchanged by the refusal cases | verified in-harness (T29) |
| `z` or other stray top-level directories | none; `dsh-test` top level = `archive, docs, evidence, experiments, scripts, README.md` |
| publication target `toolkit/` | absent |
| v0.1 frozen six files | all six digests match the pilot freeze record |
| `Evaluator v0` / `PILOT-SPEC-v0.1.md` / pilot `GOAL.md` | unchanged (`F3D22F99…`, `056D8DCA…`, `88B9B033…`) |
| all new evidence | under `evidence/rc2/` |
| writes outside the workspace | none |

---

## 6. FINAL SHA256

Read from disk after the final regression run. No candidate, evaluator or specification file was
edited after these values were taken.

### 6.1 Candidate - the eight deliverables

| File | Bytes | SHA256 |
|---|---|---|
| `README.md` | 21565 | `41093BC9141B92BA6CDAF0AD85CF06D941CEAB3633F6BCC8B27D6021AED34A7E` |
| `SKILL.md` | 25308 | `A45F11EA3B845BC0BBCC62748F9B922BC999B93E0B1B92F0FFCD26F17499B8A8` |
| `METHODOLOGY.md` | 26974 | `D6FFBB4FB13E82BE4935B52D8578C4DD783CA7681951AAA587E2E3765CBC23D2` |
| `templates/GOAL.md` | 5169 | `FD19D55CC6AFE13132CA3A4BB8271A45ABB25472FA393E17B9E69B8D941FFEC1` |
| `templates/PLAN.md` | 3023 | `54CC75C48F2688489ABFDA1E5E6979E71146AA64017FC979BCADA21882A49E30` |
| `templates/STATE.md` | 2327 | `8895BA4EA4364F8F4F4D0C2AE5B0E5BDB6C19FC715EA310864ACCDDACB0306AC` (unchanged from rc.1) |
| `templates/EVALUATION.md` | 5593 | `D4C9AFF913E98CA7E28DAA4E0D1E96B2A1AFDB058EF65D244CC22D3581C43E56` |
| `templates/FINAL-REPORT.md` | 5302 | `4F6F252D0DE32E7F838343C46AEF51336B584B2D7B0FD62BB9CD00E6ABBA8AB5` (unchanged from rc.1) |

### 6.2 Judge and baseline

| Artifact | Bytes | SHA256 |
|---|---|---|
| `evaluator/check-v0.2.ps1` | 63819 | `DE2ED525D7DCBC2D620F2D535EA0E000BF8EFB2BF372C0B6085FF043622F8D9F` |
| `evaluator/check-v0.2.selftest.ps1` | 34775 | `E051D49B5174AD32D8339BC6C0C0132A97E483124D02284D98963AA5501C7B87` |
| `V0.2-ACCEPTANCE-SPEC.md` | 28466 | `20135549B0D4D820265D3AF5ED96654168BBCBA14A9AE005BD6FACCD3E3A3EC6` |

`RC1-CHANGE-REPORT.md` (`4F21472E…`) and the rc1 scenario/log evidence are unchanged apart from
the single incident in §5.2.

---

## 7. RESIDUAL RISKS

| # | Risk | Severity | Why it remains | Next step |
|---|---|---|---|---|
| R1 | One author lineage: the toolkit, the scenarios and the judge were written by the same party, so a green result is weak evidence of adoptability | medium | the mandate was a controlled repair, not an independent audit | an independent re-run of the frozen judge, or an adoption by a second person, would strengthen it |
| R2 | `-GoalContract` is optional; an adopter who omits it gets `instance-root consistency: UNCHECKED` and a hygiene PASS | medium | making it mandatory would break the documented default-layout path that rc.1 and rc.2 both promise | the output names the unchecked state explicitly; making it mandatory for custom layouts is the natural next revision |
| R3 | `Policy` verdicts read a *record*, never intent | low | intent is not machine-checkable | the vocabulary, the `NOT CLAIMED` paragraph and the `PENDING` gates make the limit explicit rather than implicit |
| R4 | The readiness contract is verified against synthetic projects only | medium | no real project may be touched | run it once against a disposable copy of a real project under separate authorization |
| R5 | `R09` (permission boundary) and `R11` (human approvals) can never reach `PASS` mechanically, so a fully built project still returns exit 3 | low, by design | these are exactly the human gates the contract exists to expose | a human records their decision outside the evaluator; the evaluator is not the place for it |
| R6 | The `Approval record:` check accepts any non-`NOT RECORDED` string | low | it is deliberately a policy record, not an authorization check | a human reads the record during readiness review |
| R7 | V14/V15 are documentation checks over substring rules; they can be satisfied by wording that is technically present and substantively thin | medium | documentation quality is not machine-decidable | this is precisely what `HUMAN CONTENT ACCEPTANCE` is for |
| R8 | `Copy-Item -Destination <nonexistent>` semantics continue to cause test-fixture mistakes | low | PowerShell behaviour, not a toolkit defect | each adoption case now takes a fresh copy; a future harness should assert the destination parent exists |

---

## 8. HUMAN REVIEW STATUS

Kept separate on purpose; never merged into one PASS.

| Dimension | Verdict | Basis |
|---|---|---|
| **MECHANICAL CHECKS** | **PASS** | `-Mode Candidate` exit 0, `all V1-V15 and R1-R3 checks satisfied` |
| **INSTANCE HYGIENE** | **PASS** | adoption on the default, declared-custom and equivalent-form scenarios; refusal cases fail closed |
| **INITIALIZATION READINESS CONTRACT** | **PARTIAL** | the twelve-item contract is implemented, exercised item by item, and correctly returns exit 3 for missing prerequisites and for open human gates; it has never been run against a real project, and two of its items are human gates by construction |
| **ADOPTION DRY-RUN** | **PASS** | 6 scenarios, 11/11 matrix rows, 35/35 harness cases |
| **HUMAN CONTENT ACCEPTANCE** | **PENDING** | reserved to a human; nothing here grants it |
| **PUBLICATION** | **NOT PUBLISHED** | `toolkit/` does not exist; nothing was copied |

Open items for a human, none of which this round may decide:

1. Content acceptance of the rc.2 candidate (the eight files).
2. The two rc.1 archives in `candidate/` (section 9): keep, rename, or remove - and confirm
   whether the `(2)` copy was intentional.
3. Whether `-GoalContract` should become mandatory for a custom instance root (residual risk R2).
4. Whether the two permanent human gates (R09, R11) should stay `PENDING` forever or gain a
   recorded human attestation elsewhere.
5. Whether to run the readiness contract once against a disposable copy of a real project (R4).
6. Whether to commission an independent re-run of the frozen judge (R1).

```
V0.2-RC2 MECHANICAL CHECKS: PASS
INSTANCE HYGIENE: PASS
INITIALIZATION READINESS CONTRACT: PARTIAL
ADOPTION DRY-RUN: PASS
HUMAN CONTENT ACCEPTANCE: PENDING
PUBLICATION: NOT PUBLISHED
```

`rc.2` is a revision candidate marker, not a release.

---

## 9. UNEXPECTED FILES FOUND THIS ROUND (not created by this round, not removed)

A post-freeze sweep of the change set surfaced two archive files that this round did **not**
create and did **not** remove. They are recorded here because an unexplained file in a candidate
directory is exactly the class of finding that gets buried.

| Path | Bytes | Created | Contents |
|---|---|---|---|
| `candidate/long-running.zip` | 33504 | 2026-10-09 13:45:12 | a snapshot of the **rc.1** eight files (README 17428, SKILL 20089, METHODOLOGY 22930, plus the five templates) |
| `candidate/long-running (2).zip` | 34757 | 2026-10-09 20:51:03 | the same shape, again an **rc.1** snapshot (identical member list) |

Observations, kept strictly to what was observed:

- Both sit in `candidate/`, i.e. **as siblings of** the `long-running/` directory, not inside it.
  The evaluator's eight-file contract scans the toolkit root (`candidate/long-running/`), and its
  contents are exactly the eight required entries, so neither archive affects any check. Verified
  by listing the directory and re-running the candidate mode (section 5.1).
- `long-running.zip` predates this work by hours. `long-running (2).zip` was written at 20:51,
  during this session, but this round's tooling did not create it: no command in this round used
  a packaging or compression cmdlet, and the file's creation timestamp does not correspond to any
  step recorded in the rc2 logs (the closest activity, the rc1 freeze, was earlier).
- Both archives contain **rc.1** bytes. Neither contains the rc.2 candidate, so neither can be
  mistaken for the current artifact, but a reader who opens "the zip in the candidate folder"
  would be looking at a superseded revision.

**This round does not delete them.** They were not covered by any cleanup authorization here, and
the `(2)` suffix suggests a second party's action rather than an artifact of this work. They are
listed as a human review item so the owner can decide whether they are intentional snapshots,
accidental copies, or debris - and, if they are kept, whether the rc.1 archives should be renamed
so a reader cannot confuse them with the rc.2 candidate.

# RC3 CHANGE REPORT - Long-running Toolkit v0.2-rc.3 minimal contract repair

Status: **FROZEN at v0.2-rc.3**. All changes implemented, all targeted regression run, final
hashes in section G. This report was last edited to record its own freeze; no candidate file,
evaluator or specification changed after those values were read.

Target: **Long-running Toolkit v0.2-rc.3**. `rc.3` is a revision candidate marker. Publication is
unauthorized and `HUMAN CONTENT ACCEPTANCE` remains pending.

Scope: close the Goal-Contract verification bypass found in rc.2, make the guarantee scope of each
check explicit, run the bounded regression, and freeze. Not a feature release, not a new pilot,
no new delivery template, eight-file structure preserved.

Out of scope: the first pilot workspace, the v0.1 frozen assets, the rc.1/rc.2 records, the user's
ZIP archives, any new goal or automatic round, Ralph, a controller framework, dependency installs,
global DSH / profile / sandbox changes, real business projects, network research, publication.

---

## A. RC2 BASELINE

Confirmed read-only **before** any modification.

| Check | Result |
|---|---|
| workspace | `D:\Projects\dsh-test`; file policy `workspace-write`; approval `ask` |
| eight rc.2 candidate files present | yes |
| `RC2-CHANGE-REPORT.md`, `V0.2-ACCEPTANCE-SPEC.md`, evaluator, selftest present | yes |
| current digests vs the RC2 freeze record | **0 mismatches** |
| goal state | no goal exists in this session; nothing to continue, nothing armed |
| `toolkit/` publication target | absent |
| stray top-level directories | none (`archive, docs, evidence, experiments, scripts, README.md`) |

### A.1 Frozen rc.2 candidate (8 files)

| File | Bytes | SHA256 |
|---|---|---|
| `README.md` | 21565 | `41093BC9141B92BA6CDAF0AD85CF06D941CEAB3633F6BCC8B27D6021AED34A7E` |
| `SKILL.md` | 25308 | `A45F11EA3B845BC0BBCC62748F9B922BC999B93E0B1B92F0FFCD26F17499B8A8` |
| `METHODOLOGY.md` | 26974 | `D6FFBB4FB13E82BE4935B52D8578C4DD783CA7681951AAA587E2E3765CBC23D2` |
| `templates/GOAL.md` | 5169 | `FD19D55CC6AFE13132CA3A4BB8271A45ABB25472FA393E17B9E69B8D941FFEC1` |
| `templates/PLAN.md` | 3023 | `54CC75C48F2688489ABFDA1E5E6979E71146AA64017FC979BCADA21882A49E30` |
| `templates/STATE.md` | 2327 | `8895BA4EA4364F8F4F4D0C2AE5B0E5BDB6C19FC715EA310864ACCDDACB0306AC` |
| `templates/EVALUATION.md` | 5593 | `D4C9AFF913E98CA7E28DAA4E0D1E96B2A1AFDB058EF65D244CC22D3581C43E56` |
| `templates/FINAL-REPORT.md` | 5302 | `4F6F252D0DE32E7F838343C46AEF51336B584B2D7B0FD62BB9CD00E6ABBA8AB5` |

### A.2 Frozen rc.2 judge and baseline

| Artifact | Bytes | SHA256 |
|---|---|---|
| `evaluator/check-v0.2.ps1` | 63819 | `DE2ED525D7DCBC2D620F2D535EA0E000BF8EFB2BF372C0B6085FF043622F8D9F` |
| `evaluator/check-v0.2.selftest.ps1` | 34775 | `E051D49B5174AD32D8339BC6C0C0132A97E483124D02284D98963AA5501C7B87` |
| `V0.2-ACCEPTANCE-SPEC.md` | 28466 | `20135549B0D4D820265D3AF5ED96654168BBCBA14A9AE005BD6FACCD3E3A3EC6` |
| `RC2-CHANGE-REPORT.md` | 24401 | `7ED47904880E8E4D487045B62D6211EBE00FA9787A9415E96048E6016B48CE61` |
| `RC1-CHANGE-REPORT.md` | 22056 | `4F21472EDFD25157EFC0E8F8D7B8E8E06482CA1094FA68DABA8EF00A4993F262` |

One correction to a message sent during this round: a printed digest for `RC1-CHANGE-REPORT.md`
appeared not to match the value recorded in `RC2-CHANGE-REPORT.md` section 6. Re-checking showed the
recorded value `4F21472E…` and the current file agree exactly; the discrepancy was a transcription
error in the message, not a change to any file. `RC1-CHANGE-REPORT.md` has not been modified since
`2026-10-09 20:42:31`.

### A.3 The user's ZIP archives - source confirmed by the human

`candidate/long-running.zip` (33504 B, created 2026-10-09 13:45:12) and
`candidate/long-running (2).zip` (34757 B, created 2026-10-09 20:51:03) were both created manually
by the user: the first is an older snapshot, the second a later re-compression. Recorded here as
the user's clarification.

Consequences applied this round: no further investigation of their origin; they are **not**
classified as accidental artifacts; they were **not** deleted, moved or renamed; and they are
**not** treated as the authoritative source for the candidate. The authoritative artifact remains
the directory `candidate/long-running/`. Their contents were listed once during the rc.2 round and
both hold rc.1-era bytes; this round made no claim about which version each archive corresponds to
beyond that observation.

---

## B. ROOT CAUSE AND IMPACT

**The defect.** A4 (rc.2) introduced `-GoalContract` as an **optional** parameter. When a caller
omitted it, `-Mode Adoption` and `-Mode Readiness` printed:

```
instance-root consistency: UNCHECKED
```

on the same screen as a green instance-hygiene verdict. Instance hygiene and contract consistency
are genuinely different checks, so the individual statements were true. The defect is in the
**scope of the claim**: a reader - human or model - could take the green verdict as a complete
adoption certification, while the one check that ties the inspected directory to the project's
frozen, human-approved declaration had silently not run.

**Why it matters more than a wording issue.** The removal of that check is invisible in the
verdict. The whole purpose of the declaration check is to prevent an evaluator from certifying a
directory on the strength of the directory merely existing. An optional parameter whose omission
downgrades the check while leaving a green result is exactly that failure mode, produced by the
tool itself.

**Why documentation alone would not have fixed it.** The rc.2 documents already said that hygiene
is not readiness and that a declaration should be supplied. What failed was the **default**: an
optional parameter that yields a green output when omitted will be omitted. The repair therefore
changes behaviour, not prose. The worked example is kept in `evidence/rc3/RC3-CONTEXT.md`.

---

## C. ADOPTED CHECK SEMANTICS

Four checks, four claims, four invocation shapes. This is now the contract.

| Verdict | Invocation | Proves | Does **not** prove |
|---|---|---|---|
| **CANDIDATE VALIDATION** | `-Mode Candidate -Root <toolkit copy>` | the portable eight-file toolkit satisfies V1-V16 and R1-R3 | anything about a target project |
| **HYGIENE PASS** | `-Mode Hygiene -InstanceRoot <dir>` | the instance directory is reachable, holds instance documents, holds no blank-form marker, is not the toolkit's own `templates/`, and meets the basic directory constraints | that it is the **declared** directory, that initialization is complete, that a person approved anything, that a goal may be armed |
| **ADOPTION PASS** | `-Mode Adoption -Proposal <candidate> -GoalContract <project>/…/GOAL.md [-InstanceRoot <dir>]` | hygiene, **plus** a readable frozen contract, a valid declaration, and normalized path equality | initialization readiness, human approval, permission to arm |
| **INITIALIZATION READINESS** | `-Mode Readiness -GoalContract <project>/…/GOAL.md [-InstanceRoot <dir>]` | hygiene and contract verification, plus a per-item verdict on the twelve-item readiness contract | acceptance; it arms nothing, and its human gates stay `PENDING` |

**Fail-closed rules now enforced:**

1. `-Mode Adoption` and `-Mode Readiness` **require** `-GoalContract` (or `-InstanceRootDeclared`).
   Without one the invocation is refused with `ERROR` / exit 2 - never downgraded.
2. A contract that cannot be read fails; the run does not fall back to the default directory.
3. A missing `Instance root:` field fails.
4. A field still carrying `UNFILLED`, or explicitly unrecorded, fails.
5. A declared path that conflicts with the inspected path fails, and the evaluator never switches
   to another existing directory.
6. Equivalent Windows spellings of one directory are **not** a conflict (normalized comparison:
   absolute form, `/` vs `\`, case-insensitive, trailing separators ignored, relative resolved
   against the project root).
7. `-Mode Hygiene` **rejects** a supplied contract, so the weak mode cannot be used to imply the
   strong check.
8. The evaluator never edits the contract and never infers approval from text.
9. `-Mode Candidate` still needs no contract and claims candidate scope only.

**Why an explicit mode rather than a smaller flag.** The choice was between (a) requiring the
contract in `-Mode Adoption` and offering the directory-only check under a new, explicitly weak
name, and (b) keeping one mode with a flag that selects a weaker comparison. Option (a) was chosen
because it makes the guarantee a property of the **command**, not of a flag a reader may not
notice, and because it keeps `ADOPTION PASS` meaning exactly one thing. Option (b) would have
reintroduced the same defect one parameter later.

---

## D. SPEC AMENDMENT A5

`V0.2-ACCEPTANCE-SPEC.md` records **A5 (2026-10-09, v0.2-rc.3)** without touching A1-A4. A5 states:
the rc.2 optional-parameter risk; the guarantee carried by each of the four results; the necessary
conditions for a Full Adoption verdict; the hygiene-only output restriction (`HYGIENE PASS` plus
`CONTRACT NOT CHECKED`, never `ADOPTION PASS`, never a consistency claim); the relationship between
readiness and the contract (required, never assumed, `UNCHECKED` never treated as satisfied,
human approval never inferred); the interface and compatibility impact (one mode added, two modes
tightened, the missing-contract invocation now exit 2, V16 added); the effect on earlier rc.1/rc.2
conclusions (still valid for what they measured, not retroactively relabelled, no log rewritten);
and the new regression requirements R3-T1..R3-T12.

Spec text added: the four-mode interface block, the exit-code-2 coverage for the missing contract,
the rewritten V13, the new **V16** guarantee-scope check, the section 6 rows T31-T36 and R3-T1..T12.
28466 -> 35945 bytes.

---

## E. IMPLEMENTATION CHANGES

### E.1 Evaluator - `evaluator/check-v0.2.ps1`

| Change | Detail |
|---|---|
| mode set | `Candidate`, `Hygiene`, `Adoption`, `Readiness` |
| new refusals | `-Mode Adoption`/`-Mode Readiness` without `-GoalContract` and without `-InstanceRootDeclared` → `ERROR`, exit 2, with the reason and a pointer to `-Mode Hygiene`; `-Mode Hygiene` given a contract → `ERROR`, exit 2 |
| V13 | performs the contract comparison for `Hygiene`, `Adoption` and `Readiness`; for `Hygiene` the outcome is recorded as `NOT CHECKED` and printed as `CONTRACT NOT CHECKED`; the fail-closed branch is now unreachable for the contract-verified modes but left as `FAIL` |
| V16 (new) | in candidate mode, `README.md`, `SKILL.md` and `METHODOLOGY.md` must name all four verdicts, `CONTRACT NOT CHECKED`, and a "does not prove" limit; `templates/EVALUATION.md` must name the same vocabulary |
| copy integrity | the check now runs whenever `-Proposal` is supplied, in any mode, instead of only in `-Mode Adoption` |
| verdict output | each mode prints its own headline and its own limits: `CANDIDATE VALIDATION PASS`, `HYGIENE PASS` + `CONTRACT NOT CHECKED` + "NOT an ADOPTION PASS", `ADOPTION PASS (contract-verified)`, or the readiness table |
| guarantee notice | a hygiene run prints an explicit three-line scope statement before its verdict |

### E.2 Candidate documents

| File | Change | Bytes |
|---|---|---|
| `README.md` | new **Step 10.6 "Know which verdict you are holding"**: the four-check table, the rule that hygiene must never be reported as adoption, the deliberate refusal to downgrade, and the statement that a green result does not prove readiness, approval, or permission to arm | 21565 -> 23744 |
| `SKILL.md` | new **"Guarantee scope of each check"** section: the four-check table, and three operating rules - never call a hygiene result an adoption, do not work around the refusal, and a green result does not prove initialization, approval or authorization | 25308 -> 27405 |
| `METHODOLOGY.md` | new **A.3 "Four checks, four claims - and why an optional parameter was a defect"**: the table, the general shape of the defect ("a claim whose scope is wider than the evidence behind it"), the three design ideas of the repair, and the transferable rule | 26974 -> 29942 |
| `templates/EVALUATION.md` | new "Guarantee scope of this project's checks" block with the four verdicts and their limits, plus the instruction to run the strongest check and report it by its own name | 5593 -> 6962 |
| `templates/GOAL.md`, `templates/PLAN.md`, `templates/STATE.md`, `templates/FINAL-REPORT.md` | **not changed** | unchanged |

No new delivery template. The eight-file structure is intact.

### E.3 Selftest - `evaluator/check-v0.2.selftest.ps1`

| Change | Detail |
|---|---|
| `Run-Case` | now takes `-GoalContract` and `-InstanceRootDeclared` and passes them through |
| T12-T16 | converted from `-Mode Adoption` to `-Mode Hygiene` (they are directory-level cases, and Adoption now requires a contract); the adoption path is covered by T32/T34/T38/T39 |
| T35 | now asserts `CONTRACT NOT CHECKED` |
| T36a / T36b | readiness without a contract is **refused** (exit 2); readiness with a contract but no documents is **not ready** (exit 3) |
| T37-T42 (new) | candidate scope vocabulary; adoption refused without a contract; adoption passing with a valid contract; a raw-output check that each mode's log contains no claim it must not make; the toolkit vocabulary check; the candidate tree unchanged |
| T1 / T11 | proposal root corrected to the candidate root, which rc.2 had left pointing one level too high (harmless while copy integrity was adoption-only; exposed once A5 broadened it) |

35 -> 44 cases.

---

## F. REGRESSION RESULTS

Full detail and per-case logs: `evidence/rc3/`.

| Run | Result |
|---|---|
| `-Mode Candidate` on the candidate | **exit 0**, `CANDIDATE VALIDATION PASS` |
| `-Mode Hygiene` (declared argument, default layout) | **exit 0**, `HYGIENE PASS` + `CONTRACT NOT CHECKED` |
| `-Mode Adoption` with a valid contract, consistent root | **exit 0**, `ADOPTION PASS (contract-verified)` |
| `-Mode Adoption` **without** a contract | **exit 2**, refused, no adoption claim anywhere in the output |
| `-Mode Readiness` with a valid contract, open gates | **exit 3**, `NOT READY PENDING HUMAN GATE` |
| `-Mode Readiness` **without** a contract | **exit 2**, refused |
| Selftest | **PASS, 44 cases, 0 failures** |
| R3 matrix | **13/13 as expected** |

### F.1 R3 matrix (from `evidence/rc3/rc3-matrix.ps1`, logs `evidence/rc3/r3-*.log`)

| Case | What it exercises | Exit |
|---|---|---|
| R3-T1 | candidate validation without a contract | 0 |
| R3-T2 | adoption without a contract | **2** |
| R3-T3 | adoption with a valid contract and consistent root | 0 |
| R3-T4 | contract named but not readable | 1 |
| R3-T5 | declaration still `UNFILLED` | 1 |
| R3-T6 | declaration and inspected path conflict | 1 |
| R3-T7 | equivalent Windows spellings | 0 |
| R3-T8 | hygiene-only: green, `CONTRACT NOT CHECKED`, no adoption claim | 0 |
| R3-T9 | readiness without a contract | **2** |
| R3-T10 | readiness with a contract, human gates open | 3 |
| R3-T11a/b | discrimination retained (missing directory; toolkit templates as instance root) | 1 |
| R3-T12 | candidate eight files unmutated by the whole matrix | — |

### F.2 Failures met on the way, kept in the record

1. **Four selftest cases failed on the first rc.3 run.** T1/T11 because the harness's proposal root
   pointed at `v0.2-work` instead of the candidate root - harmless while copy integrity ran only in
   adoption mode, exposed once A5 broadened it; T36b because the expected reason wording differed
   when a prerequisite rather than hygiene failed; T40c because the adoption output legitimately
   contains the disclaimer phrase `NOT a HYGIENE ... PASS`, which the assertion treated as a claim.
   All four were test-side defects; fixed, and the whole harness re-run to 44/44.
2. **Two R3 matrix rows failed on the first run** for the same class of reason (a disclaimer
   containing the forbidden phrase, and a digest assertion written against the rc.2 digests rather
   than against run-time stability). Both assertions were corrected and the matrix re-run to 13/13.
3. **A scenario fixture bug**: the generated project evaluator used
   `$MyInvocation.MyCommand.InvocationName`, which is empty at script scope; corrected to
   `$MyInvocation.InvocationName` in all five fixtures before they were used.
4. **A one-off prose duplication** in `evidence/rc3/RC3-CONTEXT.md` on first write; rewritten.

No product defect was found in rc.3 beyond the one this round exists to fix.

### F.3 Boundary and immutability checks

| Check | Result |
|---|---|
| candidate tree unchanged by the harness | verified in-harness (T42/T28) and by the R3-T12 digest comparison |
| v0.1 frozen six files | all six match the pilot freeze record |
| `Evaluator v0` / pilot `GOAL.md` | unchanged (`F3D22F99…`, `88B9B033…`) |
| rc.1 and rc.2 reports and logs | not rewritten. Precise check: **zero** files under `evidence/rc1`, `evidence/rc2`, `adoption/rc1-scenarios` or `adoption/rc2-scenarios` were written after 21:50, i.e. after this round began. Newest mtimes are rc.1 `20:41:51` and rc.2 `21:28:32`, both from their own rounds (the two mtimes that moved during the rc.2 round are the incident already recorded in `RC2-CHANGE-REPORT.md` section 5.2) |
| user ZIP archives | both present, sizes and mtimes unchanged (`long-running.zip` 33504 B at 13:45:12; `long-running (2).zip` 34757 B at 20:51:03) |
| stray top-level directories | none; `dsh-test` top level = `archive, docs, evidence, experiments, scripts, README.md` |
| `toolkit/` publication target | absent |
| new evidence | entirely under `evidence/rc3/` |
| writes outside the workspace | none |

---

## G. FINAL HASHES

Read from disk after the final regression run.

### G.1 Candidate - the eight deliverables

| File | Bytes | SHA256 |
|---|---|---|
| `README.md` | 23744 | `F02C536C85BB9421A4381DF098BE9E52F4EF43AB28ACBD5A7FE92638C7CF2134` |
| `SKILL.md` | 27405 | `95FF1D9097580A9B5A9FBE334D456DF53B8A1E7841EC6D83391D587A8AD5A1AB` |
| `METHODOLOGY.md` | 29942 | `49B6290715D479923033BCBB6CB0020B3439C61071CF626DE94A235040EC41DC` |
| `templates/GOAL.md` | 5169 | `FD19D55CC6AFE13132CA3A4BB8271A45ABB25472FA393E17B9E69B8D941FFEC1` (unchanged from rc.2) |
| `templates/PLAN.md` | 3023 | `54CC75C48F2688489ABFDA1E5E6979E71146AA64017FC979BCADA21882A49E30` (unchanged from rc.2) |
| `templates/STATE.md` | 2327 | `8895BA4EA4364F8F4F4D0C2AE5B0E5BDB6C19FC715EA310864ACCDDACB0306AC` (unchanged from rc.2) |
| `templates/EVALUATION.md` | 6962 | `B576C5A444D13D7B18AED0A672F57E9CEA3E5869895F393B9A96A6204BB88A26` |
| `templates/FINAL-REPORT.md` | 5302 | `4F6F252D0DE32E7F838343C46AEF51336B584B2D7B0FD62BB9CD00E6ABBA8AB5` (unchanged from rc.2) |

### G.2 Judge and baseline

| Artifact | Bytes | SHA256 |
|---|---|---|
| `evaluator/check-v0.2.ps1` | 69251 | `4B5DD1D76AE6288417CB8EBEC1342F9EA1118D4E11A7D1523AA481AD3C031EA1` |
| `evaluator/check-v0.2.selftest.ps1` | 40349 | `057BE35F9578B1C1230417B19990B9E02D8CC24810A376A208736D45C6B9F75F` |
| `V0.2-ACCEPTANCE-SPEC.md` | 35945 | `480E0CD3D3EF699AC0BC229B7F7A9EE6E7B8FC629617CDE9C3DEB93DFB9E13A7` |

`RC1-CHANGE-REPORT.md` `4F21472E…` and `RC2-CHANGE-REPORT.md` `7ED47904…` are unchanged.

---

## H. REMAINING RISKS

| # | Risk | Severity | Why it remains | Next step |
|---|---|---|---|---|
| R1 | single author lineage: toolkit, scenarios and judge share one author | medium | mandate was a bounded repair, not an audit | independent re-run of the frozen judge, or adoption by a second person |
| R2 | `-InstanceRootDeclared` can satisfy the new requirement **without** a contract file, so a caller can still assert a declaration that no frozen document confirms | medium | collapsing the two would make the contract file the only accepted input, which breaks the documented case where the contract cannot be reached | the output names which source was used (`the Instance root: field of …` vs `-InstanceRootDeclared`), so a reader can weigh it; tightening further is a policy decision for a human |
| R3 | adoption and readiness now refuse without a contract, which will fail existing rc.1/rc.2-style invocations | low, intended | that is the correction | the RCA and the new invocation shapes are in sections B and C |
| R4 | readiness is still only exercised against synthetic projects | medium | no real project may be touched | run it once against a disposable copy under separate authorization |
| R5 | V16 is a vocabulary check; wording can be present yet substantively thin | medium | documentation quality is not machine-decidable | this is what `HUMAN CONTENT ACCEPTANCE` is for |
| R6 | two permanent human gates (R09, R11) mean a fully built project still returns exit 3 | low, by design | nobody can mechanically perform a person's approval | the gates are reported, never closed, by the evaluator |
| R7 | `-GoalContract` must point at the project's `GOAL.md`; a caller could point it at an unrelated but valid contract file | low | the evaluator is not a source-of-truth service | the printed declared value and the contract path make it auditable in the log |
| R8 | the two user ZIP archives hold rc.1-era bytes while sitting beside the current candidate | low | the user confirmed they are intentional snapshots | recorded for the owner; renaming them to make the era explicit is a human decision |

---

## I. HUMAN REVIEW ITEMS

1. Content acceptance of the rc.3 candidate (the eight files).
2. Whether `-InstanceRootDeclared` should remain an accepted alternative to a contract file (risk
   R2), or be removed so that only a readable frozen contract can satisfy the requirement.
3. Whether the two ZIP snapshots should be renamed to make their era explicit, now that the
   candidate beside them is three revisions newer (risk R8).
4. Whether to run the readiness contract once against a disposable copy of a real project (risk R4).
5. Whether to commission an independent re-run of the frozen judge (risk R1).
6. Whether the four-verdict vocabulary is the right final set, or whether `ADOPTION PASS` should be
   renamed to something that cannot be confused with readiness at all.

---

## J. FINAL STATUS

Kept separate on purpose; never merged into one PASS.

| Dimension | Verdict | Basis |
|---|---|---|
| **V0.2-RC3 CANDIDATE** | **READY** | eight files complete, mechanically validated, frozen with digests |
| **CANDIDATE VALIDATION** | **PASS** | `-Mode Candidate` exit 0, `all V1-V16 and R1-R3 checks satisfied` |
| **INSTANCE HYGIENE** | **PASS** | `-Mode Hygiene` exit 0 on five scenarios, with `CONTRACT NOT CHECKED` stated |
| **CONTRACT-VERIFIED ADOPTION** | **PASS** | `-Mode Adoption` exit 0 with a valid contract; refused (exit 2) without one; conflicts and blank declarations fail |
| **INITIALIZATION READINESS** | **HUMAN PENDING** | the contract is implemented and returns exit 3 for missing prerequisites and for open human gates; its two human gates can only be closed by a person, and it has never been run against a real project |
| **SELFTEST** | **PASS** | 44 cases, 0 failures |
| **V0.1 FROZEN ARTIFACTS** | **UNCHANGED** | all six digests plus `check.ps1` and the pilot `GOAL.md` match the freeze record |
| **RC1/RC2 HISTORICAL EVIDENCE** | **UNCHANGED** | neither report nor any log was rewritten; both sets predate this round |
| **HUMAN CONTENT ACCEPTANCE** | **PENDING** | reserved to a human; nothing here grants it |
| **PUBLICATION STATUS** | **NOT PUBLISHED** | `toolkit/` does not exist; nothing was copied |

```
V0.2-RC3 CANDIDATE: READY
CANDIDATE VALIDATION: PASS
INSTANCE HYGIENE: PASS
CONTRACT-VERIFIED ADOPTION: PASS
INITIALIZATION READINESS: HUMAN PENDING
SELFTEST: PASS
V0.1 FROZEN ARTIFACTS: UNCHANGED
RC1/RC2 HISTORICAL EVIDENCE: UNCHANGED
HUMAN CONTENT ACCEPTANCE: PENDING
PUBLICATION STATUS: NOT PUBLISHED
```

`rc.3` is a revision candidate marker, not a release.

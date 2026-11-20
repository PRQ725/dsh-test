# RC1 CHANGE REPORT - Long-running Toolkit v0.2-rc.1 release readiness

Status: **FROZEN at v0.2-rc.1** - all changes are implemented, all verification ran, and the
final hashes are in section 6. The report was last edited to record its own freeze; no candidate
file, evaluator or specification changed after the values in section 6 were read. Earlier
sections are updated in place and never rewritten; failures and superseded runs stay in the
record.

Target name: **Long-running Toolkit v0.2-rc.1**. `rc.1` is a **revision candidate marker**, not
a release. Publication remains unauthorized.

Authorized by: direct human instruction, this round. Scope: controlled revision + regression
verification + directory hygiene for the v0.2 line only.

Explicitly out of scope: the first pilot workspace (read-only), the v0.1 frozen six files, the
v0.1 evaluator, v0.1 evidence, any new goal or automatic round, Ralph, dependency installs,
global DSH / profile / sandbox changes, real business projects, network research, publication.

---

## 1. BASELINE

Captured read-only, before any modification.

### 1.1 Workspace and permissions (confirmed first)

| Item | Value |
|---|---|
| workspace root | `D:\Projects\dsh-test` |
| session file policy | `workspace-write` |
| approval policy | `ask` |
| DSH_HOME / profile | `C:\Users\user02\.dsh` / `browser-lab` |
| version control | **absent** - `git.exe` cannot be spawned in this sandbox, and the workspace has no `.git`; there is no rollback net |
| execution policy | `CurrentUser = RemoteSigned`; nested `powershell.exe` / `cmd.exe` / `git.exe` spawns are refused |
| promotion target `toolkit\` | does not exist |

### 1.2 Candidate files (8)

| File | Bytes | SHA256 |
|---|---|---|
| `README.md` | 16201 | `56A858840F416CBEF7C0BC97BD877E988A4882513211A61FFB3974450640535A` |
| `SKILL.md` | 18738 | `D10E26A4FB8D18F3FF0426280A5AEB1DAF4030A6B88F0F0E9A9C9104037AB48A` |
| `METHODOLOGY.md` | 22930 | `6EAACC526DA2E2D9E94460309948C7F07B3A11AA8232040C4614119B9A429475` |
| `templates/GOAL.md` | 4151 | `CD296857AF086E76C04DCC0C67B94F25089F90B80ADF7FFAC7A0FD861D0FCF14` |
| `templates/PLAN.md` | 2669 | `27DA9A6034A97F52433F6B312AAA9C712B83CECDC705AD67166CB221192A4F8F` |
| `templates/STATE.md` | 2327 | `8895BA4EA4364F8F4F4D0C2AE5B0E5BDB6C19FC715EA310864ACCDDACB0306AC` |
| `templates/EVALUATION.md` | 3832 | `5BA7F1F2E45D9FE351F400E2E96D3F9068A054EC276656643243AE56CC256D16` |
| `templates/FINAL-REPORT.md` | 5032 | `82123B4DA87CBC1C2084F4F10C6B1AE7425578F8FD6231E40E759745220CCD09` |

### 1.3 Judge and baseline (3)

| Artifact | Bytes | SHA256 |
|---|---|---|
| `evaluator/check-v0.2.ps1` | 31201 | `2E479296D2AC53A1A497546A906492CA9E3446F882142699511FDF3D5D7681BF` |
| `evaluator/check-v0.2.selftest.ps1` | 13707 | `F20DB7D292DEC0F2623748956EDB63542EBE19CC9870464BB718A0424F923C48` |
| `V0.2-ACCEPTANCE-SPEC.md` | 13678 | `8266FB69769AF0A53E71015466AE793400E391E8EC37E3265BE5674613956234` |

### 1.4 Baseline PASS results

Re-run at baseline (raw logs in `evidence/rc1/baseline-candidate.log`,
`evidence/rc1/baseline-adoption.log`):

| Run | Result |
|---|---|
| `-Mode Candidate` on `candidate/long-running/` | **exit 0 PASS** |
| `-Mode Adoption` on `adoption/dryrun-project/toolkit/long-running/` | **exit 0 PASS** |

Baseline selftest result was **12 cases, 0 failures** (recorded in `evidence/CHECK-REPORT.md`
section 3, and re-confirmed during the previous round).

### 1.5 Known defects entering this round, with their evidence

| ID | Defect | Evidence |
|---|---|---|
| **D1** | Accidental directory `D:\Projects\dsh-test\z\` (0 bytes, one empty child `01-T1-pass`) | previous round's investigation: structure matches the selftest's `"<WorkRoot>\{0:d2}-{1}"` naming, creation time `2026-10-09 01:07:10` coincides with the v0.2 selftest runs, no references anywhere, no reparse point |
| **D2** | Selftest scratch root is not validated: a bad `-WorkRoot` value silently creates directories wherever the resolved path points, because `New-Item -ItemType Directory -Force` creates missing parents | D1 itself is the observed symptom; the exact failing invocation is **not** reconstructible and is not claimed |
| **D3** | Adoption mode hard-codes the instance location `docs/long-running/`, while the candidate `README.md` Step 3 lets a project choose its own working directory | previous round's live probe: instances in `planning/` produced `V12 no filled project documents found …` and exit 1 (scenarios A and B) |
| **D4** | Repository navigation: the root `README.md` never mentions the Long-running Toolkit line, and `v0.2-work/` has no index of its own | previous round's audit |
| **D5** | Empty directory `adoption/dryrun-project/src/` (0 entries, zero references) | previous round's audit |
| **D6** | A full copy of the toolkit lives inside `adoption/dryrun-project/toolkit/long-running/` and can silently drift from the candidate | previous round's audit |

---

## 2. PROPOSED CHANGE

| # | Change | Addresses | Risk if not done |
|---|---|---|---|
| P1 | Verify `z` again, then delete it under this round's explicit authorization, using a literal path | D1 | an unexplained top-level directory stays in the research repository |
| P2 | Add fail-closed path validation to the selftest: absolute-only `WorkRoot`, containment inside an approved scratch root by path-segment comparison (not string prefix), execution-policy-independent reparse-point check on existing path segments, and validation before any directory creation | D2 | the same accident can recur silently |
| P3 | Add a `-InstanceRoot <dir>` parameter to the evaluator's adoption mode; default to `<projectRoot>/docs/long-running/`; always report the path actually used; reject instances that are missing, empty, unfilled, or that resolve into the toolkit's own `templates/` | D3 | legitimate adopters are failed for choosing a different directory |
| P4 | Minimal IA: root `README.md` gains a Long-running Toolkit index entry and a short status block; `experiments/long-running/README.md` gains the complete v0.1 + v0.2-rc.1 line description; new `v0.2-work/README.md` index | D4 | the toolkit line stays undiscoverable from the repository root |
| P5 | Record the layout contract in the toolkit itself: `README.md` Step 3 (default + declared custom location), `templates/GOAL.md` gains an `Instance root:` field, `SKILL.md` instructs the agent to read that declaration and pass it explicitly | D3 | the contract would exist only in the evaluator, not in the toolkit |
| P6 | Selftest gains T12-T16 (path contract) and T17-T20 (scratch path safety) | D2, D3 | new rules would be unverified |
| P7 | Delete the empty `adoption/dryrun-project/src/` | D5 | cosmetic |
| P8 | Rebuild the adoption dry-run as fresh, separate scenario projects under `adoption/rc1-scenarios/`, leaving `dryrun-project/` untouched as historical evidence | D6, and the "do not hard-code one project" rule | prior evidence would be overwritten, or the test would prove nothing new |

Not proposed: any restructuring of the `long-running/` tree, any move of existing evidence, any
change to the v0.1 assets, any new architecture component, any change to the goal/plan contracts
beyond one additive field.

---

## 3. IMPLEMENTED CHANGE

Every item below was implemented in this round. Nothing outside the list was touched.

### 3.1 `z` directory and the empty `src` directory (P1, P7)

- Re-verified before deleting: directory, not a reparse point, `LinkType`/`Target` empty, one
  child `01-T1-pass`, **0 files**, 0 bytes, creation and last-write both `2026-10-09 01:07:10`.
- Reference scan over the whole `dsh-test` tree: the only textual mention of the path is this
  report. The four raw matches of a looser pattern were binary PNG coincidences inside
  `experiments/browser-probe/captures/`; the narrower path-shaped scan found none.
- Check was still consistent with the previous investigation, so deletion proceeded under this
  round's explicit authorization, with a literal path and a pre-check that the resolved path was
  exactly `D:\Projects\dsh-test\z`. **Deleted.**
- `adoption/dryrun-project/src/` was verified empty (0 entries, 0 references) and deleted.
- No other cleanup was performed.

### 3.2 Selftest scratch-path safety (P2)

`check-v0.2.selftest.ps1` now validates before it writes:

- `Test-ScratchRoot` is a pure check (reads only) and returns a typed refusal: `empty`,
  `wildcard`, `relative`, `unc`, `outside`, `base-missing`, `missing`, `reparse`, or `Ok`.
- Absolute-only: a relative `WorkRoot` is refused with the reason that it would silently resolve
  against the current directory.
- Containment is decided by **path segments** (`Test-UnderBase`), never by string prefix, so
  `<base>-evil` is refused as `outside`.
- `..` traversal is resolved by `GetFullPath` and then judged by the same segment comparison.
- Every existing path segment between the approved base and the target is checked for a reparse
  point (`Get-ReparseAncestor`); an unreadable segment counts as unsafe.
- The harness **never creates its own scratch root**: a missing root is `ERROR`, and a
  **non-empty** root is `ERROR` (new, T30) rather than being purged or run on dirty state.
- Two boundaries exist: `$env:TEMP` and the process cwd are refused, and the approved base
  defaults to `<v0.2-work>/evidence`. A caller passing `-ScratchBase` is the human authorizing
  that fence, and the parameter is documented as such in the file header.
- An invalid scratch root produces `ERROR` (exit 2) and the harness prints
  "Nothing was created or modified."

### 3.3 Instance-root contract (P3, P5) - amendment A3

- `check-v0.2.ps1` gains `-InstanceRoot <directory>` (adoption mode). Omitted, the documented
  default `<projectRoot>/docs/long-running/` is used. The path actually inspected is always
  printed, marked `instance root (declared):` or `instance root (default):`.
- Refusals: declared root that does not exist; default root that does not exist; no `.git`/`.dsh`
  marker to derive a project root from; instance tree with no `.md`; instance tree containing
  `UNFILLED`; **any instance root that resolves inside the toolkit's own tree** (segment-based,
  `Test-Under`), named in the reason as the reusable toolkit tree.
- The evaluator does **not** parse the declaration out of `GOAL.md`; the project declares it there
  and the adopter passes it on the command line.

### 3.4 Candidate document changes (P5)

| File | Change | Bytes |
|---|---|---|
| `README.md` | Step 3 rewritten: the default layout is shown as a tree, the *instance root* is defined, `templates/` is excluded, a custom location is allowed but must be **declared** and passed to the evaluator. Step 4 now says `GOAL.md` is copied into the instance root. | 16201 -> 17428 |
| `SKILL.md` | "Project discovery" must settle where the filled documents live; "Goal design" must read back the `Instance root:` declaration and pass it explicitly, never point it at `templates/`; "Evaluator design and freeze" gains the rule that an evaluator must be told the location instead of assuming one. | 18738 -> 20089 |
| `templates/GOAL.md` | New additive field `Instance root:` (the declaration of record; default `docs/long-running/`; never `templates/`). | 4151 -> 4680 |
| `templates/FINAL-REPORT.md` | New additive field `Instance root:`, because the report is written inside it. | 5032 -> 5302 |
| `METHODOLOGY.md` | **not changed** | 22930 (same) |
| `templates/PLAN.md`, `templates/STATE.md`, `templates/EVALUATION.md` | **not changed** | same |

No field was removed from any template, and no existing check was relaxed.

### 3.5 Acceptance baseline (spec) - amendment A3

`V0.2-ACCEPTANCE-SPEC.md`: interface line documents `-InstanceRoot`; V12 restated; §3 per-file
fields extended with `Instance root:` for `GOAL.md` and `FINAL-REPORT.md`; §6 cases extended to
T1-T30; §7 gains **A3** describing the path contract, what it replaces, and what it does not do.
A1 and A2 are untouched. 13678 -> 19492 bytes.

### 3.6 Repository navigation (P4)

| File | Change |
|---|---|
| `README.md` (repo root) | new section 9 "Long-running Toolkit" stating: no release exists; v0.1 is a frozen pilot candidate; v0.2-rc.1 is the revision candidate under human review; where the development candidate, acceptance spec and evidence live; where to find the adoption procedure; the three release gates; and the future publication path (which does not exist). Also one new row in the quick index. |
| `experiments/long-running/README.md` | rewritten: the bucket table (v0.1 research line, v0.1 frozen artifact and evidence outside the repo, v0.2-rc.1 candidate, accepted release), the v0.1 asset table, the v0.2 index, and the three release gates. |
| `experiments/long-running/v0.2-work/README.md` | **new.** The navigation index for the development area: where to look for what, the directory map, and the rules that apply inside it (read-only neighbours, append-only evidence, revisions go through the spec, the scratch rule, no publication). It states plainly that this is a development/experiment area, not an installation directory. |

No directory was moved or renamed; no second index tree was created.

### 3.7 Adoption dry-run rebuilt as separate scenarios (P8)

`adoption/rc1-scenarios/{A-default-layout,B-custom-layout,C-blank-instances,D-missing-instances,E-pristine-toolkit}/`
- five independent, synthetic projects. The historical `adoption/dryrun-project/` is left in place
  and **still passes** (see 4.3), so the previous round's evidence stays reproducible. No test is
  pinned to that one project's layout: every scenario builds its own tree.

### 3.8 One bug found and fixed during the revision itself

The first run of the extended selftest **failed**, because the harness reused the previous
round's scratch root: `Copy-Item -Recurse -Force` merged into survivor directories and case T2
then mutated the wrong tree. Fixed by refusing a non-empty scratch root (T30) instead of purging
it, since an earlier run's evidence may live there. The failure and its fix are recorded here
rather than erased; the failing run's logs were superseded by the fresh run and the failed
console output is quoted in `evidence/RC1-DRY-RUN-EVIDENCE.md` section 5.

---

## 4. VERIFICATION

### 4.1 Mechanical

| Run | Command (in-process; see `evidence/INVOCATION.md`) | Result |
|---|---|---|
| Candidate mode | `Invoke-Check -Root candidate/long-running -Mode Candidate` | **exit 0 PASS** - `evidence/rc1/final-candidate.log` |
| Adoption, default layout | `… -Mode Adoption` on scenario A | **exit 0 PASS**, printed `instance root (default):` - `final-adoption-default.log` |
| Adoption, declared custom layout | `… -Mode Adoption -InstanceRoot <B>/planning` | **exit 0 PASS**, printed `instance root (declared):` - `final-adoption-custom.log` |
| Adoption, missing instances | scenario D | **exit 1**, reason names the path - `final-adoption-missing.log` |
| Adoption, blank instances | scenario C | **exit 1**, reason names `UNFILLED` - `final-adoption-blank.log` |
| Historical dry-run project (regression) | `adoption/dryrun-project` | **exit 0 PASS** - `final-adoption-historical.log` |
| Selftest | `Invoke-SelfTest` on a fresh scratch root | **SELFTEST PASS, 29 cases, 0 failures** - `final-selftest.log` |

### 4.2 Selftest case coverage (29 cases)

T1-T9 evaluator discrimination (missing artifact, missing frontmatter, absolute path, missing
section, stale count, placeholder, missing `UNFILLED`, `ERROR` on a missing root).
T10-T11 adoption default layout with a blank instance, and the same project's toolkit judged in
candidate mode. T12-T16 the instance-root contract (declared custom passes; declared missing
fails; declared-but-blank fails; toolkit templates refused; undeclared falls back to the printed
default). T17-T27 the scratch guard, each refusal typed and each followed by a filesystem check
that nothing was created. T28-T29 immutability of the candidate tree and of the whole scratch
base across the run.

### 4.3 Fail-closed scratch guard, verified at the harness entry point

Three real invocations were made, not just unit checks:

| Input | Observed |
|---|---|
| non-empty scratch root (`evidence/rc1/selftest-scratch`) | `ERROR: refusing to run: the scratch root is not empty` → **exit 2** |
| `-WorkRoot 'z\01-T1-pass'` (relative) | `ERROR: refusing to run: [relative] …` → **exit 2**; `z` does **not** exist afterwards |
| `-WorkRoot D:\Projects\dsh-test\somewhere-else` (outside the base) | `ERROR: refusing to run: [outside] …` → **exit 2**; the directory was **not** created |

### 4.4 Immutability of everything that had to stay frozen

| Object | Expected | Observed |
|---|---|---|
| v0.1 six frozen files | unchanged | all six digests match the pilot's freeze record exactly |
| `Evaluator v0` (`check.ps1`) | unchanged | `F3D22F99…` unchanged |
| `PILOT-SPEC-v0.1.md` | unchanged | `056D8DCA…` unchanged |
| pilot `GOAL.md` | unchanged | `88B9B033…` unchanged |
| pilot workspace overall | no writes | read-only inspection only |
| candidate trees inside scenarios | never modified | 8/8 files byte-identical to the candidate in all five scenarios; scenario E's five `templates/` still carry `UNFILLED` |
| promotion target `toolkit/` | must not exist | `Test-Path` = False |
| stray top-level directories after cleanup | none | `dsh-test` top level = `archive, docs, evidence, experiments, scripts, README.md` |

### 4.5 Out-of-bounds writes

None. The workspace file policy is `workspace-write`; every written path is under
`D:\Projects\dsh-test\experiments\long-running\v0.2-work\` plus the two repository-level README
edits, both inside the workspace. No write to the pilot workspace, no global DSH change, no
profile or sandbox change, no dependency install, no network access, no goal created.

---

## 5. RESIDUAL RISK

| # | Risk | Severity | Why it remains | Mitigation / next step |
|---|---|---|---|---|
| R1 | The evaluator was written by the same party that wrote the candidate and the scenarios; there is no independent judge. | medium | this round's mandate was a controlled revision, not an independent audit | human content acceptance is the compensating control; a second party re-running the frozen evaluator would strengthen it |
| R2 | The instance-root contract is verified in synthetic projects only, never in a real project with pre-existing conventions. | medium | touching a real business project is out of scope | run the adoption procedure once in a disposable copy of a real project, under a separate authorization |
| R3 | `-InstanceRoot` is a convention the adopter must follow; an evaluator that omits it silently falls back to the default and would fail a legitimate custom layout. | low | the default is documented and the fallback is printed, so the failure is visible rather than silent | the reason string now names `-InstanceRoot` as the fix; `SKILL.md` requires the agent to pass it |
| R4 | The evaluator does not parse `Instance root:` from `GOAL.md`, so the declaration and the command line can disagree. | low | deliberate separation (a toolkit file must not redirect the judge) | the printed `instance root (…)` line makes the disagreement visible; a human reviewing the log sees both |
| R5 | `COPY` semantics of `Copy-Item -Destination <nonexistent>` bit this round twice. | low | it is a PowerShell behaviour, not a toolkit defect | the harness now refuses dirty/missing scratch roots; a future `New-RealCopy` should assert the destination's parent exists first |
| R6 | The scratch guard trusts the `-ScratchBase` a caller passes. | low | only the human who invokes the harness can authorize a boundary; hard-coding one would make the harness host-bound | documented in the file header; the refusal messages state the boundary actually used |
| R7 | Symlink/junction aliasing is checked on existing segments only; a link created after the check is not detected. | low | the check runs immediately before use and the harness is single-threaded | acceptable for a local test harness; noted rather than solved |
| R8 | `rc.1` is a revision candidate; the content has now been revised twice and still has one authoring lineage. | medium | unchanged from the previous round | it is exactly the question `HUMAN CONTENT ACCEPTANCE` exists to answer |

---

## 6. FREEZE (v0.2-rc.1)

Read from disk after the final regression run. No file was edited after these values were taken.

### 6.1 Candidate - `candidate/long-running/` (8 files)

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

### 6.2 Judge and baseline

| Artifact | Bytes | SHA256 |
|---|---|---|
| `evaluator/check-v0.2.ps1` | 35010 | `2A96D3C404A8695633D24E78A57E526BFB2C5F628FAD6AD2B35C61641C98FF58` |
| `evaluator/check-v0.2.selftest.ps1` | 28279 | `E7E53A38C807794ACA9BC3E8D2664139835FA96F925A9B29698FFB54482027D2` |
| `V0.2-ACCEPTANCE-SPEC.md` | 19492 | `A3AA9A56BBE683F0A5612D707AEDF5CEA432006278D9930DE4D9DD1070A5B6CD` |

### 6.3 Status

```
V0.2-RC1 MECHANICAL PASS
V0.2-RC1 ADOPTION PASS
HUMAN CONTENT ACCEPTANCE PENDING
PUBLICATION NOT AUTHORIZED
```

`rc.1` is a revision candidate marker. The promotion target `toolkit/long-running/v0.2/` was
confirmed **not to exist** and nothing was copied into it.

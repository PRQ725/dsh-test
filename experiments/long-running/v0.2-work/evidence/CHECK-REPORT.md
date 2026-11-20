# V0.2 CHECK REPORT (mechanical verification record)

Object: the Long-running Toolkit v0.2 development candidate.
Judge: `evaluator/check-v0.2.ps1`, written for the eight-file v0.2 structure.
Baseline: `V0.2-ACCEPTANCE-SPEC.md`.
Everything below is recorded from actual runs in this round. Nothing here is estimated.

---

## 1. Artifacts

All digests below were read from disk with `Get-FileHash -Algorithm SHA256`.

| Artifact | Path | Bytes | SHA256 |
|---|---|---|---|
| Acceptance spec | `V0.2-ACCEPTANCE-SPEC.md` | 13678 | `8266FB69769AF0A53E71015466AE793400E391E8EC37E3265BE5674613956234` |
| Evaluator (frozen) | `evaluator/check-v0.2.ps1` | 31201 | `2E479296D2AC53A1A497546A906492CA9E3446F882142699511FDF3D5D7681BF` |
| Evaluator selftest | `evaluator/check-v0.2.selftest.ps1` | 13707 | `F20DB7D292DEC0F2623748956EDB63542EBE19CC9870464BB718A0424F923C48` |

Candidate per-file digests (recorded at the moment the candidate passed):

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

Adopting project's own evaluator (a different program, written by the adopter as the toolkit
instructs): `adoption/dryrun-project/evaluator/check-project.ps1`, 5863 bytes,
`421C75B6C4B142404CA13ECC02362684670E043323EFD3973919EAD8D3AC4CC5`. The dry-run project's
copy of the toolkit is byte-identical to the candidate for all eight files; that comparison is
one of the checks the project evaluator performs, and it passed.

---

## 2. Mechanical result

```
check-v0.2.ps1 - Long-running Toolkit v0.2 evaluator
mode: Candidate
root: <candidate>/long-running

PASS
  all V1-V12 and R1-R3 checks satisfied.
  NOTE: this says nothing about guidance quality, adoptability or version-claim correctness - human review required.
```

**Exit code 0.** Raw output preserved in `evidence/candidate-run.log`.

Adoption mode:

```
check-v0.2.ps1 - Long-running Toolkit v0.2 evaluator
mode: Adoption
root: <dryrun project>/toolkit/long-running
candidate: <candidate>

PASS
  all V1-V12 and R1-R3 checks satisfied.
```

**Exit code 0.** Raw output preserved in `evidence/adoption-run.log`.

---

## 3. Selftest matrix (real runs, real artifacts)

```
  PASS  T1 compliant copy passes
  PASS  T2 missing artifact fails
  PASS  T3 missing skill frontmatter fails
  PASS  T4 absolute path fails
  PASS  T5 missing required section fails
  PASS  T6 stale file count fails
  PASS  T7 placeholder token fails
  PASS  T8 missing UNFILLED marker fails
  PASS  T9 nonexistent root errors
  PASS  T10 adoption mode rejects blank instances
  PASS  T10b filled instance passes adoption
  PASS  T11 candidate unchanged by the selftest

SELFTEST PASS
  12 cases, 0 failures.
```

Each negative case is a **real copy of the candidate** mutated in exactly one way, never a
hand-written near-miss fixture. Observable outcomes per case are preserved under
`evidence/selftest-scratch/log-*.txt`, together with the mutated copies themselves. T11
re-hashes the candidate tree before and after the whole harness, so the harness cannot have
passed by damaging the artifact it validates.

---

## 4. Protocol deviations (recorded, not hidden)

1. **The freeze order in the spec's section 5 was not followed literally.** The spec says to
   write the spec, then the candidate, then the evaluator, then record its hash, then score.
   In practice the evaluator was authored first and driven with `-Root` against the candidate
   *while the candidate documents were still being written*, and the spec received two
   amendments during that same work. Consequences, stated honestly:
   - the first scoring runs therefore have **no** independent value;
   - the only run that counts as the verification result is the final one, whose evaluator
     digest is the one in section 1.
   The property that protects the truth of the record is that nothing was edited **after** the
   final scoring run: the evaluator digest did not change between the candidate PASS and the
   adoption PASS, and the candidate's own digests are re-verifiable.

2. **The evaluator's own first run produced false failures.** Five references were reported
   broken because the reference pattern used a backtick-assertion lookaround, and a backtick in
   a double-quoted PowerShell string is an escape character on this host. Recorded as spec
   amendment A2. The check was not weakened; the pattern was corrected, and case T2 still
   proves a broken reference is caught.

3. **The first real adoption run failed V12, and the failure was in the rule, not the
   project.** As first written, adoption mode scanned the toolkit root for blank-form markers,
   which can never pass in a correct adoption because a copied toolkit keeps its templates
   blank on purpose. Recorded as spec amendment A1; V12 now inspects the adopting project's
   own filled instances. Case T10/T10b prove the corrected rule discriminates in both
   directions.

4. **Nested-process execution is unavailable on this host.** `check.ps1`'s v0.1 selftest
   already recorded that a nested `powershell.exe` spawn is denied here. The v0.2 evaluator is
   therefore structured so its logic lives in a function that returns an exit code, letting the
   harness load it as text and invoke it in-process. This is a host limitation, not a design
   preference, and the same limitation is why the runner commands in the documents use the
   in-process form.

---

## 5. How to reproduce

```powershell
# record the evaluator digest that produced this report
Get-FileHash -LiteralPath <v0.2-work>\evaluator\check-v0.2.ps1 -Algorithm SHA256

# candidate
$sb = [scriptblock]::Create([System.IO.File]::ReadAllText('<v0.2-work>\evaluator\check-v0.2.ps1'))
. $sb -Root '__load__'
Invoke-Check -Root '<v0.2-work>\candidate\long-running' -Mode Candidate -LogPath '<v0.2-work>\evidence\candidate-run.log'

# adoption
Invoke-Check -Root '<v0.2-work>\adoption\dryrun-project\toolkit\long-running' -Proposal '<v0.2-work>\candidate' -Mode Adoption -LogPath '<v0.2-work>\evidence\adoption-run.log'

# selftest
$st = [scriptblock]::Create([System.IO.File]::ReadAllText('<v0.2-work>\evaluator\check-v0.2.selftest.ps1'))
. $st -Evaluator 'x'
Invoke-SelfTest -Evaluator '<v0.2-work>\evaluator\check-v0.2.ps1' -Candidate '<v0.2-work>\candidate\long-running' -WorkRoot '<v0.2-work>\evidence\selftest-scratch'
```

A nonzero exit from the direct `.ps1` invocation is expected on this host: `CurrentUser`
execution policy is `RemoteSigned`, so an unsigned local script is refused both directly and
through a nested `powershell -File` spawn, which is itself denied by the sandbox. The
in-process form above is the supported path here.

---

## 6. What this report does not establish

- It does not establish that the guidance is **good**, adoptable in a project unlike the
  dry-run project, or correctly generalised from DSH `0.2.0-rc.2`.
- It does not establish the version-bound mechanism claims; no runtime probe of goal
  activation, pause, the round cap or Skill discovery was performed in this round.
- It does not establish `HUMAN CONTENT ACCEPTANCE`, which remains pending.
- The evaluator was written by the same party that wrote the candidate. There is no
  independent judge here, and a green result from a self-authored gate is weak evidence.

`MECHANICAL PASS` on the candidate is a necessary condition, never a sufficient one.

---

## 7. Verdict and freeze

| State | Value | Who decided |
|---|---|---|
| `MECHANICAL PASS` (candidate) | **yes** - evaluator exit 0 | the evaluator |
| `ADOPTION DRY-RUN` | **pass** - evaluator exit 0 in adoption mode, harness independently PASS | the evaluator + the exercise |
| `READY FOR HUMAN REVIEW` | **yes** | reported by this round |
| `HUMAN CONTENT ACCEPTANCE` | **not given - pending** | reserved to a human |
| `PUBLICATION` | **not performed**; the promotion target does not exist | reserved to a human |

The candidate and the evaluator are both **frozen as of 2026-10-09**, at the digests in
section 1. The last action of this round was a confirmation run: the evaluator was re-hashed
immediately before and after the final candidate-mode and adoption-mode runs and the digest was
identical, so the recorded results belong to the recorded evaluator. Any later edit to a
candidate file or to the evaluator invalidates this report and requires re-running it from
section 5.

Also re-verified at the end of the round, unchanged: the six v0.1 frozen files (all six digests
match the first pilot's freeze record) and `Evaluator v0` (digest
`F3D22F99A59C4316A7DD0764FE7B83E441B91DD40148A53B2022E82A33C7BDA7`, still exiting 0 on the
frozen artifact). The promotion target directory was confirmed not to exist.

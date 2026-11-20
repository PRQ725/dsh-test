# RELEASE REPORT - Long-running Toolkit v0.2

Status: **RELEASED**. This is the development area's closing record. It is not a delivery file:
the portable release contains exactly eight files and none of this.

| Field | Value |
|---|---|
| Version | **v0.2** |
| Source revision | **v0.2-rc.3** |
| Release date | 2026-10-09 |
| Human content acceptance | **APPROVED** - direct authorization by the user, this round |
| Publication authorization | **APPROVED** - direct authorization by the user, this round |
| Source path | `experiments/long-running/v0.2-work/candidate/long-running/` (kept; it is the traceable release source) |
| Release path | `toolkit/long-running/v0.2/` |
| Research line status | **CLOSED / RELEASED** |

The user's decision this round also closes the v0.2 development line: no further changes to the
methodology or templates, no rc.4. New findings are registered and planned for a future version.

---

## 1. Released artifact

The release directory contains **exactly eight files** and no others:

```
toolkit/long-running/v0.2/
    README.md
    SKILL.md
    METHODOLOGY.md
    templates/
        GOAL.md
        PLAN.md
        STATE.md
        EVALUATION.md
        FINAL-REPORT.md
```

Nothing else was copied: no evaluator, no evidence, no adoption project, no selftest scratch, no
RC1/RC2/RC3 reports, no ZIP archives, no fixtures, no research material.

### 1.1 Release file hashes - 8/8 match

Each row was verified three ways: the release file, the frozen source file, and the digest
recorded in `RC3-CHANGE-REPORT.md` section G. All three agree for all eight files.

| File | Bytes | SHA256 |
|---|---|---|
| `README.md` | 23744 | `F02C536C85BB9421A4381DF098BE9E52F4EF43AB28ACBD5A7FE92638C7CF2134` |
| `SKILL.md` | 27405 | `95FF1D9097580A9B5A9FBE334D456DF53B8A1E7841EC6D83391D587A8AD5A1AB` |
| `METHODOLOGY.md` | 29942 | `49B6290715D479923033BCBB6CB0020B3439C61071CF626DE94A235040EC41DC` |
| `templates/GOAL.md` | 5169 | `FD19D55CC6AFE13132CA3A4BB8271A45ABB25472FA393E17B9E69B8D941FFEC1` |
| `templates/PLAN.md` | 3023 | `54CC75C48F2688489ABFDA1E5E6979E71146AA64017FC979BCADA21882A49E30` |
| `templates/STATE.md` | 2327 | `8895BA4EA4364F8F4F4D0C2AE5B0E5BDB6C19FC715EA310864ACCDDACB0306AC` |
| `templates/EVALUATION.md` | 6962 | `B576C5A444D13D7B18AED0A672F57E9CEA3E5869895F393B9A96A6204BB88A26` |
| `templates/FINAL-REPORT.md` | 5302 | `4F6F252D0DE32E7F838343C46AEF51336B584B2D7B0FD62BB9CD00E6ABBA8AB5` |

Additional publication checks:

- the source directory was re-hashed after the copy and **all eight source files are unchanged**;
- the release `README.md`'s five `templates/*.md` references all resolve to files inside the
  release directory;
- the release directory contains no non-Markdown file.

---

## 2. Acceptance results carried into the release

These are the results of the frozen judge on the exact bytes that were published. They are quoted
from the rc.3 evidence and were re-checked against the release hashes above; the release itself
was not re-judged, because the bytes are identical.

| Check | Result | Evidence |
|---|---|---|
| **CANDIDATE VALIDATION** | **PASS** - `all V1-V16 and R1-R3 checks satisfied` | `evidence/rc3/final-candidate.log` |
| **INSTANCE HYGIENE** | **PASS** - `HYGIENE PASS` + `CONTRACT NOT CHECKED` on five scenarios | `evidence/rc3/final-hygiene.log`, `final-hygiene-default.log` |
| **CONTRACT-VERIFIED ADOPTION** | **PASS** - `ADOPTION PASS (contract-verified)`; refused (exit 2) without a contract | `evidence/rc3/final-adoption.log`, `final-adoption-nocontract.log` |
| **INITIALIZATION READINESS** | **HUMAN PENDING** - contract implemented; returns exit 3 for missing prerequisites and for open human gates | `evidence/rc3/final-readiness.log`, `final-readiness-nocontract.log` |
| **SELFTEST** | **PASS - 44 cases, 0 failures** | `evidence/rc3/final-selftest.log` |
| **R3 regression matrix** | **13/13 as expected** | `evidence/rc3/r3-R3-T*.log`, `evidence/rc3/rc3-matrix.ps1` |

**HUMAN CONTENT ACCEPTANCE: APPROVED** by the user's direct authorization this round. This is a
human act; no evaluator output was treated as a substitute for it, and the release record states
which person authorized the publication (the user) rather than inferring approval from text.

---

## 3. Not-yet-verified mechanisms

Recorded so the release does not imply more than was tested. None of these was exercised against
the v0.2 toolkit:

- goal creation and any automatic round under this toolkit;
- pause, resume, and re-arming a goal;
- host-restart recovery;
- the round-cap behaviour of the continuation driver;
- any `SOFT` stop condition's practical effect;
- live DSH Skill discovery and loading of `SKILL.md`;
- adoption by a project other than the synthetic scenarios.

---

## 4. Known Limitations

These are published as-is. **The eight release files were not modified to add them**; where a
limitation concerns wording inside the release, it is recorded here rather than patched into a
frozen artifact.

**L1 - Skill auto-discovery is unverified.** Whether DSH actually discovers and loads the installed
`SKILL.md` has never been observed. Placement and frontmatter were checked as files; no live
session catalog or `skill` tool call was performed. Treat path 2 of the installation section as a
documented, plausible procedure to confirm locally.

**L2 - No real multi-round goal execution.** Real multi-round goal execution, pause/resume, and
host-restart recovery have not been exercised through a complete adoption of the v0.2 toolkit.

**L3 - Readiness partly requires human judgement.** Some readiness conditions depend on a real
person's judgement and cannot be granted mechanically. The evaluator reports them as `PENDING`
and never closes them; a machine result never authorizes starting a goal.

**L4 - `-InstanceRootDeclared` is weaker than a contract.** It can supply a path declaration, but
using it alone does not prove the declaration came from a frozen `GOAL.md`. Real projects should
prefer a readable `-GoalContract` and check it against the frozen baseline. The evaluator names
which of the two sources it used, so the distinction is auditable in the output.

**L5 - Historical wording difference between README Step 10.5 and Step 10.6.** The two steps were
written in different revisions and their wording differs in places. **The four-verdict contract of
rc.3 and amendment A5 are authoritative** where they disagree with the older prose. This is a
documented inconsistency, not a silent repair.

**L6 - Acceptance evidence is mostly synthetic.** The accepted verification results come mainly
from synthetic projects; adoption against a complex real project has not been validated.

**L7 - Structural checks are not content quality judgement.** The evaluator's text and structure
checks cannot replace a human content quality judgement. A mechanically clean document set can
still be poor guidance.

---

## 5. Archival inventory - what is preserved and where

The v0.2 development line is **CLOSED / RELEASED**. The following are preserved in place, not
copied, so that every path a report cites keeps working.

### 5.1 Permanent records (A)

| Artifact | Bytes | SHA256 |
|---|---|---|
| `RC1-CHANGE-REPORT.md` | 22056 | `4F21472EDFD25157EFC0E8F8D7B8E8E06482CA1094FA68DABA8EF00A4993F262` |
| `RC2-CHANGE-REPORT.md` | 24401 | `7ED47904880E8E4D487045B62D6211EBE00FA9787A9415E96048E6016B48CE61` |
| `RC3-CHANGE-REPORT.md` | 23915 | `BB131F571AFA142C6CFFABB2511237E683F46019B27646AEFCFD20BE9FA8766C` |
| `V0.2-ACCEPTANCE-SPEC.md` | 35945 | `480E0CD3D3EF699AC0BC229B7F7A9EE6E7B8FC629617CDE9C3DEB93DFB9E13A7` |
| `evaluator/check-v0.2.ps1` | 69251 | `4B5DD1D76AE6288417CB8EBEC1342F9EA1118D4E11A7D1523AA481AD3C031EA1` |
| `evaluator/check-v0.2.selftest.ps1` | 40349 | `057BE35F9578B1C1230417B19990B9E02D8CC24810A376A208736D45C6B9F75F` |
| `candidate/long-running/` (8 files) | - | section 1.1 |
| `README.md` (this development area's index) | - | see the file itself |
| `RC3-CHANGE-REPORT.md`-referenced release record | - | `toolkit/long-running/RELEASES.md` |

### 5.2 Essential evidence (B) - kept, because it is not regenerable or is cited by a report

| Group | Files | Bytes | Why preserved |
|---|---|---|---|
| `evidence/rc3/` acceptance logs | `final-candidate.log` (423), `final-adoption.log` (916), `final-readiness.log` (3159), `final-readiness-nocontract.log` (361), `final-adoption-nocontract.log` (360), `final-hygiene.log` (828), `final-hygiene-default.log` (839) | ~6.9 K | the accepted run's raw output; cited in section 2 |
| `evidence/rc3/final-selftest.log` | 21952 | 21 K | the 44-case harness result |
| `evidence/rc3/r3-R3-T*.log` | 13 files | ~6 K | the R3 matrix's raw per-case output, including the four refusal cases |
| `evidence/rc3/RC3-CONTEXT.md` | 2793 | 2.7 K | the worked example of the closed defect |
| `evidence/rc2/final-selftest.log`, `evidence/rc1/final-selftest.log` | 16172, 9314 | 25 K | each revision's own harness result |
| `evidence/CHECK-REPORT.md`, `DRY-RUN-EVIDENCE.md`, `RC1-DRY-RUN-EVIDENCE.md`, `RC2-DRY-RUN-EVIDENCE.md`, `INVOCATION.md` | - | 31 K | the acceptance and dry-run records the reports cite |
| `evidence/rc1|rc2|rc3/selftest-scratch/` | 99 + 140 + 225 + 322 files | ~5.6 MB | contains unique failure reproductions (mutated copies referenced by name in the reports) and the scratch-guard refusal evidence; see section 6 |
| `adoption/dryrun-project/`, `adoption/rc1-scenarios/`, `adoption/rc2-scenarios/` | 18 + 47 + 85 files | ~1.2 MB | the dry-run projects the reports measure; several report tables quote their instance-root declarations |

### 5.3 v0.1 Pilot index and raw evidence reference

The first pilot is **outside this repository** and was not touched:
`D:\Projects\dsh-longloop-pilot\` (read-only this round). Its frozen six files and its evidence
retain the digests recorded in it, re-verified this round:

| v0.1 artifact | SHA256 |
|---|---|
| `out\toolkit-v0.1\README.md` | `EA0F9422DBE963FC0EB583E965D8701EFC16CEF13F12F67DF0F0B8A3634F9E32` |
| `out\toolkit-v0.1\SKILL.md` | `537D4135F6CBA8BD579F0A2E932C5DC28B6FC9218805AB8A9C65C9F0BE3B2F86` |
| `out\toolkit-v0.1\METHODOLOGY.md` | `B9BF5F0D7CB97ACC218BFCACF586A934540A0DA9ABC46C1A41B2119A6D534BDC` |
| `out\toolkit-v0.1\templates\GOAL.md` | `06D4FA447F0D7522049699E21DAFA6D88383079BD41C264EA096BD201C049DD1` |
| `out\toolkit-v0.1\templates\STATE.md` | `62D650DC6A9CF799C9FD733889A18928BCC7607C7BA022B96C20D26940FA8CD4` |
| `out\toolkit-v0.1\templates\EVALUATION.md` | `B5D18E3D96FB3D5D1868A46363CFE169B7FB0EC2D896C025EEA755905AD0B180` |
| `experiments/long-running/check.ps1` (Evaluator v0) | `F3D22F99A59C4316A7DD0764FE7B83E441B91DD40148A53B2022E82A33C7BDA7` |
| pilot `GOAL.md` | `88B9B033B26DB2067F9055963FDF9BFC9253B07C46B87E4DBDB41DF74FCDC095` |

### 5.4 What "frozen archive" means here, and what it does not

It means: unauthorised modification is forbidden by policy, the digests above are recorded, and
the status of this line is CLOSED / RELEASED.

It does **not** mean the operating system prevents modification. This workspace is **not a git
repository**, carries no version-control history, and no verified read-only enforcement was
applied to these paths - the evaluator is read-only by construction, but the filesystem will
happily overwrite a "frozen" file if a future process is careless. Anyone resuming work here
should treat the digests as the integrity check, and should not describe the archive as
OS-protected without first verifying such a mechanism.

---

## 6. Cleanup inventory and decisions

Every file under `v0.2-work` before cleanup: **963 files, 8,556,502 bytes (8.16 MB)**.
After the executed cleanup: **947 files, 8,397,988 bytes (8.01 MB)** - **158,514 bytes freed**.

| Class | Meaning | Action |
|---|---|---|
| **A. PERMANENT** | release source, acceptance spec, evaluator/selftest code, reports, indexes | kept |
| **B. ESSENTIAL EVIDENCE** | unique failure reproductions, accepted run results, dry-run projects and fixtures a report cites | kept |
| **C. REGENERABLE TEMP** | can be deterministically regenerated from kept scripts and frozen inputs, with no independent historical value | eligible for deletion |
| **D. UNKNOWN** | origin, purpose or regenerability not established | kept |

### 6.1 The `scratch` naming trap

A directory called `scratch` is **not automatically** class C. `evidence/rc1|rc2|rc3/selftest-scratch/`
were examined individually and classified **B**, because they contain the mutated copies that the
acceptance reports cite by name (for example the copy with the injected absolute path, and the copy
with the wrong file count) together with the raw per-case logs. Regenerating them would produce
different directory names and possibly different bytes, so they are not equivalent evidence.

### 6.2 Items classified C and removed

See section 7 for the executed deletions, each with its ten-point protection check.

### 6.3 Items deliberately kept that a future round may revisit

| Item | Why kept now |
|---|---|
| `evidence/selftest-scratch/` (99 files, 0.81 MB) | it is the **v0.2-baseline** harness run, predating the rc.1/rc.2/rc.3 renumbered layouts. Its nested `long-running\long-running\` tree is debris from the historical path bug, but the directory as a whole is cited evidence for that era and its logs are unique. Classified **B** as a whole; the nested debris inside it was classified **C** and removed (section 7). |
| `evidence/rc2/r2-*.log` and `evidence/rc2/final-r2-*.log` (superseded exploratory matrix runs) | superseded by `final-r2-*`, but they are the raw record of the run whose assertions were later corrected. Kept as **B** rather than rewritten away. |
| `evidence/rc3/probe-*.log` | exploratory first-run logs from this revision; superseded by `final-*` and not cited. Classified **C-eligible** but kept in this round because they document the evaluator's behaviour before the last edit. |
| `adoption/rc1-scenarios/`, `adoption/rc2-scenarios/` | the reports quote their declarations and compare their files; `rc2-scenarios` is also the only place a pre-rc.3 `check-project.ps1` survives. |
| the two user ZIP archives in `candidate/` | user-created; explicitly protected. See section 7.2 - a **third** archive appeared during this round. |

### 6.4 User ZIP archives - protected, not touched

The user confirmed during the rc.3 round that the archives in `candidate/` are their own manual
snapshots. **Three** are now present; a third was created during this round at `22:17:15`, after
the publication copy was made. All three are recorded, protected, and were neither
deleted, moved, renamed, nor re-compressed.

| Archive | Bytes | Created | Note |
|---|---|---|---|
| `candidate/long-running.zip` | 33504 | 2026-10-09 13:45:12 | user-confirmed older snapshot |
| `candidate/long-running (2).zip` | 34757 | 2026-10-09 20:51:03 | user-confirmed later re-compression |
| `candidate/long-running (3).zip` | 43557 | 2026-10-09 22:17:15 | **created during this round by the user**, after publication; not created by this task |

They sit **beside** the `long-running/` directory, not inside it, so the eight-file candidate and
the eight-file release are unaffected. Version correspondence was not inferred from the file names
and was not re-inspected this round.

---

## 7. Executed cleanup

Only items that passed all ten protection checks were removed. Each entry records the checks that
mattered, and the deletion used a literal absolute path inside `v0.2-work`.

| # | Path | Files | MB | Class | Why regenerable / valueless | Protection checks |
|---|---|---|---|---|---|---|
| C1 | `evidence/selftest-scratch/{01-T1-pass,02-T2-missing}/long-running/long-running/` (nested duplicate trees left by the historical path bug) | 16 | 0.15 | C | the nested `long-running\long-running\` copies are an artifact of the evaluator's old relative-path bug; the correct copy of each case sits beside them in the same case directory, and the case logs that cite those cases do not reference the nested path | inside `v0.2-work` (verified by string prefix **and** by a regex requiring the `\long-running\long-running` suffix); not a reparse point; **0 references** anywhere in the repository across `.md`, `.ps1`, `.log`, `.txt`; no unique evidence (the sibling copy is the cited one, and the nested copy was identified as rc.1-era bytes by its file sizes); reproducible by re-running the kept harness; release and candidate hashes unaffected |

**Executed result:** 16 files, 158,514 bytes removed. No other object passed all ten checks, so
nothing else was deleted. No deletion failed, and no wider permission was requested at any point.

### 7.1 Post-cleanup verification

- release directory: still exactly eight files, **8/8 hashes match** the rc.3 freeze;
- candidate directory: still exactly eight files, **8/8 hashes match** the rc.3 freeze;
- `RC1/RC2/RC3-CHANGE-REPORT.md`, `V0.2-ACCEPTANCE-SPEC.md`, `evaluator/check-v0.2.ps1`,
  `evaluator/check-v0.2.selftest.ps1`: present;
- user ZIP archives: present, byte sizes unchanged;
- repository root: no unexpected directory.

---

## 8. Release-state governance for the closed line

The v0.2 release directory and this archive are **frozen by policy**:

1. The eight files in `toolkit/long-running/v0.2/` are not edited. A defect found in v0.2 is
   registered as an issue and planned for the next version; it is not hot-patched in place.
2. `RC1`, `RC2` and `RC3` reports, the acceptance spec, the evaluator and the selftest are retained
   as recorded, including every failed run and every superseded assertion.
3. New evidence may be added; existing evidence is not rewritten to make a later result look
   cleaner.
4. A future version starts from the release as its baseline and produces its own candidate,
   acceptance spec revision and evidence. It does not reopen rc.3.
5. Integrity is checked by comparing digests, not by assuming a filesystem guarantee (section 5.4).

---

## 9. Closing statement

The v0.2 line is **CLOSED / RELEASED**. The publication is complete: eight files, 8/8 hash match
against the frozen rc.3 source, human acceptance and publication authorization recorded from the
user's direct instruction this round, and the limitations published above rather than hidden.

The line is closed deliberately. Any further work - including the seven known limitations - belongs
to a future version with its own candidate and its own acceptance record.

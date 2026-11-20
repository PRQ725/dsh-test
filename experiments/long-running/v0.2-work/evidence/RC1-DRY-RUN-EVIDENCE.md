# ADOPTION DRY-RUN - v0.2-rc.1 scenario matrix

Purpose: after the rc.1 revision (instance-root contract, fail-closed scratch guard, navigation),
re-run the bounded adoption exercise against fresh scenario projects and record what actually
happened. This file records the **rc.1** run; the earlier v0.2-baseline dry-run remains in
`DRY-RUN-EVIDENCE.md` and its project remains at `../adoption/dryrun-project/` unchanged.

- Candidate under test: `../candidate/long-running/` (8 files; digests in `RC1-CHANGE-REPORT.md`)
- Judge: `../evaluator/check-v0.2.ps1` (digest in `RC1-CHANGE-REPORT.md`)
- Scenarios: `../adoption/rc1-scenarios/{A,B,C,D,E}/`
- Command shape for every run below:
  `Invoke-Check -Root <scenario>/toolkit/long-running -Proposal <candidate> -Mode Adoption [-InstanceRoot <dir>] -LogPath <log>`
  (in-process invocation; see `INVOCATION.md` for why the direct `.ps1` form is refused on this host)
- No goal was created, no automatic round ran, and no real project was touched.

## 1. Scenario results

| # | Scenario | Instance root | Declared? | Expected | Observed | Log |
|---|---|---|---|---|---|---|
| 1 | A-default-layout | `docs/long-running/` | no (default) | exit 0 | **exit 0**, printed `instance root (default):` | `rc1/adoption-A-default.log` |
| 2 | A-default-layout | `docs/long-running/` | yes | exit 0 | **exit 0**, printed `instance root (declared):` | `rc1/adoption-A-default-decl.log` |
| 3 | B-custom-layout | `planning/` | yes | exit 0 | **exit 0**, printed `instance root (declared):` | `rc1/adoption-B-custom.log` |
| 4 | B-custom-layout | not declared | no | exit 1 | **exit 1**: `the default instance root does not exist … (pass -InstanceRoot to declare a different directory)` | `rc1/adoption-B-custom-nodecl.log` |
| 5 | C-blank-instances | `docs/long-running/` | no | exit 1 | **exit 1**: `the project document GOAL.md is still a blank form (contains UNFILLED)` | `rc1/adoption-C-blank.log` |
| 6 | D-missing-instances | not declared | no | exit 1 | **exit 1**: `the default instance root does not exist …` | `rc1/adoption-D-missing.log` |
| 7 | D-missing-instances | declared, absent | yes | exit 1 | **exit 1**: `the declared instance root does not exist as a directory` | `rc1/adoption-D-missing-decl.log` |
| 8 | E-pristine-toolkit | not declared | no | exit 1 | **exit 1**: `the default instance root does not exist …` | `rc1/adoption-E-pristine.log` |
| 9 | B-custom-layout | `toolkit/long-running/templates` | yes | exit 1 | **exit 1**: `the instance root resolves inside the toolkit's own reusable toolkit tree` | `rc1/adoption-T-templates.log` |

**9 scenarios, 18 assertions (exit code and required reason text each), 18/18 as expected.**

Scenario 1 and scenario 2 are deliberately the same directory reached two ways. They prove the
default path and a declaration of that same path agree, while the banner distinguishes which one
was used - so a PASS can never be attributed to a path nobody can see.

## 2. What the scenarios establish

| Claim | Evidence |
|---|---|
| A fresh project using the documented default layout reaches a verified initialization | scenario 1 |
| A project that declares a different instance root is **not** failed for it | scenario 3 (was exit 1 before amendment A3) |
| Not declaring a non-default layout is caught, with the fix named in the reason | scenario 4 |
| Blank forms are never mistaken for an initialized project | scenario 5 |
| A missing instance root fails with the concrete path | scenarios 6, 7 |
| The toolkit's own reusable `templates/` is never accepted as an instance root | scenario 9 |
| Adoption does not require the generic templates to be modified | section 3 |
| No scenario required creating a goal | no goal exists; nothing armed |

## 3. The toolkit copy stayed pristine in every scenario

For all five scenarios, all eight files of `toolkit/long-running/` are byte-identical to the
candidate (0 differing files in each). In scenario E specifically, all five files under
`templates/` still carry the `UNFILLED` marker, i.e. the reusable forms were never consumed.

The filled instances live outside the toolkit copy in every scenario: `docs/long-running/` in A,
`planning/` in B. That separation is what the rc.1 README now states and what the evaluator
enforces by refusing any instance root that resolves inside the toolkit tree.

## 4. The declaration really is explicit

Both filled `GOAL.md` instances carry the field as the first line of the declaration, with the
project's real relative path:

```
A: Instance root:  ->  docs/long-running/
B: Instance root:  ->  planning/
```

Nothing inferred the location from a convention: the task text, the README, the `SKILL.md`
instruction and the evaluator all name it, and the evaluator prints back what it was given.

## 5. Deviations and incidents in this run

1. **A first attempt at the scenario matrix was built incorrectly** while the run was being
   assembled (`Copy-Item -Destination` creates the destination directory when it does not exist,
   which nested a copy one level too deep). It was discarded and the scenarios rebuilt. Recorded
   because the resulting tree is what the recorded logs refer to; no log from the discarded
   attempt is cited.
2. **The first run of the extended selftest failed** - not because the evaluator was wrong, but
   because the harness reused a *dirty* scratch root left by the previous round, so `Copy-Item`
   merged into a survivor directory and case T2 mutated the wrong tree. The fix is recorded as
   T30 in `V0.2-ACCEPTANCE-SPEC.md`: the harness now refuses a non-empty scratch root with
   `ERROR` (exit 2) instead of running on dirty state or purging it. The failing run is preserved
   in the round record rather than erased.
3. **`Instance root:` is declared, not parsed.** The evaluator does not read the field out of
   `GOAL.md`; it takes the directory on the command line and reports what it used. Two separate
   mechanisms on purpose: the field is the project's declaration of record, the parameter is the
   adopter's explicit instruction to the judge. A toolkit file therefore cannot silently redirect
   the judge.

## 6. Not tested

Goal creation, automatic rounds, the round cap, pause/resume, restart recovery, and the
behaviour of any `SOFT` stop condition. All of them require a goal, which this exercise
deliberately never created. Independent adoption is also not tested: the same party wrote the
toolkit, the scenarios and the judge.

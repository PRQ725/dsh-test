# R2 quiescent baseline: compare-validator FALSE FAIL (zero-diff rejected)

Status: **FIXED — R2 revalidated PASS**
Written: 2026-10-05 (local, UTC+8)
Scope: `Test-GuardedCompareOutput` / `Invoke-GuardedCompare` in `capture-guard.ps1`

---

## 1. Symptom

The R2 quiescent capture itself succeeded completely:

```
gate #1 True   capture #1 valid True   sessions=56 shared-state=30 projcache=56
gate #2 True   capture #2 valid True   sessions=56 shared-state=30 projcache=56
formats capture#1: v3=54 v4=2   (rows 56)
formats capture#2: v3=54 v4=2   (rows 56)
```

`compare-captures.ps1` also completed normally:

```
SECTION: SHARED STATE              total tracked 30  ADDED 0 DELETED 0 CONTENT-CHANGED 0 MTIME-ONLY 0
SECTION: DSH_HOME FINGERPRINTS     total tracked 12  ADDED 0 DELETED 0 CONTENT-CHANGED 0 MTIME-ONLY 0
SECTION: SESSION INVENTORY         total tracked 56  ADDED 0 DELETED 0 CONTENT-CHANGED 0 MTIME-ONLY 0
SECTION: PROJCACHE INVENTORY       total tracked 56  ADDED 0 DELETED 0 CONTENT-CHANGED 0 MTIME-ONLY 0
SECTION: SESSION FORMAT SUMMARY    BEFORE total=56 v3=54 v4=2 / AFTER total=56 v3=54 v4=2
report lines written = 49     warnings: 0
```

Yet the wrapper printed:

```
[FATAL] [diff] compare-detail.csv is empty
  diff valid : False
QUIESCENT BASELINE: FAIL
```

## 2. Root cause

`compare-captures.ps1` writes the detail file with

```powershell
$all | Export-Csv -LiteralPath (Join-Path $OutDir 'compare-detail.csv') -NoTypeInformation -Encoding UTF8
```

`compare-detail.csv` contains **only entries that CHANGED**. When the two captures are
identical, `$all` is empty and a zero-row `Export-Csv` produces a **3-byte, BOM-only file**
(no header line at all). That is the correct, expected artifact for a zero-diff pair — and
it is exactly the outcome a quiescent-baseline capture exists to prove.

The validator contradicted that:

```powershell
$raw = Get-Content -LiteralPath $detail -Raw -Encoding UTF8
if (-not $raw -or $raw.Trim().Length -eq 0) { $errors.Add('compare-detail.csv is empty') }
```

`Get-Content -Encoding UTF8` strips the BOM, so a BOM-only file reads back as `""` and the
validator raised `compare-detail.csv is empty`. This made "no differences" unrepresentable:
the validator could only accept a baseline that showed differences.

Classification: **FALSE FAIL / fail-too-closed**, not an environment problem and not a
capture problem.

## 3. Why the earlier self test did not catch it

The self test's TEST 8 stub wrote a **CSV header line**:

```powershell
"Section,Class,Rel,BeforeSize,AfterSize,BeforeHash,AfterHash" | Set-Content ... compare-detail.csv
```

`Import-Csv` then returned 0 rows with no error, so the assertion "a valid 0-row diff is
accepted" passed — but it exercised a file shape the **production producer never emits**.
The production zero-row artifact is header-less and empty. The self test therefore tested
the helper with a synthetic input instead of the production path, and the divergence sat
exactly on the boundary being tested.

Lesson: a validator test must be driven by the real producer's real output, not by a
hand-written approximation of it.

## 4. Corrected validity rule

`diffValid = True` iff all of:

1. the compare script ran to completion (`Invoke-GuardedCompare` did not throw, and the
   redirection log exists and is non-empty)
2. the log carries the completion marker `SCRIPT D DONE`
3. all four sections are present and each reports `total tracked`:
   `SHARED STATE`, `DSH_HOME FINGERPRINTS`, `SESSION INVENTORY`, `PROJCACHE INVENTORY`
4. every section's `total tracked` is > 0
5. every section reports all four classes: `ADDED`, `DELETED`, `CONTENT-CHANGED`, `MTIME-ONLY`
6. the log's completion marker and the report both report `warnings: 0`
7. no `SKIPPED`, no `manifest missing`, no `[!]` flagged problem, no parser error,
   no truncation notice
8. the `SESSION FORMAT SUMMARY` section exists and its `BEFORE total=` / `AFTER total=`
   values parse and are > 0
9. **`detailRows == expectedDetailRows`**, where
   `expectedDetailRows = Σ over all required sections (ADDED + DELETED + CONTENT-CHANGED + MTIME-ONLY)`

`detailRows` is the number of rows in `compare-detail.csv`.

**`detailRows == 0` is never by itself a reason to call the diff invalid.** Both mismatch
directions are invalid: counts > 0 with `detailRows == 0`, and all counts == 0 with
`detailRows > 0`.

Log encoding is auto-detected (`Read-TextAnyEncoding`): `compare-report.txt` is UTF-8 with
BOM (written by `Set-Content -Encoding UTF8`) while the compare log comes from a `*>`
redirection and is UTF-16LE.

## 5. Verification

- `compare-validator.regression.ps1` — production-path regression, **25 passed / 0 failed**,
  exit 0. Cases: real R2 output validates; identical fixtures → valid with 0/0; changed
  fixtures → valid with detail == expected; counts > 0 with empty detail → invalid;
  all counts 0 with detail rows → invalid; SKIPPED → invalid; truncated log → invalid.
  The cases run through `Invoke-GuardedCompare` → real `compare-captures.ps1` where possible.
- `capture-guard.selftest.ps1` — updated TEST 6 (complete report with one SKIPPED section is
  rejected, and the empty detail is explicitly *not* the reason) and TEST 8 (complete,
  consistent zero-row diff is accepted). **29 passed / 0 failed**, exit 0.

## 6. Related defects fixed in the same pass

1. **`$CMP` / `$cmp` case collision.** `capture-e1-quiescent-baseline.ps1` used `$CMP` for the
   compare path and `$cmp` for the result object. PowerShell variable names are
   case-insensitive, so the result object overwrote the path and the verdict printed
   `compare : @{Ok=False; Errors=System.String[]; ...}` instead of the path. Renamed to
   `$cmpResult` in all three wrappers.
2. **Fragile test assertions.** `CHECK "..." (@($r.Errors) -match 'x').Count -gt 0 ...` is
   parsed in command-argument mode, so `-gt 0` became a stray argument and only `.Count` was
   tested. Replaced with an explicit `HasErr` helper called inside parentheses.

## 7. Revalidation result (no re-capture)

`revalidate-e1-quiescent-baseline.ps1` re-ran the compare into a new directory
(`e1-BASE-QUIESCENT-R2-compare-revalidated`), re-validated the **original** compare output
too, and re-verified capture completeness and format stability from the existing artifacts:

```
capture #1 valid (re-verified)   : True
capture #2 valid (re-verified)   : True
diff valid (re-run)              : True   detailRows=0 expectedDetailRows=0
diff valid (original artifacts)  : True
format stable                    : True
captures unmodified              : True
changes                          : fatal=0 drift=0
QUIESCENT BASELINE (R2, REVALIDATED): PASS
```

The script records a SHA-256 inventory of both capture directories before and after and
asserts it is unchanged, so "the captures were not overwritten" is verified rather than
asserted. Fingerprints: `e1-BASE-QUIESCENT-R2-CAPTURE-FINGERPRINTS.txt`.

The original FAIL verdict is **preserved unchanged** as history:
`e1-BASE-QUIESCENT-R2-VERDICT.txt` (2944 B, `DCD49D68F45AFD927C1424CA892F087463FA7E8C9639BD74C0DF4CA1A8DE5CDF`).
The new result is a separate file: `e1-BASE-QUIESCENT-R2-REVALIDATED-VERDICT.txt`.

## 8. Facts established

[FACT] The two R2 captures are content-identical across all four compared manifests.
The four manifest files have identical size and SHA-256 in both directories:

| File | Size | SHA-256 |
|------|------|---------|
| `shared-state-manifest.csv` | 3462 B | `FDCE95FEA208D74E798F3A7391DDBBD6E57A749B7CCFD735B54D98CCC0C0AFD1` |
| `dsh-home-fingerprints.csv` | 1404 B | `469AAF0A0451CB9173773C80FB248FC2B6F000059131B00EFA60BEC919E852AA` |
| `session-inventory.csv` | 21331 B | `C6D0B1DBE3472E551B53534DB5F8A9D3EC761A3EFA0F45E9A6BF027886C35C61` |
| `projcache-inventory.csv` | 8589 B | `393C37A97A444B19FE16A1D98370E95117E80B1E2D0789BC5DC5004873C258F3` |

[FACT] Session format distribution is `v3=54 v4=2` (56 rows) in both captures.
[FACT] `compare-captures.ps1` reported `warnings: 0` and `report lines written = 49`.
[FACT] The environment was quiescent across the two captures: gate #1 and gate #2 were both
recorded True in the original run (0 desktop processes, 0 cli hosts, 0 MCP processes,
ports 3080/3180 free). This is carried forward as recorded, not re-measured.
[FACT] Both captures pass the capture sentinel and sanity checks when re-verified.
[INFERENCE] The earlier FAIL was caused solely by the validator defect; no environmental
drift is evidenced.
[NOTE] Files outside the compared set also came out byte-identical between the two
captures: `credentials-metadata.json`, `desktop-app-fingerprints.csv`, `dir-metadata.csv`,
`listeners.csv`, `presence-flags.json`, `session-summaries.jsonl` (see
`e1-BASE-QUIESCENT-R2-CAPTURE-FINGERPRINTS.txt`). They are not part of the diff by design.
[NOTE] The only files that differ between the two captures are those that embed the capture
label and timestamps: `_log-A/B/C.txt`, `summary.txt`, `shared-state-summary.txt`,
`runtime-test-session.json`. Their difference is not evidence of drift.
[UNKNOWN] Whether any of the non-compared files would stay byte-identical on a *future*
re-capture is untested; only the two present copies were compared.

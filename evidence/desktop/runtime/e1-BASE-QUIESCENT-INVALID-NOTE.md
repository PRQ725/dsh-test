# INVALID: R1 quiescent baseline capture — FALSE PASS (quarantined, never usable)

Status: **INVALID — do not use, do not delete**
Written: 2026-10-05 (local, UTC+8)
Scope: `evidence\desktop\runtime\e1-BASE-QUIESCENT*` (R1 namespace)
Replacement: `evidence\desktop\runtime\e1-BASE-QUIESCENT-R2*` (R2 namespace, not yet captured)

---

## 1. What was claimed

On 2026-10-05 13:33:18 the R1 wrapper `capture-e1-quiescent-baseline.ps1` printed:

```
QUIESCENT BASELINE: PASS
  both captures are byte-identical: no ADDED / DELETED / CONTENT-CHANGED / MTIME-ONLY
  baseline : ...\e1-BASE-QUIESCENT
  verify   : ...\e1-BASE-QUIESCENT-2
```

## 2. Why that claim is FALSE

**Neither capture directory exists.** There is no baseline. The two directories named in
the PASS text were never created; no capture script ever ran; no manifest was ever written.

```
e1-BASE-QUIESCENT    -> ABSENT   (verified)
e1-BASE-QUIESCENT-2  -> ABSENT   (verified)
```

The PASS therefore asserted "byte-identical" about two directories that do not exist.

## 3. Root cause (fail-open at three independent points)

The R1 wrapper redirected a child's **entire output stream into a file inside a directory
that did not exist yet**:

```powershell
& capture-desktop-runtime.ps1 -OutDir $CAP1 -Label ... *> "$CAP1\_log-A.txt"
```

`$CAP1` had never been created. Windows PowerShell could not open the redirection target
and raised a **DirectoryNotFoundException** while setting up the redirection, **before the
child process could run**. Because the target file could not be opened, this exception had
nowhere to be logged — it appeared only on the console of the R1 run, which is itself part
of why the failure was invisible in the artifacts. It is reproduced on disk by
`_selftest-r2\...\selftest-report.txt` (TEST 7), whose recorded message is:

```
Could not find a part of the path
'...\_selftest-r2\run-<id>\does-not-exist\cap\_log-A.txt'.
```

The three independent fail-open points were:

| # | Point | Actual behaviour | Required behaviour |
|---|-------|------------------|--------------------|
| 1 | redirection target | directory missing -> child never executes | create destination before redirecting |
| 2 | wrapper success line | `[PASS] capture #1 written` printed **unconditionally**, without checking any artifact | must verify the child ran AND produced non-empty sentinels |
| 3 | compare / verdict | compare found no manifests, marked **every section SKIPPED**, produced an **empty** `compare-detail.csv`; the verdict read "no data" as "no change" | a diff that skipped sections must be INVALID, never "clean" |

Evidence of point 3, from `e1-BASE-QUIESCENT-compare\_log.txt`:

```
SECTION: SHARED STATE   (shared-state-manifest.csv)
  [!] manifest missing (before=False, after=False) -> section skipped
  SKIPPED (manifest not found in one of the captures)
... (identical for DSH_HOME FINGERPRINTS, SESSION INVENTORY, PROJCACHE INVENTORY)
BEFORE  (no session-inventory.csv)
AFTER   (no session-inventory.csv)
```

`compare-detail.csv` is **3 bytes** — a UTF-8 BOM and nothing else.

The R1 verdict file records the same hole directly: the section
`--- E. diff capture #1 vs capture #2 ---` is followed by `per-section counts:` and
**no counts at all**, immediately followed by `QUIESCENT BASELINE: PASS`.

## 4. Class of defect

This is a **fail-open** defect: an error condition (nothing was captured, the diff has no
data) was converted into a success verdict. It is the most dangerous possible failure for
a baseline artifact, because a downstream immutability guard pointed at a non-existent
baseline can only produce meaningless comparisons — and, if that emptiness is read as
"no change", a meaningless *pass*.

It is **not** an evidence-integrity failure: nothing in `$DSH_HOME` was read incorrectly or
modified. No session, setting, profile or file was touched. The R1 run was read-only.

## 5. Contamination is a separate, compounding fact

The *other* baseline directory, `e1-BASE`, is **CONTAMINATED** independently of this bug:
it was captured while `browser-lab` was running, so its session inventory is a moving
target (see `e1-BASE\CONTAMINATION-NOTE.md`). `e1-BASE` must likewise never be used as an
immutability baseline. Together, R1 and `e1-BASE` mean that **no valid quiescent baseline
exists as of this note**.

## 6. Two further defects found during the R2 rewrite

Both were found by the fail-path self test and by running the R2 wrapper, not by reasoning:

1. **`$home` clobbered a read-only automatic variable.** In the first draft of the shared
   guard, `$home = Join-Path $OutDir 'dsh-home-fingerprints.csv'` was silently rejected by
   Windows PowerShell (`$HOME` is read-only and variable names are case-insensitive), so
   the sanity check read `C:\Users\user02` instead of the capture output. Same variable-name
   family as the earlier `$H`/`$h` and `$P`/`$p` defects. Renamed to `$homeFp`.
2. **The gate-failure path lost its own record.** The R1-era code wrote the
   "attempt failed" note into `$Root`, but `$Root` might not exist, producing the same
   `DirectoryNotFoundException` and silently discarding the record. The R2 wrapper now
   creates `$Root` before anything else and then verifies the note was written.
   (Note: `e1-BASE-QUIESCENT-ATTEMPT-FAILED.txt` from 13:13:23 did survive, because on
   that occasion `$Root` already existed.)
3. **No exit code.** The R1 wrapper exited `0` on every path, including FAIL, so any
   automation reading the exit code would have read a failure as success. Fail paths now
   exit non-zero (`2` for a refused gate, `1` otherwise), success exits `0`.
4. **Host detection matched itself.** The host probe tested
   `CommandLine -match 'dsh-desktop-host'` across *all* processes. A research command whose
   own command line merely *contains* that literal (for example a session inspecting the
   gate) was therefore reported as a running Desktop: during this round a single check
   reported `desktop = 2` while the true count was `0`. That is a false-STOP generator, and
   the second-order harm is worse — an operator who learns the gate cries wolf stops
   trusting it. `Get-HostProcesses -Kind 'desktop'` now excludes this process and its
   ancestors. The `cli` probe deliberately does **not** exclude ancestors, because the DSH
   CLI host serving the running research session *is* an ancestor; excluding it would hide
   a genuinely running host and turn the gate into a false PASS. Verified: while
   `browser-lab` (pid 12816) is an ancestor, the `cli` probe still reports it
   (self test TEST 9).

## 7. Artifacts preserved (NOT deleted)

These R1 artifacts remain on disk as the record of the failure and of the fix:

| Path | Size | SHA-256 |
|------|------|---------|
| `e1-BASE-QUIESCENT-VERDICT.txt` | 2141 B | `465D4CE7C1700FE51992BB0AF256BEBF7605EFC8C89B210E949A937F4EA75523` |
| `e1-BASE-QUIESCENT-ATTEMPT-FAILED.txt` | 962 B | `01035654AC80705EA4AEF2CD1EB100EDCEBD62EA39A82128EA85D9F1E91305C4` |
| `e1-BASE-QUIESCENT-compare\_log.txt` | 3724 B | `110B924AAEC7100F6B09891BF4D03EDD1563574454D6FF44C9FDDDAFA1496B99` |
| `e1-BASE-QUIESCENT-compare\compare-report.txt` | 1529 B | `12E8BD6C171360E38A28DE544E0A2C8D31045CE2CFF0236077C9039E0A7DF026` |
| `e1-BASE-QUIESCENT-compare\compare-detail.csv` | 3 B | `F1945CD6C19E56B3C1C78943EF5EC18116907A4CA1EFC40A57D48AB1DB7ADFC5` |

The two absent directories (`e1-BASE-QUIESCENT`, `e1-BASE-QUIESCENT-2`) are recorded as
absent; nothing was fabricated to fill them in.

## 8. Rules that follow from this note

1. `e1-BASE-QUIESCENT*` (R1) **must never** be used as an E1 guard baseline. It is a
   failed attempt, not a baseline.
2. The R1 artifacts **must not be deleted** — they are the evidence that the fail-open
   defect was real.
3. The official baseline lives in the **R2 namespace** only:
   `e1-BASE-QUIESCENT-R2` (baseline), `e1-BASE-QUIESCENT-R2-VERIFY` (second capture),
   `e1-BASE-QUIESCENT-R2-compare`, `e1-BASE-QUIESCENT-R2-VERDICT.txt`.
   As of this note none of these exist: **a real quiescent baseline has NOT yet been
   captured.**
4. A baseline may only be promoted to "usable" when the R2 verdict says PASS **and** all
   of `gate1`, `capture1Valid`, `gate2`, `capture2Valid`, `diffValid`, `fmtOk` are true
   **and** there are zero ADDED / DELETED / CONTENT-CHANGED / MTIME-ONLY entries.
5. No mtime-only drift is ever acceptable for a *quiescent* claim. Content-identical
   mtime drift downgrades the artifact to a CONTENT guard, which is what the E1 guard
   compares (Size + SHA-256), and must be recorded as such.

## 9. Fix status

`capture-guard.ps1` (new, shared) + guarded `capture-e1-quiescent-baseline.ps1` (R2),
`e1-capture.ps1` and `e5-capture.ps1`. Fail-path self test
`capture-guard.selftest.ps1` asserts the unsafe conditions are now rejected; see
`_selftest-r2\selftest-report-latest.txt`. The R1 bug is reproduced inside that self test
(TEST 7) and shown to be caught by the guard. Latest self-test result: **26 passed,
0 failed**, exit code 0.

## 10. Post-fix toolset fingerprints

`scripts\desktop-runtime-experiment\` after the fail-closed rewrite:

| File | Bytes | SHA-256 |
|------|-------|---------|
| `capture-guard.ps1` | 14050 | `DE1C195A65AB49A11EBFC741BB18A6D5969F3B033517241F1CECF33AC1A40C5C` |
| `capture-guard.selftest.ps1` | 14093 | `2D7E59F2859C9B48C51AEA676B8E925BE5FC1143FBB8A2F14A23BAC23F960249` |
| `capture-e1-quiescent-baseline.ps1` | 14092 | `A9659A04631718A26B539108306EF71A6EBB85B54883212D7B1BEB18032EF3A8` |
| `e1-capture.ps1` | 25384 | `5EC17870768EFE73073411C1E593E45A5559A4788419A2A4F63D431A65CD6699` |
| `e5-capture.ps1` | 13493 | `719D7C1A7D4B6E69996EF00B49D06989FC40AD95914DD5C4FD9334B91C1B3610` |
| `capture-shared-state.ps1` | 13023 | `2397CB9A7B1EA9FAF544D301D1AEDE3FB5595F9BC215CB9D79638ACBDE78B9CD` |
| `capture-desktop-runtime.ps1` | 9972 | `FE459E8ADEF2153CDEB61459B80C03526BD26D6BE8A443A7ED68CA53D6D4E05A` |
| `detect-runtime-test-session.ps1` | 6734 | `3B7E19340AB42DD457D3262AECFBD3DD3DB4A3C7C3C13B0761AD90ADE0357862` |
| `compare-captures.ps1` | 7737 | `0354CC5868159643D1B5D9585AE83F858F2D63253C451082815F270F01E91E19` |

Nothing in this round wrote to `$DSH_HOME`. Verified after all tests: `settings.yaml`
52 B `EA141B86…C884BAF`, `settings.yaml.imported` 176 B `0D6DBB77…7BB5746`, home
`cordis.patch.yml` absent, PJOS v4 session 409 B `9E85AA90…E233897` — all unchanged.

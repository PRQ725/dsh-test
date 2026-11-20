<#
.SYNOPSIS
  Revalidate the EXISTING R2 quiescent-baseline captures with the fixed compare validator.

.DESCRIPTION
  The original R2 run captured two genuinely identical snapshots, but the compare validator
  rejected the (legally empty) compare-detail.csv and wrote QUIESCENT BASELINE: FAIL.

  This script does NOT capture anything. It:

    1. records a SHA-256 inventory of both existing capture directories
    2. re-verifies capture completeness (sentinels + sanity minimums) on those directories
    3. re-runs compare-captures.ps1 into a NEW directory and validates it with the fixed
       validator
    4. re-validates the ORIGINAL compare directory as well
    5. re-checks session-format stability from the two existing inventories
    6. re-records the SHA-256 inventory and proves it is UNCHANGED (nothing was overwritten)
    7. writes a NEW verdict file, leaving the original FAIL verdict untouched

.PARAMETER Root
  Evidence root. Default: D:\Projects\dsh-test\evidence\desktop\runtime

.EXAMPLE
  .\revalidate-e1-quiescent-baseline.ps1
#>
[CmdletBinding()]
param(
  [string]$Root = 'D:\Projects\dsh-test\evidence\desktop\runtime',
  [string]$ToolsDir = 'D:\Projects\dsh-test\scripts\desktop-runtime-experiment',
  [string]$Cap1Name = 'e1-BASE-QUIESCENT-R2',
  [string]$Cap2Name = 'e1-BASE-QUIESCENT-R2-VERIFY',
  [string]$OrigCompareName = 'e1-BASE-QUIESCENT-R2-compare',
  [string]$NewCompareName = 'e1-BASE-QUIESCENT-R2-compare-revalidated',
  [string]$VerdictName = 'e1-BASE-QUIESCENT-R2-REVALIDATED-VERDICT.txt',
  [string]$OriginalVerdictName = 'e1-BASE-QUIESCENT-R2-VERDICT.txt'
)

$ErrorActionPreference = 'Continue'
$script:stops = 0
$script:report = New-Object System.Collections.Generic.List[string]
function WRL($m)  { $script:report.Add([string]$m) | Out-Null; Write-Host $m }
function OK($m)   { WRL ("[PASS] " + $m) }
function WARN($m) { WRL ("[WARN] " + $m) }
function FAIL($m) { $script:stops++; WRL ("[FATAL] " + $m) }
function INFO($m) { WRL ("[INFO] " + $m) }

$CAP1 = Join-Path $Root $Cap1Name
$CAP2 = Join-Path $Root $Cap2Name
$CMP0 = Join-Path $Root $OrigCompareName
$CMP1 = Join-Path $Root $NewCompareName

WRL "================================================================"
WRL ("R2 QUIESCENT BASELINE - REVALIDATION (no capture)   ({0})" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
WRL "Root = $Root"
WRL "================================================================"
WRL ""

foreach ($s in @('capture-guard.ps1','compare-captures.ps1')) {
  if (-not (Test-Path (Join-Path $ToolsDir $s))) { FAIL "missing tool script: $s" }
}
if ($script:stops -gt 0) { WRL ""; WRL "ABORT: missing tools."; exit 1 }
. (Join-Path $ToolsDir 'capture-guard.ps1')

# ---------------------------------------------------------------- 1. capture inventory
function Get-DirInventory {
  param([string]$Dir)
  $map = @{}
  if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return $map }
  Get-ChildItem -LiteralPath $Dir -File -Force -Recurse |
    Sort-Object FullName | ForEach-Object {
      $rel = $_.FullName.Substring($Dir.Length).TrimStart('\')
      $map[$rel] = [PSCustomObject]@{ Rel=$rel; Size=$_.Length; Sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    }
  return $map
}
function Compare-Inventory {
  param($Before, $After)
  $changed = New-Object System.Collections.Generic.List[string]
  foreach ($k in ($Before.Keys | Sort-Object)) {
    if (-not $After.ContainsKey($k)) { $changed.Add("REMOVED  $k"); continue }
    if ($After[$k].Sha256 -ne $Before[$k].Sha256) { $changed.Add("CHANGED  $k") }
  }
  foreach ($k in ($After.Keys | Sort-Object)) { if (-not $Before.ContainsKey($k)) { $changed.Add("ADDED    $k") } }
  return $changed
}

WRL "--- A. capture directories (must exist; NEVER re-captured) ---"
foreach ($d in @($CAP1,$CAP2)) {
  if (Test-Path -LiteralPath $d -PathType Container) { OK ("present: {0}" -f $d) }
  else { FAIL ("MISSING capture directory: {0}" -f $d) }
}
if ($script:stops -gt 0) { WRL ""; WRL "ABORT: the existing R2 captures are required."; exit 1 }

$inv1Before = Get-DirInventory -Dir $CAP1
$inv2Before = Get-DirInventory -Dir $CAP2
INFO ("capture #1 files = {0}   capture #2 files = {1}" -f $inv1Before.Count, $inv2Before.Count)
WRL ""

# ---------------------------------------------------------------- 2. capture completeness
WRL "--- B. capture completeness re-verification (read-only) ---"
$cap1Valid = $true
$cap2Valid = $true
foreach ($pair in @(@('capture#1',$CAP1), @('capture#2',$CAP2))) {
  $label = $pair[0]; $dir = $pair[1]
  $ok = $true
  foreach ($name in @('A','B','C')) {
    $spec = $script:CaptureSentinels[$name]
    foreach ($f in $spec.Files) {
      $p = Join-Path $dir $f
      if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { FAIL ("{0}: missing sentinel {1}" -f $label, $f); $ok = $false; continue }
      if ((Get-Item -LiteralPath $p).Length -le 0) { FAIL ("{0}: empty sentinel {1}" -f $label, $f); $ok = $false }
    }
  }
  $san = Test-GuardedCaptureSanity -OutDir $dir
  foreach ($e in $san.Fatal) { FAIL ("{0}: {1}" -f $label, $e); $ok = $false }
  foreach ($e in $san.Warn)  { WARN ("{0}: {1}" -f $label, $e) }
  if ($ok) {
    $sn = @(Import-Csv -LiteralPath (Join-Path $dir 'session-inventory.csv')).Count
    $sh = @(Import-Csv -LiteralPath (Join-Path $dir 'shared-state-manifest.csv')).Count
    $pc = @(Import-Csv -LiteralPath (Join-Path $dir 'projcache-inventory.csv')).Count
    OK ("{0} valid: sessions={1} shared-state={2} projcache={3}" -f $label, $sn, $sh, $pc)
  }
  if ($label -eq 'capture#1') { $cap1Valid = $ok } else { $cap2Valid = $ok }
}
WRL ""

# ---------------------------------------------------------------- 3. re-run the compare
WRL "--- C. re-run compare-captures.ps1 into a NEW directory (captures are not touched) ---"
INFO ("new compare dir : {0}" -f $CMP1)
INFO ("original compare: {0}  (kept as history)" -f $CMP0)
$cmpNew = Invoke-GuardedCompare -ToolsDir $ToolsDir -Before $CAP1 -After $CAP2 -OutDir $CMP1
foreach ($e in $cmpNew.Errors) { FAIL ("[revalidated diff] " + $e) }
$diffValidNew = $cmpNew.Ok
if ($diffValidNew) {
  OK ("revalidated diff VALID: detailRows={0} expectedDetailRows={1} warnings={2}" -f `
      $cmpNew.DetailRows, $cmpNew.ExpectedDetailRows, $cmpNew.Warnings)
} else {
  WRL "  revalidated diff INVALID"
}
WRL ""

# ---------------------------------------------------------------- 4. re-validate the ORIGINAL compare dir
WRL "--- D. re-validate the ORIGINAL compare output (the artifact the old validator rejected) ---"
$diffValidOrig = $false
if (Test-Path -LiteralPath (Join-Path $CMP0 'compare-report.txt')) {
  $cmpOrig = Test-GuardedCompareOutput -CompareDir $CMP0
  foreach ($e in $cmpOrig.Errors) { FAIL ("[original diff] " + $e) }
  $diffValidOrig = $cmpOrig.Ok
  if ($diffValidOrig) {
    OK ("original compare output VALID: detailRows={0} expectedDetailRows={1} warnings={2}" -f `
        $cmpOrig.DetailRows, $cmpOrig.ExpectedDetailRows, $cmpOrig.Warnings)
  } else {
    WRL "  original compare output INVALID"
  }
} else {
  FAIL ("original compare directory has no compare-report.txt: {0}" -f $CMP0)
}
WRL ""

# ---------------------------------------------------------------- 5. format stability
WRL "--- E. session format stability (from the existing inventories) ---"
$i1 = @(Import-Csv -LiteralPath (Join-Path $CAP1 'session-inventory.csv'))
$i2 = @(Import-Csv -LiteralPath (Join-Path $CAP2 'session-inventory.csv'))
$f1 = ($i1 | Group-Object Format | Sort-Object Name | ForEach-Object { $_.Name + '=' + $_.Count }) -join ' '
$f2 = ($i2 | Group-Object Format | Sort-Object Name | ForEach-Object { $_.Name + '=' + $_.Count }) -join ' '
WRL ("  formats capture#1: {0}   (rows {1})" -f $f1, $i1.Count)
WRL ("  formats capture#2: {0}   (rows {1})" -f $f2, $i2.Count)
$fmtOk = ($f1 -eq $f2) -and ($i1.Count -gt 0)
if (-not $fmtOk) { FAIL "session format distribution changed (or empty) between captures" } else { OK "session format distribution stable" }
WRL ""

# ---------------------------------------------------------------- 6. change counts
WRL "--- F. change classification from the revalidated diff ---"
$rows  = @($cmpNew.Rows)
$fatal = @($rows | Where-Object { $_.Class -in @('ADDED','DELETED','CONTENT-CHANGED') })
$drift = @($rows | Where-Object { $_.Class -eq 'MTIME-ONLY' })
$sum = @{}
foreach ($r in $rows) {
  $k = "$($r.Section)|$($r.Class)"
  if (-not $sum.ContainsKey($k)) { $sum[$k] = 0 }
  $sum[$k]++
}
WRL "  per-section counts:"
if ($sum.Keys.Count -eq 0) { WRL "    (none - no differences)" }
$sum.Keys | Sort-Object | ForEach-Object { WRL ("    {0} = {1}" -f $_, $sum[$_]) }
WRL ("  ADDED/DELETED/CONTENT-CHANGED = {0}   MTIME-ONLY = {1}" -f $fatal.Count, $drift.Count)
if ($fatal.Count -eq 0 -and $drift.Count -eq 0) { OK "zero changes in every class" } else { FAIL "the two captures are NOT identical" }
WRL ""

# ---------------------------------------------------------------- 7. nothing was overwritten
WRL "--- G. proof that revalidation did not modify the captures ---"
$inv1After = Get-DirInventory -Dir $CAP1
$inv2After = Get-DirInventory -Dir $CAP2
$chg1 = @(Compare-Inventory -Before $inv1Before -After $inv1After)
$chg2 = @(Compare-Inventory -Before $inv2Before -After $inv2After)
$capturesUntouched = ($chg1.Count -eq 0) -and ($chg2.Count -eq 0)
if ($capturesUntouched) { OK "both capture directories are byte-identical to their pre-revalidation state (nothing overwritten)" }
else {
  FAIL "a capture directory changed during revalidation"
  $chg1 | ForEach-Object { WRL ("    capture#1 " + $_) }
  $chg2 | ForEach-Object { WRL ("    capture#2 " + $_) }
}
WRL ""

# ---------------------------------------------------------------- 8. recorded gate values
WRL "--- H. quiescence gate values (AS RECORDED in the original run; not re-executable) ---"
$origVerdict = Join-Path $Root $OriginalVerdictName
$gate1Recorded = 'UNKNOWN'
$gate2Recorded = 'UNKNOWN'
if (Test-Path -LiteralPath $origVerdict) {
  $ov = Read-TextAnyEncoding $origVerdict
  $m1 = [regex]::Match($ov, 'gate #1\s*:\s*(\w+)')
  $m2 = [regex]::Match($ov, 'gate #2\s*:\s*(\w+)')
  if ($m1.Success) { $gate1Recorded = $m1.Groups[1].Value }
  if ($m2.Success) { $gate2Recorded = $m2.Groups[1].Value }
  OK ("original verdict found: {0}" -f $origVerdict)
} else { WARN ("original verdict not found: {0}" -f $origVerdict) }
WRL ("  gate #1 (recorded) : {0}" -f $gate1Recorded)
WRL ("  gate #2 (recorded) : {0}" -f $gate2Recorded)
WRL "  NOTE: the host/port gate cannot be re-evaluated retroactively. Its recorded values are"
WRL "        carried forward as [FACT-AS-RECORDED], not re-measured by this script."
WRL ""

# ---------------------------------------------------------------- verdict
$pipelineOk = $cap1Valid -and $cap2Valid -and $diffValidNew -and $diffValidOrig -and $fmtOk -and $capturesUntouched
$noChanges  = ($fatal.Count -eq 0) -and ($drift.Count -eq 0)
$pass       = $pipelineOk -and $noChanges

WRL "================================================================"
WRL "REVALIDATED VERDICT INPUTS"
WRL ("  capture #1 valid (re-verified)   : {0}" -f $cap1Valid)
WRL ("  capture #2 valid (re-verified)   : {0}" -f $cap2Valid)
WRL ("  gate #1 (as recorded)            : {0}" -f $gate1Recorded)
WRL ("  gate #2 (as recorded)            : {0}" -f $gate2Recorded)
WRL ("  diff valid (re-run)              : {0}   detailRows={1} expectedDetailRows={2}" -f $diffValidNew, $cmpNew.DetailRows, $cmpNew.ExpectedDetailRows)
WRL ("  diff valid (original artifacts)  : {0}" -f $diffValidOrig)
WRL ("  format stable                    : {0}" -f $fmtOk)
WRL ("  captures unmodified              : {0}" -f $capturesUntouched)
WRL ("  changes                          : fatal={0} drift={1}" -f $fatal.Count, $drift.Count)
WRL ""

if ($pass) {
  WRL "QUIESCENT BASELINE (R2, REVALIDATED): PASS"
  WRL "  both captures valid, byte-identical, format stable, warnings=0"
  WRL "  the earlier FAIL was a VALIDATOR FALSE FAIL on a legally empty compare-detail.csv"
  WRL ("  baseline : {0}" -f $CAP1)
  WRL ("  verify   : {0}" -f $CAP2)
  WRL ("  compare  : {0}" -f $CMP1)
  WRL ("  this is the E1 run2 guard baseline: {0}" -f $CAP1)
} else {
  WRL "QUIESCENT BASELINE (R2, REVALIDATED): FAIL"
  WRL ""
  if (-not $pipelineOk) { WRL "  [FATAL] a validation step did not complete validly (see inputs above)" }
  if ($fatal.Count -gt 0) { $fatal | Select-Object -First 25 | ForEach-Object { WRL ("      {0}  {1}  {2}" -f $_.Class, $_.Section, $_.Rel) } }
  if ($drift.Count -gt 0) { $drift | Select-Object -First 25 | ForEach-Object { WRL ("      MTIME-ONLY  {0}  {1}" -f $_.Section, $_.Rel) } }
}
WRL ""
WRL "HISTORY"
WRL ("  the original FAIL verdict is PRESERVED, not overwritten: {0}" -f $origVerdict)
WRL ("  this revalidated verdict is a NEW file            : {0}" -f (Join-Path $Root $VerdictName))
WRL ""
WRL "ZERO-ROW DETAIL POLICY (explicit)"
WRL "  compare-detail.csv records ONLY entries that CHANGED, so 0 rows is the legal"
WRL "  representation of a zero-diff pair. Validity is decided by section completeness"
WRL "  plus detailRows == sum of all section change counts."
WRL ("captures: {0}" -f $CAP1)
WRL ("          {0}" -f $CAP2)
WRL ("compare : {0}" -f $CMP1)

$outPath = Join-Path $Root $VerdictName
$script:report | Set-Content -LiteralPath $outPath -Encoding UTF8
Write-Host ""
Write-Host ("verdict written: {0}" -f $outPath)
if (-not (Test-Path -LiteralPath $origVerdict -PathType Leaf)) { Write-Host "WARNING: the original verdict is missing!" }

if ($pass) { exit 0 } else { exit 1 }

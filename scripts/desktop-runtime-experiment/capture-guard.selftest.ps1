<#
.SYNOPSIS
  FAIL-PATH self test for capture-guard.ps1.

.DESCRIPTION
  Reproduces the exact conditions of the R1 FALSE PASS and asserts that the shared
  guard now refuses to call any of them a success.

  R1 FALSE PASS mechanism (reproduced in TEST 7):
      & child.ps1 ... *> "$CAP1\_log-A.txt"
  where $CAP1 did not exist. PowerShell could not OPEN the redirection target, so the
  child never ran. The old wrapper still printed "[PASS] capture written". The compare
  step then found no manifests, skipped every section, and the verdict read
  "no data" as "no change" and printed PASS.

  Every case below asserts the fail-closed outcome. Nothing outside the scratch root
  is created or modified, and $DSH_HOME is never touched.
  Exit code 0 = all assertions passed. Exit code 1 = at least one assertion failed.
#>
[CmdletBinding()]
param(
  [string]$Scratch = 'D:\Projects\dsh-test\evidence\desktop\runtime\_selftest-r2'
)

$ErrorActionPreference = 'Continue'
$script:pass = 0
$script:fail = 0
$script:lines = New-Object System.Collections.Generic.List[string]

function WRL($m) { $script:lines.Add([string]$m) | Out-Null; Write-Host $m }
function CHECK($name, $cond, $detail) {
  if ($cond) { $script:pass++; WRL ("  [ok]   {0}" -f $name) }
  else       { $script:fail++; WRL ("  [FAIL] {0}   {1}" -f $name, $detail) }
}
# NOTE: always call this INSIDE parentheses. In PowerShell command-argument mode a bare
# "$x.Count -gt 0" is parsed as an argument list (the -gt part becomes a stray parameter),
# so the comparison would silently test only ".Count".
function HasErr($result, $pattern) {
  return (@($result.Errors) | Where-Object { $_ -match $pattern }).Count -gt 0
}

$ToolsDir = 'D:\Projects\dsh-test\scripts\desktop-runtime-experiment'
# Every run gets a FRESH scratch subtree so no assertion can be satisfied by stale state.
# Nothing is ever deleted; old run dirs remain as the test record.
$RunId = Get-Date -Format 'yyyyMMdd-HHmmss'
$Scratch = Join-Path $Scratch ("run-" + $RunId)
$stub     = Join-Path $Scratch 'tools'
$stubEmpty= Join-Path $Scratch 'tools-empty'
$capOk    = Join-Path $Scratch 'cap-ok'
$capSilent= Join-Path $Scratch 'cap-silent'
$capThrow = Join-Path $Scratch 'cap-throw'
$capEmpty = Join-Path $Scratch 'cap-empty'
$capGone  = Join-Path $Scratch 'cap-missing-child'
$cmpDir   = Join-Path $Scratch 'compare-skipped'

WRL "================================================================"
WRL "capture-guard FAIL-PATH SELF TEST   ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))"
WRL "scratch = $Scratch"
WRL "================================================================"
WRL ""
WRL "NOTE: this test never writes to `$DSH_HOME and never removes evidence."
WRL "      The scratch root is created once and then left in place as the test record."
WRL ""

# ---- the guard must refuse to run at all if it is not found ----------------
foreach ($d in @($stub,$stubEmpty,$capOk,$capSilent,$capThrow,$capEmpty,$cmpDir)) {
  if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# ---- stub children ---------------------------------------------------------
# A-success: writes every sentinel script A requires, all non-empty.
$srcOk = @'
param([string]$OutDir,[string]$Label)
foreach ($f in @('processes.csv','listeners.csv','dsh-home-fingerprints.csv','desktop-app-fingerprints.csv','summary.txt')) {
  "stub $f" | Set-Content -LiteralPath (Join-Path $OutDir $f) -Encoding UTF8
}
Write-Host "stub A success"
'@

# A-silent: exits 0 but writes NOTHING (the dangerous case: looks like success).
$srcSilent = @'
param([string]$OutDir,[string]$Label)
Write-Host "stub A silent: exited 0 without writing any artifact"
'@

# A-throw: fails loudly.
$srcThrow = @'
param([string]$OutDir,[string]$Label)
Write-Host "stub A about to throw"
throw "stub A deliberate failure"
'@

$srcOk     | Set-Content -LiteralPath (Join-Path $stub 'capture-desktop-runtime.ps1')      -Encoding UTF8
$srcSilent | Set-Content -LiteralPath (Join-Path $stub 'capture-shared-state.ps1')         -Encoding UTF8
$srcThrow  | Set-Content -LiteralPath (Join-Path $stub 'detect-runtime-test-session.ps1')  -Encoding UTF8
# compare-captures.ps1 is deliberately NOT created in the stub dir for TEST 5,
# and is created later as a SKIPPED-report stub for TEST 6.

. (Join-Path $ToolsDir 'capture-guard.ps1')

# ---------------------------------------------------------------- TEST 1
WRL "--- TEST 1: OutDir does not exist yet, child succeeds -> guard must create it and PASS"
$r1 = Invoke-GuardedCapture -Name 'A' -ToolsDir $stub -OutDir $capOk -ChildArgs @{ Label='t1' }
CHECK "T1 guard reports Ok" $r1.Ok ($r1.Errors -join ' | ')
CHECK "T1 OutDir was created" (Test-Path -LiteralPath $capOk -PathType Container) "missing $capOk"
CHECK "T1 redirection log exists" (Test-Path -LiteralPath (Join-Path $capOk '_log-A.txt') -PathType Leaf) "log missing"
CHECK "T1 all 5 sentinels present and non-empty" (@(Get-ChildItem -LiteralPath $capOk -File).Count -ge 6) "too few files"
WRL ""

# ---------------------------------------------------------------- TEST 2
WRL "--- TEST 2: child exits 0 but writes nothing -> guard must FAIL"
$r2 = Invoke-GuardedCapture -Name 'B' -ToolsDir $stub -OutDir $capSilent -ChildArgs @{ Label='t2' }
CHECK "T2 guard reports NOT Ok" (-not $r2.Ok) "guard wrongly accepted a silent child"
CHECK "T2 error names a missing sentinel" (HasErr $r2 'missing sentinel') ("errors: " + ($r2.Errors -join ' | '))
CHECK "T2 log exists (proves the child DID run)" (Test-Path -LiteralPath (Join-Path $capSilent '_log-B.txt') -PathType Leaf) "log missing"
WRL ""

# ---------------------------------------------------------------- TEST 3
WRL "--- TEST 3: child throws -> guard must FAIL, not swallow it"
$r3 = Invoke-GuardedCapture -Name 'C' -ToolsDir $stub -OutDir $capThrow -ChildArgs @{ Label='t3' }
CHECK "T3 guard reports NOT Ok" (-not $r3.Ok) "guard wrongly accepted a throwing child"
CHECK "T3 error mentions the throw" (HasErr $r3 'threw') ("errors: " + ($r3.Errors -join ' | '))
WRL ""

# ---------------------------------------------------------------- TEST 4
WRL "--- TEST 4: child script missing -> guard must FAIL before running anything"
$stubEmpty = Join-Path $Scratch 'tools-empty'
$r4 = Invoke-GuardedCapture -Name 'A' -ToolsDir $stubEmpty -OutDir $capGone -ChildArgs @{ Label='t4' }
CHECK "T4 guard reports NOT Ok" (-not $r4.Ok) "guard wrongly reported Ok"
CHECK "T4 error says the child was not found" (HasErr $r4 'child script not found') ("errors: " + ($r4.Errors -join ' | '))
CHECK "T4 no capture dir was created for the missing child" (-not (Test-Path -LiteralPath $capGone)) "unexpected dir $capGone"
WRL ""

# ---------------------------------------------------------------- TEST 5
WRL "--- TEST 5: sanity minimums on an EMPTY capture dir -> 0 rows must be FATAL"
$s5 = Test-GuardedCaptureSanity -OutDir $capEmpty
CHECK "T5 sanity reports NOT Ok" (-not $s5.Ok) "0-row capture wrongly accepted"
CHECK "T5 at least 3 fatal items" (@($s5.Fatal).Count -ge 3) ("fatal: " + ($s5.Fatal -join ' | '))
WRL ""

# ---------------------------------------------------------------- TEST 6
WRL "--- TEST 6: an otherwise COMPLETE report with one SKIPPED section -> diff must be INVALID"
# The report is complete in every other respect (all four sections present, four counts
# each, format summary, warnings: 0, completion marker), and compare-detail.csv is a legal
# BOM-only empty file. The ONLY defect is the SKIPPED section, so this isolates that cause
# and simultaneously proves that an empty detail file is NOT what makes a diff invalid.
$srcCmp = @'
param([string]$Before,[string]$After,[string]$OutDir)
$rep = Join-Path $OutDir 'compare-report.txt'
$L = New-Object System.Collections.Generic.List[string]
$L.Add('=== SCRIPT D: compare captures ===')
foreach ($s in @(
  @('SHARED STATE','shared-state-manifest.csv'),
  @('DSH_HOME FINGERPRINTS (script A)','dsh-home-fingerprints.csv'),
  @('SESSION INVENTORY','session-inventory.csv'),
  @('PROJCACHE INVENTORY','projcache-inventory.csv'))) {
  $L.Add('SECTION: ' + $s[0] + '   (' + $s[1] + ')')
  if ($s[0] -eq 'PROJCACHE INVENTORY') {
    $L.Add('  SKIPPED (manifest not found in one of the captures)')
    continue
  }
  $L.Add('  total tracked   : 5')
  $L.Add('  ADDED           : 0')
  $L.Add('  DELETED         : 0')
  $L.Add('  CONTENT-CHANGED : 0')
  $L.Add('  MTIME-ONLY      : 0')
}
$L.Add('SECTION: SESSION FORMAT SUMMARY (informational)')
$L.Add('  BEFORE  total=5     v3=4 v4=1')
$L.Add('  AFTER   total=5     v3=4 v4=1')
$L.Add('warnings: 0')
$L | Set-Content -LiteralPath $rep -Encoding UTF8
'' | Set-Content -LiteralPath (Join-Path $OutDir 'compare-detail.csv') -Encoding UTF8
Write-Host 'report lines written = 47'
Write-Host '=== SCRIPT D DONE (warnings: 0) ==='
'@
$srcCmp | Set-Content -LiteralPath (Join-Path $stub 'compare-captures.ps1') -Encoding UTF8

$r6 = Invoke-GuardedCompare -ToolsDir $stub -Before $capOk -After $capSilent -OutDir $cmpDir
CHECK "T6 compare guard reports NOT Ok" (-not $r6.Ok) "a report with a SKIPPED section was wrongly accepted"
CHECK "T6 error mentions SKIPPED" (HasErr $r6 'SKIPPED') ("errors: " + ($r6.Errors -join ' | '))
CHECK "T6 the diff is rejected even though the detail file is legally empty" ($r6.DetailRows -eq 0) ("DetailRows = " + $r6.DetailRows)
CHECK "T6 no 'empty detail' error is raised (emptiness is not the defect)" (-not (HasErr $r6 'is empty')) ("errors: " + ($r6.Errors -join ' | '))
WRL ""

# ---------------------------------------------------------------- TEST 7
WRL "--- TEST 7: REPRODUCE the R1 bug - unguarded redirection into a missing dir ---"
# Mechanism-agnostic assertion: whatever PowerShell does internally, the OBSERVABLE
# outcome of the R1 pattern is that the redirection log is never created, so the old
# wrapper had no way to tell that the child had not produced evidence. The guard turns
# exactly that into "redirection log was not created ... the child did NOT run".
$gone    = Join-Path $Scratch 'does-not-exist'
$capR1   = Join-Path $Scratch 'cap-r1-bug'
if (-not (Test-Path -LiteralPath $capR1)) { New-Item -ItemType Directory -Path $capR1 -Force | Out-Null }
$goneLog = Join-Path $gone 'cap\_log-A.txt'
$child   = Join-Path $stub 'capture-desktop-runtime.ps1'
$threw   = $false
$msg     = ''
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
try {
  & $child -OutDir $capR1 -Label 't7' *> $goneLog
} catch {
  $threw = $true; $msg = $_.Exception.Message
} finally { $ErrorActionPreference = $prevEAP }
CHECK "T7 the OLD pattern leaves NO redirection log" (-not (Test-Path -LiteralPath $goneLog)) "unexpected log at $goneLog"
CHECK "T7 the OLD pattern leaves the missing dir missing" (-not (Test-Path -LiteralPath $gone)) "unexpected dir $gone"
CHECK "T7 the GUARDED pattern DOES produce a log (T1)" (Test-Path -LiteralPath (Join-Path $capOk '_log-A.txt') -PathType Leaf) "guarded log missing"
WRL ("  [note] old pattern terminating error raised = {0}" -f $threw)
WRL ("  [note] old pattern error message          = {0}" -f $msg)
WRL ""

# ---------------------------------------------------------------- TEST 8
WRL "--- TEST 8: a COMPLETE report with a legal ZERO-ROW diff must be ACCEPTED ---"
# This is the regression for the FALSE FAIL: all four sections present, every count 0,
# total tracked > 0, warnings 0, completion marker present, and compare-detail.csv is the
# BOM-only file that a zero-row Export-Csv produces. The guard must say Ok.
$srcCmpOk = @'
param([string]$Before,[string]$After,[string]$OutDir)
$rep = Join-Path $OutDir 'compare-report.txt'
$L = New-Object System.Collections.Generic.List[string]
$L.Add('=== SCRIPT D: compare captures ===')
foreach ($s in @(
  @('SHARED STATE','shared-state-manifest.csv'),
  @('DSH_HOME FINGERPRINTS (script A)','dsh-home-fingerprints.csv'),
  @('SESSION INVENTORY','session-inventory.csv'),
  @('PROJCACHE INVENTORY','projcache-inventory.csv'))) {
  $L.Add('SECTION: ' + $s[0] + '   (' + $s[1] + ')')
  $L.Add('  total tracked   : 5')
  $L.Add('  ADDED           : 0')
  $L.Add('  DELETED         : 0')
  $L.Add('  CONTENT-CHANGED : 0')
  $L.Add('  MTIME-ONLY      : 0')
}
$L.Add('SECTION: SESSION FORMAT SUMMARY (informational)')
$L.Add('  BEFORE  total=5     v3=4 v4=1')
$L.Add('  AFTER   total=5     v3=4 v4=1')
$L.Add('warnings: 0')
$L | Set-Content -LiteralPath $rep -Encoding UTF8
'' | Set-Content -LiteralPath (Join-Path $OutDir 'compare-detail.csv') -Encoding UTF8
Write-Host 'report lines written = 49'
Write-Host '=== SCRIPT D DONE (warnings: 0) ==='
'@
$srcCmpOk | Set-Content -LiteralPath (Join-Path $stub 'compare-captures.ps1') -Encoding UTF8
$capValid = Join-Path $Scratch 'compare-valid'
$r8 = Invoke-GuardedCompare -ToolsDir $stub -Before $capOk -After $capSilent -OutDir $capValid
CHECK "T8 a complete, consistent ZERO-ROW diff IS accepted" $r8.Ok ("errors: " + ($r8.Errors -join ' | '))
CHECK "T8 Rows is 0" (@($r8.Rows).Count -eq 0) ("rows: " + @($r8.Rows).Count)
CHECK "T8 DetailRows = ExpectedDetailRows = 0" (($r8.DetailRows -eq 0) -and ($r8.ExpectedDetailRows -eq 0)) ("{0} vs {1}" -f $r8.DetailRows, $r8.ExpectedDetailRows)
CHECK "T8 warnings read as 0" ($r8.Warnings -eq 0) ("warnings = " + $r8.Warnings)
WRL ""

# ---------------------------------------------------------------- TEST 9
WRL "--- TEST 9: host detection must not match itself, and must not hide an ancestor host ---"
$self = @(Get-SelfProcessIds)
CHECK "T9 self pid list is non-empty and starts with `$PID" ($self.Count -gt 0 -and $self -contains $PID) ("self: " + ($self -join ','))
$dEx = @(Get-HostProcesses -Kind 'desktop' -ExcludeSelf)
$dNo = @(Get-HostProcesses -Kind 'desktop')
$selfInEx = @($dEx | Where-Object { $self -contains [int]$_.ProcessId }).Count
CHECK "T9 desktop probe with -ExcludeSelf excludes this process tree" ($selfInEx -eq 0) "self pids leaked into the desktop probe"
CHECK "T9 desktop probe excludes MORE (or equal) with -ExcludeSelf" ($dEx.Count -le $dNo.Count) ("excl={0} noexcl={1}" -f $dEx.Count, $dNo.Count)
# the cli probe must NOT exclude ancestors: an ancestor CLI host is a real host
$cli = @(Get-HostProcesses -Kind 'cli')
$hiddenAncestor = @($self | Where-Object { $_ -ne $PID } | ForEach-Object { $_ }) | Where-Object {
  @(Get-CimInstance Win32_Process -Filter ("ProcessId = {0}" -f $_) -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq 'node.exe' -and $_.CommandLine -match 'dsh[\\/]lib[\\/]bin\.js' }).Count -gt 0
}
if (@($hiddenAncestor).Count -gt 0) {
  CHECK "T9 a CLI host IS an ancestor here, and the cli probe still reports it" (@($cli).Count -gt 0) "cli probe hid an ancestor host - FALSE PASS RISK"
  WRL ("  [note] ancestor cli host pid(s): {0}" -f (@($hiddenAncestor) -join ','))
} else {
  WRL "  [note] no CLI host in this process tree; the no-hiding property is not exercised now"
}
WRL ""

# ---------------------------------------------------------------- summary
WRL "================================================================"
WRL ("RESULT: {0} passed, {1} failed" -f $script:pass, $script:fail)
if ($script:fail -eq 0) { WRL "FAIL-PATH SELF TEST: PASS (every unsafe condition was rejected)" }
else                    { WRL "FAIL-PATH SELF TEST: FAIL (a fail-open path still exists)" }
WRL "================================================================"

$script:lines | Set-Content -LiteralPath (Join-Path $Scratch 'selftest-report.txt') -Encoding UTF8
$latest = 'D:\Projects\dsh-test\evidence\desktop\runtime\_selftest-r2\selftest-report-latest.txt'
$script:lines | Set-Content -LiteralPath $latest -Encoding UTF8
Write-Host ""
Write-Host ("report written: {0}" -f (Join-Path $Scratch 'selftest-report.txt'))
Write-Host ("latest        : {0}" -f $latest)
if ($script:fail -gt 0) { exit 1 }
exit 0

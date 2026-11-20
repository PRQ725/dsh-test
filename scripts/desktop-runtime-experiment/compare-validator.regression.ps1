<#
.SYNOPSIS
  Production-path regression test for the compare validator (zero-diff handling).

.DESCRIPTION
  These cases deliberately run through the SAME code path the wrappers use:

      Invoke-GuardedCompare
        -> create OutDir, run compare-captures.ps1 with *> log
        -> check the redirection log
        -> Test-GuardedCompareOutput (the production validator)

  They do NOT call the validator helper in isolation.

  Cases 1, 2 and 5 drive the REAL compare-captures.ps1 over real CSV fixtures.
  Cases 3, 4 and 6 need report/detail combinations the real producer cannot emit
  (they are precisely the corruptions the validator exists to catch), so a stub
  producer writes them into the same validation path.

  Exit code 0 = all cases behaved as required. 1 = at least one regression.

  Nothing here writes to $DSH_HOME, and nothing is removed.
#>
[CmdletBinding()]
param(
  [string]$Scratch = 'D:\Projects\dsh-test\evidence\desktop\runtime\_selftest-r2',
  [string]$RealCompareDir = 'D:\Projects\dsh-test\evidence\desktop\runtime\e1-BASE-QUIESCENT-R2-compare'
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
function HasErr($result, $pattern) {
  return (@($result.Errors) | Where-Object { $_ -match $pattern }).Count -gt 0
}

$ToolsDir = 'D:\Projects\dsh-test\scripts\desktop-runtime-experiment'
$RunId = Get-Date -Format 'yyyyMMdd-HHmmss'
$Root  = Join-Path $Scratch ("zerodiff-" + $RunId)
$stubTools = Join-Path $Root 'tools-stub'
$fixtures  = Join-Path $Root 'fixtures'

WRL "================================================================"
WRL "COMPARE VALIDATOR PRODUCTION-PATH REGRESSION TEST   ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))"
WRL "scratch = $Root"
WRL "================================================================"
WRL ""
WRL "Path under test: Invoke-GuardedCompare -> compare-captures.ps1 -> Test-GuardedCompareOutput"
WRL ""

foreach ($d in @($Root,$stubTools,$fixtures)) { if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }
. (Join-Path $ToolsDir 'capture-guard.ps1')

# ---------------------------------------------------------------- fixture builder
function New-CaptureFixture {
  param([string]$Dir, [string]$Variant)
  if (-not (Test-Path -LiteralPath $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }

  $shared = @(
    [PSCustomObject]@{ Rel='settings.yaml';          Size=52;  Utc='2026-10-05T04:29:50.0000000Z'; Sha256='AAAA1111' },
    [PSCustomObject]@{ Rel='settings.yaml.imported'; Size=176; Utc='2026-10-04T13:22:58.0000000Z'; Sha256='BBBB2222' }
  )
  $homeFp = @(
    [PSCustomObject]@{ Rel='AGENTS.md'; Size=626; Utc='2026-09-12T14:06:51.0000000Z'; Sha256='CCCC3333' }
  )
  $sessions = @(
    [PSCustomObject]@{ Rel='ws\session-1\session.v3.jsonl.zstd'; Format='v3'; Size=100; Utc='2026-09-20T10:00:00.0000000Z'; Sha256='DDDD4444' },
    [PSCustomObject]@{ Rel='ws\session-2\session.v4.jsonl.zstd'; Format='v4'; Size=200; Utc='2026-10-04T10:00:00.0000000Z'; Sha256='EEEE5555' }
  )
  $projcache = @(
    [PSCustomObject]@{ Rel='session-1.json'; Size=10; Utc='2026-09-20T10:00:00.0000000Z'; Sha256='FFFF6666' }
  )

  switch ($Variant) {
    'changed' {
      $shared[0].Sha256 = 'AAAA9999'          # one CONTENT-CHANGED
      $projcache += [PSCustomObject]@{ Rel='session-2.json'; Size=11; Utc='2026-10-04T10:00:00.0000000Z'; Sha256='GGGG7777' }   # one ADDED
    }
    'noprojcache' {
      # deliberately do not write projcache-inventory.csv -> real compare must SKIP that section
    }
  }

  $shared     | Export-Csv -LiteralPath (Join-Path $Dir 'shared-state-manifest.csv') -NoTypeInformation -Encoding UTF8
  $homeFp     | Export-Csv -LiteralPath (Join-Path $Dir 'dsh-home-fingerprints.csv') -NoTypeInformation -Encoding UTF8
  $sessions   | Export-Csv -LiteralPath (Join-Path $Dir 'session-inventory.csv')     -NoTypeInformation -Encoding UTF8
  if ($Variant -ne 'noprojcache') {
    $projcache | Export-Csv -LiteralPath (Join-Path $Dir 'projcache-inventory.csv')   -NoTypeInformation -Encoding UTF8
  }
}

# ---------------------------------------------------------------- stub producers
# Emits a report with the requested per-section counts, plus a detail file that may be
# empty or over-full. Log completion marker optional (Case 6 omits it).
$srcStub = @'
param(
  [string]$Before,[string]$After,[string]$OutDir,
  [int]$ChgPerSection = 0,
  [int]$DetailRows = -1,
  [switch]$NoDoneMarker,
  [switch]$SkipSection
)
$rep = Join-Path $OutDir 'compare-report.txt'
$secs = @(
  @('SHARED STATE','shared-state-manifest.csv'),
  @('DSH_HOME FINGERPRINTS (script A)','dsh-home-fingerprints.csv'),
  @('SESSION INVENTORY','session-inventory.csv'),
  @('PROJCACHE INVENTORY','projcache-inventory.csv')
)
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('=== SCRIPT D: compare captures ===')
$sum = 0
foreach ($s in $secs) {
  if ($SkipSection -and $s[0] -eq 'PROJCACHE INVENTORY') {
    $lines.Add('SECTION: ' + $s[0] + '   (' + $s[1] + ')')
    $lines.Add('  SKIPPED (manifest not found in one of the captures)')
    continue
  }
  $lines.Add('--------------------------------------------------------------------')
  $lines.Add('SECTION: ' + $s[0] + '   (' + $s[1] + ')')
  $lines.Add('--------------------------------------------------------------------')
  $lines.Add('  total tracked   : 5')
  $lines.Add('  ADDED           : ' + $ChgPerSection)
  $lines.Add('  DELETED         : 0')
  $lines.Add('  CONTENT-CHANGED : 0')
  $lines.Add('  MTIME-ONLY      : 0')
  $sum += $ChgPerSection
}
$lines.Add('--------------------------------------------------------------------')
$lines.Add('SECTION: SESSION FORMAT SUMMARY (informational)')
$lines.Add('--------------------------------------------------------------------')
$lines.Add('  BEFORE  total=5     v3=4 v4=1')
$lines.Add('  AFTER   total=5     v3=4 v4=1')
$lines.Add('')
$lines.Add('warnings: 0')
$lines | Set-Content -LiteralPath $rep -Encoding UTF8

$rows = New-Object System.Collections.Generic.List[object]
if ($DetailRows -lt 0) { $DetailRows = $sum }
for ($i = 1; $i -le $DetailRows; $i++) {
  $rows.Add([PSCustomObject]@{ Section='SHARED STATE'; Class='ADDED'; Rel=('x' + $i); BeforeSize=''; AfterSize='1'; BeforeHash=''; AfterHash='h' })
}
$rows | Export-Csv -LiteralPath (Join-Path $OutDir 'compare-detail.csv') -NoTypeInformation -Encoding UTF8
Write-Host 'report lines written = 49'
if (-not $NoDoneMarker) { Write-Host '=== SCRIPT D DONE (warnings: 0) ===' }
'@
$srcStub | Set-Content -LiteralPath (Join-Path $stubTools 'compare-captures.ps1') -Encoding UTF8

# ================================================================ CASE 0
WRL "--- CASE 0: the REAL R2 compare output that was previously rejected must now VALIDATE"
if (Test-Path -LiteralPath (Join-Path $RealCompareDir 'compare-report.txt')) {
  $c0 = Test-GuardedCompareOutput -CompareDir $RealCompareDir
  CHECK "C0 real R2 compare validates" $c0.Ok ("errors: " + ($c0.Errors -join ' | '))
  CHECK "C0 real R2 detailRows = 0" ($c0.DetailRows -eq 0) ("detailRows = " + $c0.DetailRows)
  CHECK "C0 real R2 expectedDetailRows = 0" ($c0.ExpectedDetailRows -eq 0) ("expected = " + $c0.ExpectedDetailRows)
  CHECK "C0 real R2 warnings = 0" ($c0.Warnings -eq 0) ("warnings = " + $c0.Warnings)
  CHECK "C0 all four required sections parsed" (@($c0.Sections | Where-Object { $_.Title -in @('SHARED STATE','DSH_HOME FINGERPRINTS','SESSION INVENTORY','PROJCACHE INVENTORY') }).Count -eq 4) `
        ("parsed: " + ((@($c0.Sections) | ForEach-Object { $_.Title }) -join ' / '))
} else {
  CHECK "C0 real R2 compare dir present" $false ("not found: " + $RealCompareDir)
}
WRL ""

# ================================================================ CASE 1
WRL "--- CASE 1: identical fixtures (all counts 0, detail rows 0) -> diffValid = True"
$c1a = Join-Path $fixtures 'capA'
$c1b = Join-Path $fixtures 'capB'
New-CaptureFixture -Dir $c1a -Variant 'base'
New-CaptureFixture -Dir $c1b -Variant 'base'
$r1 = Invoke-GuardedCompare -ToolsDir $ToolsDir -Before $c1a -After $c1b -OutDir (Join-Path $Root 'cmp-case1')
CHECK "C1 diff valid" $r1.Ok ("errors: " + ($r1.Errors -join ' | '))
CHECK "C1 DetailRows = 0" ($r1.DetailRows -eq 0) ("DetailRows = " + $r1.DetailRows)
CHECK "C1 ExpectedDetailRows = 0" ($r1.ExpectedDetailRows -eq 0) ("Expected = " + $r1.ExpectedDetailRows)
CHECK "C1 warnings = 0" ($r1.Warnings -eq 0) ("warnings = " + $r1.Warnings)
CHECK "C1 the empty detail file really is BOM-only" ((Get-Item -LiteralPath (Join-Path (Join-Path $Root 'cmp-case1') 'compare-detail.csv')).Length -le 3) "detail file is not empty"
WRL ""

# ================================================================ CASE 2
WRL "--- CASE 2: change counts > 0 and detail rows match -> diffValid = True"
$c2b = Join-Path $fixtures 'capC'
New-CaptureFixture -Dir $c2b -Variant 'changed'
$r2 = Invoke-GuardedCompare -ToolsDir $ToolsDir -Before $c1a -After $c2b -OutDir (Join-Path $Root 'cmp-case2')
CHECK "C2 diff valid" $r2.Ok ("errors: " + ($r2.Errors -join ' | '))
CHECK "C2 DetailRows > 0" ($r2.DetailRows -gt 0) ("DetailRows = " + $r2.DetailRows)
CHECK "C2 DetailRows = ExpectedDetailRows" ($r2.DetailRows -eq $r2.ExpectedDetailRows) ("{0} vs {1}" -f $r2.DetailRows, $r2.ExpectedDetailRows)
CHECK "C2 ExpectedDetailRows = 2 (1 CONTENT-CHANGED + 1 ADDED)" ($r2.ExpectedDetailRows -eq 2) ("Expected = " + $r2.ExpectedDetailRows)
WRL ""

# ================================================================ CASE 3
WRL "--- CASE 3: change counts > 0 but detail rows = 0 -> diffValid = False"
$stub3 = Join-Path $Root 'tools-case3'
if (-not (Test-Path -LiteralPath $stub3)) { New-Item -ItemType Directory -Path $stub3 -Force | Out-Null }
@'
param([string]$Before,[string]$After,[string]$OutDir)
& (Join-Path (Split-Path $PSScriptRoot -Parent) 'tools-stub\compare-captures.ps1') -Before $Before -After $After -OutDir $OutDir -ChgPerSection 2 -DetailRows 0
'@ | Set-Content -LiteralPath (Join-Path $stub3 'compare-captures.ps1') -Encoding UTF8
$r3 = Invoke-GuardedCompare -ToolsDir $stub3 -Before $c1a -After $c1b -OutDir (Join-Path $Root 'cmp-case3')
CHECK "C3 diff INVALID" (-not $r3.Ok) "counts said 8 changes but detail was empty - validator accepted it"
CHECK "C3 error is the report/detail mismatch" (HasErr $r3 'detail rows') ("errors: " + ($r3.Errors -join ' | '))
CHECK "C3 DetailRows = 0 and Expected = 8" (($r3.DetailRows -eq 0) -and ($r3.ExpectedDetailRows -eq 8)) ("{0} vs {1}" -f $r3.DetailRows, $r3.ExpectedDetailRows)
WRL ""

# ================================================================ CASE 4
WRL "--- CASE 4: all counts = 0 but detail rows > 0 -> diffValid = False"
$stub4 = Join-Path $Root 'tools-case4'
if (-not (Test-Path -LiteralPath $stub4)) { New-Item -ItemType Directory -Path $stub4 -Force | Out-Null }
@'
param([string]$Before,[string]$After,[string]$OutDir)
& (Join-Path (Split-Path $PSScriptRoot -Parent) 'tools-stub\compare-captures.ps1') -Before $Before -After $After -OutDir $OutDir -ChgPerSection 0 -DetailRows 3
'@ | Set-Content -LiteralPath (Join-Path $stub4 'compare-captures.ps1') -Encoding UTF8
$r4 = Invoke-GuardedCompare -ToolsDir $stub4 -Before $c1a -After $c1b -OutDir (Join-Path $Root 'cmp-case4')
CHECK "C4 diff INVALID" (-not $r4.Ok) "counts said 0 changes but detail had rows - validator accepted it"
CHECK "C4 error is the report/detail mismatch" (HasErr $r4 'detail rows') ("errors: " + ($r4.Errors -join ' | '))
CHECK "C4 DetailRows = 3 and Expected = 0" (($r4.DetailRows -eq 3) -and ($r4.ExpectedDetailRows -eq 0)) ("{0} vs {1}" -f $r4.DetailRows, $r4.ExpectedDetailRows)
WRL ""

# ================================================================ CASE 5
WRL "--- CASE 5: SKIPPED / missing manifest -> diffValid = False"
$c5b = Join-Path $fixtures 'capD-noprojcache'
New-CaptureFixture -Dir $c5b -Variant 'noprojcache'
$r5 = Invoke-GuardedCompare -ToolsDir $ToolsDir -Before $c1a -After $c5b -OutDir (Join-Path $Root 'cmp-case5')
CHECK "C5 diff INVALID" (-not $r5.Ok) "a SKIPPED section was accepted"
CHECK "C5 error mentions SKIPPED or missing manifest" ((HasErr $r5 'SKIPPED') -or (HasErr $r5 'manifest missing')) ("errors: " + ($r5.Errors -join ' | '))
$stub5 = Join-Path $Root 'tools-case5'
if (-not (Test-Path -LiteralPath $stub5)) { New-Item -ItemType Directory -Path $stub5 -Force | Out-Null }
@'
param([string]$Before,[string]$After,[string]$OutDir)
& (Join-Path (Split-Path $PSScriptRoot -Parent) 'tools-stub\compare-captures.ps1') -Before $Before -After $After -OutDir $OutDir -ChgPerSection 0 -DetailRows 0 -SkipSection
'@ | Set-Content -LiteralPath (Join-Path $stub5 'compare-captures.ps1') -Encoding UTF8
$r5b = Invoke-GuardedCompare -ToolsDir $stub5 -Before $c1a -After $c1b -OutDir (Join-Path $Root 'cmp-case5b')
CHECK "C5b stubbed SKIPPED section also invalid" (-not $r5b.Ok) "a SKIPPED section was accepted"
WRL ""

# ================================================================ CASE 6
WRL "--- CASE 6: truncated compare log (no completion marker) -> diffValid = False"
$stub6 = Join-Path $Root 'tools-case6'
if (-not (Test-Path -LiteralPath $stub6)) { New-Item -ItemType Directory -Path $stub6 -Force | Out-Null }
@'
param([string]$Before,[string]$After,[string]$OutDir)
& (Join-Path (Split-Path $PSScriptRoot -Parent) 'tools-stub\compare-captures.ps1') -Before $Before -After $After -OutDir $OutDir -ChgPerSection 0 -DetailRows 0 -NoDoneMarker
'@ | Set-Content -LiteralPath (Join-Path $stub6 'compare-captures.ps1') -Encoding UTF8
$r6 = Invoke-GuardedCompare -ToolsDir $stub6 -Before $c1a -After $c1b -OutDir (Join-Path $Root 'cmp-case6')
CHECK "C6 diff INVALID" (-not $r6.Ok) "a truncated compare log was accepted"
CHECK "C6 error mentions the completion marker" (HasErr $r6 'completion marker') ("errors: " + ($r6.Errors -join ' | '))
WRL ""

# ================================================================ summary
WRL "================================================================"
WRL ("RESULT: {0} passed, {1} failed" -f $script:pass, $script:fail)
if ($script:fail -eq 0) { WRL "ZERO-DIFF REGRESSION: PASS" } else { WRL "ZERO-DIFF REGRESSION: FAIL" }
WRL "================================================================"

$script:lines | Set-Content -LiteralPath (Join-Path $Root 'zerodiff-regression-report.txt') -Encoding UTF8
$latest = Join-Path 'D:\Projects\dsh-test\evidence\desktop\runtime\_selftest-r2' 'zerodiff-regression-latest.txt'
$script:lines | Set-Content -LiteralPath $latest -Encoding UTF8
Write-Host ""
Write-Host ("report : {0}" -f (Join-Path $Root 'zerodiff-regression-report.txt'))
Write-Host ("latest : {0}" -f $latest)
if ($script:fail -gt 0) { exit 1 }
exit 0

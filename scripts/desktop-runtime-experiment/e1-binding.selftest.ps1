<#
.SYNOPSIS
  Path-binding / fail-closed tests for the explicit E1 baseline binding.

.DESCRIPTION
  Everything runs in a scratch root against MOCK captures. No host is started, nothing in
  $DSH_HOME is touched, and the real evidence tree is not written to.

  Cases:
    1. a valid, sealed baseline binds correctly and Stage A diffs THE BASELINE
    2. baseline directory missing              -> STOP
    3. baseline belongs to a different run     -> STOP
    4. workspace mismatch                      -> STOP (end to end, through e1-capture.ps1)
    5. Stage B/C lock belongs to another run   -> STOP (end to end, before any capture)
    6. baseline manifests changed after sealing-> STOP
    7. no metadata at all                      -> STOP (never guess e1-<RunName>-BASE)
    8. the retired derivation e1-<RunName>-BASE must not appear as a baseline anywhere

  Exit 0 = all cases behaved as required.
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
function HasErr($arr, $pattern) { return (@($arr) | Where-Object { $_ -match $pattern }).Count -gt 0 }

$ToolsDir = 'D:\Projects\dsh-test\scripts\desktop-runtime-experiment'
$RunId = Get-Date -Format 'yyyyMMdd-HHmmss'
$Root  = Join-Path $Scratch ("binding-" + $RunId)

WRL "================================================================"
WRL "E1 BASELINE BINDING / FAIL-CLOSED TESTS   ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))"
WRL "scratch = $Root"
WRL "================================================================"
WRL ""
WRL "Mock-only. No host is started; no capture touches the real evidence tree."
WRL ""

if (-not (Test-Path -LiteralPath $Root)) { New-Item -ItemType Directory -Path $Root -Force | Out-Null }
. (Join-Path $ToolsDir 'capture-guard.ps1')
. (Join-Path $ToolsDir 'capture-run-config.ps1')

# ---------------------------------------------------------------- mock helpers
function New-MockCapture {
  param([string]$Dir, [string]$Tag)
  if (-not (Test-Path -LiteralPath $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
  $shared = @(
    [PSCustomObject]@{ Rel='settings.yaml'; Size=52;  Utc='2026-10-05T04:29:50.0000000Z'; Sha256=("AAAA" + $Tag) },
    [PSCustomObject]@{ Rel='settings.yaml.imported'; Size=176; Utc='2026-10-04T13:22:58.0000000Z'; Sha256=("BBBB" + $Tag) }
  )
  $sessions = @(
    [PSCustomObject]@{ Rel='ws\session-1\session.v3.jsonl.zstd'; Format='v3'; Size=100; Utc='2026-09-20T10:00:00.0000000Z'; Sha256=("DDDD" + $Tag) }
  )
  $shared   | Export-Csv -LiteralPath (Join-Path $Dir 'shared-state-manifest.csv') -NoTypeInformation -Encoding UTF8
  $sessions | Export-Csv -LiteralPath (Join-Path $Dir 'session-inventory.csv')     -NoTypeInformation -Encoding UTF8
  @([PSCustomObject]@{ Rel='AGENTS.md'; Size=626; Utc='2026-09-12T14:06:51.0000000Z'; Sha256='CCCC1' }) |
    Export-Csv -LiteralPath (Join-Path $Dir 'dsh-home-fingerprints.csv') -NoTypeInformation -Encoding UTF8
  @([PSCustomObject]@{ Rel='c1.json'; Size=10; Utc='2026-09-20T10:00:00.0000000Z'; Sha256='FFFF1' }) |
    Export-Csv -LiteralPath (Join-Path $Dir 'projcache-inventory.csv') -NoTypeInformation -Encoding UTF8
}

function New-SealedRun {
  param(
    [string]$RunName,
    [string]$WorkspacePath,
    [string]$BaselineNamespace,
    [string]$SealRunName = ''      # default: same as RunName
  )
  $metaPath = Get-E1MetadataPath -Root $Root -RunName $RunName
  $meta = New-E1RunMetadata -RunName $RunName -Root $Root -WorkspacePath $WorkspacePath `
                            -BaselineNamespace $BaselineNamespace -DshHome $Root
  Save-E1RunMetadata -Metadata $meta -Path $metaPath
  $cap1 = $meta.BaselineDir
  New-MockCapture -Dir $cap1 -Tag 'B1'
  $verdict = Join-Path $Root ($BaselineNamespace + '-VERDICT.txt')
  "QUIESCENT BASELINE: PASS (mock)" | Set-Content -LiteralPath $verdict -Encoding UTF8

  $sealMeta = Import-E1RunMetadata -Path $metaPath
  if ($SealRunName) { $sealMeta.RunName = $SealRunName }    # deliberately wrong run, for case 3
  $binding = New-E1BaselineBinding -Metadata $sealMeta -BaselineDir $cap1 -VerdictPath $verdict
  Save-E1BaselineBinding -Binding $binding -BaselineDir $cap1 | Out-Null
  $metaReal = Import-E1RunMetadata -Path $metaPath
  $metaReal.BaselineVerified = $true
  $metaReal.BaselineSealedAt = $binding.SealedAt
  $metaReal.BaselineFingerprint = (Get-ComparedManifestFingerprint -Dir $cap1)
  Save-E1RunMetadata -Metadata $metaReal -Path $metaPath
  return [PSCustomObject]@{ MetaPath=$metaPath; Meta=$metaReal; Cap1=$cap1; Verdict=$verdict }
}

# ================================================================ CASE 1
WRL "--- CASE 1: valid sealed baseline -> correct binding, Stage A diffs THE BASELINE ---"
$run1 = New-SealedRun -RunName 'runT1' -WorkspacePath (Join-Path $Root 'ws1') -BaselineNamespace 'e1-BASE-QUIESCENT-T1'
$ctx1 = Resolve-E1RunContext -Root $Root -RunName 'runT1' -MetadataPath $run1.MetaPath
CHECK "C1 context resolves" $ctx1.Ok ("errors: " + ($ctx1.Errors -join ' | '))
CHECK "C1 BaselineDir comes from metadata" ($ctx1.BaselineDir -eq $run1.Meta.BaselineDir) ("{0} vs {1}" -f $ctx1.BaselineDir, $run1.Meta.BaselineDir)
$prev1 = Get-E1PreviousStage -Context $ctx1 -Stage 'A'
CHECK "C1 Stage A previous stage IS the sealed baseline" ($prev1.Dir -eq $run1.Cap1 -and $prev1.IsBaseline) ("dir={0} isBaseline={1}" -f $prev1.Dir, $prev1.IsBaseline)
CHECK "C1 Stage A previous label is BASELINE" ($prev1.Label -eq 'BASELINE') ("label=" + $prev1.Label)
CHECK "C1 Stage A compare dir is the metadata BASELINE-A dir" ($prev1.CompareDir -eq $run1.Meta.CompareDirs.'BASELINE-A') ("cmp=" + $prev1.CompareDir)
$prev1b = Get-E1PreviousStage -Context $ctx1 -Stage 'B'
CHECK "C1 Stage B previous stage is Stage A" ($prev1b.Dir -eq $run1.Meta.StageDirs.A -and -not $prev1b.IsBaseline) ("dir=" + $prev1b.Dir)
CHECK "C1 no 'e1-<RunName>-BASE' path is produced anywhere" ($prev1.Dir -notmatch 'runT1-BASE' -and $prev1.CompareDir -notmatch 'BASE-' ) "a guess path leaked"
WRL ""

# ================================================================ CASE 2
WRL "--- CASE 2: declared baseline directory missing -> STOP ---"
$meta2 = New-E1RunMetadata -RunName 'runT2' -Root $Root -WorkspacePath (Join-Path $Root 'ws2') `
                           -BaselineNamespace 'e1-BASE-QUIESCENT-T2-ABSENT' -DshHome $Root
$meta2.BaselineVerified = $true          # even a 'verified' flag must not save it
$p2 = Get-E1MetadataPath -Root $Root -RunName 'runT2'
Save-E1RunMetadata -Metadata $meta2 -Path $p2
$ctx2 = Resolve-E1RunContext -Root $Root -RunName 'runT2' -MetadataPath $p2
CHECK "C2 context NOT ok" (-not $ctx2.Ok) "a missing baseline was accepted"
CHECK "C2 error names the missing directory" (HasErr $ctx2.Errors 'does not exist') ("errors: " + ($ctx2.Errors -join ' | '))
WRL ""

# ================================================================ CASE 3
WRL "--- CASE 3: baseline belongs to a DIFFERENT run -> STOP ---"
# baseline sealed with RunName 'runOTHER', metadata claims 'runT3'
$run3 = New-SealedRun -RunName 'runT3' -WorkspacePath (Join-Path $Root 'ws3') `
                      -BaselineNamespace 'e1-BASE-QUIESCENT-T3' -SealRunName 'runOTHER'
$ctx3 = Resolve-E1RunContext -Root $Root -RunName 'runT3' -MetadataPath $run3.MetaPath
CHECK "C3 context NOT ok" (-not $ctx3.Ok) "a foreign baseline was accepted"
CHECK "C3 error names the run mismatch" (HasErr $ctx3.Errors "belongs to run 'runOTHER'") ("errors: " + ($ctx3.Errors -join ' | '))
WRL ""

# ================================================================ CASE 4
WRL "--- CASE 4: workspace mismatch -> STOP (end to end through e1-capture.ps1) ---"
$run4 = New-SealedRun -RunName 'runT4' -WorkspacePath (Join-Path $Root 'ws4') -BaselineNamespace 'e1-BASE-QUIESCENT-T4'
$e1 = Join-Path $ToolsDir 'e1-capture.ps1'
$wrongWs = Join-Path $Root 'ws4-OTHER'
$out4 = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $e1 -RunName 'runT4' -Root $Root -Stage A -WorkspacePath $wrongWs 2>&1 | Out-String
$code4 = $LASTEXITCODE
$stageDir4 = Join-Path $Root 'e1-runT4-A'
CHECK "C4 exit code is 1" ($code4 -eq 1) ("exit=$code4")
CHECK "C4 STOP names the workspace mismatch" ($out4 -match 'workspace mismatch') ("output tail: " + ($out4.Substring([Math]::Max(0,$out4.Length-300))))
CHECK "C4 no capture ran (no session-inventory.csv was produced)" (-not (Test-Path -LiteralPath (Join-Path $stageDir4 'session-inventory.csv'))) "a capture ran despite the mismatch"
CHECK "C4 no _log-A.txt (guarded capture never invoked)" (-not (Test-Path -LiteralPath (Join-Path $stageDir4 '_log-A.txt'))) "a guarded capture was invoked"
CHECK "C4 the stage directory was NOT created" (-not (Test-Path -LiteralPath $stageDir4)) "a half-built stage dir was left behind"
CHECK "C4 a refusal record was written instead" (Test-Path -LiteralPath (Join-Path $Root 'e1-runT4-BINDING-REFUSED.txt') -PathType Leaf) "no refusal record"
WRL ""

# ================================================================ CASE 5
WRL "--- CASE 5: Stage B/C lock belongs to another run -> STOP before any capture ---"
$run5 = New-SealedRun -RunName 'runT5' -WorkspacePath (Join-Path $Root 'ws5') -BaselineNamespace 'e1-BASE-QUIESCENT-T5'
$lock5 = [PSCustomObject]@{
  SchemaVersion=1; RunName='runOTHER'; LockedAt=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  WorkspacePath=(Join-Path $Root 'ws5'); WorkspaceDir=(Join-Path $Root 'other-session-dir')
  WorkspaceDirName='--OTHER--'; MetadataPath=''; BaselineDir='D:\somewhere\else'
  SessionId='session-deadbeef'; File='session.v4.jsonl.zstd'; Format='v4'
  SizeAtLock=1; Sha256AtLock='X'; ProjCache=''
}
$lock5 | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $run5.Meta.LockFile -Encoding UTF8
$out5 = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $e1 -RunName 'runT5' -Root $Root -Stage B 2>&1 | Out-String
$code5 = $LASTEXITCODE
$stageDir5 = Join-Path $Root 'e1-runT5-B'
CHECK "C5 exit code is 1" ($code5 -eq 1) ("exit=$code5")
CHECK "C5 STOP names the exact-session-lock mismatch" ($out5 -match 'EXACT SESSION LOCK MISMATCH') ("output tail: " + ($out5.Substring([Math]::Max(0,$out5.Length-300))))
CHECK "C5 fault list names the RunName mismatch" ($out5 -match "lock RunName 'runOTHER'") "the fault list did not name the RunName mismatch"
CHECK "C5 fault list names the BaselineDir mismatch" ($out5 -match 'lock BaselineDir') "the fault list did not name the BaselineDir mismatch"
CHECK "C5 no capture ran (checked BEFORE section 1)" (-not (Test-Path -LiteralPath (Join-Path $stageDir5 '_log-B.txt'))) "a capture ran despite the lock mismatch"
CHECK "C5 the stage directory was NOT created" (-not (Test-Path -LiteralPath $stageDir5)) "a half-built stage dir was left behind"
CHECK "C5 a refusal record was written instead" (Test-Path -LiteralPath (Join-Path $Root 'e1-runT5-BINDING-REFUSED.txt') -PathType Leaf) "no refusal record"
WRL ""

# ================================================================ CASE 6
WRL "--- CASE 6: baseline manifests changed after sealing -> STOP ---"
$run6 = New-SealedRun -RunName 'runT6' -WorkspacePath (Join-Path $Root 'ws6') -BaselineNamespace 'e1-BASE-QUIESCENT-T6'
# mutate one manifest AFTER sealing (mock dir only; nothing real is touched)
$m6 = Join-Path $run6.Cap1 'shared-state-manifest.csv'
$extra = @([PSCustomObject]@{ Rel='settings.yaml'; Size=99; Utc='2026-10-06T00:00:00.0000000Z'; Sha256='ZZZZ9' })
$extra | Export-Csv -LiteralPath $m6 -NoTypeInformation -Encoding UTF8
$ctx6 = Resolve-E1RunContext -Root $Root -RunName 'runT6' -MetadataPath $run6.MetaPath
CHECK "C6 context NOT ok" (-not $ctx6.Ok) "a drifted baseline was accepted"
CHECK "C6 error names the drifted manifest" (HasErr $ctx6.Errors 'changed after sealing') ("errors: " + ($ctx6.Errors -join ' | '))
WRL ""

# ================================================================ CASE 7
WRL "--- CASE 7: no metadata at all -> STOP (a baseline path is never guessed) ---"
$ctx7 = Resolve-E1RunContext -Root $Root -RunName 'runNOPE'
CHECK "C7 context NOT ok" (-not $ctx7.Ok) "a run without metadata was accepted"
CHECK "C7 error says metadata was not found" (HasErr $ctx7.Errors 'run metadata not found') ("errors: " + ($ctx7.Errors -join ' | '))
CHECK "C7 error tells the operator to use new-e1-run.ps1" (HasErr $ctx7.Errors 'new-e1-run') "the error does not say how to create the run"
WRL ""

# ================================================================ CASE 8
WRL "--- CASE 8: the retired derivation must be gone from the source ---"
$src = Get-Content -LiteralPath $e1 -Raw -Encoding UTF8
CHECK "C8 e1-capture.ps1 has no 'e1-BASE-QUIESCENT-R2' hard-coding" ($src -notmatch 'e1-BASE-QUIESCENT-R2') "a hard-coded baseline namespace remains"
CHECK "C8 e1-capture.ps1 has exactly one baseline variable assignment" ((@([regex]::Matches($src,'\$baselineDir\s*=')).Count) -eq 1) ("assignments=" + @([regex]::Matches($src,'\$baselineDir\s*=')).Count)
CHECK "C8 Stage BASE is rejected by the parameter set" ($src -match "ValidateSet\('A','B','C'\)") "Stage BASE may still be accepted"
CHECK "C8 previous stage comes from metadata, not from the run name" ($src -match 'Get-E1PreviousStage -Context \$ctx') "the previous stage is still derived locally"
CHECK 'C8 the classifier uses $baselineDir' (([regex]::Matches($src,'Join-Path \$baselineDir')).Count -ge 2) "the classifier does not use the bound baseline"

# "no hard-coded namespace" must mean CODE, not prose: the docstrings deliberately quote the
# old namespaces to explain the defect. Strip line comments AND <# ... #> block comments
# before checking. (A '<#' inside a string literal would confuse this simple scanner; none
# of the files under test contain one.)
function Get-CodeOnly {
  param([string]$Text)
  $out = New-Object System.Collections.Generic.List[string]
  $depth = 0
  foreach ($ln in ($Text -split "`r?`n")) {
    $work = $ln
    if ($depth -gt 0) {
      $close = $work.IndexOf('#>')
      if ($close -lt 0) { continue }
      $work = $work.Substring($close + 2)
      $depth = 0
    }
    while ($true) {
      $open = $work.IndexOf('<#')
      if ($open -lt 0) { break }
      $close = $work.IndexOf('#>', $open + 2)
      if ($close -lt 0) { $work = $work.Substring(0, $open); $depth = 1; break }
      $work = $work.Substring(0, $open) + $work.Substring($close + 2)
    }
    if ($work -match '^\s*#') { continue }
    $out.Add($work)
  }
  return ($out -join "`n")
}
$cfgCode = Get-CodeOnly -Text (Get-Content -LiteralPath (Join-Path $ToolsDir 'capture-run-config.ps1') -Raw -Encoding UTF8)
$e1Code  = Get-CodeOnly -Text $src
$blCode  = Get-CodeOnly -Text (Get-Content -LiteralPath (Join-Path $ToolsDir 'capture-e1-quiescent-baseline.ps1') -Raw -Encoding UTF8)
CHECK "C8 run-config has no hard-coded namespace in CODE" ($cfgCode -notmatch 'QUIESCENT-R2') "a hard-coded namespace appears in executable code"
CHECK "C8 e1-capture has no hard-coded namespace in CODE" ($e1Code -notmatch 'QUIESCENT-R2') "a hard-coded namespace appears in executable code"
CHECK 'C8 e1-capture has no $baseNs variable in CODE' ($e1Code -notmatch '\$baseNs') "a second baseline variable still exists"
CHECK "C8 baseline wrapper has no hard-coded namespace in CODE" ($blCode -notmatch 'QUIESCENT-R2') "the wrapper still hard-codes a namespace"
CHECK "C8 baseline wrapper requires -Namespace" ($blCode -match 'Mandatory=\$true\)\]\[string\]\$Namespace') "the namespace is not mandatory"
WRL ""

# ================================================================ summary
WRL "================================================================"
WRL ("RESULT: {0} passed, {1} failed" -f $script:pass, $script:fail)
if ($script:fail -eq 0) { WRL "BASELINE BINDING TESTS: PASS" } else { WRL "BASELINE BINDING TESTS: FAIL" }
WRL "================================================================"
$script:lines | Set-Content -LiteralPath (Join-Path $Root 'binding-tests-report.txt') -Encoding UTF8
$latest = Join-Path $Scratch 'binding-tests-latest.txt'
$script:lines | Set-Content -LiteralPath $latest -Encoding UTF8
Write-Host ""
Write-Host ("report : {0}" -f (Join-Path $Root 'binding-tests-report.txt'))
Write-Host ("latest : {0}" -f $latest)
if ($script:fail -gt 0) { exit 1 }
exit 0

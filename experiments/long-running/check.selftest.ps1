#requires -Version 5.1
<#
  check.selftest.ps1 - regression harness for check.ps1 (Evaluator v0)

  Proves the evaluator can tell PASS from FAIL in four independent situations,
  and that it is genuinely read-only.

  T1  empty directory                  -> FAIL
  T2  core artifact missing             -> FAIL (names the artifact)
  T3  required field missing            -> FAIL (names the field)
  T4  compliant on-disk fixture         -> PASS
  T5  read-only + no write cmdlets      -> PASS

  The compliant fixture lives on disk at fixtures/complete. The three FAIL
  cases are derived at run time by copying that fixture into a temp directory
  and mutating the copy, so the real pilot deliverable is never pre-generated.

  EXIT 0 only when every case behaves as expected.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Check = Join-Path $Here 'check.ps1'
$Fixture = Join-Path $Here 'fixtures\complete'

$script:Pass = 0
$script:Fail = 0

function Invoke-Check([string]$root) {
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Check -Root $root 2>&1 | Out-String
    return [PSCustomObject]@{ Exit = $LASTEXITCODE; Text = $out }
}

function Assert-Case {
    param([string]$Name, [string]$Expect, $Result, [string[]]$MustMention)
    $ok = $true
    $why = @()

    if ($Expect -eq 'FAIL' -and $Result.Exit -eq 0) { $ok = $false; $why += "expected non-zero exit, got 0" }
    if ($Expect -eq 'PASS' -and $Result.Exit -ne 0) { $ok = $false; $why += "expected exit 0, got $($Result.Exit)" }
    if ($Expect -eq 'FAIL' -and $Result.Exit -eq 2) { $ok = $false; $why += "exit 2 (ERROR) is not an acceptable FAIL" }

    foreach ($needle in $MustMention) {
        if ($Result.Text -notmatch [regex]::Escape($needle)) {
            $ok = $false
            $why += "output did not mention '$needle'"
        }
    }

    if ($ok) {
        $script:Pass++
        Write-Host "  [PASS] $Name"
    }
    else {
        $script:Fail++
        Write-Host "  [FAIL] $Name"
        foreach ($w in $why) { Write-Host "         $w" }
        Write-Host "         ---- evaluator output ----"
        ($Result.Text -split "`n") | ForEach-Object { Write-Host "         $_" }
    }
}

Write-Host ""
Write-Host "check.selftest.ps1 - Evaluator v0 regression"
Write-Host "evaluator: $Check"
Write-Host "fixture  : $Fixture"
Write-Host ""

# ---------------------------------------------------------------- preflight
if (-not (Test-Path -LiteralPath $Check -PathType Leaf)) { Write-Host "ERROR: check.ps1 not found"; exit 2 }
if (-not (Test-Path -LiteralPath $Fixture -PathType Container)) { Write-Host "ERROR: compliant fixture not found"; exit 2 }

# ------------------------------------------------- T5a read-only source audit
Write-Host "T5a read-only source audit"
$src = [System.IO.File]::ReadAllText($Check, [System.Text.Encoding]::UTF8)
$writeCmdlets = @('Set-Content', 'Add-Content', 'Out-File', 'New-Item', 'Remove-Item', 'Move-Item', 'Copy-Item', 'Clear-Content', 'Set-Item', 'Rename-Item')
$offenders = @()
foreach ($c in $writeCmdlets) {
    if ($src -match ('(?m)^\s*' + [regex]::Escape($c) + '\b')) { $offenders += $c }
}
if ($offenders.Count -eq 0) {
    $script:Pass++
    Write-Host "  [PASS] T5a no write cmdlet appears in check.ps1"
}
else {
    $script:Fail++
    Write-Host "  [FAIL] T5a check.ps1 contains write cmdlet(s): $($offenders -join ', ')"
}
Write-Host ""

$tmp = Join-Path $env:TEMP ("lrtk-selftest-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
    # --------------------------------------------------------------- T1 empty
    Write-Host "T1 empty directory -> FAIL"
    $emptyRoot = Join-Path $tmp 'empty'
    New-Item -ItemType Directory -Path $emptyRoot -Force | Out-Null
    $r = Invoke-Check $emptyRoot
    Assert-Case -Name 'T1 empty directory FAILs and names missing artifacts' -Expect 'FAIL' -Result $r -MustMention @('missing artifact: SKILL.md', 'missing artifact: METHODOLOGY.md')

    # ---------------------------------------------------- T2 missing artifact
    Write-Host "T2 missing core artifact -> FAIL"
    $r2root = Join-Path $tmp 'missing-artifact'
    Copy-Item -LiteralPath $Fixture -Destination $r2root -Recurse -Force
    Remove-Item -LiteralPath (Join-Path $r2root 'templates\EVALUATION.md') -Force
    $r = Invoke-Check $r2root
    Assert-Case -Name 'T2 missing templates/EVALUATION.md FAILs and names it' -Expect 'FAIL' -Result $r -MustMention @('missing artifact: templates/EVALUATION.md')

    # ------------------------------------------------------- T3 missing field
    Write-Host "T3 missing required field -> FAIL"
    $r3root = Join-Path $tmp 'missing-field'
    Copy-Item -LiteralPath $Fixture -Destination $r3root -Recurse -Force
    $gp = Join-Path $r3root 'templates\GOAL.md'
    $gt = [System.IO.File]::ReadAllText($gp, [System.Text.Encoding]::UTF8)
    $gt = ($gt -split "`n" | Where-Object { $_ -notmatch '^Non-goals:' }) -join "`n"
    [System.IO.File]::WriteAllText($gp, $gt, (New-Object System.Text.UTF8Encoding($false)))
    $r = Invoke-Check $r3root
    Assert-Case -Name 'T3 missing Non-goals field FAILs and names it' -Expect 'FAIL' -Result $r -MustMention @("missing required field in templates/GOAL.md: 'Non-goals:'")

    # ---------------------------------------------------- T6 missing README
    Write-Host "T6 missing README.md -> FAIL"
    $r6root = Join-Path $tmp 'missing-readme'
    Copy-Item -LiteralPath $Fixture -Destination $r6root -Recurse -Force
    Remove-Item -LiteralPath (Join-Path $r6root 'README.md') -Force
    $r = Invoke-Check $r6root
    Assert-Case -Name 'T6 missing README.md FAILs and names it' -Expect 'FAIL' -Result $r -MustMention @('missing artifact: README.md')

    # ------------------------------------------- T7 non-portable local coupling
    Write-Host "T7 hardcoded local path -> FAIL"
    $r7root = Join-Path $tmp 'non-portable'
    Copy-Item -LiteralPath $Fixture -Destination $r7root -Recurse -Force
    $mp = Join-Path $r7root 'METHODOLOGY.md'
    $mt = [System.IO.File]::ReadAllText($mp, [System.Text.Encoding]::UTF8)
    $mt = $mt + "`nState lives at D:\Projects\dsh-longloop-pilot\STATE.md`n"
    [System.IO.File]::WriteAllText($mp, $mt, (New-Object System.Text.UTF8Encoding($false)))
    $r = Invoke-Check $r7root
    Assert-Case -Name 'T7 hardcoded absolute path FAILs as non-portable' -Expect 'FAIL' -Result $r -MustMention @('non-portable absolute path')

    # --------------------------------------------- T8 version statement missing
    Write-Host "T8 dropped version note -> FAIL"
    $r8root = Join-Path $tmp 'no-version'
    Copy-Item -LiteralPath $Fixture -Destination $r8root -Recurse -Force
    $rp = Join-Path $r8root 'README.md'
    $rt = [System.IO.File]::ReadAllText($rp, [System.Text.Encoding]::UTF8)
    $rt = $rt.Replace('Verified against DSH 0.2.0', 'Verified against DSH')
    [System.IO.File]::WriteAllText($rp, $rt, (New-Object System.Text.UTF8Encoding($false)))
    $r = Invoke-Check $r8root
    Assert-Case -Name 'T8 missing verified version FAILs' -Expect 'FAIL' -Result $r -MustMention @('record the verified DSH version')

    # ------------------------------------------------------------- T4 compliant
    Write-Host "T4 compliant fixture -> PASS"
    $r = Invoke-Check $Fixture
    Assert-Case -Name 'T4 compliant fixture PASSes with exit 0' -Expect 'PASS' -Result $r -MustMention @('PASS', 'human review required')

    # ------------------------------------------------- T5b inputs left untouched
    Write-Host "T5b read-only behaviour on the real fixture"
    $before = @{}
    Get-ChildItem -LiteralPath $Fixture -Recurse -File | ForEach-Object {
        $before[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
    $null = Invoke-Check $Fixture
    $drift = @()
    foreach ($k in $before.Keys) {
        if (-not (Test-Path -LiteralPath $k)) { $drift += "deleted: $k"; continue }
        if ((Get-FileHash -LiteralPath $k -Algorithm SHA256).Hash -ne $before[$k]) { $drift += "modified: $k" }
    }
    if ($drift.Count -eq 0) {
        $script:Pass++
        Write-Host "  [PASS] T5b all fixture hashes unchanged after a run"
    }
    else {
        $script:Fail++
        Write-Host "  [FAIL] T5b fixture drifted: $($drift -join '; ')"
    }
}
finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
Write-Host "cases passed: $script:Pass   failed: $script:Fail"
if ($script:Fail -eq 0) {
    Write-Host "SELFTEST PASS"
    exit 0
}
Write-Host "SELFTEST FAIL"
exit 1

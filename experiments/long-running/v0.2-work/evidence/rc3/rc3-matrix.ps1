# rc3-matrix.ps1 - R3-T1..R3-T12 regression matrix for v0.2-rc.3
#
# Run in-process on this host (execution policy RemoteSigned + sandbox child-spawn refusal):
#   $sb = [scriptblock]::Create([System.IO.File]::ReadAllText($rc3matrix))
#   $sb
# Every case writes its raw log to evidence/rc3/r3-<label>.log.

Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

$base = 'D:\Projects\dsh-test\experiments\long-running\v0.2-work'
$sc = Join-Path $base 'evidence\rc3\scenarios'
$logDir = Join-Path $base 'evidence\rc3'
$ev = Join-Path $base 'evaluator\check-v0.2.ps1'

$sbEval = [scriptblock]::Create([System.IO.File]::ReadAllText($ev))
. $sbEval -Root '__load__'

$script:passed = 0
$script:total = 0

function Run3 {
    param(
        [string]$Label,
        [hashtable]$Case,
        [int]$Expect,
        [string[]]$MustHave = @(),
        [string[]]$MustNotHave = @()
    )
    $script:total++
    $a = @{}
    foreach ($k in $Case.Keys) { $a[$k] = $Case[$k] }
    $a['LogPath'] = Join-Path $logDir ("r3-{0}.log" -f $Label)
    $code = Invoke-Check @a 6>$null
    $text = [System.IO.File]::ReadAllText($a['LogPath'], [System.Text.Encoding]::UTF8)
    $fail = @()
    if ($code -ne $Expect) { $fail += "exit $code (expected $Expect)" }
    foreach ($m in $MustHave) { if ($text.IndexOf($m, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { $fail += "missing '$m'" } }
    foreach ($m in $MustNotHave) { if ($text.IndexOf($m, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $fail += "unexpected '$m'" } }
    if ($fail.Count -eq 0) {
        $script:passed++
        Write-Output ("  {0,-10} OK      exit={1}" -f $Label, $code)
    } else {
        Write-Output ("  {0,-10} FAIL    {1}" -f $Label, ($fail -join '; '))
    }
}

$cand = Join-Path $base 'candidate\long-running'
$u1 = Join-Path $sc 'U1-consistent'
$u2 = Join-Path $sc 'U2-equivalent'
$u3 = Join-Path $sc 'U3-conflict'
$u4 = Join-Path $sc 'U4-blank-decl'
$u5 = Join-Path $sc 'U5-no-contract'

# Captured before the first case runs, compared again by R3-T12 at the end.
$digestBefore = @{}
$digestPaths = @('README.md', 'SKILL.md', 'METHODOLOGY.md', 'templates/GOAL.md', 'templates/PLAN.md', 'templates/STATE.md', 'templates/EVALUATION.md', 'templates/FINAL-REPORT.md')
foreach ($rel in $digestPaths) {
    $digestBefore[$rel] = (Get-FileHash -LiteralPath (Join-Path $cand ($rel -replace '/', '\')) -Algorithm SHA256).Hash
}

Write-Output '=== R3 regression matrix (v0.2-rc.3) ==='

# R3-T1 Candidate Validation needs no GoalContract and must claim only candidate scope
Run3 'R3-T1' @{ Root = $cand; Mode = 'Candidate' } 0 @('CANDIDATE VALIDATION PASS') @('ADOPTION PASS')

# R3-T2 full Adoption without a contract must be refused, not downgraded
Run3 'R3-T2' @{ Root = (Join-Path $u1 'toolkit\long-running'); Mode = 'Adoption'; InstanceRoot = (Join-Path $u1 'planning') } 2 @('requires -GoalContract') @('ADOPTION PASS')

# R3-T3 full Adoption with a valid contract and a consistent root
Run3 'R3-T3' @{ Root = (Join-Path $u1 'toolkit\long-running'); Mode = 'Adoption'; InstanceRoot = (Join-Path $u1 'planning'); GoalContract = (Join-Path $u1 'planning\GOAL.md') } 0 @('ADOPTION PASS', 'instance-root consistency: PASS') @('CONTRACT NOT CHECKED')

# R3-T4 contract named but not readable
Run3 'R3-T4' @{ Root = (Join-Path $u1 'toolkit\long-running'); Mode = 'Adoption'; InstanceRoot = (Join-Path $u1 'planning'); GoalContract = (Join-Path $u1 'planning\NOPE.md') } 1 @('does not exist') @('ADOPTION PASS')

# R3-T5 declaration still UNFILLED
Run3 'R3-T5' @{ Root = (Join-Path $u4 'toolkit\long-running'); Mode = 'Adoption'; InstanceRoot = (Join-Path $u4 'planning'); GoalContract = (Join-Path $u4 'planning\GOAL.md') } 1 @('is not recorded') @('ADOPTION PASS')

# R3-T6 declaration and inspected path conflict
Run3 'R3-T6' @{ Root = (Join-Path $u3 'toolkit\long-running'); Mode = 'Adoption'; InstanceRoot = (Join-Path $u3 'docs\long-running'); GoalContract = (Join-Path $u3 'planning\GOAL.md') } 1 @('instance-root conflict') @('ADOPTION PASS')

# R3-T7 equivalent Windows spellings must not be a conflict
Run3 'R3-T7' @{ Root = (Join-Path $u2 'toolkit\long-running'); Mode = 'Adoption'; InstanceRoot = (Join-Path $u2 'planning'); GoalContract = (Join-Path $u2 'planning\GOAL.md') } 0 @('ADOPTION PASS') @('conflict')

# R3-T8 hygiene-only vocabulary: green, and it must NOT make an adoption claim.
# The output legitimately contains the phrase "NOT an ADOPTION PASS" as a disclaimer, so the
# assertion targets the claim itself rather than the bare words.
Run3 'R3-T8' @{ Root = (Join-Path $u5 'toolkit\long-running'); Mode = 'Hygiene'; InstanceRoot = (Join-Path $u5 'docs\long-running') } 0 @('HYGIENE PASS', 'CONTRACT NOT CHECKED') @('ADOPTION PASS (contract-verified)', 'instance-root consistency: PASS')

# R3-T9 readiness without a contract is refused; consistency is never assumed
Run3 'R3-T9' @{ Root = (Join-Path $u1 'toolkit\long-running'); Mode = 'Readiness'; InstanceRoot = (Join-Path $u1 'planning') } 2 @('requires -GoalContract') @('READY')

# R3-T10 readiness with a contract but open human gates
Run3 'R3-T10' @{ Root = (Join-Path $u1 'toolkit\long-running'); Mode = 'Readiness'; InstanceRoot = (Join-Path $u1 'planning'); GoalContract = (Join-Path $u1 'planning\GOAL.md') } 3 @('NOT READY PENDING HUMAN GATE') @('READY FOR THE HUMAN GOAL-ARMING DECISION')

# R3-T11 the earlier discrimination cases still discriminate (delegated to the harness; here we
# assert the two vocabulary-level regressions that rc.3 could have broken)
Run3 'R3-T11a' @{ Root = (Join-Path $u1 'toolkit\long-running'); Mode = 'Hygiene'; InstanceRoot = (Join-Path $u1 'nowhere') } 1 @('V12') @('HYGIENE PASS')
Run3 'R3-T11b' @{ Root = (Join-Path $u1 'toolkit\long-running'); Mode = 'Hygiene'; InstanceRoot = (Join-Path $u1 'toolkit\long-running\templates') } 1 @('reusable toolkit') @('HYGIENE PASS')

# R3-T12 the candidate's eight files are byte-stable across the whole matrix.
# $digestBefore was captured before the first case ran; $digestAfter is read now. The assertion
# is about what the tests DID, not about what the rc.3 revision intentionally changed. (The rc.3
# freeze digests are recorded separately in RC3-CHANGE-REPORT.md section G.)
$script:total++
$drift = @()
foreach ($rel in $digestBefore.Keys) {
    $now = (Get-FileHash -LiteralPath (Join-Path $cand ($rel -replace '/', '\')) -Algorithm SHA256).Hash
    if ($now -ne $digestBefore[$rel]) { $drift += $rel }
}
if ($drift.Count -eq 0) {
    $script:passed++
    Write-Output '  R3-T12     OK      the candidate eight files were not mutated by any case'
} else {
    Write-Output ("  R3-T12     FAIL    changed during the run: " + ($drift -join ', '))
}

Write-Output ''
Write-Output ("R3 matrix: {0}/{1} as expected" -f $script:passed, $script:total)
if ($script:passed -eq $script:total) { return 0 }
return 1

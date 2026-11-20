#requires -Version 5.1
<#
  check.ps1 - Long-running Toolkit v0.1 mechanical evaluator (Evaluator v0)

  PURPOSE
    Read-only, artifact-based acceptance check for the pilot deliverable
    (the "Long-running Toolkit v0.1" produced inside the pilot workspace).

  WHAT IT DELIBERATELY DOES NOT DO
    - It never reads, trusts, or looks for a model-declared "COMPLETE" claim.
    - It never modifies anything: no write cmdlet appears in this file.
    - It cannot judge whether the methodology is GOOD. It only proves the
      deliverable is structurally complete and internally referentially sound.
      Quality is a HUMAN REVIEW decision (see PILOT-SPEC-v0.1.md S4).

  EXIT CODES
    0 = PASS   (no failure reasons)
    1 = FAIL   (one or more concrete reasons printed)
    2 = ERROR  (bad invocation / unreadable root)

  USAGE
    pwsh -File check.ps1 -Root <path-to-toolkit-root>
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Root,

    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$script:Reasons = New-Object 'System.Collections.Generic.List[string]'

function Add-Failure([string]$reason) {
    $script:Reasons.Add($reason)
}

function Get-Text([string]$path) {
    # Read as UTF-8 without letting a BOM corrupt the first heading match.
    $raw = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    return ($raw -replace "^\uFEFF", "")
}

function Test-Contains([string]$text, [string]$needle) {
    return $text.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Assert-File {
    param(
        [string]$Relative,
        [int]$MinBytes,
        [string[]]$Headings,
        [string[]]$Fields
    )
    $full = Join-Path $Root $Relative
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        Add-Failure "missing artifact: $Relative"
        return $null
    }
    $item = Get-Item -LiteralPath $full
    if ($item.Length -lt $MinBytes) {
        Add-Failure "artifact too small: $Relative is $($item.Length) bytes, expected >= $MinBytes"
    }
    $text = Get-Text $full

    foreach ($h in $Headings) {
        if (-not (Test-Contains $text $h)) {
            Add-Failure "missing required section in ${Relative}: '$h'"
        }
    }
    foreach ($f in $Fields) {
        if (-not (Test-Contains $text $f)) {
            Add-Failure "missing required field in ${Relative}: '$f'"
        }
    }

    foreach ($marker in @('TODO', 'TBD', 'FIXME', 'XXX')) {
        if (Test-Contains $text $marker) {
            Add-Failure "unfinished placeholder '$marker' left in $Relative"
        }
    }
    # Angle-bracket placeholders left inside a required field value.
    foreach ($f in $Fields) {
        $idx = $text.IndexOf($f, [System.StringComparison]::OrdinalIgnoreCase)
        if ($idx -ge 0) {
            $lineEnd = $text.IndexOf("`n", $idx)
            if ($lineEnd -lt 0) { $lineEnd = $text.Length }
            $line = $text.Substring($idx, $lineEnd - $idx)
            if ($line -match '<[^>]{2,}>') {
                Add-Failure "unfilled angle-bracket placeholder in ${Relative}: $($line.Trim())"
            }
        }
    }
    return $text
}

# ---------------------------------------------------------------- invocation
if ([string]::IsNullOrWhiteSpace($Root)) {
    Write-Host "ERROR: -Root is required"
    exit 2
}
if (-not (Test-Path -LiteralPath $Root)) {
    Write-Host "ERROR: root does not exist: $Root"
    exit 2
}
if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    Write-Host "ERROR: root is not a directory: $Root"
    exit 2
}
$Root = (Resolve-Path -LiteralPath $Root).ProviderPath

# ------------------------------------------------------- C1 artifact presence
$readme     = Assert-File -Relative 'README.md'               -MinBytes 300 -Headings @('## What this is', '## How to use it in a new project', '## Compatibility') -Fields @()
$skill      = Assert-File -Relative 'SKILL.md'                -MinBytes 400 -Headings @('## When to use', '## Contracts', '## Round loop', '## Stop and escalate') -Fields @()
$methodology = Assert-File -Relative 'METHODOLOGY.md'         -MinBytes 800 -Headings @('## 1 Objective', '## 2 Plan', '## 3 State', '## 4 Evaluation', '## 5 Budget', '## 6 Stop', '## 7 Recovery', '## 8 Knowledge deposition') -Fields @()
$goalTpl    = Assert-File -Relative 'templates/GOAL.md'       -MinBytes 120 -Headings @() -Fields @('Objective:', 'Success criteria:', 'Scope boundaries:', 'Non-goals:', 'Evidence requirements:', 'Budget:', 'Stop conditions:', 'Human escalation:')
$stateTpl   = Assert-File -Relative 'templates/STATE.md'      -MinBytes 120 -Headings @() -Fields @('Round:', 'Completed:', 'Verified facts:', 'Open questions:', 'Next step:', 'Artifacts:', 'Evidence:', 'Budget used:')
$evalTpl    = Assert-File -Relative 'templates/EVALUATION.md' -MinBytes 120 -Headings @() -Fields @('Machine checks:', 'Evidence quality:', 'Human review:')

# ------------------------------------------------- C2 evidence-grade vocabulary
if ($methodology -ne $null) {
    foreach ($grade in @('FACT', 'INFERENCE', 'UNKNOWN')) {
        if (-not (Test-Contains $methodology $grade)) {
            Add-Failure "METHODOLOGY.md must define the evidence grade '$grade'"
        }
    }
    # S4 must separate the three acceptance layers.
    foreach ($layer in @('Machine', 'Evidence', 'Human')) {
        if (-not (Test-Contains $methodology $layer)) {
            Add-Failure "METHODOLOGY.md evaluation contract must name the '$layer' acceptance layer"
        }
    }
}

# --------------------------------------------- C3 internal reference soundness
# Any `templates/<name>.md` mentioned in SKILL/METHODOLOGY must exist on disk.
$refPattern = 'templates/[A-Za-z0-9_.\-]+\.md'
foreach ($pair in @(@('SKILL.md', $skill), @('METHODOLOGY.md', $methodology))) {
    $rel = $pair[0]
    $text = $pair[1]
    if ($text -eq $null) { continue }
    $seen = @{}
    foreach ($m in [regex]::Matches($text, $refPattern)) {
        $ref = $m.Value
        if ($seen.ContainsKey($ref)) { continue }
        $seen[$ref] = $true
        if (-not (Test-Path -LiteralPath (Join-Path $Root $ref) -PathType Leaf)) {
            Add-Failure "broken reference in ${rel}: '$ref' does not exist under the toolkit root"
        }
    }
}

# --------------------------------------------------------- C4 budget hard/soft
if ($methodology -ne $null) {
    if (-not (Test-Contains $methodology 'maxGoalRounds')) {
        Add-Failure "METHODOLOGY.md budget contract must mention the enforced 'maxGoalRounds'"
    }
    if (-not (Test-Contains $methodology 'SOFT')) {
        Add-Failure "METHODOLOGY.md budget contract must mark unenforced budgets as 'SOFT'"
    }
}

# ------------------------------------------------ C5 portability (no local coupling)
# The toolkit must be copyable into another project root. A machine-specific
# absolute path or a pilot-specific identifier makes it non-portable.
$portable = @(
    @('README.md', $readme),
    @('SKILL.md', $skill),
    @('METHODOLOGY.md', $methodology),
    @('templates/GOAL.md', $goalTpl),
    @('templates/STATE.md', $stateTpl),
    @('templates/EVALUATION.md', $evalTpl)
)
$absolutePath = '(?<![A-Za-z0-9])[A-Za-z]:[\\/]'
$localTokens = @('dsh-longloop-pilot', 'dsh-test', 'Personal Job Search OS', 'user02')
foreach ($pair in $portable) {
    $rel = $pair[0]
    $text = $pair[1]
    if ($text -eq $null) { continue }
    foreach ($m in [regex]::Matches($text, $absolutePath)) {
        Add-Failure "non-portable absolute path '$($m.Value)' found in $rel"
    }
    foreach ($tok in $localTokens) {
        if (Test-Contains $text $tok) {
            Add-Failure "non-portable local identifier '$tok' found in $rel"
        }
    }
}

# ------------------------------------------------- C6 version awareness (recorded)
if ($readme -ne $null) {
    if (-not (Test-Contains $readme '0.2.0')) {
        Add-Failure "README.md compatibility section must record the verified DSH version (expected '0.2.0...')"
    }
    foreach ($pkg in @('@deepseek-ai/dsh-goal', '@deepseek-ai/dsh-plan-mode')) {
        if (-not (Test-Contains $readme $pkg)) {
            Add-Failure "README.md compatibility section must name the official package '$pkg'"
        }
    }
    # C7 re-confirmation duty in the target environment.
    if (-not ((Test-Contains $readme 're-confirm') -or (Test-Contains $readme 'reconfirm'))) {
        Add-Failure "README.md must instruct the reader to re-confirm the mechanism contract in the target environment"
    }
}
if ($methodology -ne $null) {
    if (-not (Test-Contains $methodology '@deepseek-ai/dsh-goal-round-driver')) {
        Add-Failure "METHODOLOGY.md must name the official continuation package '@deepseek-ai/dsh-goal-round-driver'"
    }
}

# ---------------------------------------------------------------------- report
Write-Host ""
Write-Host "check.ps1 - Long-running Toolkit v0.1 evaluator"
Write-Host "root: $Root"
Write-Host ""

if ($script:Reasons.Count -eq 0) {
    Write-Host "PASS"
    Write-Host "  all structural, field, vocabulary and reference checks satisfied."
    Write-Host "  NOTE: this says nothing about methodology quality - human review required."
    exit 0
}

Write-Host "FAIL"
foreach ($r in $script:Reasons) {
    Write-Host "  - $r"
}
Write-Host ""
Write-Host "failure reasons: $($script:Reasons.Count)"
exit 1

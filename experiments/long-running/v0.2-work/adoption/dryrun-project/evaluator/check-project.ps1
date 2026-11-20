#requires -Version 5.1
<#
  check-project.ps1 - project-level mechanical evaluator for the adoption dry-run

  This is the ADOPTER's evaluator, not the toolkit's. It exists to show that the toolkit's
  step 8 (author, test and freeze your own evaluator) is actually reachable by a project
  that has never done it before.

  It checks, read-only:
    P1  the portable toolkit copy is complete: exactly 8 Markdown files, the 8 expected names
    P2  the portable toolkit copy is byte-identical to the candidate it was copied from
        (no in-place editing of a copied toolkit)
    P3  the project's filled instances exist and carry no blank-form marker
    P4  the onboarding guide exists and carries its required sections

  EXIT CODES
    0 = PASS
    1 = FAIL (reasons printed)
    2 = ERROR (bad invocation or missing project)

  Frozen before any goal exists. It must never be edited to make a check pass.
#>

[CmdletBinding()]
param(
    [string]$Project
)

Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

function Invoke-ProjectCheck {
    param([string]$Project)

    $reasons = New-Object 'System.Collections.Generic.List[string]'

    if ([string]::IsNullOrWhiteSpace($Project)) {
        Write-Host 'ERROR: -Project is required'
        return 2
    }
    if (-not (Test-Path -LiteralPath $Project -PathType Container)) {
        Write-Host "ERROR: project root does not exist: $Project"
        return 2
    }
    $root = (Resolve-Path -LiteralPath $Project).ProviderPath

    $expected = @('README.md', 'SKILL.md', 'METHODOLOGY.md', 'templates/GOAL.md',
                  'templates/PLAN.md', 'templates/STATE.md', 'templates/EVALUATION.md',
                  'templates/FINAL-REPORT.md')

    # ---- P1 the portable copy is complete
    $toolkitRoot = Join-Path $root 'toolkit\long-running'
    if (-not (Test-Path -LiteralPath $toolkitRoot -PathType Container)) {
        $reasons.Add('P1 the portable toolkit copy is missing at toolkit/long-running/')
    } else {
        $found = @()
        foreach ($f in (Get-ChildItem -LiteralPath $toolkitRoot -Recurse -File -Filter '*.md')) {
            $found += ($f.FullName.Substring($toolkitRoot.Length).TrimStart('\', '/') -replace '\\', '/')
        }
        if ($found.Count -ne 8) {
            $reasons.Add("P1 expected 8 toolkit files, found $($found.Count)")
        }
        foreach ($e in $expected) {
            if ($found -notcontains $e) { $reasons.Add("P1 toolkit file missing: $e") }
        }
        $nonMd = @(Get-ChildItem -LiteralPath $toolkitRoot -Recurse -File | Where-Object { $_.Extension -ne '.md' })
        if ($nonMd.Count -gt 0) {
            $reasons.Add("P1 unexpected non-Markdown file in the toolkit copy: $($nonMd[0].Name)")
        }
    }

    # ---- P2 the copy was not edited after copying
    if (-not [string]::IsNullOrWhiteSpace($env:DRYRUN_CANDIDATE_ROOT)) {
        $candRoot = $env:DRYRUN_CANDIDATE_ROOT
        if (Test-Path -LiteralPath $candRoot -PathType Container) {
            foreach ($e in $expected) {
                $src = Join-Path $candRoot $e
                $dst = Join-Path $toolkitRoot $e
                if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { continue }
                if (-not (Test-Path -LiteralPath $dst -PathType Leaf)) { continue }
                $h1 = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
                $h2 = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash
                if ($h1 -ne $h2) {
                    $reasons.Add("P2 the copied toolkit file was edited in place: $e")
                }
            }
        } else {
            $reasons.Add("P2 the candidate root named by DRYRUN_CANDIDATE_ROOT does not exist")
        }
    } else {
        $reasons.Add('P2 no candidate root supplied; run with DRYRUN_CANDIDATE_ROOT set so the copy can be compared')
    }

    # ---- P3 the project's filled instances exist and are filled
    foreach ($doc in @('docs\long-running\GOAL.md', 'docs\long-running\PLAN.md', 'docs\long-running\STATE.md')) {
        $full = Join-Path $root $doc
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            $reasons.Add("P3 missing project document: $doc")
            continue
        }
        $text = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
        if ($text.IndexOf('UNFILLED', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $reasons.Add("P3 project document is still a blank form: $doc")
        }
    }

    # ---- P4 the deliverable and its sections
    $guide = Join-Path $root 'docs\onboarding\GUIDE.md'
    if (-not (Test-Path -LiteralPath $guide -PathType Leaf)) {
        $reasons.Add('P4 the onboarding guide does not exist yet: docs/onboarding/GUIDE.md')
    } else {
        $text = [System.IO.File]::ReadAllText($guide, [System.Text.Encoding]::UTF8)
        foreach ($section in @('## Purpose', '## Prerequisites', '## Walkthrough', '## Verification', '## Rollback')) {
            if ($text.IndexOf($section, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
                $reasons.Add("P4 guide is missing the required section: $section")
            }
        }
    }

    Write-Host ''
    Write-Host 'check-project.ps1 - adoption dry-run project evaluator'
    Write-Host "project: $root"
    Write-Host ''
    if ($reasons.Count -eq 0) {
        Write-Host 'PASS'
        Write-Host '  portable copy intact, filled instances carry no blank-form marker, guide complete.'
        Write-Host '  NOTE: this proves structure only; usability is a human judgement.'
        return 0
    }
    Write-Host 'FAIL'
    foreach ($r in $reasons) { Write-Host "  - $r" }
    Write-Host ''
    Write-Host "failure reasons: $($reasons.Count)"
    return 1
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-ProjectCheck -Project $Project)
}

#requires -Version 5.1
# Minimal project evaluator used by the rc.3 scenarios (synthetic).
[CmdletBinding()]
param([string]$Project)
Set-StrictMode -Off
$ErrorActionPreference = 'Stop'
function Invoke-ProjectCheck {
    param([string]$Project)
    if ([string]::IsNullOrWhiteSpace($Project)) { Write-Host 'ERROR: -Project is required'; return 2 }
    if (-not (Test-Path -LiteralPath $Project -PathType Container)) { Write-Host "ERROR: project root does not exist: $Project"; return 2 }
    $root = (Resolve-Path -LiteralPath $Project).ProviderPath
    $reasons = New-Object 'System.Collections.Generic.List[string]'
    foreach ($rel in @('toolkit\long-running\README.md','toolkit\long-running\SKILL.md','toolkit\long-running\METHODOLOGY.md')) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $rel) -PathType Leaf)) { $reasons.Add("missing $rel") }
    }
    if ($reasons.Count -eq 0) { Write-Host 'PASS'; return 0 }
    Write-Host 'FAIL'
    foreach ($r in $reasons) { Write-Host "  - $r" }
    return 1
}
if ($MyInvocation.InvocationName -ne '.') { exit (Invoke-ProjectCheck -Project $Project) }
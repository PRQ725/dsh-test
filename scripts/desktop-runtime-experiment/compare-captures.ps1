<#
.SYNOPSIS
  Script D - compare two capture directories produced by Script A / Script B.

.DESCRIPTION
  READ-ONLY. Reads only the CSV manifests written by the capture scripts.
  Never touches $DSH_HOME.

  Compares:
    shared-state-manifest.csv      (Script B)   -> authoritative for shared state
    dsh-home-fingerprints.csv      (Script A)   -> supplementary
    session-inventory.csv          (Script B)   -> session-level changes
    projcache-inventory.csv        (Script B)   -> projcache changes

  Classifies each differing file as:
    ADDED / DELETED / CONTENT-CHANGED / MTIME-ONLY

.PARAMETER Before
  Capture directory taken earlier (e.g. the "pre" capture).

.PARAMETER After
  Capture directory taken later (e.g. the "post" capture).

.PARAMETER OutDir
  Where to write compare-report.txt / compare-detail.csv.

.EXAMPLE
  .\compare-captures.ps1 -Before D:\...\e1-pre -After D:\...\e1-post -OutDir D:\...\e1-compare
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Before,
  [Parameter(Mandatory=$true)][string]$After,
  [Parameter(Mandatory=$true)][string]$OutDir
)

$ErrorActionPreference = 'Continue'
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$script:problems = 0
function Note($m) { Write-Host $m }
function Flag($m) { Write-Host "  [!] $m" -ForegroundColor Yellow; $script:problems++ }

$script:report = New-Object System.Collections.Generic.List[string]
# NOTE: do NOT name this function "R" - "r" is a built-in alias for Invoke-History and
#       alias resolution wins over function resolution in PowerShell.
function Write-ReportLine($m) { $script:report.Add([string]$m) | Out-Null; Write-Host $m }

Write-ReportLine "=== SCRIPT D: compare captures ==="
Write-ReportLine "Before = $Before"
Write-ReportLine "After  = $After"
Write-ReportLine "Time   = $stamp"
Write-ReportLine ""

function Load-Manifest {
  param([string]$Dir, [string]$Name)
  $p = Join-Path $Dir $Name
  if (-not (Test-Path $p)) { return $null }
  return @(Import-Csv -LiteralPath $p)
}

# ------------------------------------------------------------------ main diff
function Compare-Manifest {
  param([string]$Title, [string]$FileName)

  Write-ReportLine "--------------------------------------------------------------------"
  Write-ReportLine "SECTION: $Title   ($FileName)"
  Write-ReportLine "--------------------------------------------------------------------"
  $b = Load-Manifest -Dir $Before -Name $FileName
  $a = Load-Manifest -Dir $After  -Name $FileName
  if ($null -eq $b -or $null -eq $a) {
    Flag "manifest missing (before=$($null -ne $b), after=$($null -ne $a)) -> section skipped"
    Write-ReportLine "  SKIPPED (manifest not found in one of the captures)"
    Write-ReportLine ""
    return
  }

  $bMap = @{}; foreach ($r in $b) { $bMap[[string]$r.Rel] = $r }
  $aMap = @{}; foreach ($r in $a) { $aMap[[string]$r.Rel] = $r }

  $added   = @($aMap.Keys | Where-Object { -not $bMap.ContainsKey($_) } | Sort-Object)
  $deleted = @($bMap.Keys | Where-Object { -not $aMap.ContainsKey($_) } | Sort-Object)
  $common  = @($aMap.Keys | Where-Object { $bMap.ContainsKey($_) })

  $contentChg = New-Object System.Collections.Generic.List[object]
  $mtimeOnly  = New-Object System.Collections.Generic.List[object]
  foreach ($k in $common) {
    $x = $bMap[$k]; $y = $aMap[$k]
    $bs = [string]$x.Size; $as = [string]$y.Size
    $bh = [string]$x.Sha256; $ah = [string]$y.Sha256
    $bu = [string]$x.Utc; $au = [string]$y.Utc
    if ($bs -eq 'ABSENT' -and $as -eq 'ABSENT') { continue }
    if ($bh -ne $ah -or $bs -ne $as) {
      $contentChg.Add([PSCustomObject]@{ Rel=$k; BeforeSize=$bs; AfterSize=$as; BeforeHash=$bh; AfterHash=$ah; Class='CONTENT-CHANGED' })
    } elseif ($bu -ne $au) {
      $mtimeOnly.Add([PSCustomObject]@{ Rel=$k; BeforeSize=$bs; AfterSize=$as; BeforeHash=$bh; AfterHash=$ah; Class='MTIME-ONLY' })
    }
  }

  Write-ReportLine ("  total tracked   : {0}" -f $aMap.Keys.Count)
  Write-ReportLine ("  ADDED           : {0}" -f $added.Count)
  Write-ReportLine ("  DELETED         : {0}" -f $deleted.Count)
  Write-ReportLine ("  CONTENT-CHANGED : {0}" -f $contentChg.Count)
  Write-ReportLine ("  MTIME-ONLY      : {0}" -f $mtimeOnly.Count)
  Write-ReportLine ""
  if ($added.Count)   { Write-ReportLine "  --- ADDED ---";   $added   | ForEach-Object { Write-ReportLine ("    {0}" -f $_) } ; Write-ReportLine "" }
  if ($deleted.Count) { Write-ReportLine "  --- DELETED ---"; $deleted | ForEach-Object { Write-ReportLine ("    {0}" -f $_) } ; Write-ReportLine "" }
  if ($contentChg.Count) {
    Write-ReportLine "  --- CONTENT-CHANGED ---"
    foreach ($c in $contentChg) {
      Write-ReportLine ("    {0}" -f $c.Rel)
      Write-ReportLine ("        size {0} -> {1}" -f $c.BeforeSize, $c.AfterSize)
      Write-ReportLine ("        hash {0}" -f $c.BeforeHash)
      Write-ReportLine ("          -> {0}" -f $c.AfterHash)
    }
    Write-ReportLine ""
  }
  if ($mtimeOnly.Count) {
    Write-ReportLine "  --- MTIME-ONLY (content identical) ---"
    foreach ($c in $mtimeOnly) { Write-ReportLine ("    {0}" -f $c.Rel) }
    Write-ReportLine ""
  }

  # emit detail rows
  $detail = New-Object System.Collections.Generic.List[object]
  foreach ($k in $added)   { $detail.Add([PSCustomObject]@{Section=$Title;Class='ADDED';Rel=$k;BeforeSize='';AfterSize=$aMap[$k].Size;BeforeHash='';AfterHash=$aMap[$k].Sha256}) }
  foreach ($k in $deleted) { $detail.Add([PSCustomObject]@{Section=$Title;Class='DELETED';Rel=$k;BeforeSize=$bMap[$k].Size;AfterSize='';BeforeHash=$bMap[$k].Sha256;AfterHash=''}) }
  foreach ($c in $contentChg) { $detail.Add([PSCustomObject]@{Section=$Title;Class='CONTENT-CHANGED';Rel=$c.Rel;BeforeSize=$c.BeforeSize;AfterSize=$c.AfterSize;BeforeHash=$c.BeforeHash;AfterHash=$c.AfterHash}) }
  foreach ($c in $mtimeOnly)  { $detail.Add([PSCustomObject]@{Section=$Title;Class='MTIME-ONLY';Rel=$c.Rel;BeforeSize=$c.BeforeSize;AfterSize=$c.AfterSize;BeforeHash=$c.BeforeHash;AfterHash=$c.AfterHash}) }
  return $detail
}

$all = New-Object System.Collections.Generic.List[object]
foreach ($pair in @(
  @('SHARED STATE','shared-state-manifest.csv'),
  @('DSH_HOME FINGERPRINTS (script A)','dsh-home-fingerprints.csv'),
  @('SESSION INVENTORY','session-inventory.csv'),
  @('PROJCACHE INVENTORY','projcache-inventory.csv')
)) {
  $d = Compare-Manifest -Title $pair[0] -FileName $pair[1]
  if ($d) { foreach ($x in $d) { $all.Add($x) } }
}

# ------------------------------------------------------------------ sessions summary delta
Write-ReportLine "--------------------------------------------------------------------"
Write-ReportLine "SECTION: SESSION FORMAT SUMMARY (informational)"
Write-ReportLine "--------------------------------------------------------------------"
foreach ($side in @(@('BEFORE',$Before), @('AFTER',$After))) {
  $p = Join-Path $side[1] 'session-inventory.csv'
  if (Test-Path $p) {
    $rows = @(Import-Csv -LiteralPath $p)
    $g = $rows | Group-Object Format | Sort-Object Name
    Write-ReportLine ("  {0,-7} total={1,-5} {2}" -f $side[0], $rows.Count, (($g | ForEach-Object { $_.Name + '=' + $_.Count }) -join ' '))
  } else { Write-ReportLine ("  {0,-7} (no session-inventory.csv)" -f $side[0]) }
}
Write-ReportLine ""

$all | Export-Csv -LiteralPath (Join-Path $OutDir 'compare-detail.csv') -NoTypeInformation -Encoding UTF8
$script:report.Add("")
$script:report.Add("warnings: $script:problems")
$script:report | Set-Content -LiteralPath (Join-Path $OutDir 'compare-report.txt') -Encoding UTF8
Write-Host ("  report lines written = {0}" -f $script:report.Count)

Write-ReportLine "=== SCRIPT D DONE (warnings: $script:problems) ==="

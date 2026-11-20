<#
.SYNOPSIS
  Shared fail-closed capture guard used by every *-capture.ps1 wrapper.

.DESCRIPTION
  Dot-source this file:

      . (Join-Path $PSScriptRoot 'capture-guard.ps1')

  It exists because of a real FALSE PASS. The previous quiescent wrapper did:

      & capture-desktop-runtime.ps1 -OutDir $CAP1 ... *> "$CAP1\_log-A.txt"

  $CAP1 did not exist yet, so PowerShell failed to OPEN THE REDIRECTION TARGET
  before the child ran; the child never executed; the wrapper printed
  "[PASS] capture written" unconditionally; the compare step found no manifests
  and treated "no data" as "no change"; the final verdict printed PASS.

  The guard makes every one of those steps fail-closed:
    * the destination directory is created BEFORE any redirection
    * a child that throws or does not run is reported
    * sentinel artifacts must exist AND be non-empty
    * sanity minimums (0 sessions / 0 shared-state rows) are FATAL
    * a diff that skipped sections is INVALID, never "clean"

  Nothing here writes to $DSH_HOME.
#>

# Sentinel artifacts each child script MUST produce, non-empty.
$script:CaptureSentinels = @{
  'A' = @{
    Script = 'capture-desktop-runtime.ps1'
    Files  = @('processes.csv','listeners.csv','dsh-home-fingerprints.csv','desktop-app-fingerprints.csv','summary.txt')
  }
  'B' = @{
    Script = 'capture-shared-state.ps1'
    Files  = @('shared-state-manifest.csv','session-inventory.csv','projcache-inventory.csv','dir-metadata.csv','presence-flags.json','shared-state-summary.txt')
  }
  'C' = @{
    Script = 'detect-runtime-test-session.ps1'
    Files  = @('runtime-test-session.json','runtime-test-session.txt')
  }
}

<#
.SYNOPSIS
  PIDs of THIS process and all of its ancestors.

.DESCRIPTION
  Host detection matches on command lines. A research command that merely CONTAINS a
  detection pattern (for example because it inspects or prints 'dsh-desktop-host') would
  otherwise match ITSELF and be reported as a running Desktop/CLI host. That produces a
  false STOP, or worse, trains the operator to ignore the gate.

  Every host query must therefore exclude this process tree.
#>
$script:SelfPids = @()
function Get-SelfProcessIds {
  if (@($script:SelfPids).Count -gt 0) { return $script:SelfPids }
  $ids = New-Object System.Collections.Generic.List[int]
  $cur = $PID
  $hops = 0
  while ($cur -and $hops -lt 24) {
    $ids.Add([int]$cur) | Out-Null
    $p = Get-CimInstance Win32_Process -Filter ("ProcessId = {0}" -f $cur) -ErrorAction SilentlyContinue
    if (-not $p) { break }
    $cur = [int]$p.ParentProcessId
    $hops++
  }
  $script:SelfPids = $ids.ToArray()
  return $script:SelfPids
}

<#
.SYNOPSIS
  True when a Win32_Process object belongs to this process tree (never a host).
#>
function Test-IsSelfProcess {
  param($Proc)
  if ($null -eq $Proc) { return $true }
  return ((Get-SelfProcessIds) -contains [int]$Proc.ProcessId)
}

<#
.SYNOPSIS
  Processes matching one host class.
.PARAMETER Kind
  desktop = DeepSeek Harness shell / desktop host
  cli     = @deepseek-ai/dsh/lib/bin.js node host
  mcp     = playwright MCP server process(es)
  mcpchr  = MCP-dedicated Chrome
.PARAMETER ExcludeSelf
  Skip this process and its ancestors.

  Use it ONLY for probes that can match their own command text. The 'desktop' probe
  contains a CommandLine alternative, so a command line that merely CONTAINS the literal
  'dsh-desktop-host' - for example a research session inspecting the gate - would match
  itself and be reported as a running Desktop.

  Do NOT use it for the 'cli' probe. This process tree may ROOT at the very host being
  tested: when a research session runs the wrapper from its own shell, the DSH CLI host
  that serves that session is an ANCESTOR. Excluding ancestors would hide a running host,
  which is the dangerous direction - the gate must fail closed, so a false STOP is
  acceptable and a false PASS is not.

  Residual risk for 'cli': a caller whose own command line literally contains
  'dsh/lib/bin.js' would self-match. Always invoke the wrappers with -File (never an
  inline -Command that embeds that string).
#>
function Get-HostProcesses {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][ValidateSet('desktop','cli','mcp','mcpchr')][string]$Kind,
    [switch]$ExcludeSelf
  )

  $all = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
  if ($ExcludeSelf) {
    $self = Get-SelfProcessIds
    $all  = @($all | Where-Object { $self -notcontains [int]$_.ProcessId })
  }

  switch ($Kind) {
    # Desktop: match by NAME, or by the desktop-host probe with self-ancestors removed.
    'desktop' {
      $self = Get-SelfProcessIds
      return @($all | Where-Object {
        $_.Name -match '(?i)DeepSeek Harness' -or
        ($self -notcontains [int]$_.ProcessId -and $_.CommandLine -match 'dsh-desktop-host')
      })
    }
    'cli'     { return @($all | Where-Object { $_.Name -eq 'node.exe' -and $_.CommandLine -match 'dsh[\\/]lib[\\/]bin\.js' }) }
    'mcp'     { return @($all | Where-Object { $_.CommandLine -match '@playwright/mcp|playwright\\mcp\\cli\.js' }) }
    'mcpchr'  { return @($all | Where-Object { $_.Name -match '^(chrome|chromium)\.exe$' -and $_.CommandLine -match 'ms-playwright|mcp-chrome|remote-debugging-pipe' }) }
  }
  return @()
}

<#
.SYNOPSIS
  Run one child capture script fail-closed.
.OUTPUTS
  PSCustomObject{ Name; Ok; Errors(string[]); Log }
#>
function Invoke-GuardedCapture {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][ValidateSet('A','B','C')][string]$Name,
    [Parameter(Mandatory=$true)][string]$ToolsDir,
    [Parameter(Mandatory=$true)][string]$OutDir,
    [hashtable]$ChildArgs = @{}
  )

  $errors = New-Object System.Collections.Generic.List[string]
  $spec   = $script:CaptureSentinels[$Name]
  $child  = Join-Path $ToolsDir $spec.Script

  # --- 0. the child must exist BEFORE anything is created (no litter on a bad call) ---
  if (-not (Test-Path -LiteralPath $child -PathType Leaf)) {
    return [PSCustomObject]@{ Name=$Name; Ok=$false; Errors=@("child script not found: $child"); Log='' }
  }

  # --- 1. the destination MUST exist before the redirection is established ---
  try {
    if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force -ErrorAction Stop | Out-Null }
  } catch {
    return [PSCustomObject]@{ Name=$Name; Ok=$false; Errors=@("cannot create OutDir ${OutDir}: $($_.Exception.Message)"); Log='' }
  }

  $log = Join-Path $OutDir ("_log-" + $Name + ".txt")

  $splat = @{}
  foreach ($k in $ChildArgs.Keys) { $splat[$k] = $ChildArgs[$k] }
  $splat['OutDir'] = $OutDir

  # --- 2. invoke with a LOCAL Stop preference so a redirection failure throws ---
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = 'Stop'
  $cmdOk = $false
  try {
    & $child @splat *> $log
    $cmdOk = $true
  } catch {
    $errors.Add("child '$($spec.Script)' threw: $($_.Exception.Message)")
  } finally {
    $ErrorActionPreference = $prevEAP
  }
  if (-not $cmdOk) { return [PSCustomObject]@{ Name=$Name; Ok=$false; Errors=$errors.ToArray(); Log=$log } }

  # --- 3. the log itself must exist (proves the redirection actually worked) ---
  if (-not (Test-Path -LiteralPath $log -PathType Leaf)) {
    $errors.Add("redirection log was not created: $log  (the child did NOT run)")
  }

  # --- 4. sentinel artifacts must exist AND be non-empty ---
  foreach ($f in $spec.Files) {
    $p = Join-Path $OutDir $f
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { $errors.Add("missing sentinel: $f"); continue }
    try { if ((Get-Item -LiteralPath $p -ErrorAction Stop).Length -le 0) { $errors.Add("empty sentinel: $f") } }
    catch { $errors.Add("unreadable sentinel: $f") }
  }

  return [PSCustomObject]@{ Name=$Name; Ok=($errors.Count -eq 0); Errors=$errors.ToArray(); Log=$log }
}

<#
.SYNOPSIS
  Sanity minimums on a capture directory. 0 sessions / 0 tracked shared-state rows are FATAL.
.OUTPUTS
  PSCustomObject{ Ok; Fatal(string[]); Warn(string[]) }
#>
function Test-GuardedCaptureSanity {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$OutDir)

  $fatal = New-Object System.Collections.Generic.List[string]
  $warn  = New-Object System.Collections.Generic.List[string]

  $sess = Join-Path $OutDir 'session-inventory.csv'
  if (-not (Test-Path -LiteralPath $sess)) { $fatal.Add('session-inventory.csv missing') }
  else {
    $n = @(Import-Csv -LiteralPath $sess -ErrorAction SilentlyContinue).Count
    if ($n -le 0) { $fatal.Add('session-inventory.csv has 0 rows (a real $DSH_HOME always has sessions)') }
  }

  $shared = Join-Path $OutDir 'shared-state-manifest.csv'
  if (-not (Test-Path -LiteralPath $shared)) { $fatal.Add('shared-state-manifest.csv missing') }
  else {
    $n = @(Import-Csv -LiteralPath $shared -ErrorAction SilentlyContinue).Count
    if ($n -le 0) { $fatal.Add('shared-state-manifest.csv has 0 tracked rows') }
  }

  # NOTE: this variable is deliberately NOT named $home - $HOME is a read-only
  # automatic variable in Windows PowerShell and the assignment would silently fail.
  $homeFp = Join-Path $OutDir 'dsh-home-fingerprints.csv'
  if (-not (Test-Path -LiteralPath $homeFp)) { $fatal.Add('dsh-home-fingerprints.csv missing') }
  else {
    $n = @(Import-Csv -LiteralPath $homeFp -ErrorAction SilentlyContinue).Count
    if ($n -le 0) { $fatal.Add('dsh-home-fingerprints.csv has 0 rows') }
  }

  $pc = Join-Path $OutDir 'projcache-inventory.csv'
  if (-not (Test-Path -LiteralPath $pc)) { $warn.Add('projcache-inventory.csv missing') }
  else {
    $n = @(Import-Csv -LiteralPath $pc -ErrorAction SilentlyContinue).Count
    if ($n -le 0) { $warn.Add('projcache-inventory.csv has 0 rows') }
  }

  return [PSCustomObject]@{ Ok=($fatal.Count -eq 0); Fatal=$fatal.ToArray(); Warn=$warn.ToArray() }
}

<#
.SYNOPSIS
  The four capture classes every section of a compare report must report.
#>
$script:CompareClasses = @('ADDED','DELETED','CONTENT-CHANGED','MTIME-ONLY')

<#
.SYNOPSIS
  The sections a complete compare report must contain.
#>
$script:DefaultRequiredSections = @('SHARED STATE','DSH_HOME FINGERPRINTS','SESSION INVENTORY','PROJCACHE INVENTORY')

<#
.SYNOPSIS
  Read a text file whose encoding may be UTF-8 (with or without BOM), UTF-16LE or UTF-16BE.

.DESCRIPTION
  compare-report.txt is written with Set-Content -Encoding UTF8, while _log.txt is produced
  by a PowerShell stream redirection (*>) and comes out UTF-16LE. Both must be readable by
  the same validator, so the BOM is detected instead of assumed.
#>
function Read-TextAnyEncoding {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  $b = [System.IO.File]::ReadAllBytes($Path)
  if ($b.Length -ge 2 -and $b[0] -eq 0xFF -and $b[1] -eq 0xFE) { return [System.Text.Encoding]::Unicode.GetString($b, 2, $b.Length - 2) }
  if ($b.Length -ge 2 -and $b[0] -eq 0xFE -and $b[1] -eq 0xFF) { return [System.Text.Encoding]::BigEndianUnicode.GetString($b, 2, $b.Length - 2) }
  if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { return [System.Text.Encoding]::UTF8.GetString($b, 3, $b.Length - 3) }
  return [System.Text.Encoding]::UTF8.GetString($b)
}

<#
.SYNOPSIS
  Run compare-captures.ps1 fail-closed. Creates OutDir BEFORE the redirection, verifies the
  child actually ran, verifies the log, then validates the produced report/detail.
.OUTPUTS
  PSCustomObject{ Ok; Errors(string[]); Log; CompareDir; Rows; DetailRows; ExpectedDetailRows; Sections; Warnings }
#>
function Invoke-GuardedCompare {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$ToolsDir,
    [Parameter(Mandatory=$true)][string]$Before,
    [Parameter(Mandatory=$true)][string]$After,
    [Parameter(Mandatory=$true)][string]$OutDir,
    [string[]]$RequiredSections = $null
  )

  if (-not $RequiredSections) { $RequiredSections = $script:DefaultRequiredSections }
  $errors = New-Object System.Collections.Generic.List[string]
  $log  = Join-Path $OutDir '_log.txt'

  try {
    if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force -ErrorAction Stop | Out-Null }
  } catch {
    return [PSCustomObject]@{ Ok=$false; Errors=@("cannot create CompareDir ${OutDir}: $($_.Exception.Message)"); Log=''; CompareDir=$OutDir;
                              Rows=@(); DetailRows=-1; ExpectedDetailRows=-1; Sections=@(); Warnings=-1 }
  }

  foreach ($d in @($Before,$After)) {
    if (-not (Test-Path -LiteralPath $d -PathType Container)) { $errors.Add("input capture dir missing: $d") }
  }
  $child = Join-Path $ToolsDir 'compare-captures.ps1'
  if (-not (Test-Path -LiteralPath $child -PathType Leaf)) { $errors.Add("child script not found: $child") }
  if ($errors.Count -gt 0) {
    return [PSCustomObject]@{ Ok=$false; Errors=$errors.ToArray(); Log=''; CompareDir=$OutDir;
                              Rows=@(); DetailRows=-1; ExpectedDetailRows=-1; Sections=@(); Warnings=-1 }
  }

  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = 'Stop'
  $cmdOk = $false
  try {
    & $child -Before $Before -After $After -OutDir $OutDir *> $log
    $cmdOk = $true
  } catch {
    $errors.Add("compare-captures.ps1 threw: $($_.Exception.Message)")
  } finally {
    $ErrorActionPreference = $prevEAP
  }
  if (-not $cmdOk) {
    return [PSCustomObject]@{ Ok=$false; Errors=$errors.ToArray(); Log=$log; CompareDir=$OutDir;
                              Rows=@(); DetailRows=-1; ExpectedDetailRows=-1; Sections=@(); Warnings=-1 }
  }

  if (-not (Test-Path -LiteralPath $log -PathType Leaf)) {
    $errors.Add("redirection log was not created: $log  (compare-captures.ps1 did NOT run)")
  }

  $v = Test-GuardedCompareOutput -CompareDir $OutDir -RequiredSections $RequiredSections
  foreach ($e in $v.Errors) { $errors.Add($e) }

  return [PSCustomObject]@{ Ok=($errors.Count -eq 0); Errors=$errors.ToArray(); Log=$log; CompareDir=$OutDir;
                            Rows=$v.Rows; DetailRows=$v.DetailRows; ExpectedDetailRows=$v.ExpectedDetailRows;
                            Sections=$v.Sections; Warnings=$v.Warnings }
}

<#
.SYNOPSIS
  Validate a compare-captures.ps1 output directory.

.DESCRIPTION
  A diff is VALID when the compare actually ran to completion AND every section reported
  a complete set of counts AND the detail rows agree with those counts.

  AN EMPTY compare-detail.csv IS LEGAL. compare-detail.csv only records entries that
  CHANGED, so a genuinely identical pair of captures produces zero detail rows and
  Export-Csv writes a BOM-only file. Treating "empty detail" as "invalid diff" is a
  FALSE FAIL: it rejects exactly the outcome the quiescent-baseline capture is trying to
  prove. This was a real defect (see e1-BASE-QUIESCENT-R2-VALIDATOR-NOTE.md).

  The reliable consistency rule is:

      expectedDetailRows = SUM over all required sections of
                           (ADDED + DELETED + CONTENT-CHANGED + MTIME-ONLY)
      detailRows        == expectedDetailRows

  Both directions are checked, so a wrong report and a wrong detail file cannot cancel out.

.PARAMETER CompareDir
  Directory holding compare-report.txt, compare-detail.csv and the compare log.

.PARAMETER RequiredSections
  Section titles that must be present with a complete count block.

.PARAMETER LogName
  Name of the redirection log inside CompareDir. Default '_log.txt'.

.OUTPUTS
  PSCustomObject{ Ok; Errors(string[]); Rows; DetailRows; ExpectedDetailRows; Sections;
                  Warnings; TotalTracked }
#>
function Test-GuardedCompareOutput {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$CompareDir,
    [string[]]$RequiredSections = $null,
    [string]$LogName = '_log.txt'
  )

  if (-not $RequiredSections) { $RequiredSections = $script:DefaultRequiredSections }

  $errors = New-Object System.Collections.Generic.List[string]
  $sectionsOut = New-Object System.Collections.Generic.List[object]
  $rows = @()
  $detailRows = 0
  $expectedDetailRows = 0
  $warnings = -1
  $totalTracked = @{}
  $reportPath = Join-Path $CompareDir 'compare-report.txt'
  $detailPath = Join-Path $CompareDir 'compare-detail.csv'
  $logPath    = Join-Path $CompareDir $LogName

  # ------------------------------------------------ 1. compare must have finished
  $logText = $null
  if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) { $errors.Add("compare log missing: $LogName") }
  else {
    $logText = Read-TextAnyEncoding $logPath
    if (-not $logText -or $logText.Trim().Length -eq 0) { $errors.Add("compare log is empty: $LogName") }
    elseif ($logText -notmatch 'SCRIPT D DONE') {
      $errors.Add("compare log has no completion marker 'SCRIPT D DONE' - output was truncated or the run aborted")
    }
  }

  # ------------------------------------------------ 2. report must exist
  $reportText = $null
  if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { $errors.Add('compare-report.txt missing') }
  else {
    $reportText = Read-TextAnyEncoding $reportPath
    if (-not $reportText -or $reportText.Trim().Length -eq 0) { $errors.Add('compare-report.txt is empty') }
  }

  # ------------------------------------------------ 7. forbidden markers / warnings
  if ($reportText) {
    if ($reportText -match 'SKIPPED')        { $errors.Add('compare report contains SKIPPED section(s) - a manifest was missing') }
    if ($reportText -match 'manifest missing') { $errors.Add('compare report reports a missing manifest') }
    if ($reportText -match '(?i)parser error|ParserError|Unexpected token') { $errors.Add('compare report reports a parser error') }
    if ($reportText -match '(?i)truncated')  { $errors.Add('compare report says its output was truncated') }
    if ($reportText -match 'warnings:\s*(\d+)') { $warnings = [int]$Matches[1] }
    else { $errors.Add('compare report does not report a "warnings: N" count - cannot confirm it ran to the end') }
  }
  if ($logText) {
    if ($logText -match 'warnings:\s*(\d+)\s*\)') {
      $lw = [int]$Matches[1]
      if ($lw -ne 0) { $errors.Add("compare log reports warnings = $lw (expected 0)") }
    } elseif ($logText -match 'SCRIPT D DONE') {
      $errors.Add('compare log completion marker has no warnings count')
    }
    if ($logText -match '\[!\]') { $errors.Add('compare log contains [!] flagged problems') }
  }
  if ($warnings -gt 0) { $errors.Add("compare report reports warnings = $warnings (expected 0)") }

  # ------------------------------------------------ 3./4./5. per-section counts
  if ($reportText) {
    $lines = $reportText -split "`r?`n"
    $cur = $null
    foreach ($ln in $lines) {
      if ($ln -match '^\s*SECTION:\s*(.+?)\s*(\(|$)') {
        $title = $Matches[1].Trim()
        $cur = [PSCustomObject]@{ Title=$title; Body=(New-Object System.Collections.Generic.List[string]) }
        $sectionsOut.Add($cur)
      } elseif ($cur) { $cur.Body.Add($ln) }
    }

    foreach ($want in $RequiredSections) {
      $sec = $sectionsOut | Where-Object { $_.Title -eq $want } | Select-Object -First 1
      if (-not $sec) { $errors.Add("compare report is missing required section: $want"); continue }
      $body = ($sec.Body -join "`n")

      $mTotal = [regex]::Match($body, 'total tracked\s*:\s*(\d+)')
      if (-not $mTotal.Success) { $errors.Add("section '$want' does not report 'total tracked'") }
      else {
        $tt = [int]$mTotal.Groups[1].Value
        $totalTracked[$want] = $tt
        if ($tt -le 0) { $errors.Add("section '$want' reports total tracked = 0 (nothing was compared)") }
      }

      $secSum = 0
      foreach ($cls in $script:CompareClasses) {
        $mC = [regex]::Match($body, [regex]::Escape($cls) + '\s*:\s*(\d+)')
        if (-not $mC.Success) { $errors.Add("section '$want' does not report a '$cls' count") ; continue }
        $secSum += [int]$mC.Groups[1].Value
      }
      $expectedDetailRows += $secSum
    }

    # ------------------------------------------------ 8. session format summary
    $fmt = $sectionsOut | Where-Object { $_.Title -eq 'SESSION FORMAT SUMMARY' } | Select-Object -First 1
    if (-not $fmt) { $errors.Add('compare report is missing required section: SESSION FORMAT SUMMARY') }
    else {
      $fbody = ($fmt.Body -join "`n")
      $mBefore = [regex]::Match($fbody, 'BEFORE\s+total=(\d+)')
      $mAfter  = [regex]::Match($fbody, 'AFTER\s+total=(\d+)')
      if (-not $mBefore.Success) { $errors.Add('session format summary: BEFORE total is missing/unparseable') }
      if (-not $mAfter.Success)  { $errors.Add('session format summary: AFTER total is missing/unparseable') }
      if ($mBefore.Success -and $mAfter.Success) {
        if ([int]$mBefore.Groups[1].Value -le 0 -or [int]$mAfter.Groups[1].Value -le 0) {
          $errors.Add('session format summary reports 0 sessions on one side')
        }
      }
    }
  }

  # ------------------------------------------------ detail rows (EMPTY IS LEGAL)
  if (-not (Test-Path -LiteralPath $detailPath -PathType Leaf)) { $errors.Add('compare-detail.csv missing') }
  else {
    $raw = Read-TextAnyEncoding $detailPath
    $trimmed = ''
    if ($raw) { $trimmed = $raw.Trim() }
    if ($trimmed.Length -eq 0) {
      # ZERO-ROW Export-Csv output. Legal: no changes -> no detail rows.
      $rows = @()
    } else {
      try {
        $rows = @(Import-Csv -LiteralPath $detailPath -ErrorAction Stop)
        if (@($rows).Count -gt 0 -and -not ($rows[0].PSObject.Properties.Name -contains 'Class')) {
          $errors.Add('compare-detail.csv has no Class column')
        }
      } catch { $errors.Add("compare-detail.csv unreadable: $($_.Exception.Message)") }
    }
  }
  $detailRows = @($rows).Count

  # ------------------------------------------------ 4. consistency (both directions)
  # Checked even when other errors were found, so the message is always available.
  if ($detailRows -ne $expectedDetailRows) {
    $errors.Add("detail rows ($detailRows) != sum of section change counts ($expectedDetailRows) - report and detail disagree")
  }

  return [PSCustomObject]@{
    Ok                 = ($errors.Count -eq 0)
    Errors             = $errors.ToArray()
    Rows               = $rows
    DetailRows         = $detailRows
    ExpectedDetailRows = $expectedDetailRows
    Sections           = $sectionsOut.ToArray()
    Warnings           = $warnings
    TotalTracked       = $totalTracked
  }
}

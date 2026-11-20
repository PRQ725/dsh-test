<#
.SYNOPSIS
  Capture a TRULY QUIESCENT $DSH_HOME baseline for an E1 run, then SEAL the run metadata.

.DESCRIPTION
  FAIL-CLOSED. History of this script:
    * R1 produced a FALSE PASS: it redirected a child's output into a directory that did not
      exist yet, so the redirection target could not be opened and THE CHILD NEVER RAN; it
      printed "[PASS] capture written" unconditionally; the compare step found no manifests,
      skipped every section, and the verdict read "no data" as "no change" and printed PASS.
    * R2 produced a FALSE FAIL: the compare validator rejected the legally empty
      compare-detail.csv that a zero-diff pair produces.
  Both are fixed. This version:
    * creates every destination directory BEFORE any redirection
    * runs each child through Invoke-GuardedCapture (capture-guard.ps1)
    * requires sentinel artifacts to exist AND be non-empty
    * runs sanity minimums (0 sessions / 0 tracked rows => FATAL)
    * validates the diff with the zero-diff-aware validator
    * PASS requires: gate1 AND capture1Valid AND gate2 AND capture2Valid AND diffValid AND
      formatStable AND noChanges
    * on PASS with -MetadataPath, SEALS the run: writes E1-BASELINE-BINDING.json into the
      baseline directory and flips BaselineVerified in the run metadata

  The namespace is an EXPLICIT required parameter. The script never hard-codes one and never
  derives one from the run name.

.PARAMETER Namespace
  REQUIRED. Evidence directory name for this run's baseline, e.g. e1-BASE-QUIESCENT-R3.
  Produces <Namespace>, <Namespace>-VERIFY, <Namespace>-compare and <Namespace>-VERDICT.txt.

.PARAMETER Root
  Evidence root. Default: D:\Projects\dsh-test\evidence\desktop\runtime

.PARAMETER MetadataPath
  Optional run metadata (from new-e1-run.ps1). When supplied it is cross-checked against
  -Namespace/-WorkspacePath and, on PASS, SEALED. A baseline captured without it is valid
  evidence but NOT bindable: no E1 stage can run against it.

.PARAMETER WorkspacePath
  The run's isolated workspace, used for the session probe. Taken from metadata when omitted.

.PARAMETER GapSeconds
  Wait between capture #1 and capture #2. Default 20.

.EXAMPLE
  .\capture-e1-quiescent-baseline.ps1 -Namespace e1-BASE-QUIESCENT-R3 `
      -MetadataPath D:\Projects\dsh-test\evidence\desktop\runtime\e1-run3.metadata.json `
      -WorkspacePath D:\Projects\dsh-desktop-runtime-test-3

.OUTPUTS
  exit 0 = PASS and sealed
  exit 1 = FAIL (gate, capture, diff, format, or sealing error)
  exit 2 = refused by the quiescence gate (nothing was captured)
  exit 3 = PASS but NOT sealed (no -MetadataPath, or sealing failed)
#>
[CmdletBinding()]
param(
  # REQUIRED and explicit. The old version hard-coded e1-BASE-QUIESCENT-R2, which made the
  # baseline identity invisible at the call site. It is never defaulted and never derived.
  [Parameter(Mandatory=$true)][string]$Namespace,
  [string]$Root = 'D:\Projects\dsh-test\evidence\desktop\runtime',
  [string]$ToolsDir = 'D:\Projects\dsh-test\scripts\desktop-runtime-experiment',
  [string]$WorkspacePath = '',
  # When supplied, the run metadata is cross-checked and, on PASS, SEALED:
  # manifest fingerprints are recorded and BaselineVerified becomes true. Until that
  # happens no E1 stage may run against this baseline.
  [string]$MetadataPath = '',
  [int]$GapSeconds = 20
)

$ErrorActionPreference = 'Continue'
$script:stops = 0
$script:report = New-Object System.Collections.Generic.List[string]
function WRL($m)  { $script:report.Add([string]$m) | Out-Null; Write-Host $m }
function OK($m)   { WRL ("[PASS] " + $m) }
function WARN($m) { WRL ("[WARN] " + $m) }
function FAIL($m) { $script:stops++; WRL ("[FATAL] " + $m) }
function INFO($m) { WRL ("[INFO] " + $m) }

# ---- namespace is EXPLICIT; the R1 attempt and the R2 baseline are never overwritten ----
$CAP1 = Join-Path $Root $Namespace
$CAP2 = Join-Path $Root ($Namespace + '-VERIFY')
$CMP  = Join-Path $Root ($Namespace + '-compare')
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

# ---- the evidence root MUST exist before ANY redirection or write ----------
# This is the same failure class as the R1 bug: writing into a directory that does
# not exist yet. Here it silently lost the "attempt failed" record; now it cannot.
if (-not (Test-Path -LiteralPath $Root)) { New-Item -ItemType Directory -Path $Root -Force | Out-Null }
if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
  Write-Host ("FATAL: cannot create evidence root {0}" -f $Root)
  exit 1
}

WRL "================================================================"
WRL ("QUIESCENT BASELINE CAPTURE   namespace = {0}" -f $Namespace)
WRL "Root = $Root"
WRL ("started {0}" -f $stamp)
WRL "================================================================"
WRL ""

# ---- preconditions BEFORE dot-sourcing the guard ---------------------------
foreach ($s in @('capture-guard.ps1','capture-run-config.ps1','capture-desktop-runtime.ps1','capture-shared-state.ps1','detect-runtime-test-session.ps1','compare-captures.ps1')) {
  if (-not (Test-Path (Join-Path $ToolsDir $s))) { FAIL "missing tool script: $s" }
}
if ($script:stops -gt 0) {
  WRL ""; WRL "ABORT: missing tool scripts."
  $script:report | Set-Content -LiteralPath (Join-Path $Root ($Namespace + '-ATTEMPT-FAILED.txt')) -Encoding UTF8
  exit 1
}
. (Join-Path $ToolsDir 'capture-guard.ps1')
. (Join-Path $ToolsDir 'capture-run-config.ps1')

# ---- optional run metadata: cross-check, then SEAL on PASS ------------------
$meta = $null
if ($MetadataPath) {
  WRL "--- run metadata cross-check ---"
  $meta = Import-E1RunMetadata -Path $MetadataPath
  if ($null -eq $meta) { FAIL ("metadata not found: {0}" -f $MetadataPath) }
  else {
    foreach ($e in (Test-E1RunMetadataShape -Metadata $meta)) { FAIL $e }
    if ([string]$meta.BaselineNamespace -ne $Namespace) {
      FAIL ("-Namespace '$Namespace' != metadata BaselineNamespace '$($meta.BaselineNamespace)'")
    }
    if ([string]$meta.BaselineDir -ne $CAP1) {
      FAIL ("metadata BaselineDir '$($meta.BaselineDir)' != '{0}'" -f $CAP1)
    }
    if ($WorkspacePath -and ([string]$meta.WorkspacePath -ne $WorkspacePath)) {
      FAIL ("-WorkspacePath '$WorkspacePath' != metadata WorkspacePath '$($meta.WorkspacePath)'")
    }
    if (-not $WorkspacePath) { $WorkspacePath = [string]$meta.WorkspacePath }
    if (-not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) { FAIL "metadata file vanished" }
    WRL ("  metadata   : {0}" -f $MetadataPath)
    WRL ("  run        : {0}" -f $meta.RunName)
    WRL ("  workspace  : {0}" -f $meta.WorkspacePath)
    WRL ("  baseline   : {0}" -f $meta.BaselineDir)
  }
  if ($script:stops -gt 0) {
    WRL ""; WRL "ABORT: metadata does not match the requested namespace/workspace."
    $script:report | Set-Content -LiteralPath (Join-Path $Root ($Namespace + '-ATTEMPT-FAILED.txt')) -Encoding UTF8
    exit 1
  }
  OK "metadata cross-check passed"
  WRL ""
}

if (-not $WorkspacePath) { $WorkspacePath = 'D:\Projects\dsh-desktop-runtime-test-3' }
WRL ("  session-workspace probe : {0}" -f $WorkspacePath)
WRL ""

# ---- the R1 artifacts are INVALID and must never be mistaken for a baseline
foreach ($bad in @('e1-BASE-QUIESCENT','e1-BASE-QUIESCENT-2','e1-BASE-QUIESCENT-compare','e1-BASE-QUIESCENT-VERDICT.txt')) {
  $p = Join-Path $Root $bad
  if (Test-Path $p) { WARN ("R1 artifact present and INVALID (do not use): {0}" -f $p) }
}
# Warn about ANY other baseline namespace already on disk, without hard-coding its name, so
# this keeps working for run4/run5 without editing the script.
Get-ChildItem -LiteralPath $Root -Directory -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -like 'e1-BASE*' -and $_.FullName -ne $CAP1 } |
  Sort-Object Name | ForEach-Object {
    WARN ("other baseline namespace present (NOT this run's, never used): {0}" -f $_.FullName)
  }

# ------------------------------------------------------------------ gate
function Test-Quiescence {
  param([string]$When)
  $res = [PSCustomObject]@{ When=$When; Ok=$true; Lines=@() }
  $add = { param($t) $res.Lines += $t }

  # Detection notes:
  #  * 'desktop' uses -ExcludeSelf: the desktop-host probe is a CommandLine match, so a
  #    command line that merely CONTAINS 'dsh-desktop-host' would match itself.
  #  * 'cli'/'mcp' deliberately do NOT exclude self/ancestors: the DSH CLI host serving
  #    this research session is an ANCESTOR, and hiding it would turn the gate into a
  #    false PASS. A false STOP is acceptable; a false PASS is not.
  $desktop = @(Get-HostProcesses -Kind 'desktop' -ExcludeSelf)
  $cli     = @(Get-HostProcesses -Kind 'cli')
  $mcp     = @(Get-HostProcesses -Kind 'mcp')
  $mcpChr  = @(Get-HostProcesses -Kind 'mcpchr')
  $lis     = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -in 3080,3180 })

  & $add ("desktop(electron-shell/desktop-host) = {0}" -f $desktop.Count)
  & $add ("cli host (@deepseek-ai/dsh/lib/bin.js) = {0}" -f $cli.Count)
  & $add ("playwright MCP processes                 = {0}" -f $mcp.Count)
  & $add ("MCP-dedicated Chrome                     = {0}" -f $mcpChr.Count)
  & $add ("listeners on 3080/3180                   = {0}" -f $lis.Count)

  if ($desktop.Count -gt 0) { $res.Ok = $false; foreach($p in $desktop){ & $add ("  desktop pid {0}: {1}" -f $p.ProcessId, $p.Name) } }
  if ($cli.Count -gt 0)     { $res.Ok = $false; foreach($p in $cli){ & $add ("  cli pid {0}: {1}" -f $p.ProcessId, $p.CommandLine) } }
  if ($mcp.Count -gt 0)     { $res.Ok = $false }
  if ($mcpChr.Count -gt 0)  { $res.Ok = $false }
  if ($lis.Count -gt 0)     { $res.Ok = $false; foreach($l in $lis){ & $add ("  port {0} held by pid {1}" -f $l.LocalPort, $l.OwningProcess) } }
  return $res
}

WRL "--- A. quiescence gate (before capture #1) ---"
$gate1 = Test-Quiescence -When 'pre1'
$gate1.Lines | ForEach-Object { WRL ("  " + $_) }
if (-not $gate1.Ok) {
  WRL ""
  FAIL "host/port NOT quiescent -> refusing to capture. Nothing was written."
  WRL "       Stop Desktop (tray included) and browser-lab, close this research session,"
  WRL "       and re-run this wrapper from an external PowerShell."
  WRL ""
  WRL "QUIESCENT BASELINE: FAIL (gate) - no capture directory was created"
  $notePath = Join-Path $Root ($Namespace + '-ATTEMPT-FAILED.txt')
  $script:report | Set-Content -LiteralPath $notePath -Encoding UTF8
  if (-not (Test-Path -LiteralPath $notePath -PathType Leaf)) { Write-Host ("FATAL: could not write {0}" -f $notePath) }
  Write-Host ("note written: {0}" -f $notePath)
  exit 2
}
OK "all hosts stopped and 3080/3180 free"
WRL ""

# ---- create ALL destinations up-front (the R1 bug: redirection before mkdir)
foreach ($d in @($CAP1,$CAP2,$CMP)) {
  if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}
INFO "destination directories pre-created"

# ------------------------------------------------------------------ helpers
function Invoke-StageCapture {
  param([string]$Dir, [string]$LabelSuffix)
  $ra = Invoke-GuardedCapture -Name 'A' -ToolsDir $ToolsDir -OutDir $Dir -ChildArgs @{ Label = ("baseline-" + $LabelSuffix) }
  $rb = Invoke-GuardedCapture -Name 'B' -ToolsDir $ToolsDir -OutDir $Dir -ChildArgs @{ Label = ("baseline-" + $LabelSuffix); DecodeSessions = $true }
  $rc = Invoke-GuardedCapture -Name 'C' -ToolsDir $ToolsDir -OutDir $Dir -ChildArgs @{ WorkspacePath = $WorkspacePath; All = $true }
  $rs = Test-GuardedCaptureSanity -OutDir $Dir
  $ok = $ra.Ok -and $rb.Ok -and $rc.Ok -and $rs.Ok
  foreach ($r in @($ra,$rb,$rc)) {
    foreach ($e in $r.Errors) { FAIL ("[capture " + $r.Name + "] " + $e) }
  }
  foreach ($e in $rs.Fatal) { FAIL ("[sanity] " + $e) }
  foreach ($e in $rs.Warn)  { WARN ("[sanity] " + $e) }
  if (-not $ok) {
    WRL ("  CAPTURE INCOMPLETE -> {0}" -f $Dir)
  } else {
    $sn = @(Import-Csv -LiteralPath (Join-Path $Dir 'session-inventory.csv')).Count
    $sh = @(Import-Csv -LiteralPath (Join-Path $Dir 'shared-state-manifest.csv')).Count
    $pc = @(Import-Csv -LiteralPath (Join-Path $Dir 'projcache-inventory.csv')).Count
    OK ("capture valid: sessions={0} shared-state={1} projcache={2}" -f $sn, $sh, $pc)
  }
  return $ok
}

# ------------------------------------------------------------------ capture #1
WRL "--- B. capture #1 -> $CAP1 ---"
$capture1Valid = Invoke-StageCapture -Dir $CAP1 -LabelSuffix 'quiescent'
WRL ""

if (-not $capture1Valid) {
  FAIL "capture #1 is INCOMPLETE -> aborting before capture #2 (no diff, no PASS)"
  WRL ""
  WRL "QUIESCENT BASELINE: FAIL (capture #1 incomplete)"
  $script:report | Set-Content -LiteralPath (Join-Path $Root ($Namespace + '-VERDICT.txt')) -Encoding UTF8
  exit 1
}

# ------------------------------------------------------------------ capture #2
WRL ("--- C. waiting {0}s ---" -f $GapSeconds)
Start-Sleep -Seconds $GapSeconds

WRL "--- D0. quiescence gate (before capture #2) ---"
$gate2 = Test-Quiescence -When 'pre2'
$gate2.Lines | ForEach-Object { WRL ("  " + $_) }
$gate2Ok = $gate2.Ok
if (-not $gate2Ok) { FAIL "something started between the two captures -> second capture is not quiescent" }
WRL ""

WRL "--- D. capture #2 -> $CAP2 ---"
$capture2Valid = Invoke-StageCapture -Dir $CAP2 -LabelSuffix 'quiescent-verify'
WRL ""

if (-not $capture2Valid) {
  FAIL "capture #2 is INCOMPLETE -> aborting before the diff (no PASS)"
  WRL ""
  WRL "QUIESCENT BASELINE: FAIL (capture #2 incomplete)"
  $script:report | Set-Content -LiteralPath (Join-Path $Root ($Namespace + '-VERDICT.txt')) -Encoding UTF8
  exit 1
}

# ------------------------------------------------------------------ diff
WRL "--- E. diff capture #1 vs capture #2 ---"
# Uses the shared fail-closed compare guard: pre-created destination, throw capture,
# redirection-log check, then report/detail validation.
#
# A ZERO-ROW compare-detail.csv IS LEGAL and expected here: compare-detail.csv records only
# entries that CHANGED, so two identical captures yield no rows at all (Export-Csv writes a
# BOM-only file). Validity is therefore decided by section completeness plus
# detailRows == sum of all section change counts, never by "is the detail file empty".
# NOTE: local variables are deliberately NOT named $CMP - PowerShell variable names are
# case-insensitive, so $cmp would silently clobber the $CMP path variable.
$cmpResult = Invoke-GuardedCompare -ToolsDir $ToolsDir -Before $CAP1 -After $CAP2 -OutDir $CMP
foreach ($e in $cmpResult.Errors) { FAIL ("[diff] " + $e) }
$diffValid = $cmpResult.Ok
if ($diffValid) {
  OK ("diff valid: detailRows={0} expectedDetailRows={1} warnings={2}" -f `
      $cmpResult.DetailRows, $cmpResult.ExpectedDetailRows, $cmpResult.Warnings)
  if ($cmpResult.DetailRows -eq 0) { OK "zero-row diff: every section reported 0 changes (this is the quiescent outcome, NOT an error)" }
} else {
  WRL "  diff INVALID -> 'no change' cannot be concluded from it"
}

$rows  = @($cmpResult.Rows)
$fatal = @($rows | Where-Object { $_.Class -in @('ADDED','DELETED','CONTENT-CHANGED') })
$drift = @($rows | Where-Object { $_.Class -eq 'MTIME-ONLY' })

$sum = @{}
foreach ($r in $rows) {
  $k = "$($r.Section)|$($r.Class)"
  if (-not $sum.ContainsKey($k)) { $sum[$k] = 0 }
  $sum[$k]++
}
WRL "  per-section counts:"
if ($sum.Keys.Count -eq 0) { WRL "    (none - no differences)" }
$sum.Keys | Sort-Object | ForEach-Object { WRL ("    {0} = {1}" -f $_, $sum[$_]) }
WRL ""

# session format stability (independent of the diff)
WRL "--- F0. session format stability ---"
$i1 = @(Import-Csv -LiteralPath (Join-Path $CAP1 'session-inventory.csv'))
$i2 = @(Import-Csv -LiteralPath (Join-Path $CAP2 'session-inventory.csv'))
$f1 = ($i1 | Group-Object Format | Sort-Object Name | ForEach-Object { $_.Name + '=' + $_.Count }) -join ' '
$f2 = ($i2 | Group-Object Format | Sort-Object Name | ForEach-Object { $_.Name + '=' + $_.Count }) -join ' '
WRL ("  formats capture#1: {0}   (rows {1})" -f $f1, $i1.Count)
WRL ("  formats capture#2: {0}   (rows {1})" -f $f2, $i2.Count)
$fmtOk = ($f1 -eq $f2) -and ($i1.Count -gt 0)
if (-not $fmtOk) { FAIL "session format distribution changed (or empty) between captures" } else { OK "session format distribution stable" }
WRL ""

# ------------------------------------------------------------------ verdict
$noChanges = ($fatal.Count -eq 0) -and ($drift.Count -eq 0)
$failClosedOk = $gate1.Ok -and $capture1Valid -and $gate2Ok -and $capture2Valid -and $diffValid -and $fmtOk

WRL "================================================================"
WRL "VERDICT INPUTS"
WRL ("  gate #1            : {0}" -f $gate1.Ok)
WRL ("  capture #1 valid   : {0}" -f $capture1Valid)
WRL ("  gate #2            : {0}" -f $gate2Ok)
WRL ("  capture #2 valid   : {0}" -f $capture2Valid)
WRL ("  diff valid         : {0}" -f $diffValid)
WRL ("    detailRows        : {0}   (entries that CHANGED; 0 is legal for a zero-diff pair)" -f $cmpResult.DetailRows)
WRL ("    expectedDetailRows: {0}   (sum of ADDED+DELETED+CONTENT-CHANGED+MTIME-ONLY over all sections)" -f $cmpResult.ExpectedDetailRows)
WRL ("    compare warnings  : {0}" -f $cmpResult.Warnings)
WRL ("  format stable      : {0}" -f $fmtOk)
WRL ("  changes            : fatal={0} drift={1}" -f $fatal.Count, $drift.Count)
WRL ""

if ($failClosedOk -and $noChanges) {
  WRL "QUIESCENT BASELINE: PASS"
  WRL "  both captures valid and byte-identical (no ADDED / DELETED / CONTENT-CHANGED / MTIME-ONLY)"
  WRL ("  baseline : {0}" -f $CAP1)
  WRL ("  verify   : {0}" -f $CAP2)
  WRL ("  this is the E1 run2 guard baseline: {0}" -f $CAP1)
} else {
  WRL "QUIESCENT BASELINE: FAIL"
  WRL ""
  if (-not $failClosedOk) { WRL "  [FATAL] pipeline did not complete validly (see VERDICT INPUTS above)" }
  if ($fatal.Count -gt 0) {
    WRL ("  [FATAL] {0} ADDED/DELETED/CONTENT-CHANGED entr(ies) -> baseline NOT usable:" -f $fatal.Count)
    $fatal | Select-Object -First 25 | ForEach-Object { WRL ("      {0}  {1}  {2}" -f $_.Class, $_.Section, $_.Rel) }
  }
  if ($drift.Count -gt 0) {
    WRL ("  [DRIFT] {0} MTIME-ONLY entr(ies) -> content identical, but quiescence is NOT proven:" -f $drift.Count)
    $drift | Select-Object -First 25 | ForEach-Object { WRL ("      {0}  {1}" -f $_.Section, $_.Rel) }
    WRL "      A mtime-only change is NOT a content mutation; the baseline stays usable as a"
    WRL "      CONTENT guard, but investigate what still touches the file before trusting it."
  }
}
WRL ""
WRL "MTIME-ONLY POLICY (explicit)"
WRL "  allowed for a QUIESCENT claim : none"
WRL "  effect on baseline usability  : content-identical => usable as CONTENT guard only"
WRL "  effect on the E1 guard        : e1-capture.ps1 compares CONTENT (Size/Sha256) only"
WRL ("captures: {0}" -f $CAP1)
WRL ("          {0}" -f $CAP2)
WRL ("compare : {0}" -f $CMP)

# ================================================================ SEAL
# A PASS is not enough on its own: the run metadata must be SEALED, because a baseline that
# is not sealed is not bindable and no E1 stage may run against it. Sealing records the
# manifest fingerprints INSIDE the baseline directory (E1-BASELINE-BINDING.json) and flips
# BaselineVerified in the metadata. If sealing fails, the script FAILS: an unsealed PASS
# would look usable while being unbindable.
$sealedOk = $false
if ($failClosedOk -and $noChanges) {
  WRL ""
  WRL "--- SEAL: bind this baseline to the run ---"
  if (-not $MetadataPath) {
    WARN "no -MetadataPath supplied -> this baseline is NOT sealed and NO E1 stage can bind to it"
    WRL "       Re-run with: -Namespace $Namespace -MetadataPath <run metadata>"
  } else {
    $metaReload = Import-E1RunMetadata -Path $MetadataPath
    if ($null -eq $metaReload) {
      FAIL ("metadata unreadable at seal time: {0}" -f $MetadataPath)
    } else {
      $fixtureSha = ''
      $fx = Join-Path $WorkspacePath 'AGENTS.md'
      if (Test-Path -LiteralPath $fx -PathType Leaf) { $fixtureSha = (Get-FileHash -LiteralPath $fx -Algorithm SHA256).Hash }
      $binding = New-E1BaselineBinding -Metadata $metaReload -BaselineDir $CAP1 `
                                       -VerdictPath (Join-Path $Root ($Namespace + '-VERDICT.txt')) `
                                       -FixtureAgentsSha256 $fixtureSha
      $bindingPath = Save-E1BaselineBinding -Binding $binding -BaselineDir $CAP1
      if (Test-Path -LiteralPath $bindingPath -PathType Leaf) {
        OK ("baseline binding record written: {0}" -f $bindingPath)
      } else {
        FAIL ("could not write baseline binding record: {0}" -f $bindingPath)
      }
      $metaReload.BaselineVerified = $true
      $metaReload.BaselineSealedAt = $binding.SealedAt
      $metaReload.BaselineFingerprint = (Get-ComparedManifestFingerprint -Dir $CAP1)
      Save-E1RunMetadata -Metadata $metaReload -Path $MetadataPath
      $verifyMeta = Import-E1RunMetadata -Path $MetadataPath
      if (-not [bool]$verifyMeta.BaselineVerified) {
        FAIL "metadata seal did not persist (BaselineVerified still false)"
      } else {
        OK ("metadata SEALED: {0}  (BaselineVerified=true)" -f $MetadataPath)
        $sealedOk = $true
      }
    }
  }
  WRL ""
}

$script:report | Set-Content -LiteralPath (Join-Path $Root ($Namespace + '-VERDICT.txt')) -Encoding UTF8
Write-Host ""
Write-Host ("verdict written: {0}" -f (Join-Path $Root ($Namespace + '-VERDICT.txt')))

# ---- explicit exit code: automation must never read a FAIL as success ------
# An unsealed PASS exits 3: the capture is good but the run is not yet bindable.
if (-not ($failClosedOk -and $noChanges)) { exit 1 }
if ($MetadataPath -and -not $sealedOk)    { exit 3 }
exit 0

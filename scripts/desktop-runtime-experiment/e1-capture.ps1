<#
.SYNOPSIS
  E1 wrapper - capture one stage of the v4-session interoperability experiment
  and evaluate the CORRECTED A/B/C criteria.

.DESCRIPTION
  READ-ONLY with respect to $DSH_HOME. Does NOT start or stop Desktop / browser-lab.

  Call it once per stage, AFTER the human has performed the stage's manual actions:

    -Stage A : Desktop created the session, Desktop fully exited
    -Stage B : browser-lab opened the session READ-ONLY (no message sent)
    -Stage C : browser-lab sent the continuation marker, browser-lab exited

  THERE IS NO -Stage BASE. A run's baseline is the SEALED quiescent baseline declared in
  e1-<RunName>.metadata.json; it is produced by capture-e1-quiescent-baseline.ps1.
  Deriving "e1-<RunName>-BASE" was the run2 Stage A defect and is now impossible.

  BASELINE BINDING (single source of truth)
  -----------------------------------------
  Every baseline-dependent step below reads ONE variable, $prevInfo.Dir, which for Stage A
  is $ctx.BaselineDir taken from the run metadata. That same value feeds:
      * the experiment-session listing diff
      * the previous-stage compare-captures.ps1 invocation
      * the shared-state change classifier (5a)
      * the session classifier (5b)
  No step derives a baseline path from the run name. If the declared baseline is missing,
  unsealed, belongs to another run, or its manifests changed after sealing, the stage STOPS
  before any interpretation.

  Criteria encoded here (corrected per review):
    A->B  content hash change  => WARN "IMPLICIT REWRITE ON OPEN"  (NOT a stop)
    B->C  content hash change  => INFO "expected after continuation" (NOT an anomaly)
    Format downgrade / second format file / .bak / .imported / existing-session
    pollution => STOP.

.PARAMETER Stage
  A | B | C

.PARAMETER Root
  Evidence root for runtime captures. Default: D:\Projects\dsh-test\evidence\desktop\runtime

.PARAMETER ToolsDir
  Directory holding the capture scripts.

.PARAMETER RunName
  Run namespace. Selects e1-<RunName>.metadata.json, which declares the workspace, the
  sealed baseline directory and every stage directory.

.PARAMETER MetadataPath
  Explicit path to the run metadata. Defaults to <Root>\e1-<RunName>.metadata.json.

.PARAMETER WorkspacePath
  Optional. If supplied it MUST equal the workspace declared in the metadata, otherwise the
  stage STOPS. If omitted, the metadata value is used.

.EXAMPLE
  .\e1-capture.ps1 -RunName run3 -Stage A -LockSession
  .\e1-capture.ps1 -RunName run3 -Stage B
  .\e1-capture.ps1 -RunName run3 -Stage C
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][ValidateSet('A','B','C')][string]$Stage,
  [string]$Root = 'D:\Projects\dsh-test\evidence\desktop\runtime',
  [string]$ToolsDir = 'D:\Projects\dsh-test\scripts\desktop-runtime-experiment',
  # Each run has its OWN isolated workspace so the session is unambiguous.
  # This value is only a CROSS-CHECK; the authoritative value is in the run metadata.
  [string]$WorkspacePath = '',
  # Run namespace. Selects <Root>\e1-<RunName>.metadata.json.
  [string]$RunName = 'run3',
  [string]$MetadataPath = '',
  # Set on Stage A to (re)write the session lock; B/C always READ it.
  [switch]$LockSession
)

$ErrorActionPreference = 'Continue'
$script:stops = 0
$script:warns = 0
$script:report = New-Object System.Collections.Generic.List[string]
function WRL($m) { $script:report.Add([string]$m) | Out-Null; Write-Host $m }
function OK($m)   { WRL ("[PASS] " + $m) }
function WARN($m) { $script:warns++; WRL ("[WARN] " + $m) }
function FAIL($m) { $script:stops++; WRL ("[STOP] " + $m) }
function INFO($m) { WRL ("[INFO] " + $m) }

$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$stageDir = Join-Path $Root ("e1-" + $RunName + "-" + $Stage)
# The stage directory is NOT created here. A refusal must not leave a half-built stage
# directory behind that a later reader could mistake for real stage evidence.
$refusePath = Join-Path $Root ("e1-" + $RunName + "-BINDING-REFUSED.txt")
function Write-Refusal {
  param([string]$Why)
  WRL ""
  WRL ("REFUSED: {0}" -f $Why)
  WRL ("stage directory was NOT created: {0}" -f $stageDir)
  $script:report | Set-Content -LiteralPath $refusePath -Encoding UTF8
  Write-Host ""
  Write-Host ("refusal record: {0}" -f $refusePath)
  exit 1
}

WRL "================================================================"
WRL "E1 RUN $RunName  STAGE $Stage   (captured $stamp)"
WRL "stageDir = $stageDir"
WRL "================================================================"
WRL ""

# ---------------------------------------------------------------- 0. guards
WRL "--- preconditions ---"
foreach ($s in @('capture-guard.ps1','capture-run-config.ps1','capture-desktop-runtime.ps1','capture-shared-state.ps1','detect-runtime-test-session.ps1','compare-captures.ps1')) {
  if (-not (Test-Path (Join-Path $ToolsDir $s))) { FAIL "missing tool script: $s" }
}
if ($script:stops -gt 0) { Write-Refusal "missing tool scripts" }
. (Join-Path $ToolsDir 'capture-guard.ps1')
. (Join-Path $ToolsDir 'capture-run-config.ps1')

# ---------------------------------------------------------------- 0b. EXPLICIT run context
# The baseline path is READ from metadata, never derived from $RunName. A missing,
# unsealed, foreign or drifted baseline STOPS the stage here, before any interpretation.
WRL "--- explicit run context / baseline binding ---"
$ctx = Resolve-E1RunContext -Root $Root -RunName $RunName -MetadataPath $MetadataPath
WRL ("  metadata      : {0}" -f $ctx.MetadataPath)
foreach ($e in $ctx.Errors) { FAIL ("[binding] " + $e) }
if (-not $ctx.Ok) {
  WRL "       Create/inspect the run with:  new-e1-run.ps1 -RunName $RunName"
  WRL "       Seal the baseline with:       capture-e1-quiescent-baseline.ps1 -Namespace <ns> -MetadataPath <meta>"
  Write-Refusal "the run baseline binding is not valid; no stage may run without it"
}

$meta = $ctx.Metadata
$baselineDir = $ctx.BaselineDir
$lockPath = [string]$ctx.LockFile

# the workspace is authoritative from metadata; a conflicting -WorkspacePath is a STOP
if ($WorkspacePath -and ($WorkspacePath -ne $meta.WorkspacePath)) {
  FAIL ("-WorkspacePath '$WorkspacePath' != metadata WorkspacePath '$($meta.WorkspacePath)'  (workspace mismatch)")
  Write-Refusal "workspace mismatch"
}
$WorkspacePath = [string]$meta.WorkspacePath

# the stage directory must be the one the metadata declares for this stage
$declaredStageDir = [string]$meta.StageDirs.$Stage
if ($declaredStageDir -ne $stageDir) {
  FAIL ("stage dir '$stageDir' != metadata StageDirs.$Stage '$declaredStageDir'")
  Write-Refusal "stage directory does not match the run metadata"
}

$prevInfo = Get-E1PreviousStage -Context $ctx -Stage $Stage
$prevStage = $prevInfo.Label
$prevDir   = $prevInfo.Dir

# ---- lock identity pre-check for B/C ---------------------------------------
# Done BEFORE any capture: a lock that belongs to another run, another workspace or another
# baseline makes every later observation meaningless. Fail fast, write nothing else.
if ($Stage -ne 'A') {
  if (-not (Test-Path -LiteralPath $lockPath -PathType Leaf)) {
    FAIL "session lock missing at $lockPath -> run Stage A for run '$RunName' first"
  } else {
    $preLock = Get-Content -LiteralPath $lockPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $faults = New-Object System.Collections.Generic.List[string]
    if ([string]$preLock.RunName -ne $RunName)                                { $faults.Add("lock RunName '$($preLock.RunName)' != '$RunName'") }
    if ([string]$preLock.WorkspacePath -ne [string]$meta.WorkspacePath)       { $faults.Add("lock WorkspacePath '$($preLock.WorkspacePath)' != '$($meta.WorkspacePath)'") }
    if ([string]$preLock.WorkspaceDirName -ne [string]$meta.WorkspaceDirName) { $faults.Add("lock WorkspaceDirName '$($preLock.WorkspaceDirName)' != '$($meta.WorkspaceDirName)'") }
    if ([string]$preLock.BaselineDir -ne [string]$baselineDir)                { $faults.Add("lock BaselineDir '$($preLock.BaselineDir)' != '$baselineDir'") }
    if (@($faults).Count -gt 0) {
      FAIL "session lock does not match this run -> EXACT SESSION LOCK MISMATCH"
      $faults | ForEach-Object { WRL ("      " + $_) }
      WRL ("      nothing is deleted; run Stage A for THIS run to write a matching lock: {0}" -f $lockPath)
      Write-Refusal ("exact session lock mismatch for stage $Stage")
    }
    OK ("session lock identity matches this run (id {0})" -f $preLock.SessionId)
  }
}
if ($script:stops -gt 0) { Write-Refusal "stage $Stage cannot proceed" }

# all pre-flight checks passed: only NOW create the stage directory
if (-not (Test-Path -LiteralPath $stageDir)) { New-Item -ItemType Directory -Path $stageDir -Force | Out-Null }
if (-not (Test-Path -LiteralPath $stageDir -PathType Container)) {
  Write-Host ("FATAL: cannot create stage directory {0}" -f $stageDir)
  exit 1
}

OK ("baseline binding valid")
WRL ("  run namespace : {0}" -f $RunName)
WRL ("  workspace     : {0}" -f $WorkspacePath)
WRL ("  session dir   : {0}" -f $meta.WorkspaceDirName)
WRL ("  BASELINE      : {0}{1}" -f $prevInfo.Dir, $(if ($prevInfo.IsBaseline) { '   <- sealed quiescent baseline' } else { '' }))
WRL ("  baseline seal : {0}" -f $ctx.Binding.SealedAt)
WRL ("  previous stage: {0}{1}" -f $prevStage, $(if ($prevInfo.IsBaseline) { ' (the baseline itself)' } else { '' }))
WRL ("  compare dir   : {0}" -f $prevInfo.CompareDir)
WRL ("  session lock  : {0}" -f $lockPath)
WRL ""

# warn if a DSH host is unexpectedly running during stages that expect none
# 'desktop' excludes self/ancestors (its probe is a CommandLine match); 'cli' does not,
# because the host serving this research session is an ancestor and must stay visible.
$hosts   = @(Get-HostProcesses -Kind 'cli')
$desktop = @(Get-HostProcesses -Kind 'desktop' -ExcludeSelf)
INFO ("cli-host processes = {0} ; desktop processes = {1}" -f @($hosts).Count, @($desktop).Count)
if ($Stage -eq 'A' -and @($desktop).Count -gt 0) { WARN "Stage A expects Desktop to be FULLY EXITED (including tray). Desktop process(es) still present." }
if ($Stage -eq 'B' -and @($hosts).Count -eq 0) { WARN "Stage B expects browser-lab RUNNING (or just-closed before capture). No cli-host found." }
if ($Stage -eq 'C' -and @($hosts).Count -gt 0) { WARN "Stage C expects browser-lab to be CLOSED before capture. cli-host still present." }
WRL ""

# ---------------------------------------------------------------- 1. captures (fail-closed)
WRL "--- running capture scripts (guarded) ---"
$capA = Invoke-GuardedCapture -Name 'A' -ToolsDir $ToolsDir -OutDir $stageDir -ChildArgs @{ Label = ("e1-" + $Stage) }
$capB = Invoke-GuardedCapture -Name 'B' -ToolsDir $ToolsDir -OutDir $stageDir -ChildArgs @{ Label = ("e1-" + $Stage); DecodeSessions = $true }
$capC = Invoke-GuardedCapture -Name 'C' -ToolsDir $ToolsDir -OutDir $stageDir -ChildArgs @{ WorkspacePath = $WorkspacePath; All = $true }
$capSan = Test-GuardedCaptureSanity -OutDir $stageDir
$captureValid = $capA.Ok -and $capB.Ok -and $capC.Ok -and $capSan.Ok
foreach ($r in @($capA,$capB,$capC)) { foreach ($e in $r.Errors) { FAIL ("[capture " + $r.Name + "] " + $e) } }
foreach ($e in $capSan.Fatal) { FAIL ("[sanity] " + $e) }
foreach ($e in $capSan.Warn)  { WARN ("[sanity] " + $e) }
if (-not $captureValid) {
  WRL ("  CAPTURE INCOMPLETE -> aborting stage {0} (no classifier, no verdict)" -f $Stage)
  $script:report | Set-Content -LiteralPath (Join-Path $stageDir 'e1-stage-report.txt') -Encoding UTF8
  Write-Host ""
  Write-Host ("STAGE {0} RESULT: *** ABORTED - CAPTURE INCOMPLETE ***" -f $Stage)
  exit 1
}
OK ("capture valid: sessions={0} shared-state={1}" -f `
    @(Import-Csv -LiteralPath (Join-Path $stageDir 'session-inventory.csv')).Count, `
    @(Import-Csv -LiteralPath (Join-Path $stageDir 'shared-state-manifest.csv')).Count)
WRL ""

# ---------------------------------------------------------------- 2. session snapshot
function Get-SessionSnapshot {
  param([string]$Dir)
  $j = Join-Path $Dir 'runtime-test-session.json'
  if (-not (Test-Path $j)) { return $null }
  try { return (Get-Content $j -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

$cur = Get-SessionSnapshot -Dir $stageDir
WRL "--- runtime-test session snapshot ---"
if ($null -eq $cur -or -not $cur.WorkspaceDirFound) {
  WRL "  workspace session dir : NOT FOUND"
  if ($Stage -eq 'A') { FAIL "Stage A: Desktop did not create a session in $WorkspacePath" }
  else { FAIL "Stage ${Stage}: session directory still not found" }
} else {
  WRL ("  workspace dir : {0}" -f $cur.WorkspaceDir)
  WRL ("  declared dir  : {0}{1}" -f $meta.WorkspaceSessionDir, $(if ($cur.WorkspaceDir -eq $meta.WorkspaceSessionDir) { '   (matches metadata)' } else { '   <- MISMATCH' }))
  if ($cur.WorkspaceDir -ne $meta.WorkspaceSessionDir) {
    FAIL ("session workspace dir '$($cur.WorkspaceDir)' != metadata declared '$($meta.WorkspaceSessionDir)'  (workspace mismatch)")
  }
  WRL ("  formats       : {0}" -f $cur.Formats)
  WRL ("  session count : {0}" -f $cur.SessionCount)
  $m = $cur.MostRecent
  if ($m) {
    WRL ("  most recent   : {0}" -f $m.SessionId)
    WRL ("    file        : {0}" -f $m.File)
    WRL ("    format      : {0}" -f $m.Format)
    WRL ("    size        : {0}" -f $m.Size)
    WRL ("    utc         : {0}" -f $m.Utc)
    WRL ("    sha256      : {0}" -f $m.Sha256)
    WRL ("    projcache   : {0}" -f $m.ProjCache)
    WRL ("    pc sha256   : {0}" -f $m.ProjCacheSha)
    if ($Stage -eq 'A' -and $m.Format -ne 'v4') { WARN ("Stage A: Desktop-created session format is {0}, expected v4" -f $m.Format) }
  }
}
WRL ""

# ---------------------------------------------------------------- 2b. EXACT session lock (run isolation)
# Run 2 lives in its own workspace, but the browser Web UI may auto-create an
# extra blank session there. The experiment session is therefore identified by an
# EXPLICIT id recorded at Stage A, never by "most recent".
WRL "--- exact session lock ---"
$expSession = $null
if ($Stage -eq 'A') {
  $all = @()
  if ($cur -and $cur.WorkspaceDirFound) { $all = @($cur.AllSessions) }
  if ($all.Count -eq 0) {
    FAIL "Stage A: no session in $WorkspacePath -> cannot lock an experiment session"
  } elseif ($all.Count -gt 1) {
    WARN ("Stage A: workspace already has {0} sessions; locking the NEWEST. Verify it is the one Desktop just created." -f $all.Count)
    $expSession = $all | Sort-Object Utc -Descending | Select-Object -First 1
  } else {
    $expSession = $all[0]
  }
  if ($expSession) {
    if ($expSession.Format -ne 'v4') { WARN ("experiment session format is {0}, expected v4" -f $expSession.Format) }
    $lock = [PSCustomObject]@{
      SchemaVersion=1
      RunName=$RunName; LockedAt=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
      WorkspacePath=$WorkspacePath; WorkspaceDir=$cur.WorkspaceDir
      WorkspaceDirName=$meta.WorkspaceDirName
      MetadataPath=$ctx.MetadataPath
      BaselineDir=$baselineDir
      SessionId=$expSession.SessionId; File=$expSession.File; Format=$expSession.Format
      SizeAtLock=$expSession.Size; Sha256AtLock=$expSession.Sha256
      ProjCache=$expSession.ProjCache
    }
    $lock | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $lockPath -Encoding UTF8
    OK ("locked experiment session: {0} ({1}, {2} B)" -f $expSession.SessionId, $expSession.Format, $expSession.Size)
    WRL ("  lock file: {0}" -f $lockPath)
  }
} else {
  if (-not (Test-Path $lockPath)) {
    FAIL "session lock missing at $lockPath -> run Stage A first"
  } else {
    $lock = Get-Content $lockPath -Raw -Encoding UTF8 | ConvertFrom-Json
    WRL ("  locked id : {0} (format {1}, locked {2})" -f $lock.SessionId, $lock.Format, $lock.LockedAt)
    # lock identity was already validated before the capture; here we only locate the session
    $all = @()
    if ($cur -and $cur.WorkspaceDirFound) { $all = @($cur.AllSessions) }
    $expSession = $all | Where-Object { $_.SessionId -eq $lock.SessionId } | Select-Object -First 1
    if ($null -eq $expSession) {
      FAIL ("locked experiment session {0} is GONE from the workspace" -f $lock.SessionId)
    } else {
      OK ("experiment session located: {0} ({1}, {2} B)" -f $expSession.SessionId, $expSession.Format, $expSession.Size)
      if ($all.Count -gt 1) {
        $others = ($all | Where-Object { $_.SessionId -ne $lock.SessionId } | ForEach-Object { $_.SessionId }) -join ', '
        INFO ("other sessions in this workspace (NOT the experiment): {0}" -f $others)
      }
    }
  }
}
WRL ""
function Get-DirListing {
  param([string]$DirPath)
  if (-not (Test-Path $DirPath)) { return @() }
  return @(Get-ChildItem $DirPath -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
    [PSCustomObject]@{ Name=$_.Name; Size=$_.Length; Sha=(Get-FileHash $_.FullName -Algorithm SHA256).Hash }
  })
}

if ($prevDir -and (Test-Path $prevDir) -and $expSession) {
  WRL "--- experiment-session file listing diff ($prevStage -> $Stage) ---"
  $prevSnap = Get-SessionSnapshot -Dir $prevDir
  $prevSessionDir = ''
  if ($prevSnap -and $prevSnap.AllSessions) {
    $pm = @($prevSnap.AllSessions) | Where-Object { $_.SessionId -eq $expSession.SessionId } | Select-Object -First 1
    if ($pm) { $prevSessionDir = $pm.Dir }
  }
  $curSessionDir = $expSession.Dir

  if ($prevSessionDir -and $curSessionDir -and (Test-Path $prevSessionDir) -and (Test-Path $curSessionDir)) {
    $pl = @{}; foreach ($x in (Get-DirListing $prevSessionDir)) { $pl[$x.Name] = $x }
    $cl = @{}; foreach ($x in (Get-DirListing $curSessionDir)) { $cl[$x.Name] = $x }
    $added   = @($cl.Keys | Where-Object { -not $pl.ContainsKey($_) } | Sort-Object)
    $removed = @($pl.Keys | Where-Object { -not $cl.ContainsKey($_) } | Sort-Object)
    WRL ("  added files   : {0}" -f (($added -join ', ') -replace '^$','(none)'))
    WRL ("  removed files : {0}" -f (($removed -join ', ') -replace '^$','(none)'))
    foreach ($a in $added) {
      if ($a -match '\.bak$|\.imported$|\.orig$|\.old$') { FAIL "new backup-ish artifact in experiment session: $a" }
      if ($a -match '^session\.v\d+\.jsonl\.zstd$') { FAIL "SECOND session format file appeared: $a" }
    }
  } else {
    INFO "session directory listing diff skipped (previous session dir unavailable)"
  }
  WRL ""
} else {
  WRL "--- experiment-session file listing diff ---"
  FAIL "previous stage capture dir missing: $prevDir (label '$prevStage') - the declared baseline/predecessor must exist"
  WRL ""
}

# ---------------------------------------------------------------- 4. D compare (fail-closed)
# $diffValid = $true only when the diff actually ran, produced a complete report, and the
# detail rows agree with the per-section change counts.
# A ZERO-ROW compare-detail.csv is LEGAL (it only records entries that CHANGED), so it is
# never treated as "invalid"; detailRows == expectedDetailRows is the real check.
# Every stage has a predecessor: Stage A diffs the sealed baseline, B diffs A, C diffs B.
$diffValid = $true
$cmpDir = $null
if ($prevStage) {
  if (-not ($prevDir -and (Test-Path -LiteralPath $prevDir -PathType Container))) {
    FAIL "previous stage capture dir missing: $prevDir (label '$prevStage')  (stage sequence broken)"
    $diffValid = $false
  } else {
    # compare dir comes from metadata; it is never derived from the run name at call time.
    $cmpDir = [string]$prevInfo.CompareDir
    WRL "--- running compare-captures.ps1 ($prevStage -> $Stage) ---"
    WRL ("  before = {0}" -f $prevDir)
    WRL ("  after  = {0}" -f $stageDir)
    # named $cmpResult, not $cmp: PowerShell variable names are case-insensitive and a
    # variable named $cmp would silently clobber a $CMP path variable.
    $cmpResult = Invoke-GuardedCompare -ToolsDir $ToolsDir -Before $prevDir -After $stageDir -OutDir $cmpDir
    $diffValid = $cmpResult.Ok
    foreach ($e in $cmpResult.Errors) { FAIL ("[compare] " + $e) }
    if ($cmpResult.Ok) {
      OK ("compare valid: detailRows={0} expectedDetailRows={1} warnings={2}" -f `
          $cmpResult.DetailRows, $cmpResult.ExpectedDetailRows, $cmpResult.Warnings)
      $cmpReport = Join-Path $cmpDir 'compare-report.txt'
      foreach ($ln in (Get-Content -LiteralPath $cmpReport -Encoding UTF8)) {
        if ($ln -match 'CONTENT-CHANGED|ADDED|DELETED|MTIME-ONLY|total tracked') { WRL ("    " + $ln.Trim()) }
      }
      if ($cmpResult.DetailRows -eq 0) { INFO "zero-row diff: every section reported 0 changes (not an error)" }
    } else {
      WRL ("  diff INVALID -> a missing/skipped section, a bad count block, or a report/detail mismatch")
    }
    WRL ""
  }
}

# ---------------------------------------------------------------- 5. shared-state change CLASSIFIER
# Three classes (per review):
#   A. EXPECTED CROSS-VERSION SETTINGS CHURN   -> continue
#   B. UNEXPECTED CONTENT CHANGE               -> WARN, human review, continue
#   C. DESTRUCTIVE CHANGE                      -> STOP
# Rationale: Desktop 0.2.x renames settings.yaml -> settings.yaml.imported by design, and
# old Web 0.1.5 re-creates a minimal settings.yaml when the active file is missing. Those two
# are KNOWN interoperability behaviours and must not be reported as "unknown pollution".
# A benign one-time `session/end-seed` append (see dsh-session constructor) is also class A.
WRL "--- shared-state change classification (A/B/C) ---"
$EXPECTED_SETTINGS_CHURN = @('settings.yaml','settings.yaml.imported')
$DESTRUCTIVE_PATTERNS = @(
  '^profiles\\browser-lab\\', '^profiles\\web\\',
  '^cordis\.patch\.yml$', '^package\.json$', '^AGENTS\.md$'
)
$classA = New-Object System.Collections.Generic.List[string]
$classB = New-Object System.Collections.Generic.List[string]
$classC = New-Object System.Collections.Generic.List[string]

# --- 5a. explicit shared-state file list vs THE BOUND BASELINE
# $baselineDir is the single, metadata-declared baseline (validated in section 0b: it exists,
# is sealed, belongs to this run and this workspace, and its manifests still match the seal).
# It is NOT derived from $RunName. There is no fallback and no second baseline variable.
# Historical namespaces (e1-BASE contaminated; e1-BASE-QUIESCENT R1 invalid) are never used.
$baseMan = Join-Path $baselineDir 'shared-state-manifest.csv'
$curMan  = Join-Path $stageDir 'shared-state-manifest.csv'
if (-not (Test-Path $baseMan)) {
  FAIL "bound baseline has no shared-state-manifest.csv -> change classifier CANNOT run."
  WRL ("       bound baseline : {0}" -f $baselineDir)
  WRL ("       metadata       : {0}" -f $ctx.MetadataPath)
} else {
  $b = @{}; foreach ($r in (Import-Csv -LiteralPath $baseMan)) { $b[[string]$r.Rel] = $r }
  $c = @{}; foreach ($r in (Import-Csv -LiteralPath $curMan))  { $c[[string]$r.Rel] = $r }
  foreach ($k in ($c.Keys | Sort-Object)) {
    $x = $b[$k]; $y = $c[$k]
    if ($null -eq $x) {
      if ($k -match '^settings\.yaml') { $classA.Add("ADDED     $k   (old Web re-bootstrapped legacy settings)") }
      else { $classC.Add("ADDED     $k") }
      continue
    }
    if ([string]$x.Size -eq 'ABSENT' -and [string]$y.Size -ne 'ABSENT') {
      if ($DESTRUCTIVE_PATTERNS | Where-Object { $k -match $_ }) { $classC.Add("APPEARED  $k") }
      elseif ($k -match '^settings\.yaml') { $classA.Add("APPEARED  $k   (old Web re-bootstrapped legacy settings)") }
      else { $classB.Add("APPEARED  $k") }
      continue
    }
    if ([string]$y.Size -eq 'ABSENT' -and [string]$x.Size -ne 'ABSENT') {
      if ($k -eq 'settings.yaml') { $classA.Add("GONE      $k   (Desktop 0.2 renamed it to .imported)") }
      elseif ($DESTRUCTIVE_PATTERNS | Where-Object { $k -match $_ }) { $classC.Add("DELETED   $k") }
      else { $classB.Add("DELETED   $k") }
      continue
    }
    if ([string]$x.Sha256 -ne [string]$y.Sha256) {
      if ($EXPECTED_SETTINGS_CHURN -contains $k) { $classA.Add("CHANGED   $k   (cross-version settings churn)") }
      elseif ($k -eq 'profiles\desktop\cordis.patch.yml') { $classA.Add("CHANGED   $k   (0.2.x import target)") }
      elseif ($DESTRUCTIVE_PATTERNS | Where-Object { $k -match $_ }) { $classC.Add("CHANGED   $k") }
      else { $classB.Add("CHANGED   $k") }
    }
  }
  foreach ($k in ($b.Keys | Sort-Object)) { if (-not $c.ContainsKey($k)) { $classC.Add("MISSING   $k") } }
}

# --- 5b. existing sessions (excluding the experiment workspace)
# SAME binding as 5a: $baselineDir, never a second baseline variable.
$rtWsName = ''
if ($expSession -and $expSession.Dir) { $rtWsName = Split-Path (Split-Path $expSession.Dir -Parent) -Leaf }
$baseInv = Join-Path $baselineDir 'session-inventory.csv'
$curInv  = Join-Path $stageDir 'session-inventory.csv'
if ((Test-Path $baseInv) -and (Test-Path $curInv)) {
  $bi = @{}; foreach ($r in (Import-Csv -LiteralPath $baseInv)) { $bi[[string]$r.Rel] = $r }
  $ci = @{}; foreach ($r in (Import-Csv -LiteralPath $curInv))  { $ci[[string]$r.Rel] = $r }
  foreach ($k in ($ci.Keys | Sort-Object)) {
    if ($rtWsName -and $k -like "$rtWsName*") { continue }        # experiment workspace sessions
    $x = $bi[$k]; $y = $ci[$k]
    if ($null -eq $x) { $classC.Add("SESSION ADDED   $k"); continue }
    if ($y.Format -ne $x.Format) { $classC.Add("SESSION FORMAT CHANGED  $k : $($x.Format) -> $($y.Format)"); continue }
    if ([string]$x.Sha256 -eq [string]$y.Sha256) { continue }
    # content changed: is it the known one-time session/end-seed append?
    # REQUIRES: the baseline did NOT already end with session/end-seed (a repeat
    # append after the marker is an anomaly, per review) and endSeedCount grew by 1.
    $esBefore = [string]$x.EndSeedCount; $esAfter = [string]$y.EndSeedCount
    $baseAlreadyEnded = ($x.LastType -eq 'session/end-seed')
    if ($y.LastType -eq 'session/end-seed' -and -not $baseAlreadyEnded -and
        $esBefore -ne '' -and $esAfter -ne '' -and ([int]$esAfter -eq [int]$esBefore + 1)) {
      $classA.Add("SESSION end-seed APPEND  $k : events $($x.Events)->$($y.Events), endSeedCount $esBefore->$esAfter (non-destructive, one-time)")
    } elseif ($baseAlreadyEnded -and $esAfter -ne $esBefore) {
      $classC.Add("SESSION REPEAT end-seed APPEND (guard violated)  $k : endSeedCount $esBefore->$esAfter")
    } else {
      $classB.Add("SESSION CONTENT CHANGED  $k : lastType=$($y.LastType) events=$($x.Events)->$($y.Events)  <-- decode this session to classify")
    }
  }
  foreach ($k in ($bi.Keys | Sort-Object)) {
    if ($rtWsName -and $k -like "$rtWsName*") { continue }
    if (-not $ci.ContainsKey($k)) { $classC.Add("SESSION DELETED  $k") }
  }
} else { FAIL "bound baseline has no session-inventory.csv -> session classifier CANNOT run" }

WRL ("  A. EXPECTED CROSS-VERSION SETTINGS CHURN : {0}" -f $classA.Count)
$classA | ForEach-Object { WRL ("      " + $_) }
WRL ("  B. UNEXPECTED CONTENT CHANGE             : {0}" -f $classB.Count)
$classB | ForEach-Object { WARN ("    " + $_) }
WRL ("  C. DESTRUCTIVE CHANGE                    : {0}" -f $classC.Count)
$classC | ForEach-Object { FAIL ("    " + $_) }
if ($classC.Count -eq 0 -and $classB.Count -eq 0) { OK "no destructive and no unexpected change" }
WRL ""

# ---------------------------------------------------------------- 6. profile / home invariants
WRL "--- profile / home invariants (must hold at every stage) ---"
$manifest = Join-Path $stageDir 'shared-state-manifest.csv'
if (Test-Path $manifest) {
  $rows = @{}; foreach ($r in (Import-Csv -LiteralPath $manifest)) { $rows[[string]$r.Rel] = $r }
  $checks = @(
    @('home cordis.patch.yml must be ABSENT', 'cordis.patch.yml', 'ABSENT'),
    @('home package.json must be ABSENT',     'package.json',     'ABSENT'),
    @('browser-lab/package.json',             'profiles\browser-lab\package.json', 'A225D87A466F586DA6AF9A3615AECD21C48FC0038BC1322700BD3B4F8A92C39B'),
    @('browser-lab/cordis.patch.yml',         'profiles\browser-lab\cordis.patch.yml', 'EFBE0E95CB160B52C2F3D5B3C204F1EF6963932EBD99E96F2524D60F74F30C76'),
    @('web/package.json',                     'profiles\web\package.json', 'B07F71CBA5C341F6BD6EBF1316573588817E3A15629A86F11D34D4A01A82C94B'),
    @('web/cordis.patch.yml',                 'profiles\web\cordis.patch.yml', 'EF189A8C27DB6D63930AA3046A3040482E952EAFCB7487C644D508E8D461F027'),
    @('AGENTS.md (global)',                   'AGENTS.md', 'DFBC51358430BDC0091658C62925BFA9385621F6E07197BFADDC7B19A043872C')
  )
  foreach ($c in $checks) {
    $label = $c[0]; $rel = $c[1]; $want = $c[2]
    $r = $rows[$rel]
    if ($null -eq $r) { WARN "$label : not present in manifest" ; continue }
    $got = [string]$r.Sha256
    if ($want -eq 'ABSENT') {
      if ($r.Size -eq 'ABSENT') { OK "$label = ABSENT" } else { FAIL "$label is PRESENT (sha=$got) - shared-layer leak" }
    } else {
      if ($got -eq $want) { OK "$label unchanged" } else { FAIL "$label CHANGED (now $got)" }
    }
  }
} else { FAIL "shared-state-manifest.csv missing -> invariants NOT checked (this is not a pass)" }
WRL ""

# ---------------------------------------------------------------- 7. human-observed checklist
WRL "--- human-observed items (fill in when reporting back) ---"
switch ($Stage) {
  'A' {
    WRL "  A1 Desktop showed a normal reply to 'E1 interoperability marker' : YES / NO"
    WRL "  A2 session title shown in Desktop UI                              : <paste>"
    WRL "  A3 Desktop fully exited (tray/background too)                     : YES / NO"
  }
  'B' {
    WRL "  B1 Web could DISCOVER the session            : YES / NO"
    WRL "  B2 Web could OPEN it                         : YES / NO"
    WRL "  B3 Desktop marker text rendered correctly     : YES / NO"
    WRL "  B4 Desktop reply rendered correctly           : YES / NO"
    WRL "  B5 any UI error shown                         : YES / NO  (paste if yes)"
    WRL "  B6 (no message was sent in stage B)           : confirmed YES / NO"
  }
  'C' {
    WRL "  C1 Web continuation got a normal reply        : YES / NO"
    WRL "  C2 'E1 web continuation marker' persisted     : YES / NO"
    WRL "  C3 Desktop 'E1 interoperability marker' still present : YES / NO"
    WRL "  C4 any UI error shown                         : YES / NO  (paste if yes)"
  }
}
WRL ""

# ---------------------------------------------------------------- 8. stage verdict
WRL "================================================================"
WRL "STAGE $Stage VERDICT"
WRL ("  run metadata              : {0}" -f $ctx.MetadataPath)
WRL ("  baseline (bound)          : {0}" -f $baselineDir)
WRL ("  baseline sealed at        : {0}" -f $ctx.Binding.SealedAt)
WRL ("  previous stage            : {0} -> {1}" -f $prevStage, $stageDir)
WRL ("  capture pipeline valid    : {0}   (A/B/C children ran + sentinels non-empty + sanity minimums)" -f $captureValid)
WRL ("  diff valid                : {0}   (compare ran + complete sections + detailRows == expectedDetailRows)" -f $diffValid)
WRL ("  STOP conditions triggered : {0}" -f $script:stops)
WRL ("  WARN items                : {0}" -f $script:warns)
if (-not $captureValid)       { WRL "  RESULT: *** ABORTED - CAPTURE INCOMPLETE ***  - no verdict may be derived" }
elseif (-not $diffValid)      { WRL "  RESULT: *** STOP ***  - diff INVALID; 'no change' cannot be concluded" }
elseif ($script:stops -gt 0)  { WRL "  RESULT: *** STOP ***  - report back before continuing" }
elseif ($script:warns -gt 0)  { WRL "  RESULT: CONTINUE WITH CAUTION - review WARN lines, they may be expected" }
else                          { WRL "  RESULT: CLEAN" }
WRL ""
WRL "REMINDERS (corrected criteria)"
WRL "  * A->B content hash change => classify as 'IMPLICIT REWRITE ON OPEN'. It is NOT by itself a stop."
WRL "  * B->C content hash change => EXPECTED (Web continued the session). Never treat as an anomaly."
WRL "  * STOP only on: history destroyed / session unopenable / format downgrade /"
WRL "    second-format conflict / .bak-.imported artifacts / existing sessions affected."

$script:report | Set-Content -LiteralPath (Join-Path $stageDir 'e1-stage-report.txt') -Encoding UTF8
Write-Host ""
Write-Host ("report written: {0}" -f (Join-Path $stageDir 'e1-stage-report.txt'))

# ---- explicit exit code: a STOP must never be readable as success ----------
$stageOk = $captureValid -and $diffValid -and ($script:stops -eq 0)
if ($stageOk) { exit 0 } else { exit 1 }

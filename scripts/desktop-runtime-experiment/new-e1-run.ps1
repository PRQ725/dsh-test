<#
.SYNOPSIS
  Create the isolated workspace, instruction fixture and run metadata for an E1 run.

.DESCRIPTION
  It creates:
    * the isolated workspace directory (must start with ZERO sessions)
    * the AGENTS.md instruction fixture, byte-identical to the run1/run2 fixture
    * <Root>\e1-<RunName>.metadata.json  with BaselineVerified = false

  It does NOT capture anything, does NOT start any host, and does NOT delete anything.
  A baseline becomes usable only after capture-e1-quiescent-baseline.ps1 -MetadataPath
  reports PASS and SEALS this metadata.

  Idempotent in the safe direction: if the metadata already exists it refuses to overwrite
  unless -Force is supplied, and it never rewrites an existing AGENTS.md.

.PARAMETER RunName
  Run namespace, e.g. run3.

.PARAMETER WorkspacePath
  Isolated workspace, e.g. D:\Projects\dsh-desktop-runtime-test-3.

.PARAMETER BaselineNamespace
  Evidence directory name for the quiescent baseline, e.g. e1-BASE-QUIESCENT-R3.

.EXAMPLE
  .\new-e1-run.ps1 -RunName run3 -WorkspacePath D:\Projects\dsh-desktop-runtime-test-3 -BaselineNamespace e1-BASE-QUIESCENT-R3
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$RunName,
  [Parameter(Mandatory=$true)][string]$WorkspacePath,
  [Parameter(Mandatory=$true)][string]$BaselineNamespace,
  [string]$Root = 'D:\Projects\dsh-test\evidence\desktop\runtime',
  [string]$ToolsDir = 'D:\Projects\dsh-test\scripts\desktop-runtime-experiment',
  [string]$DshHome = 'C:\Users\user02\.dsh',
  [string]$FixtureSource = '',
  [switch]$Force
)

$ErrorActionPreference = 'Continue'
$script:stops = 0
function WRL($m)  { Write-Host $m }
function OK($m)   { WRL ("[PASS] " + $m) }
function WARN($m) { WRL ("[WARN] " + $m) }
function FAIL($m) { $script:stops++; WRL ("[STOP] " + $m) }

WRL "================================================================"
WRL ("NEW E1 RUN '{0}'   ({1})" -f $RunName, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
WRL "================================================================"
WRL ""

foreach ($s in @('capture-run-config.ps1')) {
  if (-not (Test-Path (Join-Path $ToolsDir $s))) { FAIL "missing tool script: $s" }
}
if ($script:stops -gt 0) { exit 1 }
. (Join-Path $ToolsDir 'capture-run-config.ps1')

if (-not (Test-Path -LiteralPath $Root -PathType Container)) { FAIL "evidence root missing: $Root" }
if ($script:stops -gt 0) { exit 1 }

$metaPath = Get-E1MetadataPath -Root $Root -RunName $RunName
if ((Test-Path -LiteralPath $metaPath) -and -not $Force) {
  FAIL ("metadata already exists: {0}   (use -Force only if you intend to re-declare the run)" -f $metaPath)
  exit 1
}

# ---- 1. workspace must exist (create it if needed) and must have ZERO sessions
$ws = Get-DshWorkspaceDirName -WorkspacePath $WorkspacePath -DshHome $DshHome
if (-not (Test-Path -LiteralPath $WorkspacePath -PathType Container)) {
  New-Item -ItemType Directory -Path $WorkspacePath -Force | Out-Null
  OK ("created workspace: {0}" -f $WorkspacePath)
} else {
  OK ("workspace already exists: {0}" -f $WorkspacePath)
}
if (-not (Test-Path -LiteralPath $WorkspacePath -PathType Container)) { FAIL "cannot create workspace: $WorkspacePath"; exit 1 }

$sessCount = 0
if (Test-Path -LiteralPath $ws.FullPath -PathType Container) {
  $sessCount = @(Get-ChildItem -LiteralPath $ws.FullPath -Directory -Force -ErrorAction SilentlyContinue).Count
}
WRL ("  session dir : {0}" -f $ws.FullPath)
WRL ("  sessions    : {0}" -f $sessCount)
if ($sessCount -gt 0) {
  FAIL ("workspace already has {0} session(s) - an E1 run needs a workspace starting at ZERO sessions" -f $sessCount)
  WRL "       Do not delete them; choose a new -WorkspacePath (e.g. ...-test-4)."
  exit 1
}
OK "workspace starts with 0 sessions"

# ---- 2. instruction fixture, byte-identical to the earlier runs
$fixtureDst = Join-Path $WorkspacePath 'AGENTS.md'
if (-not $FixtureSource) {
  # prefer run2's fixture, then run1's
  foreach ($cand in @('D:\Projects\dsh-desktop-runtime-test-2\AGENTS.md','D:\Projects\dsh-desktop-runtime-test\AGENTS.md')) {
    if (Test-Path -LiteralPath $cand -PathType Leaf) { $FixtureSource = $cand; break }
  }
}
$fixtureSha = ''
if (Test-Path -LiteralPath $fixtureDst -PathType Leaf) {
  $fixtureSha = (Get-FileHash -LiteralPath $fixtureDst -Algorithm SHA256).Hash
  OK ("AGENTS.md already present (sha256={0}) - NOT rewritten" -f $fixtureSha)
} elseif ($FixtureSource -and (Test-Path -LiteralPath $FixtureSource -PathType Leaf)) {
  $bytes = [System.IO.File]::ReadAllBytes($FixtureSource)
  [System.IO.File]::WriteAllBytes($fixtureDst, $bytes)
  $fixtureSha = (Get-FileHash -LiteralPath $fixtureDst -Algorithm SHA256).Hash
  OK ("AGENTS.md fixture written byte-identically from {0} (sha256={1}, {2} B)" -f $FixtureSource, $fixtureSha, $bytes.Length)
} else {
  FAIL "no AGENTS.md fixture source found; pass -FixtureSource explicitly"
  exit 1
}

# ---- 3. metadata (unsealed)
$meta = New-E1RunMetadata -RunName $RunName -Root $Root -WorkspacePath $WorkspacePath `
                          -BaselineNamespace $BaselineNamespace -DshHome $DshHome `
                          -BaselineSource 'capture-e1-quiescent-baseline.ps1'
foreach ($e in (Test-E1RunMetadataShape -Metadata $meta)) { FAIL $e }
if ($script:stops -gt 0) { exit 1 }
Save-E1RunMetadata -Metadata $meta -Path $metaPath
OK ("metadata written: {0}" -f $metaPath)

WRL ""
WRL "DECLARED BINDING"
foreach ($n in @('RunName','WorkspacePath','WorkspaceDirName','WorkspaceSessionDir','BaselineNamespace','BaselineDir','BaselineVerifyDir','BaselineVerdictPath')) {
  WRL ("  {0,-20}: {1}" -f $n, $meta.$n)
}
WRL ("  {0,-20}: A={1}" -f 'StageDirs', $meta.StageDirs.A)
WRL ("  {0,-20}: B={1}" -f '', $meta.StageDirs.B)
WRL ("  {0,-20}: C={1}" -f '', $meta.StageDirs.C)
WRL ("  {0,-20}: {1}" -f 'LockFile', $meta.LockFile)
WRL ("  {0,-20}: {1}  (must become true before any stage may run)" -f 'BaselineVerified', $meta.BaselineVerified)
WRL ""
WRL "NEXT (human, from an EXTERNAL PowerShell - no DSH host running):"
WRL ("  1. stop Desktop, browser-lab and this research host; free ports 3080/3180")
WRL ("  2. .\capture-e1-quiescent-baseline.ps1 -Namespace {0} -MetadataPath `"{1}`" -WorkspacePath `"{2}`"" -f $BaselineNamespace, $metaPath, $WorkspacePath)
WRL ("  3. require QUIESCENT BASELINE: PASS (the script seals the metadata)")
WRL ("  4. start Desktop and do the Stage A manual actions")
WRL ("  5. .\e1-capture.ps1 -RunName {0} -Stage A -LockSession" -f $RunName)
WRL ""
WRL "RUN CREATED (baseline NOT yet captured, NOT yet sealed)"
exit 0

<#
.SYNOPSIS
  Control B (minimal B1): build the isolated home for the matched-version v4 read test.

.DESCRIPTION
  Injects ONLY what Control B needs to list and open one v4 session:
    * the run3 v4 session log (a COPY; the source is never modified)
    * its projcache file (a COPY)
    * a minimal storages\workspace.json whose run3 entry lists that session id

  It deliberately does NOT copy credentials, tokens, other sessions, the browser-lab/web
  profiles, PJOS, the dsh-test research session, or the real settings history.

  ADDITIVE ONLY. The real home is read, never written. This is the one script in this folder
  that uses Copy-Item, and every copy target is inside the isolated home.

  Source-of-truth paths are asserted, not guessed.

.PARAMETER IsolatedHome
  Must be exactly D:\Projects\dsh-desktop-controlB-home.

.EXAMPLE
  .\control-b-prep.ps1
#>
[CmdletBinding()]
param(
  [string]$IsolatedHome = 'D:\Projects\dsh-desktop-controlB-home',
  [string]$RealHome = 'C:\Users\user02\.dsh',
  [string]$WorkspacePath = 'D:\Projects\dsh-desktop-runtime-test-3',
  [string]$SessionId = 'session-0d5e7d0c-c341-48c4-a149-81250d473f20',
  [string]$WorkspaceDirName = '--D-Projects-dsh-desktop-runtime-test-3--',
  [string]$WorkspaceUuid = 'ef6f489c-c00b-46ac-94ce-1581a8137b3f',
  [string]$ExpectedSha256 = '64B4257A37C14035792E0806679A86EC19C683D0E2A9A477060E6621D5777EDB'
)

$ErrorActionPreference = 'Continue'
$script:stops = 0
$script:report = New-Object System.Collections.Generic.List[string]
function WRL($m) { $script:report.Add([string]$m) | Out-Null; Write-Host $m }
function OK($m)  { WRL ("[PASS] " + $m) }
function FAIL($m){ $script:stops++; WRL ("[FATAL] " + $m) }
function INFO($m){ WRL ("[INFO] " + $m) }

WRL "================================================================"
WRL ("CONTROL B - isolated home preparation   ({0})" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
WRL ("isolated : {0}" -f $IsolatedHome)
WRL ("real     : {0}  (READ-ONLY)" -f $RealHome)
WRL "================================================================"
WRL ""

# ---- fixed safety assertion: never build in the real home ----------------
if ($IsolatedHome -eq $RealHome) { FAIL "IsolatedHome must not be the real home"; exit 1 }
if (-not $IsolatedHome.EndsWith('dsh-desktop-controlB-home')) { FAIL "unexpected IsolatedHome: $IsolatedHome"; exit 1 }
if (-not (Test-Path -LiteralPath $RealHome -PathType Container)) { FAIL "real home not found: $RealHome"; exit 1 }

$SrcSession = Join-Path $RealHome ("sessions\" + $WorkspaceDirName + "\" + $SessionId + "\session.v4.jsonl.zstd")
$SrcProjcache = Join-Path $RealHome ("storages\session_projcache\sessions\" + $SessionId + ".json")
$DstSessionDir = Join-Path $IsolatedHome ("sessions\" + $WorkspaceDirName + "\" + $SessionId)
$DstSession = Join-Path $DstSessionDir 'session.v4.jsonl.zstd'
$DstProjcacheDir = Join-Path $IsolatedHome 'storages\session_projcache\sessions'
$DstProjcache = Join-Path $DstProjcacheDir ($SessionId + '.json')
$DstWorkspaceJson = Join-Path $IsolatedHome 'storages\workspace.json'

foreach ($p in @($SrcSession,$SrcProjcache)) {
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { FAIL "required source missing: $p" }
}
if ($script:stops -gt 0) { exit 1 }

$srcSha = (Get-FileHash -LiteralPath $SrcSession -Algorithm SHA256).Hash
$srcSize = (Get-Item -LiteralPath $SrcSession).Length
INFO ("source v4 log   : {0} B  sha256={1}" -f $srcSize, $srcSha)
if ($srcSha -ne $ExpectedSha256) { FAIL "source v4 log sha256 does not match the recorded run3 value"; exit 1 }
INFO ("source projcache: {0} B" -f (Get-Item -LiteralPath $SrcProjcache).Length)
WRL ""

# ---- create the isolated home -------------------------------------------
foreach ($d in @($IsolatedHome,$DstSessionDir,$DstProjcacheDir,(Join-Path $IsolatedHome 'storages'))) {
  if (-not (Test-Path -LiteralPath $d -PathType Container)) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    OK ("created {0}" -f $d)
  }
}

# ---- copy the v4 log and its projcache (additive) ------------------------
Copy-Item -LiteralPath $SrcSession -Destination $DstSession -Force
Copy-Item -LiteralPath $SrcProjcache -Destination $DstProjcache -Force
$dstSha = (Get-FileHash -LiteralPath $DstSession -Algorithm SHA256).Hash
if ($dstSha -ne $srcSha) { FAIL "copied v4 log differs from the source"; exit 1 }
OK ("v4 log copied byte-identically: {0} B  sha256={1}" -f (Get-Item -LiteralPath $DstSession).Length, $dstSha)
OK ("projcache copied: {0} B" -f (Get-Item -LiteralPath $DstProjcache).Length)

# ---- minimal workspace registry -----------------------------------------
# Shape copied from the live real-home file (unit 'workspace', version 2). Only the fields
# the workspace store needs for one workspace with one session are written.
$registry = [ordered]@{
  unit   = [ordered]@{ name = 'workspace'; version = 2 }
  global = [ordered]@{
    initialized        = $true
    workspaceIds       = @($WorkspaceUuid)
    archivedSessionIds = @()
    pinnedSessionIds   = @()
  }
  tables = [ordered]@{
    workspaces = [ordered]@{
      $WorkspaceUuid = [ordered]@{
        path       = $WorkspacePath
        title      = 'dsh-desktop-runtime-test-3'
        sessionIds = @($SessionId)
        createdAt  = '2026-10-05T07:39:39.165Z'
        updatedAt  = '2026-10-05T07:39:39.165Z'
      }
    }
  }
}
$registry | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $DstWorkspaceJson -Encoding UTF8
# CRITICAL: PowerShell 5.1's `Set-Content -Encoding UTF8` writes a UTF-8 BOM, and the
# runtime parses this file with a bare JSON.parse that REJECTS a BOM
# (`SyntaxError: Unexpected token '\uFEFF'`), which silently leaves the workspace registry,
# session controller and workspace controller in the `pending` state. The real file has no
# BOM (`7B 0A 20 20`), so rewrite ours without one.
$registryJson = Get-Content -LiteralPath $DstWorkspaceJson -Raw -Encoding UTF8 | ConvertFrom-Json | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($DstWorkspaceJson, $registryJson, (New-Object System.Text.UTF8Encoding($false)))
$wjBytes = [System.IO.File]::ReadAllBytes($DstWorkspaceJson)
if ($wjBytes[0] -eq 0xEF -and $wjBytes[1] -eq 0xBB -and $wjBytes[2] -eq 0xBF) { FAIL "workspace.json still has a BOM"; exit 1 }
OK "workspace.json is BOM-free (the runtime's JSON.parse rejects a BOM)"
$back = Get-Content -LiteralPath $DstWorkspaceJson -Raw -Encoding UTF8 | ConvertFrom-Json
$roundTripId = [string]$back.tables.workspaces.$WorkspaceUuid.sessionIds[0]
if ($roundTripId -ne $SessionId) { FAIL "workspace.json round-trip lost the session id"; exit 1 }
OK ("minimal workspace.json written: {0} B, sessionIds = [ {1} ]" -f (Get-Item -LiteralPath $DstWorkspaceJson).Length, $roundTripId)
WRL ""

# ---- report what was NOT copied (so the isolation is auditable) ----------
WRL "NOT copied (deliberately): credentials, account/session tokens, unrelated sessions,"
WRL "  browser-lab / web profiles, PJOS, the dsh-test research session, settings history."
WRL ""
WRL "ISOLATED HOME CONTENTS"
Get-ChildItem -LiteralPath $IsolatedHome -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
  WRL ("  {0,-72} {1,8} B" -f $_.FullName.Substring($IsolatedHome.Length), $_.Length)
}
WRL ""
WRL "source untouched check (re-hash after copy):"
$srcSha2 = (Get-FileHash -LiteralPath $SrcSession -Algorithm SHA256).Hash
if ($srcSha2 -ne $ExpectedSha256) { FAIL "the REAL source v4 log changed during preparation" } else { OK "real source v4 log unchanged" }

$out = Join-Path 'D:\Projects\dsh-test\evidence\desktop\runtime\controlB' 'controlB-prep-report.txt'
$dir = Split-Path $out -Parent
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$script:report | Set-Content -LiteralPath $out -Encoding UTF8
Write-Host ""
Write-Host ("report: {0}" -f $out)
if ($script:stops -gt 0) { exit 1 }
WRL "CONTROL B PREP: OK"
exit 0

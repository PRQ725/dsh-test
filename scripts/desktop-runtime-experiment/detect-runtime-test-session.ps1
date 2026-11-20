<#
.SYNOPSIS
  Script C - locate the session(s) belonging to the isolated runtime-test workspace.

.DESCRIPTION
  READ-ONLY. Never decodes, rewrites, or moves session files.

  Finds the $DSH_HOME\sessions\<workspace> directory whose name matches the
  target workspace path, then reports the most recent session:
  id, file name, format (v3/v4), size, utc, sha256, and the matching
  storages\session_projcache file.

.PARAMETER WorkspacePath
  The isolated test workspace, e.g. D:\Projects\dsh-desktop-runtime-test

.PARAMETER OutDir
  Directory to write outputs into.

.PARAMETER All
  If set, report ALL sessions in the workspace, not just the most recent.

.EXAMPLE
  .\detect-runtime-test-session.ps1 -OutDir D:\...\runtime\e1b -WorkspacePath D:\Projects\dsh-desktop-runtime-test
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$OutDir,
  [string]$WorkspacePath = 'D:\Projects\dsh-desktop-runtime-test',
  [switch]$All
)

$ErrorActionPreference = 'Continue'
$DSH = 'C:\Users\user02\.dsh'
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$script:problems = 0
function Note($m) { Write-Host $m }
function Flag($m) { Write-Host "  [!] $m" -ForegroundColor Yellow; $script:problems++ }

Note "=== SCRIPT C: detect runtime-test workspace session ==="
Note "WorkspacePath = $WorkspacePath"
Note "Time          = $stamp"
Note ""

# --- derive the expected DSH session-directory name -------------------------
# Observed convention:  D:\Projects\dsh-test  ->  --D-Projects-dsh-test--
#                        (drive colon and backslashes become '-', wrapped in '--')
$norm = $WorkspacePath -replace ':', '' -replace '\\', '-'
$expected = "--$norm--"
Note "expected session dir name (derived) : $expected"

$sessRoot = Join-Path $DSH 'sessions'
if (-not (Test-Path $sessRoot)) { Flag "sessions root missing: $sessRoot"; return }

$candidates = Get-ChildItem $sessRoot -Directory -Force -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -eq $expected -or $_.Name -match [regex]::Escape($norm) }

if (@($candidates).Count -eq 0) {
  Note "RESULT: NO session directory found for this workspace."
  Note "        (Desktop creates it only after a session is started in that workspace.)"
  $out = [PSCustomObject]@{
    CapturedAt=$stamp; WorkspacePath=$WorkspacePath; ExpectedDirName=$expected
    WorkspaceDirFound=$false; SessionCount=0; Session=$null
  }
  $out | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $OutDir 'runtime-test-session.json') -Encoding UTF8
  "RESULT: NOT FOUND" | Set-Content -LiteralPath (Join-Path $OutDir 'runtime-test-session.txt') -Encoding UTF8
  Note ""
  Note "=== SCRIPT C DONE (warnings: $script:problems) ==="
  return
}

foreach ($ws in $candidates) {
  Note ""
  Note "workspace session dir : $($ws.FullName)"
  Note "workspace dir utc      : $($ws.LastWriteTimeUtc.ToString('o'))"

  $sessions = @()
  foreach ($sd in (Get-ChildItem $ws.FullName -Directory -Force -ErrorAction SilentlyContinue)) {
    $files = @(Get-ChildItem $sd.FullName -File -Force -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '^session\.v\d+\.jsonl\.zstd$' })
    if ($files.Count -eq 0) {
      $sessions += [PSCustomObject]@{
        SessionId=$sd.Name; File='(none)'; Format='?'; Size=0
        Utc=$sd.LastWriteTimeUtc.ToString('o'); Sha256=''; Dir=$sd.FullName; ProjCache=''
      }
    } else {
      foreach ($f in $files) {
        $fmt = 'unknown'
        if ($f.Name -match '^session\.v(\d+)\.') { $fmt = 'v' + $Matches[1] }
        # map to projcache: projcache file is named <SessionId>.json
        $pcPath = Join-Path $DSH ("storages\session_projcache\sessions\" + $sd.Name + '.json')
        $pcSha = ''
        if (Test-Path $pcPath) { $pcSha = (Get-FileHash $pcPath -Algorithm SHA256).Hash }
        $sessions += [PSCustomObject]@{
          SessionId=$sd.Name; File=$f.Name; Format=$fmt; Size=$f.Length
          Utc=$f.LastWriteTimeUtc.ToString('o')
          Sha256=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
          Dir=$sd.FullName
          ProjCache=$(if ($pcSha) { $pcPath } else { '(none)' })
          ProjCacheSha=$pcSha
        }
      }
    }
  }

  $sessions = @($sessions | Sort-Object Utc -Descending)
  Note ("session count = {0}" -f $sessions.Count)

  $show = $sessions
  if (-not $All -and $sessions.Count -gt 0) { $show = @($sessions[0]) }

  foreach ($s in $show) {
    Note "  --------------------------------------------"
    Note "  SessionId    : $($s.SessionId)"
    Note "  File         : $($s.File)"
    Note "  Format       : $($s.Format)"
    Note "  Size         : $($s.Size)"
    Note "  Utc          : $($s.Utc)"
    Note "  Sha256       : $($s.Sha256)"
    Note "  ProjCache    : $($s.ProjCache)"
    Note "  ProjCacheSha : $($s.ProjCacheSha)"
  }

  $formats = $sessions | Group-Object Format | Sort-Object Name
  Note ""
  Note "  format breakdown:"
  foreach ($g in $formats) { Note ("    {0,-9} = {1}" -f $g.Name, $g.Count) }
  if (@($formats | Where-Object { $_.Name -eq 'v4' }).Count -gt 0 -and @($formats | Where-Object { $_.Name -eq 'v3' }).Count -gt 0) {
    Flag "MIXED formats present in the SAME workspace (v3 and v4 both exist)"
  }

  $out = [PSCustomObject]@{
    CapturedAt=$stamp; WorkspacePath=$WorkspacePath; ExpectedDirName=$expected
    WorkspaceDirFound=$true; WorkspaceDir=$ws.FullName; SessionCount=$sessions.Count
    Formats=($formats | ForEach-Object { $_.Name + ':' + $_.Count }) -join ', '
    MostRecent=$(if ($sessions.Count -gt 0) { $sessions[0] } else { $null })
    AllSessions=$sessions
  }
  $out | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $OutDir 'runtime-test-session.json') -Encoding UTF8

  $txt = @()
  $txt += "RUNTIME-TEST SESSION REPORT"
  $txt += "CapturedAt : $stamp"
  $txt += "Workspace  : $WorkspacePath"
  $txt += "Dir        : $($ws.FullName)"
  $txt += "Count      : $($sessions.Count)"
  $txt += "Formats    : $(($formats | ForEach-Object { $_.Name + '=' + $_.Count }) -join ' ')"
  if ($sessions.Count -gt 0) {
    $m = $sessions[0]
    $txt += ""
    $txt += "MOST RECENT"
    $txt += "  SessionId    : $($m.SessionId)"
    $txt += "  File         : $($m.File)"
    $txt += "  Format       : $($m.Format)"
    $txt += "  Size         : $($m.Size)"
    $txt += "  Utc          : $($m.Utc)"
    $txt += "  Sha256       : $($m.Sha256)"
    $txt += "  ProjCache    : $($m.ProjCache)"
    $txt += "  ProjCacheSha : $($m.ProjCacheSha)"
  }
  $txt | Set-Content -LiteralPath (Join-Path $OutDir 'runtime-test-session.txt') -Encoding UTF8
}

Note ""
Note "=== SCRIPT C DONE (warnings: $script:problems) ==="

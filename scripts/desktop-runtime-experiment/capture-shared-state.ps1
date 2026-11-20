<#
.SYNOPSIS
  Script B - capture shared $DSH_HOME state (hashes + session inventory).

.DESCRIPTION
  READ-ONLY. Never writes to $DSH_HOME, never starts/stops any process,
  never decodes or rewrites session files.

  Enumerates an EXPLICIT list of known paths (no recursive walk of $DSH_HOME),
  so junctions under profiles\node_modules are never traversed.

.PARAMETER OutDir
  Directory to write capture outputs into. Created if missing.

.PARAMETER Label
  Short label, e.g. "e1-pre-desktop" / "e1-post-web".

.EXAMPLE
  .\capture-shared-state.ps1 -OutDir D:\...\runtime\e1-pre -Label e1-pre-desktop
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$OutDir,
  [string]$Label = 'capture',
  # Opt-in: also decode every session log (read-only) to record event count and
  # last event type. Needed by the E1 change-classifier to tell a benign
  # one-time `session/end-seed` append from an unexpected rewrite.
  [switch]$DecodeSessions
)

$ErrorActionPreference = 'Continue'
$DSH = 'C:\Users\user02\.dsh'
$SessionSummaryScript = Join-Path $PSScriptRoot 'session-summary.mjs'
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$script:problems = 0
function Note($m) { Write-Host $m }
function Flag($m) { Write-Host "  [!] $m" -ForegroundColor Yellow; $script:problems++ }

Note "=== SCRIPT B: capture shared DSH_HOME state ==="
Note "OutDir = $OutDir"
Note "Label  = $Label"
Note "Time   = $stamp"
Note ("DecodeSessions = {0}" -f [bool]$DecodeSessions)
Note ""

# Read-only per-session summary via the existing decoder helper.
# Node's stdout cannot be captured through a PowerShell pipe in this
# environment, so summaries are APPENDED to one JSONL file inside OutDir.
# No temporary file is created and nothing is ever deleted.
function Add-SessionSummary {
  param([string]$Path)
  if (-not (Test-Path $SessionSummaryScript)) { return }
  if (-not $script:SessionSummaryJsonl) { return }
  cmd /c "node `"$SessionSummaryScript`" `"$Path`" >> `"$script:SessionSummaryJsonl`" 2>&1" | Out-Null
}

function Fingerprint {
  param([string]$Rel)
  $p = Join-Path $DSH $Rel
  if (Test-Path -LiteralPath $p -PathType Leaf) {
    $i = Get-Item -LiteralPath $p
    return [PSCustomObject]@{
      Rel    = $Rel
      Size   = $i.Length
      Utc    = $i.LastWriteTimeUtc.ToString('o')
      Sha256 = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash
    }
  }
  return [PSCustomObject]@{ Rel = $Rel; Size = 'ABSENT'; Utc = ''; Sha256 = '' }
}

# ---------------------------------------------------------------- 1. explicit file list
Note "[1/6] fingerprinting explicit file list ..."
$targets = New-Object System.Collections.Generic.List[string]
$targets.AddRange([string[]]@(
  'AGENTS.md',
  'settings.yaml',
  'settings.yaml.imported',
  '.credentials.yaml',
  '.anonymous-user-id',
  'cordis.patch.yml',
  'package.json',
  '.dshw-size.json','.dshw-turn.json','.dshw-usage.json','.dshw-bubble.json','.dshw-api.json','.dshw-codex.json'
))
# profile files (explicit names -> no directory walk)
foreach ($prof in @('desktop','browser-lab','web')) {
  foreach ($f in @('package.json','pnpm-lock.yaml','pnpm-workspace.yaml','cordis.patch.yml','cordis.yml')) {
    $targets.Add("profiles\$prof\$f")
  }
}
# storages (top-level files only)
Get-ChildItem (Join-Path $DSH 'storages') -File -Force -ErrorAction SilentlyContinue |
  ForEach-Object { $targets.Add("storages\" + $_.Name) }

$manifest = foreach ($t in $targets) { Fingerprint $t }
$manifest = @($manifest | Sort-Object Rel)
$manifest | Export-Csv -LiteralPath (Join-Path $OutDir 'shared-state-manifest.csv') -NoTypeInformation -Encoding UTF8

$present = @($manifest | Where-Object { $_.Size -ne 'ABSENT' })
$absent  = @($manifest | Where-Object { $_.Size -eq 'ABSENT' })
Note ("      present = {0}   absent = {1}" -f $present.Count, $absent.Count)
Note "      key values:"
foreach ($k in @('AGENTS.md','settings.yaml','settings.yaml.imported','.credentials.yaml','storages\workspace.json',
                 'profiles\desktop\package.json','profiles\desktop\cordis.patch.yml')) {
  $r = $manifest | Where-Object { $_.Rel -eq $k } | Select-Object -First 1
  if ($r) { Note ("        {0,-42} {1,10} {2}" -f $r.Rel, $r.Size, $r.Sha256) }
}
Note ""

# ---------------------------------------------------------------- 2. credentials METADATA only
Note "[2/6] credentials metadata (NO content read) ..."
$cred = Join-Path $DSH '.credentials.yaml'
$credInfo = [PSCustomObject]@{ Exists=$false; Size=$null; Utc=$null; Sha256=$null; LineCount=$null; TopKeyCount=$null }
if (Test-Path $cred) {
  $ci = Get-Item $cred
  # NOTE: we deliberately DO NOT parse or output the file body.
  # Line/key counts are obtained by counting newlines and indentation-0 keys only.
  $raw = Get-Content -LiteralPath $cred -Raw -Encoding UTF8
  $lines = ($raw -split "`n").Count
  $topKeys = @([regex]::Matches($raw, '(?m)^([A-Za-z0-9_\-\.]+)\s*:')).Count
  $credInfo = [PSCustomObject]@{
    Exists=$true; Size=$ci.Length; Utc=$ci.LastWriteTimeUtc.ToString('o')
    Sha256=(Get-FileHash $cred -Algorithm SHA256).Hash
    LineCount=$lines; TopKeyCount=$topKeys
  }
  # emit ONLY derived counts, never the body
  Note ("      size={0}  lines={1}  topLevelKeys={2}  sha256={3}" -f $credInfo.Size, $credInfo.LineCount, $credInfo.TopKeyCount, $credInfo.Sha256)
} else { Note "      ABSENT" }
$credInfo | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutDir 'credentials-metadata.json') -Encoding UTF8
Note ""

# ---------------------------------------------------------------- 3. session inventory
Note "[3/6] session inventory (names/sizes only; NOT decoded) ..."
$sessRoot = Join-Path $DSH 'sessions'

# --- pre-pass: decode every session once into session-summaries.jsonl (opt-in) ---
$summMap = @{}
if ($DecodeSessions) {
  $script:SessionSummaryJsonl = Join-Path $OutDir 'session-summaries.jsonl'
  # APPEND-ONLY: never truncate an evidence file. If it already exists (re-run of the
  # same stage dir) new summary lines are appended; the map below is keyed by file path,
  # so a later line simply replaces an earlier one for the same session.
  if (-not (Test-Path -LiteralPath $script:SessionSummaryJsonl)) {
    New-Item -ItemType File -Path $script:SessionSummaryJsonl -Force | Out-Null
  }
  $n = 0
  Get-ChildItem $sessRoot -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    Get-ChildItem $_.FullName -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
      Get-ChildItem $_.FullName -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^session\.v\d+\.jsonl\.zstd$' } | ForEach-Object {
          Add-SessionSummary -Path $_.FullName
          $n++
        }
    }
  }
  foreach ($line in (Get-Content -LiteralPath $script:SessionSummaryJsonl -Encoding UTF8 -ErrorAction SilentlyContinue)) {
    if (-not $line -or -not $line.Trim().StartsWith('{')) { continue }
    try {
      $o = $line | ConvertFrom-Json
      if ($o.ok) { $summMap[[string]$o.file] = $o }
    } catch { }
  }
  Note ("  decoded {0} session(s); summaries resolved for {1}" -f $n, $summMap.Count)
} else {
  Note "  (session decoding disabled; run with -DecodeSessions for event/last-event columns)"
}

$sessRows = @()
if (Test-Path $sessRoot) {
  foreach ($ws in (Get-ChildItem $sessRoot -Directory -Force -ErrorAction SilentlyContinue)) {
    foreach ($sd in (Get-ChildItem $ws.FullName -Directory -Force -ErrorAction SilentlyContinue)) {
      $files = Get-ChildItem $sd.FullName -File -Force -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '^session\.v\d+\.jsonl\.zstd$' }
      if (@($files).Count -eq 0) {
        $sessRows += [PSCustomObject]@{
          Rel="$($ws.Name)\$($sd.Name)\(none)"
          Workspace=$ws.Name; SessionId=$sd.Name; File='(none)'; Format='?'
          Size=0; Utc=$sd.LastWriteTimeUtc.ToString('o'); Sha256=''
          Events=''; LastType=''; LastSeq=''; LastTime=''; EndSeedCount=''
        }
      } else {
        foreach ($f in $files) {
          $fmt = 'unknown'
          if ($f.Name -match '^session\.v(\d+)\.') { $fmt = 'v' + $Matches[1] }
          $ev=''; $lt=''; $ls=''; $lm=''; $es=''
          if ($DecodeSessions) {
            $s = $summMap[[string]$f.FullName]
            if ($s) {
              $ev = $s.events; $lt = [string]$s.lastType; $ls = [string]$s.lastSeq
              $lm = [string]$s.lastTime; $es = [string]$s.endSeedCount
            } else { $lt = '(decode-failed)' }
          }
          $sessRows += [PSCustomObject]@{
            Rel="$($ws.Name)\$($sd.Name)\$($f.Name)"
            Workspace=$ws.Name; SessionId=$sd.Name; File=$f.Name; Format=$fmt
            Size=$f.Length; Utc=$f.LastWriteTimeUtc.ToString('o')
            Sha256=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
            Events=$ev; LastType=$lt; LastSeq=$ls; LastTime=$lm; EndSeedCount=$es
          }
        }
      }
    }
  }
}
$sessRows = @($sessRows | Sort-Object Workspace, SessionId)
$sessRows | Export-Csv -LiteralPath (Join-Path $OutDir 'session-inventory.csv') -NoTypeInformation -Encoding UTF8
$byFmt = $sessRows | Group-Object Format | Sort-Object Name
foreach ($g in $byFmt) { Note ("      format {0,-9} count = {1}" -f $g.Name, $g.Count) }
Note ("      workspace dirs = {0}" -f @($sessRows | Select-Object -ExpandProperty Workspace -Unique).Count)
Note ""

# ---------------------------------------------------------------- 4. projcache inventory
Note "[4/6] storages\session_projcache inventory ..."
$pc = Join-Path $DSH 'storages\session_projcache\sessions'
$pcRows = @()
if (Test-Path $pc) {
  $pcRows = Get-ChildItem $pc -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
    [PSCustomObject]@{ Rel=$_.Name; Size=$_.Length; Utc=$_.LastWriteTimeUtc.ToString('o'); Sha256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash }
  }
}
$pcRows = @($pcRows | Sort-Object Rel)
$pcRows | Export-Csv -LiteralPath (Join-Path $OutDir 'projcache-inventory.csv') -NoTypeInformation -Encoding UTF8
Note ("      projcache files = {0}" -f $pcRows.Count)
Note ""

# ---------------------------------------------------------------- 5. directory metadata
Note "[5/6] directory metadata ..."
$dirRows = @()
foreach ($rel in @('profiles','profiles\node_modules','sessions','storages','attachments','llm-deepseek','whale-audio','whale-bubble-imgs','whale-roles')) {
  $p = Join-Path $DSH $rel
  if (Test-Path $p) {
    $i = Get-Item -LiteralPath $p -Force
    $dirRows += [PSCustomObject]@{ Rel=$rel; Utc=$i.LastWriteTimeUtc.ToString('o'); LinkType=$i.LinkType }
  } else {
    $dirRows += [PSCustomObject]@{ Rel=$rel; Utc='ABSENT'; LinkType='' }
  }
}
$dirRows | Format-Table Rel, Utc, LinkType -AutoSize | Out-Host
$dirRows | Export-Csv -LiteralPath (Join-Path $OutDir 'dir-metadata.csv') -NoTypeInformation -Encoding UTF8
Note ""

# ---------------------------------------------------------------- 6. presence flags
Note "[6/6] presence assertions ..."
$flags = [PSCustomObject]@{
  home_cordis_patch_yml_present = (Test-Path (Join-Path $DSH 'cordis.patch.yml'))
  home_package_json_present     = (Test-Path (Join-Path $DSH 'package.json'))
  desktop_profile_present       = (Test-Path (Join-Path $DSH 'profiles\desktop'))
  desktop_profile_node_modules  = (Test-Path (Join-Path $DSH 'profiles\desktop\node_modules'))
  desktop_profile_lock          = (Test-Path (Join-Path $DSH 'profiles\desktop\pnpm-lock.yaml'))
  settings_imported_present     = (Test-Path (Join-Path $DSH 'settings.yaml.imported'))
  shared_fallback_whale         = (Test-Path (Join-Path $DSH 'profiles\node_modules\dsh-whale-widget'))
}
$flags | Format-List | Out-Host
$flags | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutDir 'presence-flags.json') -Encoding UTF8
Note ""

# ---------------------------------------------------------------- summary
$sum = @()
$sum += "SCRIPT B SHARED-STATE SUMMARY"
$sum += "Label      : $Label"
$sum += "CapturedAt : $stamp"
$sum += ""
$sum += "files present=$($present.Count) absent=$($absent.Count)"
foreach ($g in $byFmt) { $sum += ("session format {0,-9} count = {1}" -f $g.Name, $g.Count) }
$sum += "projcache files = $($pcRows.Count)"
$sum += ""
$sum += "KEY HASHES"
foreach ($k in @('AGENTS.md','settings.yaml','settings.yaml.imported','.credentials.yaml','storages\workspace.json',
                 'profiles\desktop\package.json','profiles\desktop\cordis.patch.yml','profiles\browser-lab\package.json','profiles\web\package.json')) {
  $r = $manifest | Where-Object { $_.Rel -eq $k } | Select-Object -First 1
  if ($r) { $sum += ("  {0,-42} {1,10} {2}" -f $r.Rel, $r.Size, $r.Sha256) }
}
$sum += ""
$sum += "PRESENCE"
$flags.PSObject.Properties | ForEach-Object { $sum += ("  {0,-32} = {1}" -f $_.Name, $_.Value) }
$sum | Set-Content -LiteralPath (Join-Path $OutDir 'shared-state-summary.txt') -Encoding UTF8
$sum | ForEach-Object { Note $_ }

Note ""
Note "=== SCRIPT B DONE (warnings: $script:problems) ==="

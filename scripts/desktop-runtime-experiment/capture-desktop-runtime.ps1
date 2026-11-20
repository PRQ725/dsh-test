<#
.SYNOPSIS
  Script A - capture Desktop runtime (processes / listeners / logs index / $DSH_HOME fingerprints).

.DESCRIPTION
  READ-ONLY. Never writes to $DSH_HOME, never starts/stops any process.
  Safe to run while Desktop is running OR while browser-lab is running
  (it only OBSERVES; it does not decide which host should be up).

.PARAMETER OutDir
  Directory to write capture outputs into. Created if missing.

.PARAMETER Label
  Short label for this capture, e.g. "e4-desktop-running" or "e1b-desktop-stopped".

.EXAMPLE
  .\capture-desktop-runtime.ps1 -OutDir D:\Projects\dsh-test\evidence\desktop\runtime\e4 -Label e4-desktop-running
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$OutDir,
  [string]$Label = 'capture'
)

$ErrorActionPreference = 'Continue'
$DSH = 'C:\Users\user02\.dsh'
$DesktopApp = 'C:\Users\user02\AppData\Local\Programs\DeepSeek Harness'
$DesktopData = Join-Path $env:APPDATA '@deepseek-ai\dsh-desktop'
$DesktopLogs = Join-Path $DesktopData 'logs'

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$script:problems = 0

function Note($m) { Write-Host $m }
function Flag($m) { Write-Host "  [!] $m" -ForegroundColor Yellow; $script:problems++ }

Note "=== SCRIPT A: capture Desktop runtime ==="
Note "OutDir = $OutDir"
Note "Label  = $Label"
Note "Time   = $stamp"
Note ""

# ---------------------------------------------------------------- 1. processes
Note "[1/5] process inventory ..."
$procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
  ($_.Name -match '(?i)DeepSeek Harness') -or
  ($_.CommandLine -match 'DeepSeek Harness') -or
  ($_.CommandLine -match 'dsh-desktop-host') -or
  ($_.CommandLine -match '@deepseek-ai[\\/]dsh[\\/]lib[\\/]bin\.js') -or
  ($_.CommandLine -match '@playwright/mcp') -or
  ($_.CommandLine -match 'playwright\\mcp\\cli\.js')
}
$procRows = foreach ($p in $procs) {
  [PSCustomObject]@{
    Pid               = $p.ProcessId
    Name              = $p.Name
    ParentPid         = $p.ParentProcessId
    CreationDate      = $p.CreationDate
    ExecutablePath    = $p.ExecutablePath
    CommandLine       = $p.CommandLine
    Role              = $(if     ($p.CommandLine -match 'dsh-desktop-host')            { 'desktop-host' }
                          elseif ($p.Name -match '(?i)DeepSeek Harness')              { 'electron-shell' }
                          elseif ($p.CommandLine -match '@deepseek-ai[\\/]dsh')       { 'cli-host' }
                          elseif ($p.CommandLine -match 'playwright')                 { 'playwright-mcp' }
                          else                                                        { 'other' })
  }
}
$procRows | Sort-Object Role, Pid | Format-Table Pid, Role, Name, ParentPid, CreationDate -AutoSize | Out-Host
$procRows | Export-Csv -LiteralPath (Join-Path $OutDir 'processes.csv') -NoTypeInformation -Encoding UTF8

$hasDesktopShell = @($procRows | Where-Object { $_.Role -eq 'electron-shell' }).Count -gt 0
$hasDesktopHost  = @($procRows | Where-Object { $_.Role -eq 'desktop-host'   }).Count -gt 0
$hasCliHost      = @($procRows | Where-Object { $_.Role -eq 'cli-host'       }).Count -gt 0
Note ("      electron-shell = {0} | desktop-host = {1} | cli-host(browser-lab) = {2}" -f $hasDesktopShell, $hasDesktopHost, $hasCliHost)
Note ""

# ---------------------------------------------------------------- 2. listeners
Note "[2/5] TCP listeners + owner mapping ..."
$listen = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
          Where-Object { $_.LocalAddress -in @('127.0.0.1','0.0.0.0','::1','::') }
$lisRows = foreach ($l in $listen) {
  $op = $null
  try { $op = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $l.OwningProcess) -ErrorAction SilentlyContinue } catch {}
  [PSCustomObject]@{
    LocalAddress  = $l.LocalAddress
    LocalPort     = $l.LocalPort
    OwningProcess = $l.OwningProcess
    OwnerName     = $(if ($op) { $op.Name } else { '' })
    OwnerCmdLine  = $(if ($op) { $op.CommandLine } else { '' })
    OwnerRole     = $(if ($op -and $op.CommandLine -match 'dsh-desktop-host')      { 'desktop-host' }
                      elseif ($op -and $op.Name -match '(?i)DeepSeek Harness')     { 'electron-shell' }
                      elseif ($op -and $op.CommandLine -match '@deepseek-ai[\\/]dsh') { 'cli-host' }
                      else                                                          { 'other' })
  }
}
$lisRows | Sort-Object LocalPort | Format-Table LocalAddress, LocalPort, OwningProcess, OwnerRole -AutoSize | Out-Host
$lisRows | Export-Csv -LiteralPath (Join-Path $OutDir 'listeners.csv') -NoTypeInformation -Encoding UTF8

$desktopListeners = @($lisRows | Where-Object { $_.OwnerRole -in @('desktop-host','electron-shell') })
$cliListeners     = @($lisRows | Where-Object { $_.OwnerRole -eq 'cli-host' })
Note ("      desktop-owned listeners = {0} | cli-owned listeners = {1}" -f $desktopListeners.Count, $cliListeners.Count)
if ($desktopListeners.Count -gt 0) {
  Note "      desktop listener detail:"
  $desktopListeners | ForEach-Object { Note ("        {0}:{1}  pid={2}  role={3}" -f $_.LocalAddress, $_.LocalPort, $_.OwningProcess, $_.OwnerRole) }
}
Note ""

# ---------------------------------------------------------------- 3. desktop logs
Note "[3/5] Desktop logs index ..."
$logRows = @()
if (Test-Path $DesktopLogs) {
  $logFiles = Get-ChildItem $DesktopLogs -Recurse -File -Force -ErrorAction SilentlyContinue
  $logRows = foreach ($f in $logFiles) {
    [PSCustomObject]@{
      Rel      = $f.FullName.Substring($DesktopLogs.Length + 1)
      Size     = $f.Length
      Utc      = $f.LastWriteTimeUtc.ToString('o')
      Sha256   = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
    }
  }
  if (@($logRows).Count -eq 0) {
    Note "      logs directory EXISTS but contains 0 files  -> log-based evidence NOT AVAILABLE"
  } else {
    $logRows | Format-Table Rel, Size, Utc -AutoSize | Out-Host
  }
} else {
  Note "      logs directory DOES NOT EXIST -> log-based evidence NOT AVAILABLE"
}
$logRows | Export-Csv -LiteralPath (Join-Path $OutDir 'desktop-logs-index.csv') -NoTypeInformation -Encoding UTF8

# keyword probe on logs (only if any exist) - reads content, writes only matched lines
$kw = 'AGENTS','agent-instructions','system-reminder','instruction','pre-step','webserver','websocket','protocol','dsh-app','port','IPC'
$kwHits = @()
if (@($logRows).Count -gt 0) {
  foreach ($f in (Get-ChildItem $DesktopLogs -Recurse -File -Force -ErrorAction SilentlyContinue)) {
    foreach ($k in $kw) {
      $m = Select-String -LiteralPath $f.FullName -Pattern $k -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -First 5
      foreach ($x in $m) { $kwHits += ("{0}:{1}:{2}" -f $f.Name, $x.LineNumber, $x.Line.Trim()) }
    }
  }
}
$kwHits | Set-Content -LiteralPath (Join-Path $OutDir 'desktop-logs-keyword-hits.txt') -Encoding UTF8
Note ("      keyword hits = {0} (see desktop-logs-keyword-hits.txt)" -f @($kwHits).Count)
Note ""

# ---------------------------------------------------------------- 4. install root fingerprints
Note "[4/5] Desktop install-root fingerprints ..."
$appRows = @()
foreach ($rel in @('version','resources\app-update.yml','resources\app.asar','resources\runtime\versions.json')) {
  $p = Join-Path $DesktopApp $rel
  if (Test-Path $p) {
    $i = Get-Item $p
    $appRows += [PSCustomObject]@{ Rel=$rel; Size=$i.Length; Utc=$i.LastWriteTimeUtc.ToString('o'); Sha256=(Get-FileHash $p -Algorithm SHA256).Hash }
  } else {
    $appRows += [PSCustomObject]@{ Rel=$rel; Size='ABSENT'; Utc=''; Sha256='' }
  }
}
$appRows | Format-Table Rel, Size, Sha256 -AutoSize | Out-Host
$appRows | Export-Csv -LiteralPath (Join-Path $OutDir 'desktop-app-fingerprints.csv') -NoTypeInformation -Encoding UTF8
Note ""

# ---------------------------------------------------------------- 5. $DSH_HOME fingerprints
Note "[5/5] `$DSH_HOME selected fingerprints (read-only) ..."
$homeRows = @()
foreach ($rel in @('AGENTS.md','settings.yaml','settings.yaml.imported','.credentials.yaml','.anonymous-user-id',
                   'cordis.patch.yml','package.json','storages\workspace.json',
                   'profiles\desktop\package.json','profiles\desktop\cordis.patch.yml','profiles\desktop\cordis.yml',
                   'profiles\desktop\pnpm-workspace.yaml')) {
  $p = Join-Path $DSH $rel
  if (Test-Path $p) {
    $i = Get-Item $p
    $homeRows += [PSCustomObject]@{ Rel=$rel; Size=$i.Length; Utc=$i.LastWriteTimeUtc.ToString('o'); Sha256=(Get-FileHash $p -Algorithm SHA256).Hash }
  } else {
    $homeRows += [PSCustomObject]@{ Rel=$rel; Size='ABSENT'; Utc=''; Sha256='' }
  }
}
$homeRows | Format-Table Rel, Size, Sha256 -AutoSize | Out-Host
$homeRows | Export-Csv -LiteralPath (Join-Path $OutDir 'dsh-home-fingerprints.csv') -NoTypeInformation -Encoding UTF8
Note ""

# ---------------------------------------------------------------- summary
$sum = @()
$sum += "SCRIPT A CAPTURE SUMMARY"
$sum += "Label          : $Label"
$sum += "CapturedAt     : $stamp"
$sum += "OutDir         : $OutDir"
$sum += ""
$sum += "HOST STATE"
$sum += "  electron-shell running : $hasDesktopShell"
$sum += "  desktop-host running   : $hasDesktopHost"
$sum += "  cli-host (browser-lab) : $hasCliHost"
$sum += "  desktop listeners      : $($desktopListeners.Count)"
$sum += "  cli listeners          : $($cliListeners.Count)"
$sum += "  ports                  : $(($lisRows | Sort-Object LocalPort | ForEach-Object { $_.LocalPort }) -join ', ')"
$sum += ""
$sum += "NOTE: this script is observational. Run it BOTH while Desktop is up and while browser-lab is up,"
$sum += "      then compare - it does NOT decide which host is running."
$sum | Set-Content -LiteralPath (Join-Path $OutDir 'summary.txt') -Encoding UTF8
$sum | ForEach-Object { Note $_ }

Note ""
Note "=== SCRIPT A DONE (warnings: $script:problems) ==="

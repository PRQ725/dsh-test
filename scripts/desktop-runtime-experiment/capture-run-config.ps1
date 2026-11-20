<#
.SYNOPSIS
  Explicit run metadata + baseline binding for the E1 interoperability experiment.

.DESCRIPTION
  WHY THIS FILE EXISTS

  e1-capture.ps1 used to DERIVE the baseline path from the run name:

      $prevDir = Join-Path $Root ("e1-" + $RunName + "-" + $PrevStage)   # -> e1-run2-BASE

  while the change classifier used a DIFFERENT, hard-coded baseline:

      $baseNs = 'e1-BASE-QUIESCENT-R2'

  That split-brain produced a real STOP in E1 run2 Stage A:

      [STOP] previous stage capture dir missing: ...\e1-run2-BASE

  even though a valid, revalidated baseline existed at ...\e1-BASE-QUIESCENT-R2.

  This module removes every guess. A run declares its own paths ONCE in
  e1-<RunName>.metadata.json; every stage reads that file and refuses to run if the
  declared baseline does not exist, is not sealed, or does not belong to this run.

  BINDING CHAIN

    new-e1-run.ps1            -> writes e1-<RunName>.metadata.json  (BaselineVerified=false)
    capture-e1-quiescent-baseline.ps1 -MetadataPath <meta>
                              -> captures + validates the baseline, then SEALS:
                                   * writes <BaselineDir>\E1-BASELINE-BINDING.json
                                   * fills BaselineFingerprint + BaselineVerified=true
    e1-capture.ps1 -RunName <RunName> -Stage A|B|C
                              -> reads the SAME metadata, resolves ONE $baselineDir,
                                 and uses it for: previous-stage compare, session listing
                                 diff, shared-state classifier, session classifier.

  Nothing here writes to $DSH_HOME. Nothing here deletes anything.
#>

$script:E1MetadataSchemaVersion = 1
$script:E1BindingFileName      = 'E1-BASELINE-BINDING.json'
$script:E1ComparedManifests    = @(
  'shared-state-manifest.csv',
  'dsh-home-fingerprints.csv',
  'session-inventory.csv',
  'projcache-inventory.csv'
)

function Get-E1MetadataPath {
  param([Parameter(Mandatory=$true)][string]$Root, [Parameter(Mandatory=$true)][string]$RunName)
  return (Join-Path $Root ("e1-" + $RunName + ".metadata.json"))
}

<#
.SYNOPSIS
  Derive the DSH session-directory name for a workspace path.
.DESCRIPTION
  Observed convention: D:\Projects\dsh-test -> --D-Projects-dsh-test--
  (drive colon and backslashes become '-', wrapped in '--').
#>
function Get-DshWorkspaceDirName {
  param([Parameter(Mandatory=$true)][string]$WorkspacePath, [Parameter(Mandatory=$true)][string]$DshHome)
  $norm = $WorkspacePath -replace ':', '' -replace '\\', '-'
  return [PSCustomObject]@{
    DirName = "--$norm--"
    FullPath = (Join-Path (Join-Path $DshHome 'sessions') "--$norm--")
  }
}

function New-E1RunMetadata {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$RunName,
    [Parameter(Mandatory=$true)][string]$Root,
    [Parameter(Mandatory=$true)][string]$WorkspacePath,
    [Parameter(Mandatory=$true)][string]$BaselineNamespace,
    [string]$DshHome = 'C:\Users\user02\.dsh',
    [string]$BaselineSource = 'capture-e1-quiescent-baseline.ps1'
  )

  $ws = Get-DshWorkspaceDirName -WorkspacePath $WorkspacePath -DshHome $DshHome
  $stageDirs = [PSCustomObject]@{
    A = (Join-Path $Root ("e1-" + $RunName + "-A"))
    B = (Join-Path $Root ("e1-" + $RunName + "-B"))
    C = (Join-Path $Root ("e1-" + $RunName + "-C"))
  }
  return [PSCustomObject]@{
    SchemaVersion       = $script:E1MetadataSchemaVersion
    RunName             = $RunName
    CreatedAt           = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    EvidenceRoot        = $Root
    WorkspacePath       = $WorkspacePath
    WorkspaceDirName    = $ws.DirName
    WorkspaceSessionDir = $ws.FullPath
    BaselineNamespace   = $BaselineNamespace
    BaselineDir         = (Join-Path $Root $BaselineNamespace)
    BaselineVerifyDir   = (Join-Path $Root ($BaselineNamespace + '-VERIFY'))
    BaselineCompareDir  = (Join-Path $Root ($BaselineNamespace + '-compare'))
    BaselineVerdictPath = (Join-Path $Root ($BaselineNamespace + '-VERDICT.txt'))
    BaselineSource      = $BaselineSource
    BaselineVerified    = $false
    BaselineSealedAt    = ''
    BaselineFingerprint = [PSCustomObject]@{}
    StageDirs           = $stageDirs
    CompareDirs         = [PSCustomObject]@{
      'BASELINE-A' = (Join-Path $Root ("e1-" + $RunName + "-BASELINE-A-compare"))
      'A-B'        = (Join-Path $Root ("e1-" + $RunName + "-A-B-compare"))
      'B-C'        = (Join-Path $Root ("e1-" + $RunName + "-B-C-compare"))
    }
    LockFile            = (Join-Path $Root ("e1-" + $RunName + ".session.lock.json"))
  }
}

function Save-E1RunMetadata {
  param([Parameter(Mandatory=$true)]$Metadata, [Parameter(Mandatory=$true)][string]$Path)
  $Metadata | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Import-E1RunMetadata {
  param([Parameter(Mandatory=$true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

<#
.SYNOPSIS
  Structural validation of a metadata document. Returns Errors[].
#>
function Test-E1RunMetadataShape {
  param($Metadata)
  $errors = New-Object System.Collections.Generic.List[string]
  if ($null -eq $Metadata) { $errors.Add('metadata is null'); return $errors.ToArray() }
  foreach ($f in @('SchemaVersion','RunName','EvidenceRoot','WorkspacePath','WorkspaceDirName',
                   'BaselineNamespace','BaselineDir','BaselineVerdictPath','StageDirs','LockFile')) {
    if (-not ($Metadata.PSObject.Properties.Name -contains $f)) { $errors.Add("metadata field missing: $f") }
  }
  if ($errors.Count -gt 0) { return $errors.ToArray() }
  if ([int]$Metadata.SchemaVersion -ne $script:E1MetadataSchemaVersion) {
    $errors.Add("metadata SchemaVersion $($Metadata.SchemaVersion) != expected $script:E1MetadataSchemaVersion")
  }
  foreach ($s in @('A','B','C')) {
    if (-not ($Metadata.StageDirs.PSObject.Properties.Name -contains $s)) { $errors.Add("metadata StageDirs.$s missing") }
  }
  # BaselineDir must be inside EvidenceRoot and must be named after BaselineNamespace
  $leaf = Split-Path -Leaf $Metadata.BaselineDir
  if ($leaf -ne $Metadata.BaselineNamespace) {
    $errors.Add("BaselineDir leaf '$leaf' != BaselineNamespace '$($Metadata.BaselineNamespace)'")
  }
  if (-not $Metadata.BaselineDir.StartsWith($Metadata.EvidenceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    $errors.Add("BaselineDir is outside EvidenceRoot: $($Metadata.BaselineDir)")
  }
  foreach ($s in @('A','B','C')) {
    $d = [string]$Metadata.StageDirs.$s
    if (-not $d.StartsWith($Metadata.EvidenceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
      $errors.Add("StageDirs.$s is outside EvidenceRoot: $d")
    }
    if ($d -eq $Metadata.BaselineDir) { $errors.Add("StageDirs.$s must not equal BaselineDir") }
  }
  return $errors.ToArray()
}

function Get-E1BindingPath {
  param([Parameter(Mandatory=$true)][string]$BaselineDir)
  return (Join-Path $BaselineDir $script:E1BindingFileName)
}

<#
.SYNOPSIS
  SHA-256 of each compared manifest in a capture directory (absent files recorded as ABSENT).
#>
function Get-ComparedManifestFingerprint {
  param([Parameter(Mandatory=$true)][string]$Dir)
  $fp = [ordered]@{}
  foreach ($m in $script:E1ComparedManifests) {
    $p = Join-Path $Dir $m
    if (Test-Path -LiteralPath $p -PathType Leaf) {
      $fp[$m] = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash
    } else {
      $fp[$m] = 'ABSENT'
    }
  }
  return [PSCustomObject]$fp
}

<#
.SYNOPSIS
  Build the baseline binding record that is written INTO the baseline directory.
#>
function New-E1BaselineBinding {
  param(
    [Parameter(Mandatory=$true)]$Metadata,
    [Parameter(Mandatory=$true)][string]$BaselineDir,
    [Parameter(Mandatory=$true)][string]$VerdictPath,
    [string]$FixtureAgentsSha256 = ''
  )
  $vSha = ''
  if (Test-Path -LiteralPath $VerdictPath -PathType Leaf) {
    $vSha = (Get-FileHash -LiteralPath $VerdictPath -Algorithm SHA256).Hash
  }
  return [PSCustomObject]@{
    SchemaVersion        = $script:E1MetadataSchemaVersion
    SealedAt             = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    RunName              = $Metadata.RunName
    WorkspacePath        = $Metadata.WorkspacePath
    WorkspaceDirName     = $Metadata.WorkspaceDirName
    BaselineNamespace    = $Metadata.BaselineNamespace
    BaselineDir          = $BaselineDir
    VerdictPath          = $VerdictPath
    VerdictSha256        = $vSha
    FixtureAgentsSha256  = $FixtureAgentsSha256
    ManifestFingerprint  = (Get-ComparedManifestFingerprint -Dir $BaselineDir)
  }
}

function Save-E1BaselineBinding {
  param([Parameter(Mandatory=$true)]$Binding, [Parameter(Mandatory=$true)][string]$BaselineDir)
  $p = Get-E1BindingPath -BaselineDir $BaselineDir
  $Binding | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $p -Encoding UTF8
  return $p
}

<#
.SYNOPSIS
  Resolve and validate the complete run context, including the ONE baseline binding.

.DESCRIPTION
  Fails closed. It never guesses a path. Every failure names the exact mismatch.

.OUTPUTS
  PSCustomObject{ Ok; Errors; MetadataPath; Metadata; BaselineDir; Binding; StageDirs; LockFile }
#>
function Resolve-E1RunContext {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$Root,
    [Parameter(Mandatory=$true)][string]$RunName,
    [string]$MetadataPath = ''
  )

  $errors = New-Object System.Collections.Generic.List[string]
  if (-not $MetadataPath) { $MetadataPath = Get-E1MetadataPath -Root $Root -RunName $RunName }

  $meta = Import-E1RunMetadata -Path $MetadataPath
  if ($null -eq $meta) {
    $errors.Add("run metadata not found: $MetadataPath  (create the run with new-e1-run.ps1; a baseline path is never guessed)")
    return [PSCustomObject]@{ Ok=$false; Errors=$errors.ToArray(); MetadataPath=$MetadataPath; Metadata=$null
                              BaselineDir=''; Binding=$null; StageDirs=$null; LockFile='' }
  }

  foreach ($e in (Test-E1RunMetadataShape -Metadata $meta)) { $errors.Add($e) }
  if ($meta.RunName -ne $RunName) { $errors.Add("metadata RunName '$($meta.RunName)' != requested '$RunName'") }
  if ($meta.EvidenceRoot -ne $Root) { $errors.Add("metadata EvidenceRoot '$($meta.EvidenceRoot)' != requested Root '$Root'") }
  if ($errors.Count -gt 0) {
    return [PSCustomObject]@{ Ok=$false; Errors=$errors.ToArray(); MetadataPath=$MetadataPath; Metadata=$meta
                              BaselineDir=''; Binding=$null; StageDirs=$null; LockFile='' }
  }

  $baselineDir = [string]$meta.BaselineDir

  # ---- 1. the declared baseline directory must exist
  if (-not (Test-Path -LiteralPath $baselineDir -PathType Container)) {
    $errors.Add("declared baseline directory does not exist: $baselineDir")
    return [PSCustomObject]@{ Ok=$false; Errors=$errors.ToArray(); MetadataPath=$MetadataPath; Metadata=$meta
                              BaselineDir=$baselineDir; Binding=$null; StageDirs=$meta.StageDirs; LockFile=$meta.LockFile }
  }

  # ---- 2. the metadata must have been SEALED by a baseline PASS
  if (-not [bool]$meta.BaselineVerified) {
    $errors.Add("baseline is NOT sealed (BaselineVerified=false) -> run capture-e1-quiescent-baseline.ps1 -MetadataPath '$MetadataPath' and require a PASS")
    return [PSCustomObject]@{ Ok=$false; Errors=$errors.ToArray(); MetadataPath=$MetadataPath; Metadata=$meta
                              BaselineDir=$baselineDir; Binding=$null; StageDirs=$meta.StageDirs; LockFile=$meta.LockFile }
  }

  # ---- 3. the binding record inside the baseline must exist
  $bindingPath = Get-E1BindingPath -BaselineDir $baselineDir
  if (-not (Test-Path -LiteralPath $bindingPath -PathType Leaf)) {
    $errors.Add("baseline binding record missing: $bindingPath")
    return [PSCustomObject]@{ Ok=$false; Errors=$errors.ToArray(); MetadataPath=$MetadataPath; Metadata=$meta
                              BaselineDir=$baselineDir; Binding=$null; StageDirs=$meta.StageDirs; LockFile=$meta.LockFile }
  }
  $binding = Import-E1RunMetadata -Path $bindingPath    # same JSON reader
  if ($null -eq $binding) {
    $errors.Add("baseline binding record is unreadable: $bindingPath")
    return [PSCustomObject]@{ Ok=$false; Errors=$errors.ToArray(); MetadataPath=$MetadataPath; Metadata=$meta
                              BaselineDir=$baselineDir; Binding=$null; StageDirs=$meta.StageDirs; LockFile=$meta.LockFile }
  }

  # ---- 4. the baseline must belong to THIS run and THIS workspace
  if ([string]$binding.RunName -ne [string]$meta.RunName) {
    $errors.Add("baseline belongs to run '$($binding.RunName)' but metadata says run '$($meta.RunName)'")
  }
  if ([string]$binding.BaselineNamespace -ne [string]$meta.BaselineNamespace) {
    $errors.Add("baseline namespace '$($binding.BaselineNamespace)' != metadata '$($meta.BaselineNamespace)'")
  }
  if ([string]$binding.WorkspacePath -ne [string]$meta.WorkspacePath) {
    $errors.Add("baseline was sealed for workspace '$($binding.WorkspacePath)' but metadata says '$($meta.WorkspacePath)'")
  }

  # ---- 5. the baseline content must still match what was sealed
  $live = Get-ComparedManifestFingerprint -Dir $baselineDir
  $sealed = $binding.ManifestFingerprint
  if ($null -eq $sealed) {
    $errors.Add("baseline binding has no ManifestFingerprint")
  } else {
    foreach ($m in $script:E1ComparedManifests) {
      $want = [string]$sealed.$m
      $got  = [string]$live.$m
      if ($want -eq '' -or $null -eq $want) { $errors.Add("sealed fingerprint for $m is empty"); continue }
      if ($want -eq 'ABSENT') { $errors.Add("sealed fingerprint says $m was ABSENT at seal time"); continue }
      if ($got -eq 'ABSENT')  { $errors.Add("baseline manifest $m disappeared after sealing"); continue }
      if ($want -ne $got)     { $errors.Add("baseline manifest $m changed after sealing (sealed $want, now $got)") }
    }
  }

  return [PSCustomObject]@{
    Ok           = ($errors.Count -eq 0)
    Errors       = $errors.ToArray()
    MetadataPath = $MetadataPath
    Metadata     = $meta
    BaselineDir  = $baselineDir
    Binding      = $binding
    StageDirs    = $meta.StageDirs
    LockFile     = $meta.LockFile
  }
}

<#
.SYNOPSIS
  The previous capture that the current stage diffs against.

.DESCRIPTION
  Stage A diffs against THE BASELINE declared in metadata - not against
  "e1-<RunName>-BASE", which never exists. Stage B diffs A, Stage C diffs B.
.OUTPUTS
  PSCustomObject{ Label; Dir; IsBaseline; CompareDir }
#>
function Get-E1PreviousStage {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)]$Context, [Parameter(Mandatory=$true)][ValidateSet('A','B','C')][string]$Stage)

  if ($Stage -eq 'A') {
    return [PSCustomObject]@{ Label='BASELINE'; Dir=$Context.BaselineDir; IsBaseline=$true
                              CompareDir=$Context.Metadata.CompareDirs.'BASELINE-A' }
  }
  if ($Stage -eq 'B') {
    return [PSCustomObject]@{ Label='A'; Dir=[string]$Context.StageDirs.A; IsBaseline=$false
                              CompareDir=$Context.Metadata.CompareDirs.'A-B' }
  }
  return [PSCustomObject]@{ Label='B'; Dir=[string]$Context.StageDirs.B; IsBaseline=$false
                            CompareDir=$Context.Metadata.CompareDirs.'B-C' }
}

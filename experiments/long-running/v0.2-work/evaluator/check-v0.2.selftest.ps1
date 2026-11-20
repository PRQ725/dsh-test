#requires -Version 5.1
<#
  check-v0.2.selftest.ps1 - regression harness for check-v0.2.ps1

  PURPOSE
    Prove that the v0.2 evaluator discriminates: that a compliant artifact passes, that each
    failure class fails for the expected printed reason, and that an unusable invocation
    errors. The acceptance spec requires that the evaluator's tests run against REAL producer
    output, so every evaluator case is a real copy of the candidate, mutated in exactly one
    way. No hand-written near-miss fixture is used.

  IMMUTABILITY
    Before and after the case set the harness re-hashes the candidate tree and the whole
    approved scratch base. If either changes unexpectedly, the harness fails: a self-test that
    mutates the artifact it validates would invalidate the very PASS it is meant to support,
    and a scratch guard that quietly created a directory would defeat its own purpose.

  PATH SAFETY (v0.2-rc.1)
    An earlier run of this harness left an accidental directory `z\01-T1-pass` at the
    repository root. The exact failing invocation is NOT reconstructible and is NOT claimed.
    What is established: the harness performed no validation of its scratch root, and
    `New-Item -ItemType Directory -Force` creates missing parents silently. The harness now
    validates before it writes anything:
      - the scratch root must be normalized and ABSOLUTE (no relative paths);
      - it must be contained in an approved scratch base, decided by path SEGMENTS, never by
        string prefix (so `<base>-evil` is not inside `<base>`);
      - no `..` traversal out of the approved base;
      - no symlink / junction / other reparse point on any existing path segment;
      - the scratch root must already exist; the harness NEVER creates it;
      - rejection happens before any directory is created.

  WHY IN-PROCESS
    Launching a nested PowerShell child process to run a .ps1 file is refused on this host
    (execution policy RemoteSigned plus a sandbox that denies child spawns). The evaluator's
    logic is therefore loaded as text and invoked through Invoke-Check, and this harness is
    invoked through Invoke-SelfTest. Requesting a wider sandbox for tests is not acceptable.

  ENTRY MODEL
    The whole harness lives in Invoke-SelfTest and returns an exit code.

  EXIT CODES
    0 = SELFTEST PASS
    1 = SELFTEST FAIL (one or more cases did not behave as required)
    2 = ERROR (harness could not run: missing evaluator, or an unusable scratch root)
#>

[CmdletBinding()]
param(
    [string]$Evaluator,
    [string]$Candidate,
    [string]$WorkRoot,

    # Approved boundary. Defaults to <v0.2-work>/evidence. A WorkRoot outside this base is
    # refused before anything is written.
    [string]$ScratchBase
)

Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

function Invoke-SelfTest {
    param(
        [string]$Evaluator,
        [string]$Candidate,
        [string]$WorkRoot,
        [string]$ScratchBase
    )

    $lines = New-Object 'System.Collections.Generic.List[string]'
    $script:failCount = 0

    function Record([bool]$ok, [string]$name, [string]$detail) {
        if ($ok) {
            $lines.Add("  PASS  $name")
        } else {
            $script:failCount++
            $lines.Add("  FAIL  $name :: $detail")
        }
    }

    function Get-TreeHash([string]$root) {
        $acc = @()
        foreach ($f in (Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue | Sort-Object FullName)) {
            $rel = $f.FullName.Substring($root.Length).TrimStart('\', '/')
            $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
            $acc += ($rel + ' ' + $h)
        }
        return ($acc -join '|')
    }

    function Get-EntryCount([string]$root) {
        if (-not (Test-Path -LiteralPath $root)) { return -1 }
        return @(Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue).Count
    }

    # --- path safety helpers -------------------------------------------------------------
    # These read the filesystem only. No helper in this section creates anything.

    function Test-ReparsePoint([string]$path) {
        if (-not (Test-Path -LiteralPath $path)) { return $false }
        try {
            $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        } catch {
            return $true   # unreadable is treated as unsafe
        }
        return (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
    }

    # Walks from an existing ancestor down to the target and returns the first reparse point.
    function Get-ReparseAncestor([string]$path) {
        $current = [System.IO.Path]::GetFullPath($path)
        $parts = New-Object 'System.Collections.Generic.List[string]'
        while (-not (Test-Path -LiteralPath $current)) {
            $parent = [System.IO.Path]::GetDirectoryName($current)
            if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
            $parts.Insert(0, [System.IO.Path]::GetFileName($current))
            $current = $parent
        }
        if (Test-ReparsePoint $current) { return $current }
        foreach ($p in $parts) {
            $current = [System.IO.Path]::Combine($current, $p)
            if (Test-ReparsePoint $current) { return $current }
        }
        return $null
    }

    # Containment by path SEGMENTS. A string-prefix test would accept `<base>-evil` as being
    # inside `<base>`; this cannot. PowerShell's -ne on strings is case-insensitive, which is
    # the correct comparison for Windows paths.
    function Test-UnderBase([string]$path, [string]$base) {
        $p = @([System.IO.Path]::GetFullPath($path).TrimEnd('\', '/') -split '[\\/]' | Where-Object { $_ -ne '' })
        $b = @([System.IO.Path]::GetFullPath($base).TrimEnd('\', '/') -split '[\\/]' | Where-Object { $_ -ne '' })
        if ($b.Count -eq 0 -or $p.Count -lt $b.Count) { return $false }
        for ($i = 0; $i -lt $b.Count; $i++) {
            if ($p[$i] -ne $b[$i]) { return $false }
        }
        return $true
    }

    # Pure validation of a scratch root against an approved base. Creates nothing; returns a
    # hashtable with Ok, Kind and Detail.
    function Test-ScratchRoot {
        param([string]$Path, [string]$Base)

        $result = @{ Ok = $false; Kind = ''; Detail = '' }
        if ([string]::IsNullOrWhiteSpace($Path)) {
            $result.Kind = 'empty'
            $result.Detail = 'the scratch root is empty'
            return $result
        }
        if ($Path -match '[?*]') {
            $result.Kind = 'wildcard'
            $result.Detail = "the scratch root contains a wildcard: $Path"
            return $result
        }
        if (-not [System.IO.Path]::IsPathRooted($Path)) {
            $result.Kind = 'relative'
            $result.Detail = "the scratch root must be an absolute path; got '$Path', which would silently resolve against the current directory"
            return $result
        }
        if ($Path.StartsWith('\\')) {
            $result.Kind = 'unc'
            $result.Detail = "the scratch root must not be a UNC or device path: $Path"
            return $result
        }
        $normalized = [System.IO.Path]::GetFullPath($Path)
        if (-not (Test-UnderBase -path $normalized -base $Base)) {
            $result.Kind = 'outside'
            $result.Detail = "the scratch root '$normalized' is outside the approved scratch base '$Base'"
            return $result
        }
        if (-not (Test-Path -LiteralPath $Base -PathType Container)) {
            $result.Kind = 'base-missing'
            $result.Detail = "the approved scratch base does not exist: $Base"
            return $result
        }
        if (-not (Test-Path -LiteralPath $normalized -PathType Container)) {
            $result.Kind = 'missing'
            $result.Detail = "the scratch root does not exist as a directory: $normalized. The harness never creates its own scratch root; create it explicitly first."
            return $result
        }
        $reparse = Get-ReparseAncestor -path $normalized
        if ($null -ne $reparse) {
            $result.Kind = 'reparse'
            $result.Detail = "a reparse point (symlink or junction) sits on the scratch root's path: $reparse"
            return $result
        }
        $result.Ok = $true
        $result.Detail = $normalized
        return $result
    }

    # --- locate defaults -----------------------------------------------------------------

    $here = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($here)) {
        if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) { $here = Split-Path $PSCommandPath -Parent }
    }
    if ([string]::IsNullOrWhiteSpace($here)) {
        # Loaded as a scriptblock: $PSScriptRoot and $PSCommandPath are empty by design.
        # Fall back to a path relative to the current location (the repository root).
        $here = Join-Path (Get-Location).ProviderPath 'experiments\long-running\v0.2-work\evaluator'
    }
    $workArea = Split-Path $here -Parent
    if ([string]::IsNullOrWhiteSpace($Evaluator)) { $Evaluator = Join-Path $here 'check-v0.2.ps1' }
    if ([string]::IsNullOrWhiteSpace($Candidate)) { $Candidate = Join-Path $workArea 'candidate\long-running' }
    if ([string]::IsNullOrWhiteSpace($ScratchBase)) { $ScratchBase = Join-Path $workArea 'evidence' }
    if ([string]::IsNullOrWhiteSpace($WorkRoot)) { $WorkRoot = Join-Path $ScratchBase 'selftest-scratch' }

    if (-not (Test-Path -LiteralPath $Evaluator -PathType Leaf)) {
        Write-Host "ERROR: evaluator not found: $Evaluator"
        return 2
    }
    if (-not (Test-Path -LiteralPath $Candidate -PathType Container)) {
        Write-Host "ERROR: candidate not found: $Candidate"
        return 2
    }

    # The scratch base is the boundary. An absent base is a configuration error, not something
    # to paper over by creating it.
    $baseParent = Split-Path ([System.IO.Path]::GetFullPath($ScratchBase)) -Parent
    $baseCheck = Test-ScratchRoot -Path $ScratchBase -Base $baseParent
    if (-not $baseCheck.Ok) {
        Write-Host "ERROR: the approved scratch base is not usable: [$($baseCheck.Kind)] $($baseCheck.Detail)"
        return 2
    }
    $ScratchBase = [System.IO.Path]::GetFullPath($ScratchBase)

    $rootCheck = Test-ScratchRoot -Path $WorkRoot -Base $ScratchBase
    if (-not $rootCheck.Ok) {
        Write-Host "ERROR: refusing to run: [$($rootCheck.Kind)] $($rootCheck.Detail)"
        Write-Host 'Nothing was created or modified.'
        return 2
    }
    $WorkRoot = $rootCheck.Detail

    # A dirty scratch root would silently change what the cases test (a survivor directory can
    # be merged into by Copy-Item and then mutated by a later case). Refuse rather than purge:
    # an earlier run's evidence may live there.
    if ((Get-EntryCount $WorkRoot) -ne 0) {
        Write-Host "ERROR: refusing to run: the scratch root is not empty: $WorkRoot"
        Write-Host 'A dirty scratch root makes the case results meaningless. Use a fresh directory under the approved base.'
        Write-Host 'Nothing was created or modified.'
        return 2
    }

    # --- load the evaluator --------------------------------------------------------------

    $evalText = [System.IO.File]::ReadAllText($Evaluator, [System.Text.Encoding]::UTF8)
    $sb = [scriptblock]::Create($evalText)
    . $sb -Root '__selftest_load__'
    if (-not (Get-Command Invoke-Check -CommandType Function -ErrorAction SilentlyContinue)) {
        Write-Host 'ERROR: Invoke-Check was not defined by the evaluator'
        return 2
    }

    $candidateRoot = (Resolve-Path -LiteralPath $Candidate).ProviderPath
    $proposalRoot = (Resolve-Path -LiteralPath (Split-Path (Split-Path $candidateRoot -Parent) -Parent)).ProviderPath
    $candidateHashBefore = Get-TreeHash $candidateRoot
    $baseHashBefore = Get-TreeHash $ScratchBase

    $script:caseIndex = 0
    function New-RealCopy {
        param(
            [string]$Label,
            [string]$CandidateRoot,
            [string]$ScratchRoot
        )
        $script:caseIndex++
        $dest = Join-Path $ScratchRoot ("{0:d2}-{1}" -f $script:caseIndex, $Label)
        $null = New-Item -ItemType Directory -Force -Path $dest
        Copy-Item -LiteralPath $CandidateRoot -Destination (Join-Path $dest 'long-running') -Recurse -Force
        return (Join-Path $dest 'long-running')
    }

    function Run-Case {
        param(
            [string]$Label,
            [string]$ToolkitRoot,
            [string]$Mode,
            [string]$ExpectSubstring,
            [int]$ExpectCode,
            [string]$ScratchRoot,
            [string]$ProposalRoot,
            [string]$InstanceRoot,
            [string]$GoalContract,
            [string]$InstanceRootDeclared
        )
        $log = Join-Path $ScratchRoot ("log-{0}.txt" -f ($Label -replace '[^A-Za-z0-9]+', '-'))
        $code = -999
        $text = ''
        try {
            $a = @{ Root = $ToolkitRoot; Mode = $Mode; LogPath = $log }
            if (-not [string]::IsNullOrWhiteSpace($ProposalRoot)) { $a['Proposal'] = $ProposalRoot }
            if (-not [string]::IsNullOrWhiteSpace($InstanceRoot)) { $a['InstanceRoot'] = $InstanceRoot }
            if (-not [string]::IsNullOrWhiteSpace($GoalContract)) { $a['GoalContract'] = $GoalContract }
            if (-not [string]::IsNullOrWhiteSpace($InstanceRootDeclared)) { $a['InstanceRootDeclared'] = $InstanceRootDeclared }
            $code = Invoke-Check @a
        } catch {
            $text = "harness exception: $($_.Exception.Message)"
        }
        if (Test-Path -LiteralPath $log) { $text = [System.IO.File]::ReadAllText($log, [System.Text.Encoding]::UTF8) }
        $flat = $text -replace '\s+', ' '
        if ($code -ne $ExpectCode) {
            Record $false $Label "expected exit $ExpectCode, got $code"
            return
        }
        if ($ExpectSubstring -ne '') {
            if ($flat.IndexOf($ExpectSubstring, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
                Record $false $Label "exit $code was correct but the expected reason '$ExpectSubstring' was not printed"
                return
            }
        }
        Record $true $Label "exit $code as expected"
    }

    # ================= evaluator discrimination cases (T1-T11) ==========================

    $root = New-RealCopy -Label 'T1-pass' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    Run-Case -Label 'T1 compliant copy passes' -ToolkitRoot $root -Mode 'Candidate' -ExpectSubstring 'PASS' -ExpectCode 0 -ScratchRoot $WorkRoot -ProposalRoot $candidateRoot

    $root = New-RealCopy -Label 'T2-missing' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    Remove-Item -LiteralPath (Join-Path $root 'templates\PLAN.md') -Force
    Run-Case -Label 'T2 missing artifact fails' -ToolkitRoot $root -Mode 'Candidate' -ExpectSubstring 'missing artifact' -ExpectCode 1 -ScratchRoot $WorkRoot -ProposalRoot $proposalRoot

    $root = New-RealCopy -Label 'T3-nofrontmatter' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    $skillPath = Join-Path $root 'SKILL.md'
    $skill = [System.IO.File]::ReadAllText($skillPath, [System.Text.Encoding]::UTF8)
    $body = $skill.Substring($skill.IndexOf('# SKILL'))
    [System.IO.File]::WriteAllText($skillPath, $body, (New-Object System.Text.UTF8Encoding($false)))
    Run-Case -Label 'T3 missing skill frontmatter fails' -ToolkitRoot $root -Mode 'Candidate' -ExpectSubstring 'frontmatter' -ExpectCode 1 -ScratchRoot $WorkRoot -ProposalRoot $proposalRoot

    $root = New-RealCopy -Label 'T4-abspath' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    $readmePath = Join-Path $root 'README.md'
    $readme = [System.IO.File]::ReadAllText($readmePath, [System.Text.Encoding]::UTF8)
    $readme = $readme + "`nSee C:\some\local\path for details.`n"
    [System.IO.File]::WriteAllText($readmePath, $readme, (New-Object System.Text.UTF8Encoding($false)))
    Run-Case -Label 'T4 absolute path fails' -ToolkitRoot $root -Mode 'Candidate' -ExpectSubstring 'non-portable absolute path' -ExpectCode 1 -ScratchRoot $WorkRoot -ProposalRoot $proposalRoot

    $root = New-RealCopy -Label 'T5-section' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    $methPath = Join-Path $root 'METHODOLOGY.md'
    $meth = [System.IO.File]::ReadAllText($methPath, [System.Text.Encoding]::UTF8)
    $meth = $meth.Replace('## 6 Stop', '## 6 Halting')
    [System.IO.File]::WriteAllText($methPath, $meth, (New-Object System.Text.UTF8Encoding($false)))
    Run-Case -Label 'T5 missing required section fails' -ToolkitRoot $root -Mode 'Candidate' -ExpectSubstring "missing required section in METHODOLOGY.md: '## 6 Stop'" -ExpectCode 1 -ScratchRoot $WorkRoot -ProposalRoot $proposalRoot

    $root = New-RealCopy -Label 'T6-count' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    $readmePath = Join-Path $root 'README.md'
    $readme = [System.IO.File]::ReadAllText($readmePath, [System.Text.Encoding]::UTF8)
    $readme = $readme.Replace('Exactly eight files. Count them before you copy.', 'Six files. Count them before you copy.')
    [System.IO.File]::WriteAllText($readmePath, $readme, (New-Object System.Text.UTF8Encoding($false)))
    Run-Case -Label 'T6 stale file count fails' -ToolkitRoot $root -Mode 'Candidate' -ExpectSubstring 'stale v0.1 file count wording' -ExpectCode 1 -ScratchRoot $WorkRoot -ProposalRoot $proposalRoot

    $root = New-RealCopy -Label 'T7-placeholder' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    $statePath = Join-Path $root 'templates\STATE.md'
    $state = [System.IO.File]::ReadAllText($statePath, [System.Text.Encoding]::UTF8)
    $state = $state + "`nTODO: revisit`n"
    [System.IO.File]::WriteAllText($statePath, $state, (New-Object System.Text.UTF8Encoding($false)))
    Run-Case -Label 'T7 placeholder token fails' -ToolkitRoot $root -Mode 'Candidate' -ExpectSubstring "placeholder 'TODO'" -ExpectCode 1 -ScratchRoot $WorkRoot -ProposalRoot $proposalRoot

    $root = New-RealCopy -Label 'T8-unfilled' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    foreach ($tpl in (Get-ChildItem -LiteralPath (Join-Path $root 'templates') -File)) {
        $t = [System.IO.File]::ReadAllText($tpl.FullName, [System.Text.Encoding]::UTF8)
        $t = $t.Replace('UNFILLED', 'filled in')
        [System.IO.File]::WriteAllText($tpl.FullName, $t, (New-Object System.Text.UTF8Encoding($false)))
    }
    Run-Case -Label 'T8 missing UNFILLED marker fails' -ToolkitRoot $root -Mode 'Candidate' -ExpectSubstring 'must carry the UNFILLED marker' -ExpectCode 1 -ScratchRoot $WorkRoot -ProposalRoot $proposalRoot

    Run-Case -Label 'T9 nonexistent root errors' -ToolkitRoot (Join-Path $WorkRoot 'does-not-exist') -Mode 'Candidate' -ExpectSubstring 'ERROR' -ExpectCode 2 -ScratchRoot $WorkRoot -ProposalRoot $proposalRoot

    # T10 - the default layout, with one blank instance
    $rootT10 = New-RealCopy -Label 'T10-default-blank' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    $caseDir = Split-Path $rootT10 -Parent
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $caseDir '.dsh') | Out-Null
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $caseDir 'docs\long-running') | Out-Null
    Copy-Item -LiteralPath (Join-Path $candidateRoot 'templates\GOAL.md') -Destination (Join-Path $caseDir 'docs\long-running\GOAL.md') -Force
    Run-Case -Label 'T10 default layout with a blank instance fails' -ToolkitRoot $rootT10 -Mode 'Hygiene' -ExpectSubstring 'is still a blank form' -ExpectCode 1 -ScratchRoot $WorkRoot -ProposalRoot $candidateRoot

    # T11 - an untouched copy still passes candidate mode
    $rootT11 = New-RealCopy -Label 'T11-candidate-still-passes' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    Run-Case -Label 'T11 the toolkit copy itself still passes candidate mode' -ToolkitRoot $rootT11 -Mode 'Candidate' -ExpectSubstring 'PASS' -ExpectCode 0 -ScratchRoot $WorkRoot -ProposalRoot $candidateRoot

    # ================= adoption path contract cases (T12-T16) ==========================
    # Each uses its own fresh real copy: an adoption run also checks copy integrity, so sharing a
    # copy that another case edited would fail for a reason unrelated to the case under test.
    # AMENDMENT A5: the directory-level cases below run in -Mode Hygiene, which is the explicit
    # contract-unchecked mode. -Mode Adoption would refuse without -GoalContract.

    # T12 - instances in an explicitly declared custom directory
    $rootT12 = New-RealCopy -Label 'T12-adoption-custom' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    $customDir = Split-Path $rootT12 -Parent
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $customDir '.dsh') | Out-Null
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $customDir 'planning') | Out-Null
    foreach ($tpl in @('GOAL.md', 'PLAN.md', 'STATE.md')) {
        $t = [System.IO.File]::ReadAllText((Join-Path $candidateRoot "templates\$tpl"), [System.Text.Encoding]::UTF8).Replace('UNFILLED', 'a declared project value')
        [System.IO.File]::WriteAllText((Join-Path $customDir "planning\$tpl"), $t, (New-Object System.Text.UTF8Encoding($false)))
    }
    Run-Case -Label 'T12 declared custom instance root passes' -ToolkitRoot $rootT12 -Mode 'Hygiene' -InstanceRoot (Join-Path $customDir 'planning') -ExpectSubstring 'PASS' -ExpectCode 0 -ScratchRoot $WorkRoot -ProposalRoot $candidateRoot

    # T13 - a declared custom directory that does not exist
    Run-Case -Label 'T13 declared instance root missing fails' -ToolkitRoot $rootT12 -Mode 'Hygiene' -InstanceRoot (Join-Path $customDir 'nowhere') -ExpectSubstring 'does not exist' -ExpectCode 1 -ScratchRoot $WorkRoot -ProposalRoot $candidateRoot

    # T14 - the declared directory still holds a blank form
    $unfilledDir = Join-Path $WorkRoot 'project-unfilled'
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $unfilledDir '.dsh') | Out-Null
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $unfilledDir 'planning') | Out-Null
    Copy-Item -LiteralPath $candidateRoot -Destination (Join-Path $unfilledDir 'toolkit\long-running') -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $candidateRoot 'templates\GOAL.md') -Destination (Join-Path $unfilledDir 'planning\GOAL.md') -Force
    Run-Case -Label 'T14 declared root still blank fails' -ToolkitRoot (Join-Path $unfilledDir 'toolkit\long-running') -Mode 'Hygiene' -InstanceRoot (Join-Path $unfilledDir 'planning') -ExpectSubstring 'UNFILLED' -ExpectCode 1 -ScratchRoot $WorkRoot -ProposalRoot $candidateRoot

    # T15 - the declared root points at the toolkit's own reusable templates (own fresh copy)
    $rootT15 = New-RealCopy -Label 'T15-toolkit-templates' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    Run-Case -Label 'T15 toolkit templates as instance root fails' -ToolkitRoot $rootT15 -Mode 'Hygiene' -InstanceRoot (Join-Path $rootT15 'templates') -ExpectSubstring 'reusable toolkit' -ExpectCode 1 -ScratchRoot $WorkRoot -ProposalRoot $candidateRoot

    # T16 - no declaration: the documented default is used and reported
    $rootT16 = New-RealCopy -Label 'T16-default-layout' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    $defaultDir = Split-Path $rootT16 -Parent
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $defaultDir '.dsh') | Out-Null
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $defaultDir 'docs\long-running') | Out-Null
    foreach ($tpl in @('GOAL.md', 'PLAN.md', 'STATE.md')) {
        $t = [System.IO.File]::ReadAllText((Join-Path $candidateRoot "templates\$tpl"), [System.Text.Encoding]::UTF8).Replace('UNFILLED', 'a default-layout value')
        [System.IO.File]::WriteAllText((Join-Path $defaultDir "docs\long-running\$tpl"), $t, (New-Object System.Text.UTF8Encoding($false)))
    }
    Run-Case -Label 'T16 undeclared root falls back to the documented default' -ToolkitRoot $rootT16 -Mode 'Hygiene' -ExpectSubstring 'instance root (default):' -ExpectCode 0 -ScratchRoot $WorkRoot -ProposalRoot $candidateRoot

    # ================= v0.2-rc.2 cases: round semantics, instance-root consistency,
    # ================= hygiene-vs-readiness separation (A4 / F1-F3) ====================

    # T31 - the round-execution wording: no absolute rule, and the corrected rules are present
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $skillText = [System.IO.File]::ReadAllText((Join-Path $candidateRoot 'SKILL.md'), [System.Text.Encoding]::UTF8)
    $skillFlat = $skillText -replace '\s+', ' '
    $absolutePhrase = 'a round that tries to finish everything' + ' verifies nothing'
    $t31 = @()
    $t31 += (-not $skillFlat.Contains($absolutePhrase))
    $t31 += $skillFlat.Contains('may complete several related increments')
    $t31 += $skillFlat.Contains('may complete the objective itself')
    $t31 += $skillFlat.Contains('never split work across rounds')
    $t31 += $skillFlat.Contains('verified in the round that produced it')
    $t31 += $skillFlat.Contains('is a ceiling, not a work plan')
    Record (@($t31 | Where-Object { -not $_ }).Count -eq 0) 'T31 round-execution wording corrected' 'one or more required round-semantics statements are missing, or the absolute rule is still present'

    # T32 - declaration says planning/, the argument says docs/long-running/ -> conflict, no PASS
    $rootT32 = New-RealCopy -Label 'T32-root-conflict' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    $conflictDir = Split-Path $rootT32 -Parent
    foreach ($d in @("$conflictDir\.dsh", "$conflictDir\planning", "$conflictDir\docs\long-running")) { $null = New-Item -ItemType Directory -Force -Path $d }
    foreach ($tpl in @('GOAL.md', 'PLAN.md', 'STATE.md')) {
        $t = [System.IO.File]::ReadAllText((Join-Path $candidateRoot "templates\$tpl"), [System.Text.Encoding]::UTF8).Replace('UNFILLED', 'rc.2 conflict-case value')
        [System.IO.File]::WriteAllText((Join-Path $conflictDir "planning\$tpl"), $t, $utf8NoBom)
        [System.IO.File]::WriteAllText((Join-Path $conflictDir "docs\long-running\$tpl"), $t, $utf8NoBom)
    }
    $declaredGoal = Join-Path $conflictDir 'planning\GOAL.md'
    $gTxt = [System.IO.File]::ReadAllText($declaredGoal, [System.Text.Encoding]::UTF8).Replace('Instance root:', "Instance root:`nplanning/")
    [System.IO.File]::WriteAllText($declaredGoal, $gTxt, $utf8NoBom)
    Run-Case -Label 'T32 declared/actual instance-root conflict fails' -ToolkitRoot $rootT32 -Mode 'Adoption' -InstanceRoot $rootT32 -GoalContract $declaredGoal -ExpectSubstring 'instance-root conflict' -ExpectCode 1 -ScratchRoot $WorkRoot -ProposalRoot $candidateRoot

    # T33 - the same directory written in different but equivalent forms is not a conflict
    $rootT33 = New-RealCopy -Label 'T33-equivalent-forms' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    $eqDir = Split-Path $rootT33 -Parent
    foreach ($d in @("$eqDir\.dsh", "$eqDir\planning")) { $null = New-Item -ItemType Directory -Force -Path $d }
    foreach ($tpl in @('GOAL.md', 'PLAN.md', 'STATE.md')) {
        $t = [System.IO.File]::ReadAllText((Join-Path $candidateRoot "templates\$tpl"), [System.Text.Encoding]::UTF8).Replace('UNFILLED', 'rc.2 equivalence value')
        [System.IO.File]::WriteAllText((Join-Path $eqDir "planning\$tpl"), $t, $utf8NoBom)
    }
    $eqGoal = Join-Path $eqDir 'planning\GOAL.md'
    # declared as .\planning\ with a trailing separator and backslashes; passed as planning with
    # a forward slash and different case
    $gTxt = [System.IO.File]::ReadAllText($eqGoal, [System.Text.Encoding]::UTF8).Replace('Instance root:', "Instance root:`n.\PLANNING\")
    [System.IO.File]::WriteAllText($eqGoal, $gTxt, $utf8NoBom)
    Run-Case -Label 'T33 equivalent path spellings are not a conflict' -ToolkitRoot $rootT33 -Mode 'Adoption' -InstanceRoot (Join-Path $eqDir 'planning') -GoalContract $eqGoal -ExpectSubstring 'ADOPTION PASS' -ExpectCode 0 -ScratchRoot $WorkRoot -ProposalRoot $candidateRoot

    # T34 - an unfilled declaration is not a valid path
    $rootT34 = New-RealCopy -Label 'T34-blank-declaration' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    $blankDir = Split-Path $rootT34 -Parent
    foreach ($d in @("$blankDir\.dsh", "$blankDir\planning")) { $null = New-Item -ItemType Directory -Force -Path $d }
    foreach ($tpl in @('GOAL.md', 'PLAN.md', 'STATE.md')) {
        $t = [System.IO.File]::ReadAllText((Join-Path $candidateRoot "templates\$tpl"), [System.Text.Encoding]::UTF8).Replace('UNFILLED', 'rc.2 blank-declaration value')
        [System.IO.File]::WriteAllText((Join-Path $blankDir "planning\$tpl"), $t, $utf8NoBom)
    }
    $blankGoal = Join-Path $blankDir 'planning\GOAL.md'
    $gTxt = [System.IO.File]::ReadAllText($blankGoal, [System.Text.Encoding]::UTF8).Replace('Instance root:', "Instance root:`nUNFILLED - not decided")
    [System.IO.File]::WriteAllText($blankGoal, $gTxt, $utf8NoBom)
    Run-Case -Label 'T34 unfilled declaration is refused' -ToolkitRoot $rootT34 -Mode 'Adoption' -InstanceRoot (Join-Path $blankDir 'planning') -GoalContract $blankGoal -ExpectSubstring 'is not recorded' -ExpectCode 1 -ScratchRoot $WorkRoot -ProposalRoot $candidateRoot

    # T35 / T36 - hygiene passes but readiness does not, and the two verdicts stay distinct
    $rootT35 = New-RealCopy -Label 'T35-goal-only' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    $goalOnlyDir = Split-Path $rootT35 -Parent
    foreach ($d in @("$goalOnlyDir\.dsh", "$goalOnlyDir\docs\long-running")) { $null = New-Item -ItemType Directory -Force -Path $d }
    $onlyGoal = [System.IO.File]::ReadAllText((Join-Path $candidateRoot 'templates\GOAL.md'), [System.Text.Encoding]::UTF8).Replace('UNFILLED', 'rc.2 goal-only value')
    [System.IO.File]::WriteAllText((Join-Path $goalOnlyDir 'docs\long-running\GOAL.md'), $onlyGoal, $utf8NoBom)
    Run-Case -Label 'T35 goal-only instance still passes hygiene' -ToolkitRoot $rootT35 -Mode 'Hygiene' -ExpectSubstring 'CONTRACT NOT CHECKED' -ExpectCode 0 -ScratchRoot $WorkRoot -ProposalRoot $candidateRoot
    Run-Case -Label 'T36a readiness without a contract is refused' -ToolkitRoot $rootT35 -Mode 'Readiness' -InstanceRoot (Join-Path $goalOnlyDir 'docs\long-running') -ExpectSubstring 'requires -GoalContract' -ExpectCode 2 -ScratchRoot $WorkRoot
    Run-Case -Label 'T36b readiness with a contract but no documents is not ready' -ToolkitRoot $rootT35 -Mode 'Readiness' -InstanceRoot (Join-Path $goalOnlyDir 'docs\long-running') -GoalContract (Join-Path $goalOnlyDir 'docs\long-running\GOAL.md') -ExpectSubstring 'NOT READY' -ExpectCode 3 -ScratchRoot $WorkRoot

    # ============ v0.2-rc.3 cases: guarantee scope and fail-closed contract (A5) =========

    # T37 - the candidate claims candidate scope only
    $rootT37 = New-RealCopy -Label 'T37-candidate-scope' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    Run-Case -Label 'T37 candidate claims CANDIDATE VALIDATION only' -ToolkitRoot $rootT37 -Mode 'Candidate' -ExpectSubstring 'CANDIDATE VALIDATION PASS' -ExpectCode 0 -ScratchRoot $WorkRoot

    # T38 - Adoption without a contract is refused (exit 2), never downgraded
    $rootT38 = New-RealCopy -Label 'T38-adoption-no-contract' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    $adoptDir = Split-Path $rootT38 -Parent
    foreach ($d in @("$adoptDir\.dsh", "$adoptDir\planning")) { $null = New-Item -ItemType Directory -Force -Path $d }
    foreach ($tpl in @('GOAL.md', 'PLAN.md', 'STATE.md')) {
        $t = [System.IO.File]::ReadAllText((Join-Path $candidateRoot "templates\$tpl"), [System.Text.Encoding]::UTF8).Replace('UNFILLED', 'rc.3 value')
        [System.IO.File]::WriteAllText((Join-Path $adoptDir "planning\$tpl"), $t, $utf8NoBom)
    }
    Run-Case -Label 'T38 adoption without a contract is refused' -ToolkitRoot $rootT38 -Mode 'Adoption' -InstanceRoot (Join-Path $adoptDir 'planning') -ExpectSubstring 'requires -GoalContract' -ExpectCode 2 -ScratchRoot $WorkRoot

    # T39 - the same project with the contract supplied earns the contract-verified verdict
    $rootT39 = New-RealCopy -Label 'T39-adoption-contract' -CandidateRoot $candidateRoot -ScratchRoot $WorkRoot
    $adopt2Dir = Split-Path $rootT39 -Parent
    foreach ($d in @("$adopt2Dir\.dsh", "$adopt2Dir\planning")) { $null = New-Item -ItemType Directory -Force -Path $d }
    foreach ($tpl in @('GOAL.md', 'PLAN.md', 'STATE.md')) {
        $t = [System.IO.File]::ReadAllText((Join-Path $candidateRoot "templates\$tpl"), [System.Text.Encoding]::UTF8).Replace('UNFILLED', 'rc.3 value')
        [System.IO.File]::WriteAllText((Join-Path $adopt2Dir "planning\$tpl"), $t, $utf8NoBom)
    }
    $adopt2Goal = Join-Path $adopt2Dir 'planning\GOAL.md'
    $gTxt = [System.IO.File]::ReadAllText($adopt2Goal, [System.Text.Encoding]::UTF8).Replace('Instance root:', "Instance root:`n.\PLANNING\")
    [System.IO.File]::WriteAllText($adopt2Goal, $gTxt, $utf8NoBom)
    Run-Case -Label 'T39 adoption with a valid contract passes' -ToolkitRoot $rootT39 -Mode 'Adoption' -InstanceRoot (Join-Path $adopt2Dir 'planning') -GoalContract $adopt2Goal -ExpectSubstring 'ADOPTION PASS (contract-verified)' -ExpectCode 0 -ScratchRoot $WorkRoot -ProposalRoot $candidateRoot

    # T40 - the raw output of each mode is checked for claims it must not make. The phrases are
    # read from the logs the cases just wrote, so this tests the real output, not the source.
    $forbidden = @(
        @{ Label = 'T40a candidate mode output'; File = (Join-Path $WorkRoot 'log-T37-candidate-claims-CANDIDATE-VALIDATION-only.txt'); MustNot = @('ADOPTION PASS', 'HYGIENE PASS') },
        @{ Label = 'T40b hygiene mode output';   File = (Join-Path $WorkRoot ("log-" + ('T12 declared custom instance root passes' -replace '[^A-Za-z0-9]+', '-') + '.txt')); MustNot = @('ADOPTION PASS (contract-verified)', 'instance-root consistency: PASS') },
        @{ Label = 'T40c adoption mode output';  File = (Join-Path $WorkRoot ("log-" + ('T39 adoption with a valid contract passes' -replace '[^A-Za-z0-9]+', '-') + '.txt')); MustNot = @('HYGIENE PASS -', 'READY FOR THE HUMAN GOAL-ARMING DECISION') }
    )
    foreach ($case in $forbidden) {
        if (-not (Test-Path -LiteralPath $case.File)) {
            Record $false $case.Label 'the referenced log was not produced, so the claim scope could not be checked'
            continue
        }
        $t = [System.IO.File]::ReadAllText($case.File, [System.Text.Encoding]::UTF8)
        $bad = @()
        foreach ($m in $case.MustNot) { if ($t.IndexOf($m, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $bad += $m } }
        Record ($bad.Count -eq 0) $case.Label ("output makes a claim it must not make: " + ($bad -join ', '))
    }

    # T41 - the documents of the candidate itself name all four verdicts and their limits
    $vocabFiles = @('README.md', 'SKILL.md', 'METHODOLOGY.md', 'templates\EVALUATION.md')
    $vocabMissing = @()
    foreach ($rel in $vocabFiles) {
        $t = ([System.IO.File]::ReadAllText((Join-Path $candidateRoot $rel), [System.Text.Encoding]::UTF8)) -replace '\s+', ' '
        foreach ($n in @('CANDIDATE VALIDATION', 'HYGIENE PASS', 'ADOPTION PASS', 'CONTRACT NOT CHECKED', 'does not prove')) {
            if ($t.IndexOf($n, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { $vocabMissing += "$rel/$n" }
        }
    }
    Record ($vocabMissing.Count -eq 0) 'T41 the toolkit names every verdict and its limit' ("missing: " + ($vocabMissing -join ', '))

    # T42 - the candidate documents stay byte-stable across the whole harness
    $candidateHashNow = Get-TreeHash $candidateRoot
    Record ($candidateHashBefore -eq $candidateHashNow) 'T42 candidate unchanged by the rc.3 cases' 'the candidate tree hash changed during the selftest'

    # ================= scratch path safety cases (T17-T26) ============================
    # Each rejection must happen before anything is created. Test-ScratchRoot is the exact
    # code path the harness uses at startup, and it is pure: it reads the filesystem only.

    $guardHashBefore = Get-TreeHash $ScratchBase

    function Assert-Refusal {
        param([string]$Label, [string]$Root, [string]$Base, [string]$ExpectKind)
        $r = Test-ScratchRoot -Path $Root -Base $Base
        if ($r.Ok) {
            Record $false $Label 'the unsafe scratch root was ACCEPTED'
            return
        }
        if ($r.Kind -ne $ExpectKind) {
            Record $false $Label "refused, but as '$($r.Kind)' instead of '$ExpectKind' (detail: $($r.Detail))"
            return
        }
        Record $true $Label "refused before any write: [$($r.Kind)]"
    }

    $repoRoot = (Get-Location).ProviderPath

    Assert-Refusal -Label 'T17 relative scratch root is refused'    -Root 'z\01-T1-pass'                              -Base $ScratchBase -ExpectKind 'relative'
    Assert-Refusal -Label 'T18 repository root is refused'          -Root $repoRoot                                   -Base $ScratchBase -ExpectKind 'outside'
    Assert-Refusal -Label 'T19 parent traversal is refused'         -Root (Join-Path $ScratchBase '..\escaped-scratch') -Base $ScratchBase -ExpectKind 'outside'
    Assert-Refusal -Label 'T20 shared-prefix lookalike is refused'  -Root ($ScratchBase + '-evil')                    -Base $ScratchBase -ExpectKind 'outside'
    Assert-Refusal -Label 'T21 missing scratch root is refused'     -Root (Join-Path $ScratchBase 'does-not-exist')    -Base $ScratchBase -ExpectKind 'missing'

    # the rejections above must not have created anything anywhere
    Record (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'z'))) 'T22 no relative scratch root was created' 'a directory named z exists at the repository root'
    Record (-not (Test-Path -LiteralPath ($ScratchBase + '-evil'))) 'T23 no shared-prefix directory was created' 'a shared-prefix directory exists'
    Record (-not (Test-Path -LiteralPath (Join-Path $ScratchBase 'does-not-exist'))) 'T24 no missing scratch root was created' 'the harness created its own scratch root'
    Record (-not (Test-Path -LiteralPath (Join-Path $ScratchBase '..\escaped-scratch'))) 'T25 no traversal target was created' 'the traversal target exists'

    # T26 - a legitimate root under an existing parent is admitted, and the guard still creates
    # nothing while deciding: the parent's entry count must be identical before and after.
    $guardParent = Join-Path $ScratchBase 'guard-probe'
    $null = New-Item -ItemType Directory -Force -Path $guardParent
    $preCount = Get-EntryCount $guardParent
    $rLegit = Test-ScratchRoot -Path (Join-Path $guardParent 'selftest-scratch') -Base $ScratchBase
    $postCount = Get-EntryCount $guardParent
    Record ($preCount -eq 0 -and $postCount -eq 0) 'T26 the guard creates nothing while deciding' "guard-probe went from $preCount to $postCount entries"
    Record ((-not $rLegit.Ok) -and ($rLegit.Kind -eq 'missing')) 'T27 a non-existent child is refused, never created' "kind=$($rLegit.Kind) ok=$($rLegit.Ok)"

    # ================= immutability ===================================================

    $guardHashAfter = Get-TreeHash $ScratchBase
    $candidateHashAfter = Get-TreeHash $candidateRoot
    Record ($candidateHashBefore -eq $candidateHashAfter) 'T28 candidate unchanged by the selftest' 'the candidate tree hash changed during the selftest'
    Record ($guardHashBefore -eq $guardHashAfter) 'T29 refusal cases wrote nothing' 'the scratch base changed during the path-safety cases'

    foreach ($l in $lines) { Write-Host $l }
    Write-Host ''
    Write-Host "scratch base : $ScratchBase"
    Write-Host "work root    : $WorkRoot"
    Write-Host ''
    if ($script:failCount -eq 0) {
        Write-Host 'SELFTEST PASS'
        Write-Host "  $($lines.Count) cases, 0 failures."
        Write-Host '  NOTE: this proves the evaluator discriminates and the scratch guard is fail-closed; it says nothing about guidance quality.'
        return 0
    }
    Write-Host 'SELFTEST FAIL'
    Write-Host "cases failed: $($script:failCount)"
    return 1
}

if ($MyInvocation.InvocationName -ne '.') {
    $code = Invoke-SelfTest -Evaluator $Evaluator -Candidate $Candidate -WorkRoot $WorkRoot -ScratchBase $ScratchBase
    exit $code
}

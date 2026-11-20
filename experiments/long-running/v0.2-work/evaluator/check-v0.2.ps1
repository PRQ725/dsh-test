#requires -Version 5.1
<#
  check-v0.2.ps1 - Long-running Toolkit v0.2 mechanical acceptance evaluator

  PURPOSE
    Read-only, artifact-based acceptance check for the v0.2 development candidate of the
    Long-running Toolkit, and for a project that has adopted it.

  FROZEN BY
    experiments/long-running/v0.2-work/V0.2-ACCEPTANCE-SPEC.md (checks V1-V12 plus the
    cross-cutting rules R1-R3). This implementation must test the substance of those
    checks, not merely the presence of a phrase.

  INSTANCE ROOT (spec amendment A3, v0.2-rc.1)
    In -Mode Adoption, the directory holding the adopting project's FILLED documents is
    named by -InstanceRoot. When it is omitted, the documented default
    <projectRoot>/docs/long-running/ is used. The path actually inspected is always
    printed, marked (declared) or (default), so a PASS cannot be claimed against an
    undocumented location. The toolkit's own reusable templates/ is never admissible.

  WHAT IT DELIBERATELY DOES NOT DO
    - It never reads, trusts or looks for a model-declared completion claim.
    - It never modifies anything: no write cmdlet appears in this file. The one optional
      writer is the caller (-LogPath), and the self-test uses it.
    - It cannot judge whether the guidance is GOOD, adoptable or correctly generalised.
      Quality is a human decision (see spec section 4).

  EXIT CODES
    0 = PASS   (no failure reasons)
    1 = FAIL   (one or more concrete printed reasons)
    2 = ERROR  (bad invocation, unreadable root, or internal failure)

  ENTRY MODEL
    The program logic lives in the Invoke-Check function. Running this file as a script
    executes it and exits with the code; loading the file's text and calling
    ([scriptblock]::Create($text)) exposes Invoke-Check for in-process use. This matters on
    hosts whose execution policy forbids running .ps1 files, where a nested
    "powershell -File" child process is the only alternative and may itself be denied.
#>

[CmdletBinding()]
param(
    [string]$Root,

    [string]$Proposal,

    [string]$Workspace,

    [ValidateSet('Candidate', 'Hygiene', 'Adoption', 'Readiness')]
    [string]$Mode = 'Candidate',

    [string]$InstanceRoot,

    [string]$GoalContract,

    [string]$InstanceRootDeclared,

    [string]$LogPath
)

Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

function Invoke-Check {
    param(
        [string]$Root,
        [string]$Proposal,
        [string]$Workspace,
        [string]$Mode,
        [string]$InstanceRoot,
        [string]$GoalContract,
        [string]$InstanceRootDeclared,
        [string]$LogPath
    )

    $script:Reasons = New-Object 'System.Collections.Generic.List[string]'
    $script:Lines = New-Object 'System.Collections.Generic.List[string]'
    $script:InstanceRootUsed = ''
    $script:InstanceRootSource = ''
    $script:InstanceRootDeclaredRaw = ''
    $script:InstanceRootDeclaredSource = ''
    $script:InstanceRootConsistency = ''
    $script:ProjectRootFound = ''
    $script:ReadinessRows = New-Object 'System.Collections.Generic.List[string]'
    $script:ReadinessNotReady = 0

    function Add-Reason([string]$r) { $script:Reasons.Add($r) }
    function Emit([string]$s) { $script:Lines.Add($s) }

    function Get-Text([string]$path) {
        $raw = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
        $raw = $raw -replace "^\uFEFF", ""
        # Line wrapping is not content. Prose is hard-wrapped in these documents, so
        # every whitespace run collapses to one space before any phrase is matched;
        # otherwise a phrase is only found where the author happened to break the line.
        return ($raw -replace '\s+', ' ')
    }

    function Test-Has([string]$text, [string]$needle) {
        if ($null -eq $text) { return $false }
        $n = $needle -replace '\s+', ' '
        return $text.IndexOf($n, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    }

    function Test-Any([string]$text, [string[]]$needles) {
        foreach ($n in $needles) { if (Test-Has $text $n) { return $true } }
        return $false
    }

    # Containment by path SEGMENTS. A string-prefix test would report `C:\a\beevil` as being
    # inside `C:\a\be`; this cannot. PowerShell's -ne on strings is case-insensitive, which is
    # the right comparison for Windows paths.
    function Test-Under([string]$Path, [string]$Base) {
        try {
            $p = @([System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/') -split '[\\/]' | Where-Object { $_ -ne '' })
            $b = @([System.IO.Path]::GetFullPath($Base).TrimEnd('\', '/') -split '[\\/]' | Where-Object { $_ -ne '' })
        } catch {
            return $false
        }
        if ($b.Count -eq 0 -or $p.Count -lt $b.Count) { return $false }
        for ($i = 0; $i -lt $b.Count; $i++) {
            if ($p[$i] -ne $b[$i]) { return $false }
        }
        return $true
    }

    # Line-oriented helper for the checks that must stay line-scoped (frontmatter,
    # angle-bracket placeholders). It re-reads the raw file, not the flattened text.
    function Get-RawText([string]$path) {
        $raw = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
        return ($raw -replace "^\uFEFF", "")
    }

    function Get-Line([string]$text, [int]$index) {
        $lineEnd = $text.IndexOf("`n", $index)
        if ($lineEnd -lt 0) { $lineEnd = $text.Length }
        return $text.Substring($index, $lineEnd - $index)
    }

    # --- AMENDMENT A4 helpers (v0.2-rc.2) ------------------------------------------------

    # Reads the value of a `Label:` field from a document. The value is the rest of the line
    # plus the first following non-empty line, which is how the templates are written.
    function Get-FieldValue([string]$text, [string]$label) {
        if ([string]::IsNullOrWhiteSpace($text)) { return $null }
        $idx = $text.IndexOf($label, [System.StringComparison]::OrdinalIgnoreCase)
        if ($idx -lt 0) { return $null }
        $lineEnd = $text.IndexOf("`n", $idx)
        if ($lineEnd -lt 0) { $lineEnd = $text.Length }
        $first = $text.Substring($idx + $label.Length, $lineEnd - $idx - $label.Length).Trim()
        if ($first.Length -gt 0) { return $first }
        $rest = $text.Substring($lineEnd).TrimStart("`r", "`n")
        if ($rest.Length -eq 0) { return '' }
        $nl = $rest.IndexOf("`n")
        if ($nl -lt 0) { return $rest.Trim() }
        return $rest.Substring(0, $nl).Trim()
    }

    # Normalizes a path for comparison: resolves a relative value against a base, collapses
    # `.` and `..`, drops trailing separators, and lower-cases (Windows paths are
    # case-insensitive). This is what stops two spellings of one directory being reported as
    # a conflict, and two different directories being reported as equal.
    function Get-NormalizedPath([string]$path, [string]$base) {
        if ([string]::IsNullOrWhiteSpace($path)) { return $null }
        $p = $path.Trim().Trim('"', "'")
        if ($p.Length -eq 0) { return $null }
        try {
            if (-not [System.IO.Path]::IsPathRooted($p)) {
                if ([string]::IsNullOrWhiteSpace($base)) { return $null }
                $p = [System.IO.Path]::Combine($base, $p)
            }
            $full = [System.IO.Path]::GetFullPath($p)
        } catch {
            return $null
        }
        $full = $full -replace '/', '\'
        $full = $full.TrimEnd('\')
        return $full.ToLowerInvariant()
    }

    function Test-SamePath([string]$a, [string]$b, [string]$baseA, [string]$baseB) {
        $na = Get-NormalizedPath -path $a -base $baseA
        $nb = Get-NormalizedPath -path $b -base $baseB
        if ($null -eq $na -or $null -eq $nb) { return $false }
        return ($na -eq $nb)
    }

    # A field that is still a blank form or has been explicitly left unrecorded.
    function Test-Unrecorded([string]$value) {
        if ([string]::IsNullOrWhiteSpace($value)) { return $true }
        return (Test-Any $value @('UNFILLED', 'NOT RECORDED', 'TO BE FILLED', 'PENDING'))
    }

    # A hash-looking record, without pretending to verify what it hashes.
    function Test-HashLike([string]$value) {
        if ([string]::IsNullOrWhiteSpace($value)) { return $false }
        return ($value -match '(?i)\b[0-9a-f]{16,}\b')
    }

    # ------------------------------------------------------------------ contract
    $files = @(
        @{ Rel = 'README.md';                 Min = 1500; Head = @('## What this is', '## When to use it', '## When not to use it', '## Adoption procedure', '## Compatibility', '## Files in this toolkit'); Field = @('Step 1', 'Step 14'); Template = $false }
        @{ Rel = 'SKILL.md';                  Min = 2500; Head = @('## Applicability', '## Project discovery', '## Goal design', '## Plan approval', '## Evaluator design and freeze', '## State and evidence initialization', '## Budget and safety review', '## Initialization readiness', '## Goal activation', '## Round execution', '## Stop and escalation', '## Recovery', '## Final reporting', '## Human acceptance', '## Knowledge deposition'); Field = @('Input:', 'Output:', 'HARD', 'SOFT'); Template = $false }
        @{ Rel = 'METHODOLOGY.md';            Min = 2500; Head = @('## 1 Objective', '## 2 Plan', '## 3 State', '## 4 Evaluation', '## 5 Budget', '## 6 Stop', '## 7 Recovery', '## 8 Knowledge deposition', '## A', '## B', '## C', '## D', '## E', '## F', '## G', '## H', '## I', '## J'); Field = @('maxGoalRounds', 'SOFT', 'FACT', 'INFERENCE', 'UNKNOWN'); Template = $false }
        @{ Rel = 'templates/GOAL.md';         Min = 400;  Head = @(); Field = @('Objective:', 'Success criteria:', 'Scope boundaries:', 'Non-goals:', 'Evidence requirements:', 'Budget:', 'Stop conditions:', 'Human escalation:', 'Report path:', 'Report owner:', 'Acceptance authority:', 'Evaluator location:', 'Version assumptions:'); Template = $true }
        @{ Rel = 'templates/PLAN.md';         Min = 400;  Head = @(); Field = @('Plan status:', 'Goal reference:', 'Work stages:', 'Deliverables:', 'Verification per stage:', 'Replanning triggers:', 'Budget:', 'Human approval:', 'Approval record:', 'Amendments:', 'Recovery reference:'); Template = $true }
        @{ Rel = 'templates/STATE.md';        Min = 400;  Head = @(); Field = @('Round:', 'Completed:', 'Verified facts:', 'Open questions:', 'Next step:', 'Artifacts:', 'Evidence:', 'Budget used:', 'Recovery also needs:'); Template = $true }
        @{ Rel = 'templates/EVALUATION.md';   Min = 400;  Head = @(); Field = @('Evaluation contract:', 'Evaluator implementation:', 'How the evaluator is authored:', 'Frozen:', 'Test cases:', 'Tamper check:', 'Machine checks:', 'Evidence quality:', 'Human review:', 'Initialization readiness:'); Template = $true }
        @{ Rel = 'templates/FINAL-REPORT.md'; Min = 600;  Head = @(); Field = @('Report path:', 'Report owner:', '1. Executive summary', '2. Goal and frozen baseline', '3. Execution timeline', '4. Deliverable inventory', '5. Evaluation and acceptance', '6. Budget and efficiency', '7. Deviations and incidents', '8. Lessons learned', '9. Next actions'); Template = $true }
    )

    # ------------------------------------------------------------- invocation
    $rootFull = $null
    try {
        if ([string]::IsNullOrWhiteSpace($Root)) {
            Emit 'ERROR: -Root is required'
            return 2
        }
        if (-not (Test-Path -LiteralPath $Root)) {
            Emit "ERROR: root does not exist: $Root"
            return 2
        }
        if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
            Emit "ERROR: root is not a directory: $Root"
            return 2
        }
        $rootFull = (Resolve-Path -LiteralPath $Root).ProviderPath
        if ([string]::IsNullOrWhiteSpace($Mode)) { $Mode = 'Candidate' }
        if ($Mode -notin @('Candidate', 'Hygiene', 'Adoption', 'Readiness')) {
            Emit "ERROR: unknown -Mode '$Mode'"
            return 2
        }
        if ($Mode -eq 'Readiness' -and -not [string]::IsNullOrWhiteSpace($Proposal)) {
            Emit 'ERROR: -Mode Readiness does not use -Proposal; it judges a project, not a toolkit copy'
            return 2
        }
        # AMENDMENT A5 / F-A5: a contract-verified verdict is impossible without the contract.
        # Refuse the invocation instead of silently downgrading to a weaker claim.
        if ($Mode -in @('Adoption', 'Readiness') -and [string]::IsNullOrWhiteSpace($GoalContract) -and [string]::IsNullOrWhiteSpace($InstanceRootDeclared)) {
            Emit "ERROR: -Mode $Mode requires -GoalContract (or -InstanceRootDeclared) naming the frozen declaration."
            Emit 'The instance-root consistency check cannot be performed without it, and an unverified'
            Emit 'consistency check must not be reported as an adoption or readiness result.'
            Emit 'Use -Mode Hygiene if you only want the directory-level check; it prints CONTRACT NOT CHECKED.'
            return 2
        }
        if ($Mode -eq 'Hygiene' -and (-not [string]::IsNullOrWhiteSpace($GoalContract) -or -not [string]::IsNullOrWhiteSpace($InstanceRootDeclared))) {
            Emit 'ERROR: -Mode Hygiene does not accept -GoalContract or -InstanceRootDeclared.'
            Emit 'Hygiene is deliberately the contract-unchecked mode; use -Mode Adoption for a contract-verified result.'
            return 2
        }
        if ([string]::IsNullOrWhiteSpace($Workspace)) {
            # Informational only. Resolve from this file's own location, with cwd fallbacks,
            # and never fail the run because of it.
            $self = $PSCommandPath
            if ([string]::IsNullOrWhiteSpace($self)) { $self = $MyInvocation.MyCommand.Path }
            if (-not [string]::IsNullOrWhiteSpace($self)) {
                # <workspace>/experiments/long-running/v0.2-work/evaluator/this.ps1
                $Workspace = (Resolve-Path -LiteralPath (Join-Path (Split-Path $self -Parent) '..\..\..\..')).ProviderPath
            } else {
                $Workspace = (Get-Location).ProviderPath
            }
        }
        $proposalFull = $null
        if (-not [string]::IsNullOrWhiteSpace($Proposal)) {
            if (-not (Test-Path -LiteralPath $Proposal -PathType Container)) {
                Emit "ERROR: -Proposal is not a directory: $Proposal"
                return 2
            }
            $proposalFull = (Resolve-Path -LiteralPath $Proposal).ProviderPath
        }

        # --------------------------------------------------- V1 files and fields
        $texts = @{}
        $present = 0
        foreach ($f in $files) {
            $full = Join-Path $rootFull $f.Rel
            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
                Add-Reason "V1 missing artifact: $($f.Rel)"
                $texts[$f.Rel] = $null
                continue
            }
            $present++
            $item = Get-Item -LiteralPath $full
            if ($item.Length -lt $f.Min) {
                Add-Reason "V1 artifact too small: $($f.Rel) is $($item.Length) bytes, expected >= $($f.Min)"
            }
            $text = Get-Text $full
            $rawText = Get-RawText $full
            $texts[$f.Rel] = $text
            foreach ($h in $f.Head) {
                if (-not (Test-Has $text $h)) { Add-Reason "V1 missing required section in $($f.Rel): '$h'" }
            }
            foreach ($fld in $f.Field) {
                if (-not (Test-Has $text $fld)) { Add-Reason "V1 missing required field in $($f.Rel): '$fld'" }
            }
            # R1 placeholder hygiene
            foreach ($p in @('TODO', 'TBD', 'FIXME', 'XXX')) {
                if (Test-Has $text $p) { Add-Reason "R1 unfinished placeholder '$p' left in $($f.Rel)" }
            }
            # R1 no angle-bracket placeholder on a required field line (line-scoped)
            $rawLines = $rawText -split "`r?`n"
            for ($li = 0; $li -lt $rawLines.Count; $li++) {
                $line = $rawLines[$li]
                foreach ($fld in $f.Field) {
                    if ($line.TrimStart().StartsWith($fld, [System.StringComparison]::OrdinalIgnoreCase)) {
                        if ($line -match '<[^>]{2,}>') {
                            Add-Reason "R1 unfilled angle-bracket placeholder in $($f.Rel): $($line.Trim())"
                        }
                    }
                }
            }
            # R2 skill frontmatter must be present, or DSH drops the skill silently
            if ($f.Rel -eq 'SKILL.md') {
                $lines = $rawLines
                if ($lines.Count -lt 4 -or $lines[0].Trim() -ne '---') {
                    Add-Reason 'R2 SKILL.md must open with YAML frontmatter (first line is exactly ---)'
                } else {
                    $close = -1
                    for ($i = 1; $i -lt $lines.Count; $i++) {
                        if ($lines[$i].Trim() -eq '---') { $close = $i; break }
                    }
                    if ($close -lt 0) {
                        Add-Reason 'R2 SKILL.md frontmatter block is not closed with ---'
                    } else {
                        $fm = ($lines[1..($close - 1)] -join "`n")
                        if ($fm -notmatch '(?m)^name:\s*\S') {
                            Add-Reason 'R2 SKILL.md frontmatter must declare a name (kebab-case)'
                        } elseif ($fm -notmatch '(?m)^name:\s*[a-z0-9]+(-[a-z0-9]+)*\s*$') {
                            Add-Reason 'R2 SKILL.md frontmatter name must be kebab-case'
                        }
                        if ($fm -notmatch '(?m)^description:\s*\S') {
                            Add-Reason 'R2 SKILL.md frontmatter must declare a description'
                        }
                    }
                }
            }
        }
        if ($present -eq 0) {
            Add-Reason 'V1 toolkit root contains none of the eight required files'
        }

        # file count: exactly the eight, no extras anywhere under the root
        $allMd = @(Get-ChildItem -LiteralPath $rootFull -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue)
        $allAny = @(Get-ChildItem -LiteralPath $rootFull -Recurse -File -ErrorAction SilentlyContinue)
        if ($allMd.Count -ne 8) {
            Add-Reason "V1 expected exactly 8 Markdown files under the toolkit root, found $($allMd.Count)"
        }
        if ($allAny.Count -ne $allMd.Count) {
            Add-Reason "V1 expected no non-Markdown file under the toolkit root, found $($allAny.Count - $allMd.Count)"
        }
        $expected = @{}
        foreach ($f in $files) { $expected[$f.Rel] = $true }
        foreach ($m in $allMd) {
            $rel = $m.FullName.Substring($rootFull.Length).TrimStart('\', '/') -replace '\\', '/'
            if (-not $expected.ContainsKey($rel)) { Add-Reason "V1 unexpected file under the toolkit root: $rel" }
        }

        # -------------------------------------------------------- V2 references
        # The path character class already excludes the backtick delimiter, so no
        # lookbehind is needed. Backticks are deliberately kept out of these
        # patterns: inside a double-quoted PowerShell string a backtick is an
        # escape character, which silently corrupts a regex.
        $refPattern = 'templates/[A-Za-z0-9_.\-]+\.md'
        foreach ($rel in @('README.md', 'SKILL.md', 'METHODOLOGY.md')) {
            $text = $texts[$rel]
            if ($null -eq $text) { continue }
            $seen = @{}
            foreach ($m in [regex]::Matches($text, $refPattern)) {
                $ref = $m.Value
                if ($seen.ContainsKey($ref)) { continue }
                $seen[$ref] = $true
                if (-not (Test-Path -LiteralPath (Join-Path $rootFull $ref) -PathType Leaf)) {
                    Add-Reason "V2 broken reference in ${rel}: '$ref' does not exist under the toolkit root"
                }
            }
        }
        # every templates/*.md table row in README must name an existing file and a role
        $readme = $texts['README.md']
        if ($null -ne $readme) {
            $rows = 0
            $fileRowPattern = '`(README\.md|SKILL\.md|METHODOLOGY\.md|templates/[A-Za-z0-9_.\-]+\.md)`'
            foreach ($line in ((Get-RawText (Join-Path $rootFull 'README.md')) -split "`r?`n")) {
                if ($line -notmatch '^\|') { continue }
                if ($line -notmatch $fileRowPattern) { continue }
                $rows++
                $m = [regex]::Match($line, $refPattern)
                if ($m.Success) {
                    $ref = $m.Value
                    if ($line -notmatch 'more than one|Read next') {
                        $cells = @(($line -replace '^\s*\|', '' -replace '\|\s*$', '') -split '\|')
                        if ($cells.Count -lt 2) {
                            Add-Reason "V2 README table row for '$ref' must give both the file and its role"
                        } elseif ($cells[1].Trim().Length -lt 6) {
                            Add-Reason "V2 README table row for '$ref' carries no role description"
                        }
                    }
                    if (-not (Test-Path -LiteralPath (Join-Path $rootFull $ref) -PathType Leaf)) {
                        Add-Reason "V2 README table names '$ref', which does not exist under the toolkit root"
                    }
                }
            }
            if ($rows -lt 8) {
                Add-Reason "V2 README file table must name all eight toolkit files; found $rows file rows"
            }
        }

        # ------------------------------------------------------- V3 portability
        $absolutePath = '(?<![A-Za-z0-9])[A-Za-z]:[\\/]'
        $localTokens = @('dsh-longloop-pilot', 'dsh-test', 'Personal Job Search OS', 'user02')
        foreach ($f in $files) {
            $text = $texts[$f.Rel]
            if ($null -eq $text) { continue }
            foreach ($m in [regex]::Matches($text, $absolutePath)) {
                Add-Reason "V3 non-portable absolute path '$($m.Value)' found in $($f.Rel)"
            }
            foreach ($tok in $localTokens) {
                if (Test-Has $text $tok) { Add-Reason "V3 non-portable local identifier '$tok' found in $($f.Rel)" }
            }
        }

        # ----------------------------------------------------- V4 consistency
        if ($null -ne $readme) {
            if (-not (Test-Has $readme 'Count them')) {
                Add-Reason 'V4 README must state the toolkit file count explicitly before the file table'
            }
            foreach ($m in [regex]::Matches($readme, '(?i)\b(\d+)\s+files\b')) {
                if ($m.Groups[1].Value -ne '8') {
                    Add-Reason "V4 README claims '$($m.Value)', which contradicts the eight-file contract"
                }
            }
            foreach ($f in $files) {
                $ref = $f.Rel
                $count = ([regex]::Matches($readme, [regex]::Escape($ref))).Count
                if ($count -eq 0) { Add-Reason "V4 README file table omits $ref" }
            }
        }
        foreach ($rel in @('README.md', 'SKILL.md', 'METHODOLOGY.md')) {
            $text = $texts[$rel]
            if ($null -eq $text) { continue }
            if (Test-Has $text 'six files') { Add-Reason "V4 stale v0.1 file count wording ('six files') present in $rel" }
        }

        # ------------------------------------------- V5 goal / plan / state jobs
        $methodology = $texts['METHODOLOGY.md']
        if ($null -ne $methodology) {
            if (-not (Test-Has $methodology 'the goal is the **contract**')) {
                Add-Reason 'V5 METHODOLOGY section A must name the goal as the contract'
            }
            if (-not (Test-Has $methodology 'the plan is the **route**')) {
                Add-Reason 'V5 METHODOLOGY section A must name the plan as the route'
            }
            if (-not (Test-Has $methodology 'the state is the **position**')) {
                Add-Reason 'V5 METHODOLOGY section A must name the state as the position'
            }
            if (-not (Test-Has $methodology 'only thing the next round must read')) {
                Add-Reason 'V5 METHODOLOGY must correct the v0.1 over-claim that STATE.md is the only file a round reads'
            }
        }
        $stateTpl = $texts['templates/STATE.md']
        if ($null -ne $stateTpl) {
            foreach ($needle in @('not sufficient on its own', 'approved plan', 'evidence file', 'on disk')) {
                if (-not (Test-Has $stateTpl $needle)) {
                    Add-Reason "V5 templates/STATE.md must state that recovery needs more than this file (missing: '$needle')"
                }
            }
        }

        # ------------------------------------------ V6 contract vs implementation
        if ($null -ne $methodology) {
            if (-not (Test-Has $methodology 'evaluation contract')) {
                Add-Reason 'V6 METHODOLOGY must distinguish the evaluation contract from the evaluator implementation'
            }
            if (-not (Test-Has $methodology 'evaluator implementation')) {
                Add-Reason 'V6 METHODOLOGY must name the evaluator implementation as a program, not a record'
            }
            foreach ($needle in @('Independence', 'Regression', 'Freeze')) {
                if (-not (Test-Has $methodology $needle)) {
                    Add-Reason "V6 METHODOLOGY evaluator lifecycle must cover '$needle'"
                }
            }
        }
        $evalTpl = $texts['templates/EVALUATION.md']
        if ($null -ne $evalTpl) {
            if (-not (Test-Has $evalTpl 'It is not an evaluator')) {
                Add-Reason 'V6 templates/EVALUATION.md must say plainly that a Markdown record is not an evaluator'
            }
            foreach ($needle in @('PASS', 'FAIL', 'ERROR', 'independen', 'hash')) {
                if (-not (Test-Has $evalTpl $needle)) {
                    Add-Reason "V6 templates/EVALUATION.md must cover evaluator testing/freezing (missing: '$needle')"
                }
            }
        }

        # ------------------------------------------------ V7 final report contract
        $goalTpl = $texts['templates/GOAL.md']
        if ($null -ne $goalTpl) {
            if (-not (Test-Has $goalTpl 'before')) {
                Add-Reason 'V7 templates/GOAL.md must require the report path to be fixed before arming'
            }
            if (-not (Test-Has $goalTpl 'never declares either')) {
                Add-Reason 'V7 templates/GOAL.md must reserve acceptance and completion to a human'
            }
        }
        $reportTpl = $texts['templates/FINAL-REPORT.md']
        if ($null -ne $reportTpl) {
            foreach ($needle in @('before the goal is armed', 'after automatic continuation has stopped', 'UNKNOWN', 'terminal state', 'never rewrite', 'Appendix A')) {
                if (-not (Test-Has $reportTpl $needle)) {
                    Add-Reason "V7 templates/FINAL-REPORT.md missing contract requirement: '$needle'"
                }
            }
        }

        # ------------------------------------------------------- V8 HARD vs SOFT
        foreach ($rel in @('METHODOLOGY.md', 'SKILL.md')) {
            $text = $texts[$rel]
            if ($null -eq $text) { continue }
            if (-not (Test-Has $text 'maxGoalRounds')) { Add-Reason "V8 $rel must name the enforced budget maxGoalRounds" }
            if (-not (Test-Has $text 'SOFT')) { Add-Reason "V8 $rel must label unenforced limits SOFT" }
        }
        if ($null -ne $methodology) {
            if (-not (Test-Has $methodology 'the only budget labelled `HARD`')) {
                Add-Reason 'V8 METHODOLOGY must state that the round cap is the only HARD budget'
            }
        }
        $skill = $texts['SKILL.md']
        if ($null -ne $skill) {
            if (-not (Test-Has $skill 'stops nothing')) {
                Add-Reason 'V8 SKILL.md must state that READY FOR HUMAN REVIEW stops nothing'
            }
            if (-not (Test-Has $skill 'cannot pause')) {
                Add-Reason 'V8 SKILL.md must state that the model cannot pause or re-arm its own goal'
            }
        }

        # ---------------------------------------------------- V9 skill discovery
        if ($null -ne $skill) {
            foreach ($needle in @('frontmatter', 'depth', 'UNKNOWN')) {
                if (-not (Test-Has $skill $needle)) {
                    Add-Reason "V9 SKILL.md must record the real Skill discovery boundary (missing: '$needle')"
                }
            }
        }
        if ($null -ne $readme) {
            if (-not (Test-Has $readme 'does **not** create a loadable skill')) {
                Add-Reason 'V9 README must state that copying a file to the project root does not create a loadable skill'
            }
            if (-not (Test-Has $readme 'did **not** execute')) {
                Add-Reason 'V9 README must state that this toolkit did not execute the discovery claim'
            }
        }

        # ------------------------------------------------------- V10 adoption
        if ($null -ne $readme) {
            foreach ($n in 1..14) {
                if (-not (Test-Has $readme ("### Step " + $n + " "))) {
                    Add-Reason "V10 README adoption procedure is missing step $n"
                }
            }
            if (-not (Test-Has $readme 'does not** create or arm a goal') -and -not (Test-Has $readme 'does **not** create or arm a goal')) {
                Add-Reason 'V10 README must state that plan approval does not create or arm the goal'
            }
            if (-not (Test-Has $readme 'requires a direct human request')) {
                Add-Reason 'V10 README must state that goal creation requires a direct human request'
            }
        }

        # ------------------------------------------------------- V11 version
        $planTpl = $texts['templates/PLAN.md']
        if ($null -ne $planTpl) {
            if (-not (Test-Has $planTpl 'does not create or arm a goal')) {
                Add-Reason 'V10 templates/PLAN.md must state that plan approval does not arm the goal'
            }
        }
        if ($null -ne $readme) {
            if (-not (Test-Has $readme '0.2.0')) {
                Add-Reason "V11 README must record the verified DSH version line"
            }
            if (-not (Test-Any $readme @('re-confirm', 'reconfirm'))) {
                Add-Reason 'V11 README must instruct the reader to re-confirm the mechanism contract in the target environment'
            }
            if (-not (Test-Any $readme @('version-bound', 'version bound'))) {
                Add-Reason 'V11 README must mark its mechanism claims as version-bound'
            }
            foreach ($pkg in @('@deepseek-ai/dsh-goal', '@deepseek-ai/dsh-goal-round-driver', '@deepseek-ai/dsh-tool-goal')) {
                if (-not (Test-Has $readme $pkg)) { Add-Reason "V11 README compatibility section must name '$pkg'" }
            }
        }
        if ($null -ne $methodology) {
            if (-not (Test-Has $methodology 'version-bound')) {
                Add-Reason 'V11 METHODOLOGY must mark its mechanism claims as version-bound'
            }
        }

        # ------------------------------------------------- V12 unfilled markers
        # AMENDMENT A4: this block is INSTANCE HYGIENE. -Mode Readiness runs it too, because a
        # project that fails hygiene cannot be ready.
        if ($Mode -eq 'Candidate') {
            foreach ($f in $files) {
                if (-not $f.Template) { continue }
                $text = $texts[$f.Rel]
                if ($null -eq $text) { continue }
                if (-not (Test-Has $text 'UNFILLED')) {
                    Add-Reason "V12 $($f.Rel) is a blank form and must carry the UNFILLED marker"
                }
            }
        } elseif ($Mode -in @('Hygiene', 'Adoption', 'Readiness')) {
            # AMENDMENT A1 (2026-10-09): the original rule scanned the toolkit root, which can
            # never pass in a correct adoption because a copied toolkit keeps its blank forms
            # on purpose. The rule now inspects the adopting project's own filled instances.
            # AMENDMENT A3 (2026-10-09, v0.2-rc.1): their location was hard-coded to
            # docs/long-running/ even though the toolkit's README never stated that
            # convention, so a legitimate adopter using another directory was failed. The
            # location is now the documented default OR an explicitly declared -InstanceRoot,
            # and the path actually inspected is always reported.
            # AMENDMENT A4 (2026-10-09, v0.2-rc.2): this block establishes INSTANCE HYGIENE
            # only. V13 below adds the declared-vs-actual consistency check, and -Mode
            # Readiness adds the separate INITIALIZATION READINESS contract.
            # AMENDMENT A5 (2026-10-09, v0.2-rc.3): V13's consistency check is now REQUIRED by
            # Adoption and Readiness, and -Mode Hygiene is the explicit contract-unchecked mode.
            $projectRoot = $null
            $probe = $rootFull
            for ($i = 0; $i -lt 5; $i++) {
                if ([string]::IsNullOrWhiteSpace($probe)) { break }
                if ((Test-Path -LiteralPath (Join-Path $probe '.git')) -or (Test-Path -LiteralPath (Join-Path $probe '.dsh'))) {
                    $projectRoot = $probe
                    break
                }
                $parent = Split-Path $probe -Parent
                if ($parent -eq $probe) { break }
                $probe = $parent
            }

            $instances = $null
            $instanceSource = ''
            if (-not [string]::IsNullOrWhiteSpace($InstanceRoot)) {
                $instanceSource = 'declared'
                if (-not (Test-Path -LiteralPath $InstanceRoot -PathType Container)) {
                    Add-Reason "V12 the declared instance root does not exist as a directory: $InstanceRoot"
                } else {
                    $instances = (Resolve-Path -LiteralPath $InstanceRoot).ProviderPath
                }
            } elseif ($null -eq $projectRoot) {
                Add-Reason 'V12 could not locate the adopting project root (no .git and no .dsh marker found within five levels above the toolkit root), so the default instance root could not be derived; pass -InstanceRoot explicitly'
            } else {
                $instanceSource = 'default'
                $instances = Join-Path $projectRoot 'docs\long-running'
                if (-not (Test-Path -LiteralPath $instances -PathType Container)) {
                    Add-Reason "V12 the default instance root does not exist: $instances (pass -InstanceRoot to declare a different directory)"
                    $instances = $null
                } else {
                    $instances = (Resolve-Path -LiteralPath $instances).ProviderPath
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($instances)) {
                # The toolkit's own reusable templates are never an initialized project.
                $inToolkitTree = Test-Under -Path $instances -Base $rootFull
                $templatesDir = Join-Path $rootFull 'templates'
                $isTemplates = $false
                if (Test-Path -LiteralPath $templatesDir -PathType Container) {
                    $isTemplates = (Test-Under -Path $instances -Base (Resolve-Path -LiteralPath $templatesDir).ProviderPath)
                }
                if ($inToolkitTree -or $isTemplates) {
                    Add-Reason "V12 the instance root resolves inside the toolkit's own reusable toolkit tree, which is not an initialized project: $instances"
                } else {
                    $instanceFiles = @(Get-ChildItem -LiteralPath $instances -File -Filter '*.md' -ErrorAction SilentlyContinue)
                    if ($instanceFiles.Count -eq 0) {
                        Add-Reason "V12 no filled project documents found under $instances"
                    }
                    foreach ($instance in $instanceFiles) {
                        $t = Get-Text $instance.FullName
                        if (Test-Has $t 'UNFILLED') {
                            Add-Reason "V12 the project document $($instance.Name) is still a blank form (contains UNFILLED)"
                        }
                    }
                }
                $script:InstanceRootUsed = $instances
                $script:InstanceRootSource = $instanceSource
            }
            $script:ProjectRootFound = $projectRoot
        }

        # ------------------------------ V14 round-execution semantics (A4 / F1) --------------
        # Documentation rule. The test is the substance: one round MAY complete several related
        # increments and MAY complete the whole objective, the prohibition is on splitting work
        # to consume budget, a mechanical pass is not acceptance, and nothing may claim that the
        # review marker stops the driver. The forbidden absolute is checked by DELETING the
        # marked phrase before searching, so this source file does not itself contain it.
        if ($Mode -eq 'Candidate') {
            $absolutePhrase = 'a round that tries to finish everything' + ' verifies nothing'
            foreach ($rel in @('SKILL.md', 'METHODOLOGY.md', 'README.md')) {
                $text = $texts[$rel]
                if ($null -eq $text) { continue }
                if (Test-Has $text $absolutePhrase) {
                    Add-Reason "V14 $rel still contains the absolute round rule ('$absolutePhrase'); one round may complete several related increments, or the whole objective"
                }
            }
            if ($null -ne $skill) {
                if (-not (Test-Has $skill 'may complete several related increments')) {
                    Add-Reason 'V14 SKILL.md must state that one round may complete several related increments'
                }
                if (-not (Test-Has $skill 'may complete the objective itself')) {
                    Add-Reason 'V14 SKILL.md must state that one round may complete the objective itself'
                }
                if (-not (Test-Has $skill 'never split work across rounds')) {
                    Add-Reason 'V14 SKILL.md must forbid splitting work across rounds to consume budget'
                }
                if (-not (Test-Has $skill 'verified in the round that produced it')) {
                    Add-Reason 'V14 SKILL.md must require the increment to be verified in the same round'
                }
            }
            if ($null -ne $methodology) {
                if (-not (Test-Has $methodology 'A round allowance is a ceiling, not a work plan')) {
                    Add-Reason 'V14 METHODOLOGY.md must state that a round allowance is a ceiling, not a work plan'
                }
            }
            if ($null -ne $readme) {
                if (-not (Test-Has $readme 'ceiling, not a work plan')) {
                    Add-Reason 'V14 README.md must state that the round allowance is a ceiling, not a work plan'
                }
            }
        }

        # ============================ V13 instance-root consistency (A4) ==================
        # The frozen declaration is authoritative. The inspected directory must BE the declared
        # directory, judged after normalization. A disagreement is fail-closed: the evaluator
        # never substitutes another existing directory for the declared one, and it never edits
        # the contract to match the filesystem.
        if ($Mode -in @('Adoption', 'Readiness')) {
            $declaredRaw = $null
            $declaredSource = ''

            if (-not [string]::IsNullOrWhiteSpace($InstanceRootDeclared)) {
                $declaredRaw = $InstanceRootDeclared
                $declaredSource = '-InstanceRootDeclared'
            } elseif (-not [string]::IsNullOrWhiteSpace($GoalContract)) {
                if (-not (Test-Path -LiteralPath $GoalContract -PathType Leaf)) {
                    Add-Reason "V13 the objective contract named by -GoalContract does not exist: $GoalContract"
                } else {
                    $contractText = Get-RawText (Resolve-Path -LiteralPath $GoalContract).ProviderPath
                    $declaredRaw = Get-FieldValue -text $contractText -label 'Instance root:'
                    $declaredSource = "the Instance root: field of $GoalContract"
                    if ($null -eq $declaredRaw) {
                        Add-Reason "V13 the objective contract at $GoalContract has no 'Instance root:' field"
                    } elseif ((Test-Unrecorded $declaredRaw)) {
                        Add-Reason "V13 the 'Instance root:' field of $GoalContract is not recorded ('$declaredRaw'); a blank declaration is not a valid path"
                        $declaredRaw = $null
                    }
                }
            }

            if ($null -ne $declaredRaw -and -not [string]::IsNullOrWhiteSpace($script:InstanceRootUsed)) {
                # A relative declaration resolves against the project root when one was found,
                # otherwise against the toolkit's parent (which is the project in the documented
                # layout). Both candidates are accepted as the same answer.
                $bases = @()
                if (-not [string]::IsNullOrWhiteSpace($script:ProjectRootFound)) { $bases += $script:ProjectRootFound }
                $bases += (Split-Path $rootFull -Parent)

                $matched = $false
                foreach ($b in $bases) {
                    if (Test-SamePath -a $declaredRaw -b $script:InstanceRootUsed -baseA $b -baseB $b) { $matched = $true; break }
                }
                $script:InstanceRootDeclaredRaw = $declaredRaw
                $script:InstanceRootDeclaredSource = $declaredSource
                if ($matched) {
                    $script:InstanceRootConsistency = 'PASS'
                } else {
                    $script:InstanceRootConsistency = 'FAIL'
                    $declaredNorm = Get-NormalizedPath -path $declaredRaw -base (Split-Path $rootFull -Parent)
                    Add-Reason "V13 instance-root conflict: $declaredSource declares '$declaredRaw' (normalized: $declaredNorm) but the inspected directory is '$($script:InstanceRootUsed)'. Fail-closed: the frozen declaration is not overridden by the filesystem, and the evaluator will not switch to another directory. A human decides which side is corrected."
                }
            } elseif ($null -eq $declaredRaw -and [string]::IsNullOrWhiteSpace($InstanceRootDeclared) -and [string]::IsNullOrWhiteSpace($GoalContract)) {
                if ($Mode -eq 'Hygiene') {
                    # AMENDMENT A5: the contract-unchecked mode, by design. The report says so
                    # in those words, and the mode may never emit an adoption claim.
                    $script:InstanceRootConsistency = 'NOT CHECKED'
                } else {
                    # Unreachable for Adoption/Readiness (the invocation is refused earlier), but
                    # a fail-closed default is the only safe thing to leave here.
                    $script:InstanceRootConsistency = 'FAIL'
                    Add-Reason 'V13 no declaration was available for a contract-verified mode; fail-closed'
                }
            } elseif ($null -eq $declaredRaw) {
                $script:InstanceRootConsistency = 'FAIL'
            }
        }

        # --------------------------------------------- V12b copy integrity rule
        # AMENDMENT A5: this applies whenever a candidate is named, not only in -Mode Adoption,
        # so a Hygiene or Readiness run that was given -Proposal also proves the copy intact.
        if (-not [string]::IsNullOrWhiteSpace($proposalFull)) {
            if ([string]::IsNullOrWhiteSpace($proposalFull)) {
                Add-Reason 'V12 -Mode Adoption requires -Proposal naming the candidate that was adopted'
            } else {
                # The candidate root is the directory whose child is long-running/.
                $resolvedProposal = $null
                foreach ($cand in @($proposalFull, (Split-Path $proposalFull -Parent))) {
                    if ([string]::IsNullOrWhiteSpace($cand)) { continue }
                    if (Test-Path -LiteralPath (Join-Path $cand 'long-running') -PathType Container) {
                        $resolvedProposal = $cand
                        break
                    }
                }
                if ($null -eq $resolvedProposal) {
                    Add-Reason 'V12 -Proposal does not resolve to a candidate root containing long-running/'
                } else {
                    # the adopted project must not have silently changed the portable core
                    foreach ($f in $files) {
                        if ($f.Template) { continue }
                        $src = Join-Path $resolvedProposal $f.Rel
                        $dst = Join-Path $rootFull $f.Rel
                        if ((Test-Path -LiteralPath $src -PathType Leaf) -and (Test-Path -LiteralPath $dst -PathType Leaf)) {
                            $h1 = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
                            $h2 = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash
                            if ($h1 -ne $h2) {
                                Add-Reason "V12 adopted project modified a portable toolkit file: $($f.Rel)"
                            }
                        }
                    }
                }
            }
        }

        # -------------------- V15 hygiene / readiness separation (A4 / F3) -------------------
        # The documents must not let a clean instance root read as "ready to arm a goal".
        if ($Mode -eq 'Candidate') {
            if ($null -ne $readme) {
                if (-not (Test-Has $readme 'INSTANCE HYGIENE')) {
                    Add-Reason 'V15 README.md must name INSTANCE HYGIENE as the weaker verdict'
                }
                if (-not (Test-Has $readme 'INITIALIZATION READINESS')) {
                    Add-Reason 'V15 README.md must name INITIALIZATION READINESS as the stronger, separate verdict'
                }
                if (-not (Test-Has $readme 'not acceptance')) {
                    Add-Reason 'V15 README.md must separate readiness from acceptance'
                }
            }
            if ($null -ne $skill) {
                if (-not (Test-Has $skill 'INSTANCE HYGIENE')) {
                    Add-Reason 'V15 SKILL.md must distinguish INSTANCE HYGIENE from INITIALIZATION READINESS'
                }
                if (-not (Test-Has $skill 'goal-arming decision')) {
                    Add-Reason 'V15 SKILL.md must route readiness to a human goal-arming decision'
                }
            }
            if ($null -ne $methodology) {
                if (-not (Test-Has $methodology 'INSTANCE HYGIENE')) {
                    Add-Reason 'V15 METHODOLOGY.md must name INSTANCE HYGIENE'
                }
                if (-not (Test-Has $methodology 'INITIALIZATION READINESS')) {
                    Add-Reason 'V15 METHODOLOGY.md must name INITIALIZATION READINESS'
                }
            }
            $evalTpl = $texts['templates/EVALUATION.md']
            if ($null -ne $evalTpl) {
                if (-not (Test-Has $evalTpl 'Initialization readiness:')) {
                    Add-Reason 'V15 templates/EVALUATION.md must carry the Initialization readiness: block'
                }
                if (-not (Test-Has $evalTpl 'human gate')) {
                    Add-Reason 'V15 templates/EVALUATION.md must mark the human-gated readiness items as human gates'
                }
            }
            $planTpl = $texts['templates/PLAN.md']
            if ($null -ne $planTpl) {
                if (-not (Test-Has $planTpl 'Approval record:')) {
                    Add-Reason 'V15 templates/PLAN.md must carry the Approval record: field'
                }
            }
        }

        # -------------------- V16 guarantee-scope vocabulary (A5) --------------------------
        # The four verdicts must be named, and the weakest one must say what it did not check.
        if ($Mode -eq 'Candidate') {
            foreach ($rel in @('README.md', 'SKILL.md', 'METHODOLOGY.md')) {
                $text = $texts[$rel]
                if ($null -eq $text) { continue }
                foreach ($needle in @('CANDIDATE VALIDATION', 'HYGIENE PASS', 'ADOPTION PASS', 'INITIALIZATION READINESS')) {
                    if (-not (Test-Has $text $needle)) {
                        Add-Reason "V16 $rel must name the '$needle' verdict"
                    }
                }
                foreach ($needle in @('CONTRACT NOT CHECKED', 'does not prove')) {
                    if (-not (Test-Has $text $needle)) {
                        Add-Reason "V16 $rel must state the guarantee limit using '$needle'"
                    }
                }
            }
            $evalTpl = $texts['templates/EVALUATION.md']
            if ($null -ne $evalTpl) {
                foreach ($needle in @('CANDIDATE VALIDATION', 'HYGIENE PASS', 'ADOPTION PASS', 'CONTRACT NOT CHECKED', 'does not prove')) {
                    if (-not (Test-Has $evalTpl $needle)) {
                        Add-Reason "V16 templates/EVALUATION.md must name the '$needle' verdict"
                    }
                }
            }
        }

        # ==================== INITIALIZATION READINESS contract (A4) ======================
        # AMENDMENT A4 / F3. INSTANCE HYGIENE (V12) says the instance directory is basically
        # sound. INITIALIZATION READINESS is a different, stronger question: has every
        # prerequisite for arming a goal been verified or explicitly authorized?
        #
        # Verdict vocabulary, deliberately not binary:
        #   PASS    - mechanically checkable, and it checks out.
        #   POLICY  - a policy record exists and is structurally valid. This is a record, NOT
        #             authorization, and the evaluator does not claim to have verified intent.
        #   PENDING - a human gate with no recorded authorization. The evaluator cannot and
        #             does not perform it.
        #   FAIL    - a mechanically checkable prerequisite is absent.
        # A single unmet or pending item makes the project NOT READY (exit code 3). This mode
        # never arms a goal, never writes, and never grants acceptance.
        if ($Mode -eq 'Readiness') {
            function Add-Readiness {
                param([string]$Id, [string]$Item, [string]$Verdict, [string]$Basis)
                $script:ReadinessRows.Add(("{0,-4} {1,-7} {2} :: {3}" -f $Id, $Verdict, $Item, $Basis))
                if ($Verdict -ne 'PASS' -and $Verdict -ne 'POLICY') { $script:ReadinessNotReady++ }
            }

            $inst = $script:InstanceRootUsed
            if ([string]::IsNullOrWhiteSpace($inst)) {
                Add-Readiness 'R01' 'filled objective contract' 'FAIL' 'no instance root was resolved, so no instance documents exist to inspect'
                for ($i = 2; $i -le 12; $i++) {
                    Add-Readiness ("R{0:d2}" -f $i) 'readiness item' 'FAIL' 'cannot be evaluated without an instance root'
                }
            } else {
                $doc = @{}
                foreach ($name in @('GOAL.md', 'PLAN.md', 'STATE.md', 'EVALUATION.md', 'FINAL-REPORT.md')) {
                    $p = Join-Path $inst $name
                    if (Test-Path -LiteralPath $p -PathType Leaf) { $doc[$name] = Get-RawText $p } else { $doc[$name] = $null }
                }

                # R01 filled objective contract
                if ($null -eq $doc['GOAL.md']) {
                    Add-Readiness 'R01' 'filled objective contract' 'FAIL' 'GOAL.md is absent from the instance root'
                } elseif (Test-Has (Get-Text (Join-Path $inst 'GOAL.md')) 'UNFILLED') {
                    Add-Readiness 'R01' 'filled objective contract' 'FAIL' 'GOAL.md still carries the UNFILLED marker'
                } else {
                    Add-Readiness 'R01' 'filled objective contract' 'PASS' 'GOAL.md present with no blank-form marker'
                }

                # R02 plan present with an approval record (human gate reported as POLICY/PENDING)
                $planStatus = $null; $approval = $null
                if ($null -ne $doc['PLAN.md']) {
                    $planStatus = Get-FieldValue -text $doc['PLAN.md'] -label 'Plan status:'
                    $approval = Get-FieldValue -text $doc['PLAN.md'] -label 'Approval record:'
                }
                if ($null -eq $doc['PLAN.md']) {
                    Add-Readiness 'R02' 'approved plan' 'FAIL' 'PLAN.md is absent from the instance root'
                } elseif (Test-Unrecorded $approval) {
                    Add-Readiness 'R02' 'approved plan' 'PENDING' "no approval record ('$approval'); only a human can record approval"
                } else {
                    Add-Readiness 'R02' 'approved plan' 'POLICY' "approval record present: $approval (a record, not proof of intent)"
                }

                # R03 initialized state
                if ($null -eq $doc['STATE.md']) {
                    Add-Readiness 'R03' 'initialized state' 'FAIL' 'STATE.md is absent from the instance root'
                } elseif ((Test-Has (Get-Text (Join-Path $inst 'STATE.md')) 'UNFILLED') -or (Test-Unrecorded (Get-FieldValue -text $doc['STATE.md'] -label 'Round:'))) {
                    Add-Readiness 'R03' 'initialized state' 'FAIL' 'STATE.md is still blank or has no round recorded'
                } else {
                    Add-Readiness 'R03' 'initialized state' 'PASS' "round field: $(Get-FieldValue -text $doc['STATE.md'] -label 'Round:')"
                }

                # R04 filled evaluation contract
                if ($null -eq $doc['EVALUATION.md']) {
                    Add-Readiness 'R04' 'filled evaluation contract' 'FAIL' 'EVALUATION.md is absent from the instance root'
                } elseif (Test-Has (Get-Text (Join-Path $inst 'EVALUATION.md')) 'UNFILLED') {
                    Add-Readiness 'R04' 'filled evaluation contract' 'FAIL' 'EVALUATION.md still carries the UNFILLED marker'
                } else {
                    Add-Readiness 'R04' 'filled evaluation contract' 'PASS' 'EVALUATION.md present with no blank-form marker'
                }

                # R05 a project evaluator exists. "Evaluator implementation:" has no value of its
                # own - the path is the next line - so the field value plus the following line is
                # searched for something that resolves to a file.
                $evaluatorValue = $null
                $evaluatorExists = $false
                if ($null -ne $doc['EVALUATION.md']) {
                    $evaluatorValue = Get-FieldValue -text $doc['EVALUATION.md'] -label 'Evaluator implementation:'
                    $evalTextFlat = Get-Text (Join-Path $inst 'EVALUATION.md')
                    foreach ($cand in @($evaluatorValue)) {
                        if ([string]::IsNullOrWhiteSpace($cand)) { continue }
                        $tok = ([regex]::Match($cand, '[A-Za-z0-9_.\-\\/]+\.ps1')).Value
                        if ($tok.Length -eq 0) { continue }
                        $full = [System.IO.Path]::Combine($inst, ($tok -replace '/', '\'))
                        if (Test-Path -LiteralPath $full -PathType Leaf) { $evaluatorExists = $true; $evaluatorValue = $tok; break }
                        $byName = Join-Path $inst (Split-Path $tok -Leaf)
                        if (Test-Path -LiteralPath $byName -PathType Leaf) { $evaluatorExists = $true; $evaluatorValue = $tok; break }
                    }
                    if (-not $evaluatorExists -and -not (Test-Unrecorded $evaluatorValue)) {
                        # The recorded path may be relative to the project root rather than the
                        # instance root; look there before calling it missing.
                        $tok = ([regex]::Match([string]$evaluatorValue, '[A-Za-z0-9_.\-\\/]+\.ps1')).Value
                        if ($tok.Length -gt 0 -and -not [string]::IsNullOrWhiteSpace($script:ProjectRootFound)) {
                            $full = [System.IO.Path]::Combine($script:ProjectRootFound, ($tok -replace '/', '\'))
                            if (Test-Path -LiteralPath $full -PathType Leaf) { $evaluatorExists = $true; $evaluatorValue = $tok }
                        }
                    }
                }
                if ($null -eq $doc['EVALUATION.md']) {
                    Add-Readiness 'R05' 'project evaluator exists' 'FAIL' 'no evaluation contract to name an evaluator'
                } elseif (Test-Unrecorded $evaluatorValue) {
                    Add-Readiness 'R05' 'project evaluator exists' 'FAIL' "no evaluator recorded ('$evaluatorValue')"
                } elseif ($evaluatorExists) {
                    Add-Readiness 'R05' 'project evaluator exists' 'PASS' "resolved '$evaluatorValue' to a file on disk"
                } else {
                    Add-Readiness 'R05' 'project evaluator exists' 'FAIL' "the recorded evaluator '$evaluatorValue' does not resolve to a file under the instance or project root"
                }

                # R06 evaluator test evidence
                $testCases = $null
                if ($null -ne $doc['EVALUATION.md']) { $testCases = Get-FieldValue -text $doc['EVALUATION.md'] -label 'Test cases:' }
                if ($null -eq $doc['EVALUATION.md'] -or (Test-Unrecorded $testCases)) {
                    Add-Readiness 'R06' 'evaluator test evidence' 'FAIL' "no test-case record ('$testCases')"
                } else {
                    Add-Readiness 'R06' 'evaluator test evidence' 'POLICY' "record present: $testCases (the adequacy of those tests stays a human judgement)"
                }

                # R07 frozen evaluator hash
                $frozen = $null
                if ($null -ne $doc['EVALUATION.md']) { $frozen = Get-FieldValue -text $doc['EVALUATION.md'] -label 'Frozen:' }
                if ($null -eq $doc['EVALUATION.md'] -or (Test-Unrecorded $frozen)) {
                    Add-Readiness 'R07' 'evaluator freeze baseline recorded' 'FAIL' "no freeze record ('$frozen')"
                } elseif (Test-HashLike $frozen) {
                    Add-Readiness 'R07' 'evaluator freeze baseline recorded' 'PASS' 'a hash-shaped freeze record is present'
                } else {
                    Add-Readiness 'R07' 'evaluator freeze baseline recorded' 'FAIL' "the freeze record carries no hash: $frozen"
                }

                # R08 budget and stop conditions
                $budget = $null; $stop = $null
                if ($null -ne $doc['GOAL.md']) {
                    $budget = Get-FieldValue -text $doc['GOAL.md'] -label 'Budget:'
                    $stop = Get-FieldValue -text $doc['GOAL.md'] -label 'Stop conditions:'
                }
                if ((Test-Unrecorded $budget) -or (Test-Unrecorded $stop)) {
                    Add-Readiness 'R08' 'budget and stop conditions stated' 'FAIL' 'the objective contract does not state both budget and stop conditions'
                } else {
                    Add-Readiness 'R08' 'budget and stop conditions stated' 'PASS' 'both are stated in the objective contract'
                }

                # R09 workspace and permission boundary
                Add-Readiness 'R09' 'workspace and permission boundary verified' 'PENDING' 'the evaluator cannot verify which sandbox mode or scope a human actually accepted; this stays a human gate'

                # R10 instance-root consistency (V13)
                if ($script:InstanceRootConsistency -eq 'PASS') {
                    Add-Readiness 'R10' 'instance-root consistency' 'PASS' "the declared root matches the inspected root ($inst)"
                } elseif ($script:InstanceRootConsistency -eq 'FAIL') {
                    Add-Readiness 'R10' 'instance-root consistency' 'FAIL' 'the declaration and the inspected directory disagree; a human must decide which side is corrected'
                } else {
                    Add-Readiness 'R10' 'instance-root consistency' 'PENDING' 'no declared root was supplied, so consistency could not be checked; pass -GoalContract or -InstanceRootDeclared'
                }

                # R11 human approval records
                $planApprovalState = 'not recorded'
                if (-not (Test-Unrecorded $approval)) { $planApprovalState = 'recorded' }
                Add-Readiness 'R11' 'human approval records' 'PENDING' "plan approval: $planApprovalState; workspace-boundary acceptance and goal-arming authorization are human acts with no mechanical proof"

                # R12 final report path and owner
                $reportPath = $null; $reportOwner = $null
                if ($null -ne $doc['FINAL-REPORT.md']) {
                    $reportPath = Get-FieldValue -text $doc['FINAL-REPORT.md'] -label 'Report path:'
                    $reportOwner = Get-FieldValue -text $doc['FINAL-REPORT.md'] -label 'Report owner:'
                }
                if ($null -eq $doc['FINAL-REPORT.md']) {
                    Add-Readiness 'R12' 'final report path and owner determined' 'FAIL' 'FINAL-REPORT.md is absent from the instance root'
                } elseif ((Test-Unrecorded $reportPath) -or (Test-Unrecorded $reportOwner)) {
                    Add-Readiness 'R12' 'final report path and owner determined' 'FAIL' 'the report contract does not name both a path and an owner'
                } else {
                    Add-Readiness 'R12' 'final report path and owner determined' 'PASS' 'both are named in the report contract'
                }
            }
        }

        # -------------------------------------------------------------- report
        Emit ''
        Emit "check-v0.2.ps1 - Long-running Toolkit v0.2 evaluator"
        Emit "mode: $Mode"
        Emit "root: $rootFull"
        if ($null -ne $proposalFull) { Emit "candidate: $proposalFull" }
        if ($Mode -in @('Hygiene', 'Adoption', 'Readiness')) {
            if (-not [string]::IsNullOrWhiteSpace($script:InstanceRootUsed)) {
                Emit "instance root ($($script:InstanceRootSource)): $($script:InstanceRootUsed)"
            } else {
                Emit 'instance root: not resolved (see the failure reasons below)'
            }
            if (-not [string]::IsNullOrWhiteSpace($script:InstanceRootDeclaredRaw)) {
                Emit "declared instance root ($($script:InstanceRootDeclaredSource)): $($script:InstanceRootDeclaredRaw)"
            }
            if (-not [string]::IsNullOrWhiteSpace($script:InstanceRootConsistency)) {
                if ($script:InstanceRootConsistency -eq 'NOT CHECKED') {
                    Emit 'instance-root consistency: CONTRACT NOT CHECKED'
                } else {
                    Emit "instance-root consistency: $($script:InstanceRootConsistency)"
                }
            }
            if ($Mode -eq 'Hygiene') {
                Emit 'guarantee scope: this run does NOT verify the frozen goal contract, does NOT verify'
                Emit 'initialization readiness, and does NOT authorize creating or arming a goal.'
            }
        }
        Emit ''
        if ($Mode -eq 'Readiness') {
            Emit 'INITIALIZATION READINESS'
            Emit '  PASS = mechanically checked and satisfied | POLICY = a record, not authorization'
            Emit '  PENDING = a human gate, not performed by the evaluator | FAIL = a checkable prerequisite is absent'
            Emit ''
            foreach ($row in $script:ReadinessRows) { Emit "  $row" }
            Emit ''
            Emit 'INSTANCE HYGIENE'
            if ($script:Reasons.Count -eq 0) {
                Emit '  PASS - the instance directory itself is sound.'
            } else {
                Emit '  FAIL'
                foreach ($r in $script:Reasons) { Emit "    - $r" }
            }
            Emit ''
            Emit 'NOT CLAIMED: whether a plan was genuinely approved, whether the permission boundary was deliberately accepted,'
            Emit 'whether the evaluator tests were adequate, and whether this guidance is any good. Those are human judgements.'
            Emit ''
            # Distinguish "a prerequisite is missing" from "the machine has done all it can".
            # Both block a READY verdict, and both are exit 3; what differs is the wording and
            # the fix. A PENDING human gate is not a defect - it is a brake - but a verdict of
            # READY while a gate is open would be the exact over-claim this mode exists to stop.
            $script:ReadinessFailCount = 0
            $script:ReadinessPendingCount = 0
            foreach ($row in $script:ReadinessRows) {
                if ($row -match '\sFAIL\s') { $script:ReadinessFailCount++ }
                if ($row -match '\sPENDING\s') { $script:ReadinessPendingCount++ }
            }
            if ($script:Reasons.Count -gt 0) {
                Emit "NOT READY (instance hygiene failed: $($script:Reasons.Count) reason(s))"
                return 3
            }
            if ($script:ReadinessFailCount -gt 0) {
                Emit "NOT READY ($($script:ReadinessFailCount) prerequisite(s) missing)"
                Emit '  Each FAIL above names something absent and checkable. Fix those first.'
                return 3
            }
            if ($script:ReadinessPendingCount -gt 0) {
                Emit "NOT READY PENDING HUMAN GATE ($($script:ReadinessPendingCount) item(s))"
                Emit '  Every checkable prerequisite passed, but these belong to a person:'
                foreach ($row in $script:ReadinessRows) {
                    if ($row -match '\sPENDING\s') { Emit "    $row" }
                }
                Emit '  Only a human closes these. This output is not acceptance and it arms nothing.'
                return 3
            }
            Emit 'READY FOR THE HUMAN GOAL-ARMING DECISION'
            Emit '  every checkable prerequisite passed and no human gate is recorded as open.'
            Emit '  This is still not acceptance, and it arms nothing.'
            return 0
        }
        if ($script:Reasons.Count -eq 0) {
            # AMENDMENT A5: each mode states exactly what it proved and what it did not.
            if ($Mode -eq 'Candidate') {
                Emit 'CANDIDATE VALIDATION PASS'
                Emit '  the portable eight-file toolkit satisfies V1-V16 and R1-R3.'
                Emit '  This is a statement about the toolkit artifact only. It does not prove instance hygiene,'
                Emit '  contract consistency, initialization readiness, or that any goal may be armed.'
            } elseif ($Mode -eq 'Hygiene') {
                Emit 'HYGIENE PASS'
                Emit '  CONTRACT NOT CHECKED - the frozen goal contract was not read, so this run says nothing'
                Emit '  about whether the inspected directory is the declared one.'
                Emit '  NOT an ADOPTION PASS. This does not prove contract consistency or initialization readiness,'
                Emit '  does not prove human approval, and does not authorize creating or arming a goal.'
            } elseif ($Mode -eq 'Adoption') {
                Emit 'ADOPTION PASS (contract-verified)'
                Emit '  instance hygiene passed AND the inspected instance root equals the declared root in the'
                Emit '  frozen goal contract, after path normalization.'
                Emit '  This is not INITIALIZATION READINESS, it does not prove human approval, and it does not'
                Emit '  authorize creating or arming a goal.'
            } else {
                Emit 'PASS'
                Emit '  all V1-V16 and R1-R3 checks satisfied.'
            }
            return 0
        }
        Emit 'FAIL'
        foreach ($r in $script:Reasons) { Emit "  - $r" }
        Emit ''
        Emit "failure reasons: $($script:Reasons.Count)"
        return 1
    } catch {
        $script:Lines.Add("ERROR: evaluator failed: $($_.Exception.Message)")
        $script:Lines.Add("at: $($_.InvocationInfo.PositionMessage)")
        return 2
    } finally {
        if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
            try {
                [System.IO.File]::WriteAllText($LogPath, ($script:Lines -join [Environment]::NewLine), (New-Object System.Text.UTF8Encoding($false)))
            } catch { }
        }
        foreach ($l in $script:Lines) { Write-Host $l }
    }
}

# Run only when executed as a script; stay inert when the text is loaded for in-process use.
if ($MyInvocation.InvocationName -ne '.') {
    $code = Invoke-Check -Root $Root -Proposal $Proposal -Workspace $Workspace -Mode $Mode -InstanceRoot $InstanceRoot -GoalContract $GoalContract -InstanceRootDeclared $InstanceRootDeclared -LogPath $LogPath
    exit $code
}

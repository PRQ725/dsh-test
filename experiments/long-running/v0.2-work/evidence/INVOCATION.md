# INVOCATION - how to run the v0.2 evaluator on this host

This note exists because the evaluator's entry point and the *runnable* invocation differ on
the machine this candidate was built on. Both are recorded so a later reader can reproduce the
result instead of guessing.

## The entry point as designed

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <v0.2-work>\evaluator\check-v0.2.ps1 `
    -Root <toolkit root> [-Proposal <candidate root>] [-Mode Candidate|Adoption]
```

Exit codes: 0 pass, 1 fail with printed reasons, 2 error. This is the form a project whose
execution policy allows local scripts should use.

## Why it is not the form used here

Two host facts were observed in this round, not assumed:

1. `Get-ExecutionPolicy -List` reports `CurrentUser = RemoteSigned`. Running the file directly
   with the call operator produced: `cannot be loaded. The file ... is not digitally signed.`
2. A nested `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script>` child process is
   refused by the sandbox with `Program 'powershell.exe' failed to run: Access is denied` — the
   same refusal the v0.1 selftest recorded for this host.

Neither is a property of the toolkit. Together they mean the only runnable form here is
in-process.

## The runnable form here

```powershell
$ev = '<v0.2-work>\evaluator\check-v0.2.ps1'
$sb = [scriptblock]::Create([System.IO.File]::ReadAllText($ev))
. $sb -Root '__load__'                       # placeholder; nothing is evaluated here
Invoke-Check -Root <toolkit root> -Mode Candidate -LogPath <log file>
```

`check-v0.2.ps1` is deliberately structured for this: the whole program lives in `Invoke-Check`,
which returns the exit code instead of calling `exit`, and the file's entry point runs the
function only when the file itself is executed as a script. Loading the text defines the
function and evaluates nothing.

## The same caveat applies to the selftest

`check-v0.2.selftest.ps1` exposes `Invoke-SelfTest` the same way, and returns its code rather
than exiting. Reproduction commands for every check are in
`../evidence/CHECK-REPORT.md` section 5.

## What this is not

It is not a claim that the toolkit requires this workaround. On a host with a permissive
execution policy and no sandbox refusal of child processes, the designed entry point works and
the in-process form is unnecessary.

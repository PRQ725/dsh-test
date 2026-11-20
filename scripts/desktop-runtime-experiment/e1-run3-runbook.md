# E1 run3 runbook — baseline → A with Desktop as the ONLY active variable

Prepared: 2026-10-05 (local, UTC+8). Status: **READY, NOT EXECUTED.**
Run3 workspace, fixture and metadata already exist. The baseline may or may not exist —
check before starting.

Governing idea: run2 was attribution-contaminated because the research host was restarted
between the baseline and Stage A. Run3 does **not** restart anything in that interval.

---

## 0. Pre-flight state (already done, do not redo)

| Item | Value |
|------|-------|
| Workspace | `D:\Projects\dsh-desktop-runtime-test-3` (created, 0 sessions, only `AGENTS.md`) |
| Fixture | `AGENTS.md` 122 B `0FF8FA597BA8DCCEFF7BB46AA59A77B938822FDD98E63A8502B239DF6E0FAC01` (byte-identical to run1/run2) |
| Metadata | `evidence\desktop\runtime\e1-run3.metadata.json` (`BaselineVerified=false`) |
| Baseline namespace | `e1-BASE-QUIESCENT-R3` |
| run1 / run2 workspaces | untouched, still present |

### 0.1 DECIDED — Option A, approved by human review 2026-10-05

**Decision: run run3 as-is. `settings.yaml` is NOT restored. Option A was selected.**

Rationale accepted for the record: the cross-version settings migration and the locale
fallback root cause were already established in E0.5 by source archaeology plus direct
observation. run3's research question is whether the old Web 0.1.5-rc.3 can safely
discover / open / render / continue a v4 session created by Desktop 0.2.0-rc.2. Re-testing
the legacy import would add a deliberate variable to an experiment whose purpose is to
measure an untouched home.

**Expected settings behaviour for run3 — normative, use this when reading the Stage A report:**

| | expectation |
|---|---|
| R3 baseline capture | `settings.yaml` = **ABSENT** |
| Stage A, after the Desktop launch | Desktop does **not** trigger the legacy import (the import is guarded by `if (!existsSync(path)) return;` and there is no legacy file) |
| Stage A settings churn | **0** for `settings.yaml` / `settings.yaml.imported` — neither GONE, nor ADDED, nor CHANGED |
| `settings.yaml.imported` | unchanged at 52 B `EA141B86779C2C88208AF7B032BFB8AD0E53069E83B42693598042269C884BAF` |
| `profiles\desktop\cordis.patch.yml` | unchanged at 1039 B `80655B36FC5EEC417533FE415C57370D7D07129A7E5DD30C8E7637B208B35DA5` (the previously imported entries stay put) |
| comparison with run2 | **class-A settings churn counts must NOT be compared across run2 and run3.** run2 A recorded 2 class-A settings entries because `settings.yaml` existed at its baseline; run3 must record 0 because it does not. A non-zero settings churn in run3 Stage A is therefore an ANOMALY, not a reproduction. |

Background analysis: `e1-run3-BASELINE-PRECONDITIONS.md`.

---

## 1. The one external PowerShell window

All steps below run from **one external PowerShell window that stays open** for the whole
run. Nothing in this runbook may be executed from inside a DSH session shell.

```powershell
cd D:\Projects\dsh-test\scripts\desktop-runtime-experiment
```

## 2. Stop everything and prove it

1. Quit Desktop completely (tray / background included).
2. Stop browser-lab.
3. Close this research session's DSH host (browser-lab `--profile browser-lab`, port 3080).
   Note: while you are running these commands from an external PowerShell, a DSH host that
   is still serving the research Web UI counts as a running host and will fail the gate.
4. Confirm 3080 / 3180 are free.

The wrapper's own gate measures all of this and will refuse (exit 2) if it is not clean —
there is no need to check by hand, but it saves a round trip.

## 3. Capture and seal the run3 baseline

```powershell
.\capture-e1-quiescent-baseline.ps1 `
  -Namespace e1-BASE-QUIESCENT-R3 `
  -MetadataPath "D:\Projects\dsh-test\evidence\desktop\runtime\e1-run3.metadata.json" `
  -WorkspacePath "D:\Projects\dsh-desktop-runtime-test-3"
```

Required outcome: `QUIESCENT BASELINE: PASS` **and** `metadata SEALED: ... BaselineVerified=true`,
exit code **0**.

Exit codes:

| exit | meaning | action |
|------|---------|--------|
| 0 | PASS and sealed | continue to §4 |
| 1 | FAIL (capture/diff/format/seal) | read the verdict file, do NOT continue |
| 2 | refused by the quiescence gate, nothing captured | fix the hosts, re-run §3 |
| 3 | PASS but NOT sealed | re-run §3 with `-MetadataPath`; the baseline is not bindable |

Produces (all NEW files, nothing overwritten):

```
e1-BASE-QUIESCENT-R3\                     capture #1  (+ E1-BASELINE-BINDING.json once sealed)
e1-BASE-QUIESCENT-R3-VERIFY\              capture #2
e1-BASE-QUIESCENT-R3-compare\             the diff
e1-BASE-QUIESCENT-R3-VERDICT.txt          the verdict
e1-run3.metadata.json                     now BaselineVerified=true
```

## 4. DO NOT restart anything

This is the step that run2 got wrong. From the moment the baseline PASSes:

* do **not** restart browser-lab
* do **not** restart the research DSH host
* do **not** re-open the research Web UI
* do **not** run any other DSH command in any workspace

Leave the external PowerShell window open for the whole stage. Anything you start here
becomes a second active variable and contaminates attribution.

## 5. Start Desktop and perform Stage A

1. Launch DeepSeek Desktop.
2. Open / add the workspace `D:\Projects\dsh-desktop-runtime-test-3`.
3. Start a new session there and send exactly:

   ```
   E1 interoperability marker
   ```

4. Wait for a normal reply. Record: (A1) did it reply normally, (A2) the session title
   shown in the UI.
5. Let the session settle for a few seconds.
6. Quit Desktop **completely**, including tray / background.

## 6. Capture Stage A

```powershell
.\e1-capture.ps1 -RunName run3 -Stage A -LockSession
```

Required outcome: `RESULT: CLEAN` or `CONTINUE WITH CAUTION`, exit **0**, and in the report:

```
baseline (bound)   : ...\e1-BASE-QUIESCENT-R3
previous stage     : BASELINE -> ...\e1-run3-A
capture pipeline valid : True
diff valid             : True
```

The script writes `e1-run3-A\` and locks the exact session id into
`e1-run3.session.lock.json`. If the run3 workspace somehow contains more than one session,
it locks the newest and says so — record which id it locked.

Interpretation notes for the report:

* **Expected: 0 settings churn.** No `settings.yaml` GONE / APPEARED / CHANGED, no
  `settings.yaml.imported` change. Desktop must not trigger the legacy import because there
  is no legacy file (see §0.1). If the report instead shows a settings entry in class A or
  class B, that is an **anomaly** — STOP and report it; do not read it as a reproduction of
  run2's behaviour.
* Do **not** compare run2's class-A settings churn count (2) with run3's (expected 0). The
  two runs started from different settings states by design.
* `profiles\desktop\cordis.patch.yml` must stay at
  `80655B36FC5EEC417533FE415C57370D7D07129A7E5DD30C8E7637B208B35DA5`.
* any change under `--D-Projects-dsh-test--` (the research workspace) means attribution is
  broken again — STOP and report; do not continue to Stage B.

## 7. Stop here

Stage B and Stage C are separate, later decisions. This runbook ends after Stage A.

---

## Failure behaviour you should expect

`e1-capture.ps1` will refuse (exit 1, and it writes
`e1-run3-BINDING-REFUSED.txt` at the evidence root instead of a stage directory) when:

| condition | message |
|-----------|---------|
| baseline directory absent | `declared baseline directory does not exist` |
| baseline captured but not sealed | `baseline is NOT sealed (BaselineVerified=false)` |
| baseline sealed for a different run | `baseline belongs to run 'X' but metadata says run 'Y'` |
| baseline manifests changed after sealing | `baseline manifest <f> changed after sealing` |
| `-WorkspacePath` disagrees with metadata | `workspace mismatch` |
| metadata file missing | `run metadata not found` (and it tells you to use `new-e1-run.ps1`) |

No stage directory is created in any of those cases, so a refusal can never be mistaken for
stage evidence.

## What NOT to do

* Do not re-capture `e1-BASE-QUIESCENT-R2` or `e1-BASE-QUIESCENT-R3` once sealed.
* Do not reuse `D:\Projects\dsh-desktop-runtime-test-2`.
* Do not delete run1 / run2 / R1 / R2 artifacts.
* Do not run Stage B/C for run2.
* Do not run any of this from inside a DSH session shell.

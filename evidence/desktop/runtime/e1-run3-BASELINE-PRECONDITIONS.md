# run3 baseline pre-conditions: shared-state delta since the R2 baseline

Recorded: 2026-10-05 (local, UTC+8). Read-only investigation. Nothing was modified.

This note exists because preparing run3 required asking "is the shared state the same as when
R2 was captured?" It is not, and one of the differences changes what run3 can test.

---

## 1. Where the R2 baseline now stands

`e1-BASE-QUIESCENT-R2` was captured 2026-10-05 13:57:52. Comparing its 30 tracked
shared-state entries against the live `$DSH_HOME` now:

```
identical = 25   changed = 5
```

| Rel | at R2 capture | now | cause |
|-----|---------------|-----|-------|
| `settings.yaml` | 52 B `EA141B86…C884BAF` | **ABSENT** | Desktop 0.2 legacy import renamed it |
| `settings.yaml.imported` | 176 B `0D6DBB77…7BB5746` | **52 B `EA141B86…C884BAF`** | the rename overwrote it |
| `storages\workspace.json` | 2883 B `DDCD0C26…` | 3282 B `EF26317B…` | Desktop registered the run2 workspace; run3 workspace added |
| `.dshw-turn.json` | 50 B `90F34489…` | 50 B `2F181003…` | research host activity |
| `.dshw-usage.json` | 20140 B `53BF2CE0…` | 20234 B `65F5C388…` | research host activity |

[FACT] `e1-BASE-QUIESCENT-R2` is therefore **no longer content-identical to the live
`$DSH_HOME`**. It remains a valid record of the home at 13:57:52, and it was the correct
baseline for run2 Stage A, but it must **not** be reused as the guard for any later stage.
That is exactly why run3 declares its own baseline namespace `e1-BASE-QUIESCENT-R3`.

## 2. When the settings rename happened

It happened during the **human-executed run2 Stage A Desktop launch** (session created
`2026-10-05 14:50:52`). This is not a new event and not a defect:

* the R2 baseline at 13:57 recorded `settings.yaml` present (52 B);
* `e1-run2-A`, captured 14:53:01, recorded `settings.yaml` **GONE** and
  `settings.yaml.imported` **CHANGED**;
* the run2 Stage A report classified both correctly as
  `A. EXPECTED CROSS-VERSION SETTINGS CHURN`.

The live home has matched that state ever since.

## 3. New finding: `.imported` is a destructive single slot

[FACT] The new `settings.yaml.imported` has size 52, SHA-256
`EA141B86779C2C88208AF7B032BFB8AD0E53069E83B42693598042269C884BAF` and mtime
`2026-10-05 12:29:50` — i.e. it is byte-for-byte the **old `settings.yaml`**, with the
**old mtime preserved**.

[INFERENCE] This is consistent with `rename(settings.yaml, settings.yaml.imported)` where
the rename **replaces** an existing destination (Node's `fs.renameSync` maps to
`MoveFileEx` with `MOVEFILE_REPLACE_EXISTING` on Windows). It is not a merge: a merge would
have produced a different size, a different hash and a fresh mtime.

[FACT] Consequence: the previous 176 B `.imported` document
(`0D6DBB770B3875049D70EE6EB7F922BF805ECDD6AFFCEE1C70D2282FA7BB5746`) no longer exists
anywhere on disk. A search of the whole evidence tree found no 176 B file with that hash:
the capture pipeline records size and SHA-256 only, never file contents. Only its hash and
size survive, in the manifests of `e1-A`, `e1-BASE-QUIESCENT-R2` and
`e1-BASE-QUIESCENT-R2-VERIFY`.

[INFERENCE] This is the **second** observed overwrite of the same slot
(`7A7CCB3C…`, 175 B → `0D6DBB77…`, 176 B → `EA141B86…`, 52 B). `.imported` therefore does
**not** accumulate history: it holds only the most recent legacy document, and each new
import destroys the previous one.

[NOTE] The *information* is not lost, only the raw bytes: the values that the 176 B document
carried were imported into `profiles\desktop\cordis.patch.yml`
(1039 B, `80655B36FC5EEC417533FE415C57370D7D07129A7E5DD30C8E7637B208B35DA5`), which still
holds `locale: preference: en`, `ui-settings-general: welcomeNoticeVersion: 2026-08-13.1`
and `agent-default-model: provider/model/reasoningEffort`.

[UNKNOWN] Whether the 176 B bytes were ever dumped to a text file during earlier forensic
work. No copy exists in the evidence tree now.

## 4. Consequence for run3 — a decision the human must make

[FACT] At this moment `settings.yaml` is **ABSENT**.

[FACT] The bundled `@deepseek-ai/dsh-settings` import is guarded by
`if (!existsSync(path)) return;` — with no legacy `settings.yaml` present, the import is a
no-op.

[INFERENCE] If the run3 baseline is captured in the current state, the run3 Stage A Desktop
launch will produce **no settings churn at all**, and run3 will therefore **not** re-test the
legacy-import path. The run2 Stage A already observed that path once (and reported it as
expected class-A churn); run3 would test only session creation, session-format handling and
profile/global invariants.

[FACT] `settings.yaml` is re-created (52 B, `ui-onboarding` only) by the 0.1.5 Web/browser-lab
client when it acknowledges the onboarding notice — that is how the file came back on
2026-10-05 12:29:50. It has not been re-created since the 14:50 rename.

Two acceptable options, **both requiring the human** (this round forbids modifying settings):

| Option | Effect | Cost |
|--------|--------|------|
| **A. Run run3 as-is** | baseline records `settings.yaml` ABSENT; Stage A shows 0 settings churn; run3 covers session/interop + invariants only | the legacy-import path is not re-tested; do not compare run2-vs-run3 class-A counts as if they were the same experiment |
| **B. Restore a legacy `settings.yaml` first, then capture the R3 baseline** | run3 Stage A re-exercises the import and should reproduce the class-A churn | requires an intentional settings write before the baseline, and the content should be documented so the reproduction is interpretable |

Recommendation: **Option A** is the safer default, because the import has already been
observed once under controlled conditions (run2 Stage A) and re-creating a settings file
purely to provoke it adds a deliberate mutation to an experiment whose whole point is
measuring an untouched home. If the import must be re-observed, do it as a separate,
explicitly-labelled experiment rather than folding it into run3.

Whichever option is chosen, it must be decided **before** the R3 baseline is captured, since
the baseline defines the starting state. No restore was performed here.

## 4.1 DECISION (human review, 2026-10-05): OPTION A

**Approved: Option A. `settings.yaml` is NOT restored. run3 runs against the current, real
state.**

Human rationale, recorded verbatim in intent:

> E0.5 already confirmed the cross-version settings-migration and locale-fallback root cause
> through source archaeology and direct observation. The primary research question for
> E1 run3 is whether a v4 session created by Desktop 0.2.0-rc.2 can be safely
> discovered / opened / rendered / continued by the old Web 0.1.5-rc.3. Therefore run3 does
> not re-test the legacy settings import, and `settings.yaml` is deliberately not restored,
> to avoid introducing an extra variable.

Approved scope (from the same review): RUN3 DESIGN, RUN3 WORKSPACE, RUN3 METADATA,
EXPLICIT BASELINE BINDING, SESSION LOCK, FAIL-CLOSED GATES.

### Expected settings behaviour for run3 (normative)

| | expectation |
|---|---|
| R3 baseline | `settings.yaml` = **ABSENT** |
| Stage A | Desktop does **not** trigger the legacy import |
| Stage A settings churn | **0** — no GONE / APPEARED / CHANGED for `settings.yaml` or `settings.yaml.imported` |
| `settings.yaml.imported` | unchanged: 52 B `EA141B86779C2C88208AF7B032BFB8AD0E53069E83B42693598042269C884BAF` (mtime 2026-10-05 12:29:50) |
| `profiles\desktop\cordis.patch.yml` | unchanged: 1039 B `80655B36FC5EEC417533FE415C57370D7D07129A7E5DD30C8E7637B208B35DA5` |

[FACT] At the moment of this decision the live state was verified as exactly the approved
starting state: `settings.yaml` ABSENT, `settings.yaml.imported` present (52 B,
`EA141B86…`), desktop profile patch present (1039 B, `80655B36…`).

**Prohibition that follows from the decision:** the class-A *settings* churn count of run2 (2)
and of run3 (expected 0) must never be compared as if they measured the same thing. They
started from different settings states by design. In run3 a non-zero settings churn is an
**anomaly**, not a reproduction of run2.

## 5. Status of the tooling against this state

Nothing about this delta is a defect in the tooling:

* `e1-capture.ps1` compares the stage against the **bound** baseline and classifies
  `settings.yaml` GONE / `.imported` CHANGED as EXPECTED class-A churn — correct for a
  Desktop launch, and it does not depend on which specific hashes are involved.
* `.dshw-turn.json` / `.dshw-usage.json` / `storages\workspace.json` are classified as
  class B (unexpected content change requiring review), also correct.
* run3 will produce its own baseline, so none of the above can leak into run3's
  baseline → A diff as long as the research host stays stopped between the two (runbook §4).

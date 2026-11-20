# v0.2-work - Long-running Toolkit v0.2 development area (**CLOSED / RELEASED**)

**This is a development and experiment area, not an installation directory.** Nothing here is
installed or published; a user adopting the toolkit copies **`candidate/long-running/`** - or,
better, the published release at `toolkit/long-running/v0.2/` - into their own project. Nothing
else in this tree is meant to travel with it.

The v0.2 line **closed on 2026-10-09**: rc.3 was accepted and published as **v0.2**. The published,
stable entry point is `toolkit/long-running/v0.2/`; this directory is the historical research
record and the traceable release source. Read `RELEASE-REPORT.md` for the release manifest,
acceptance record, archive inventory, cleanup decisions and the seven Known Limitations.

Current target: **released as Long-running Toolkit v0.2** (source revision `v0.2-rc.3`). No
further revisions are planned for this line; new findings belong to a future version.

## Where to look first

| I want to know | Go to |
|---|---|
| The published release and how it was accepted | `RELEASE-REPORT.md`, and `../../../../toolkit/long-running/RELEASES.md` |
| What the toolkit actually says | `candidate/long-running/README.md` (adoption procedure), then `SKILL.md`, `METHODOLOGY.md` - identical to the published release |
| What "pass" means | `V0.2-ACCEPTANCE-SPEC.md` - checks V1-V16, rules R1-R3, amendments A1-A5 |
| Whether it passes, and on what evidence | `evidence/rc3/final-*.log` (current), then `evidence/CHECK-REPORT.md` for the earlier baseline |
| What changed at each revision, and why | `CHANGE-LIST.md` (v0.2 baseline) plus `RC1`, `RC2`, `RC3` change reports |
| Whether a fresh project can adopt it | `adoption/` and `evidence/RC2-DRY-RUN-EVIDENCE.md` |
| How to run the judge on this host | `evidence/INVOCATION.md` |

## Directory map

| Path | Role |
|---|---|
| `candidate/long-running/` | the 8-file candidate **that was published**; kept as the traceable release source |
| `evaluator/check-v0.2.ps1` | the mechanical evaluator; read-only; `-Mode Candidate` / `Hygiene` / `Adoption` / `Readiness` |
| `evaluator/check-v0.2.selftest.ps1` | 44-case regression harness; every negative case is a real copy of the candidate mutated one way, and its scratch guard fails closed |
| `V0.2-ACCEPTANCE-SPEC.md` | the frozen acceptance baseline and amendments A1-A5 |
| `RELEASE-REPORT.md` | the release and closure record: manifest, acceptance, archive inventory, cleanup, Known Limitations |
| `evidence/` | mechanical results, raw logs, selftest copies, dry-run records, invocation note |
| `evidence/rc1/`, `evidence/rc2/`, `evidence/rc3/` | each revision's frozen evidence (baseline hashes, run logs, selftest scratch) |
| `adoption/dryrun-project/` | the **historical** v0.2-baseline adoption dry-run project |
| `adoption/rc1-scenarios/`, `adoption/rc2-scenarios/` | the rc.1 and rc.2 adoption scenarios, retained as recorded |
| `CHANGE-LIST.md` | v0.2 baseline change inventory with provenance |
| `RC1` / `RC2` / `RC3` change reports | the three controlled-revision records |

## Rules that apply inside this directory

- **Read-only neighbours.** The v0.1 pilot workspace and its frozen six files are never written
  from here.
- **Evidence is append-only.** Earlier run logs, failure records and the historical
  `dryrun-project/` are never rewritten to make a later result look cleaner. A revision adds new
  files and dates its changes instead.
- **Revisions go through the spec.** A change to a check is an amendment in
  `V0.2-ACCEPTANCE-SPEC.md`; a change to the artifact is a candidate edit. The two are recorded
  separately.
- **The scratch rule.** Any test that writes uses an explicit, absolute, empty directory under
  `evidence/`. The harness refuses to create its own scratch root, refuses relative paths, and
  refuses anything outside its approved base.
- **The line is closed.** v0.2 was published from `v0.2-rc.3` on 2026-10-09 and the release at
  `toolkit/long-running/v0.2/` is immutable. Do not hot-patch a released file, do not open a new
  revision of this line, and do not edit the rc.1/rc.2/rc.3 records. A defect found now is
  registered as an issue and planned for a future version, which starts from the release as its
  baseline and produces its own candidate, spec revision and evidence.

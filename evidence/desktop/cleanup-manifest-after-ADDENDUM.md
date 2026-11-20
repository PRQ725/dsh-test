# Addendum to `cleanup-manifest-after.md` — post-cleanup host side effect

Recorded 2026-10-05 (local, UTC+8), during the recovery pass. **This file only adds; it does not
replace `cleanup-manifest-after.md`.**

## What changed after the cleanup ran

The cleanup itself achieved exactly what `cleanup-manifest-after.md` records
(`evidence\desktop\runtime\` → 21 files / 103,959 B; `_selftest-r2` and the isolated Control B home
deleted; `e5-capture.ps1` deleted).

**One directory came back**, and it was not created by the cleanup:

| path | state | created | cause |
|---|---|---|---|
| `D:\Projects\dsh-desktop-runtime-test-3\` | exists, **0 files** (the `AGENTS.md` fixture is NOT there) | 2026-10-05 **17:33:01** | a DSH host re-created it |

[FACT] Cause: `$DSH_HOME\storages\workspace.json` still registers that workspace
(`D:\Projects\dsh-desktop-runtime-test-3`). Deleting the **directory** does not remove the
**registry entry**, so the next host boot re-materialised an empty directory for it.

[FACT] The same boot also created a new blank session in it:
`session-614e7e2d-fef9-48ae-b837-7570a8408111` (330 B, `session.v4.jsonl.zstd`, dir mtime 17:33:01)
and rewrote the registry entry for that workspace to list only that new id.

[FACT] The run1 / run2 workspace directories (`D:\Projects\dsh-desktop-runtime-test`,
`…-2`) were **not** re-created, even though they are also still registered.

## Nothing of value was lost

[FACT] Both run3 evidence sessions are still on disk, byte-identical to their recorded hashes:

```
session-0d5e7d0c-c341-48c4-a149-81250d473f20\session.v4.jsonl.zstd  16364 B  64B4257A37C14035792E0806679A86EC19C683D0E2A9A477060E6621D5777EDB
session-f2bc40b9-0196-4d85-b573-2468122f5ead\session.v3.jsonl.zstd    333 B  90A6B839D408E5974FB56FDA3C6645A760FACDC5C72FC97E364279AAC7355818
```

[FACT] Session census in the real home after the upgrade: **63 files — v3 = 55, v4 = 8**
(was 59 / v3 = 55, v4 = 4 before the upgrade). The four additional v4 sessions are blank drafts
created by post-upgrade 0.2.0 boots, which write v4 by design.

## Consequence for the manifest

`cleanup-manifest-after.md` §2 states "`D:\Projects` 下 `dsh-desktop-runtime-test*` /
`dsh-desktop-controlB-home` 目录: **0**". That was true **immediately after the cleanup** and is
the correct statement of what the cleanup deleted. It is now **1** (the empty
`dsh-desktop-runtime-test-3`), re-created later by a host boot.

[RECOMMENDATION] If a fully clean `D:\Projects` is wanted, either
(a) leave it — the empty directory is harmless and regenerating it is normal DSH behaviour; or
(b) remove the stale workspace entries from `storages\workspace.json` **through the UI/CLI**, not by
editing the file, and then delete the directory. Do not hand-edit the registry: it is parsed with a
bare `JSON.parse` and must stay BOM-free (see `docs/10-experiment-methodology.md` §5 case 3).

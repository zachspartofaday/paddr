# Command-line guide

[Back to Paddr](../README.md) · [Build from source](BUILDING.md)

Run these commands from a source checkout. The packaged app does not include a separate CLI executable.

The CLI shares the app's canonical profile document and is intended primarily for development and diagnostics:

```bash
scripts/paddr.sh --list-profiles
scripts/paddr.sh --select-profile "Arcade"
scripts/paddr.sh --select-profile 01234567-89ab-cdef-0123-456789abcdef
scripts/paddr.sh --dry-run
scripts/paddr.sh --observe-only --verbose --duration 10
```

Profiles are stored at `~/.config/Paddr/config.json`. On first profile-aware load, an existing raw left/right configuration is atomically migrated: unchanged defaults activate **Default**, while customized values become the active **Previous configuration** profile. Existing raw and canonical configurations retain the former coupled center-radius tracking behavior until changed; fresh profile stores and newly created configurations use full-pad pointer tracking. A failed migration leaves the original file intact and reports its path.

GUI and CLI profile edits use a shared storage lock and reject saves based on an older file version. If another process changes the profiles, Paddr keeps your unsaved draft and reports a conflict. Copy your edits before reopening the app to load the current profiles. Explicit exports to a different path deliberately replace that destination; they still reject a changed source.

`--list-profiles` prints each name and stable ID; `--select-profile` persists an exact name or ID selection. Use `--profile-store PATH` for a different canonical document. An explicit `--config PATH` remains a read-only compatibility input for an existing legacy raw configuration (or canonical document); invalid paths fail instead of loading defaults. Mapping flags—including per-pad center-tap tracking, pointer smoothing/strength, and tap stabilization/tolerance—change only the effective CLI draft unless `--write-config PATH` persists it. With canonical input, that write preserves the complete profile document and updates its active profile; with legacy raw input, it creates a new canonical document from the effective configuration. Profile list/select operations are mutually exclusive with runtime and mapping options. Run `scripts/paddr.sh --help` for the complete flag list and numeric ranges.

Example:

```bash
# Left pad as a nine-zone keyboard grid
scripts/paddr.sh --left-mode dpad --left-layout grid-nine \
  --left-grid-top-left q --left-grid-center space --left-grid-bottom-right c
```

If a key or mouse-button release fails during CLI shutdown, the process stays alive and retries until the held input is released. It prints recovery guidance instead of abandoning cleanup; restoring Accessibility access may be necessary.

## Configuration compatibility

Raw `--config` files accept an optional `rearButtons` object, for example:

```json
"rearButtons": { "l4": "f1", "l5": "mouse-left", "r4": null, "r5": "code:118" }
```

Missing or null bindings mean None. Other values use the existing key catalog (including F1–F4 and `code:N`) or `mouse-left` / `mouse-right`; empty strings and `"none"` are invalid. CLI profile selection and import/export preserve these bindings. Profile documents retain schema version 1: older binaries ignore the added fields and can discard them when saving, so export a backup before downgrading.

Pointer acceleration has an independent switch per pad. Turning it off retains the strength and uses linear motion; enabling a zero-strength setup starts at 25%. Profiles store `mouseAccelerationEnabled` separately from `mouseAcceleration`. When the flag is absent, nonzero acceleration stays enabled and zero stays off. The existing CLI acceleration options set the strength and enable it for nonzero values. Older builds ignore the new flag and use the stored amount.

Scroll retains signed fractional movement per pad until a whole scroll point accumulates; lifting or replacing the output session clears that remainder. Reports already one second old are rejected before they can emit or re-arm output. Fresh neutral input is required after such a loss. These behaviors have deterministic fixture coverage; physical rear-button behavior and latency still require controller verification.


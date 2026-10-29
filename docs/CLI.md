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

Missing or null bindings mean None. Other values use the existing key catalog (including F1–F4 and `code:N`) or `mouse-left` / `mouse-right`; empty strings and `"none"` are invalid. CLI profile selection and import/export preserve these bindings. New saves use profile schema version 2. Version-1 documents remain readable and are upgraded on save, with gyro Off and both grip actions None when absent. Older Paddr builds reject version 2 rather than silently discard sensor settings. Keep a backup before downgrading; raw configuration exports have no schema-version protection.

Pointer acceleration has an independent switch per pad. Turning it off retains the strength and uses linear motion; enabling a zero-strength setup starts at 25%. Profiles store `mouseAccelerationEnabled` separately from `mouseAcceleration`. When the flag is absent, nonzero acceleration stays enabled and zero stays off. The existing CLI acceleration options set the strength and enable it for nonzero values. Older builds ignore the new flag and use the stored amount.

Scroll retains signed fractional movement per pad until a whole scroll point accumulates; lifting or replacing the output session clears that remainder. Reports already one second old are rejected before they can emit or re-arm output. Fresh neutral input is required after such a loss. These behaviors have deterministic fixture coverage; physical rear-button behavior and latency still require controller verification.

## Gyro mouse and grip touch

Gyro and grip mappings are controller-wide profile settings, independent of the pad modes and rear buttons. They start Off/None. To stage a gyro setup without posting input:

```bash
scripts/paddr.sh --gyro on --gyro-activation right-grip \
  --gyro-sensitivity 12 --left-grip mouse-right --show-config
```

`--gyro-activation` accepts `right-grip`, `left-grip`, `either-grip`, `either-pad`, or `always`. `--left-grip` and `--right-grip` accept a key, `mouse-left`, `mouse-right`, or `none`; each action is held only while its grip is touched. Contact can activate gyro and hold an assigned action simultaneously. Grip input detects contact with the handle, not squeeze strength.

| Option | Range / meaning |
| --- | --- |
| `--gyro on\|off` | Enable gyro mouse output; retains tuning when off |
| `--gyro-sensitivity` | 0.1–40 mouse points per degree |
| `--gyro-vertical-scale` | 0.1–4 times the base sensitivity, vertical only |
| `--gyro-horizontal-scale` | 0.1–8 times the base sensitivity, horizontal only; defaults to 2.5× |
| `--gyro-holding-angle` | 0–90°: controller held flat through upright |
| `--gyro-horizontal-tilt on\|off` | Side-to-side tilt for horizontal aiming; Off retains turning |
| `--gyro-invert-horizontal on\|off` | Reverse horizontal movement |
| `--gyro-invert-vertical on\|off` | Reverse vertical movement |
| `--gyro-smoothing` | 0–1 smoothing strength |
| `--gyro-noise-threshold` | 0–5 degrees/second stationary noise cutoff |

With `--observe-only --verbose`, sensor availability and grip transitions are logged without posting mouse/key events. This still requires Input Monitoring. Diagnostics use contact states, not raw packets or device identifiers. Do not run a second mapper beside an active Paddr instance during output testing.

In raw configuration files the equivalent fields are:

```json
"gyro": {
  "enabled": true,
  "activation": "right-grip",
  "sensitivity": 10,
  "verticalScale": 2.5,
  "horizontalScale": 2.5,
  "holdingAngleDegrees": 45,
  "horizontalUsesTilt": true,
  "invertHorizontal": false,
  "invertVertical": false,
  "smoothing": 0.25,
  "noiseThreshold": 1
},
"gripTouch": { "left": "mouse-right", "right": null }
```

The holding angle mixes the controller’s yaw and roll so horizontal aiming follows your normal grip position. With horizontal tilt Off, aiming follows turning; On selects side-to-side tilt. The assignments follow the maintainer’s observed controller behavior, correcting the earlier reversed selection. Forward/back aiming is unchanged. It does not rotate the desktop mouse axes. New or omitted tuning defaults to a 45° holding angle and tilt aiming; explicitly saved values are retained. The app requires its guided **Calibrate** action before aiming. The headless CLI explicitly retains stationary calibration at runtime startup and after stale motion, so put the controller down or hold it still when starting it. Calibration never saves sensor bias or restarts pad/grip output.

See the [mapping guide](USING.md#gyro-mouse-and-grip-touch) for calibration, safe activation and the passive sensor-availability boundary.

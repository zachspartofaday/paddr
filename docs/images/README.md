# Live interface captures

These four product screenshots were refreshed on 2026-10-29 from the already
running, permission-approved Developer ID preview at
`/tmp/paddr-gyro-axis-gain-20261029/preview/Paddr.app`, on macOS 27.2 build `26B118`.
Embedded source revision: `8a634e9af533320ab0d47a088f6c4099d4e2440b`,
`PaddrSourceDirty=false`, version 2.0.1/build 20. These show the gyro/grip preview,
not the published 2.0.1 release or a notarized artifact.

The maintainer's saved World of Warcraft profile supplies left Four corners
Zones (Top left selected), right Scroll, independent rear mappings, both grip
actions None and right-grip gyro activation. The controller is connected through
the puck with 92% battery. Output was already enabled and the gyro calibrated;
those states were preserved throughout. No calibration request, output-toggle
change or profile save was made for capture.

The expanded gyro image shows the maintainer-tested settings: 10 pt/° base,
2.5× horizontal and vertical gain, 45° holding angle, tilt aiming on, 25%
smoothing, 1°/s noise cutoff and both inversions off. These saved values are the
reference for the default-tuning change; the captured binary predates that
change and still has its earlier hover-help default.

For the pointer example only, the right pad was temporarily changed to Pointer
as an unsaved draft and its tuning expanded. Returning to Scroll restored
**Configuration saved**, without writing the profile or replacing the active
runtime. The saved configuration, expanded gyro view, enabled output and dark
appearance were restored afterward.

| File | State | Dimensions |
| --- | --- | --- |
| `paddr-profile-overview.png` | Dark, saved left Zones / right Scroll, gyro collapsed | 996 × 788 |
| `paddr-profile-overview-light.png` | Same saved setup, light | 996 × 788 |
| `paddr-gyro-tuning.png` | Dark, saved setup with gyro tuning expanded | 996 × 1007 |
| `paddr-auto-sized-tuning.png` | Dark, unsaved right Pointer with pointer tuning expanded | 996 × 996 |

The app controlled its window size. Computer-use window captures were converted
to PNG and uniformly cropped by 40 pixels at the top to omit the title bar and
its pointer overlay. Profile controls, workspace and footer remain intact. No
controls, states or other content were retouched, composited or resized. All four
images were inspected for clipping and cursor overlays. The pointer graphic in
the Pointer pad is application content.

Fixture exports in `docs/ui/bespoke-preview` remain separately identified test
evidence. Product images establish visible presentation and connection state,
not latency, held-output cleanup or assistive-technology acceptance. Compatibility
remains attributed to maintainer confirmation.

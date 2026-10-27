# Live interface captures

These three screenshots were refreshed on 2026-10-27 from the currently running,
permission-approved arm64 preview at `/tmp/paddr-softer-controls/package/Paddr.app`.
They show the softened control outlines from PR #98 on macOS 27.2 build `26B118`.

The Developer ID-signed preview was built before the change was committed. Its
embedded metadata records base `5cf489190d1d0479ffa0e603afab2dea9dd89781` and
`PaddrSourceDirty=true`; its application changes are the softer-outline changes
subsequently committed as `a279af11b136733a7dd9575d32ccb6c6dba5b3fd`. This is
live preview evidence, not an exact-clean-head or notarized release capture.

Input Monitoring and Accessibility were granted, a real puck-connected controller
reported 95% battery, and output stayed off throughout. The overview captures use
the maintainer's saved World of Warcraft profile with left Four corners Zones,
Top right selected, and right Scroll. The visible dashed pad focus indicator retains
its full strength while decorative control outlines are softer.

For the expanded example, the right pad was temporarily changed to Pointer as an
unsaved draft and its tuning opened. The mode was returned to Scroll afterward,
restoring **Configuration saved** without saving or altering the stored profile.
Dark appearance, collapsed tuning and the original off output setting were restored.

| File | State | Dimensions |
| --- | --- | --- |
| `paddr-profile-overview.png` | Dark, saved left Zones / right Scroll | 996 × 598 |
| `paddr-profile-overview-light.png` | Same saved setup, light | 996 × 598 |
| `paddr-auto-sized-tuning.png` | Dark, unsaved right Pointer with tuning expanded | 996 × 825 |

The app controlled its window size. Native `screencapture -x -o -l` window captures
omit shadows and the computer-use cursor overlay. No controls, statuses or other
UI elements were composited or retouched. Every product image currently linked
from the README and mapping guide was replaced with this build.

To update: select the exact permission-approved running app, record its source
identity and host, keep mapped output off, let automatic sizing settle, and capture
the native window. Inspect for clipping, overlays and private data. Restore the
user's configuration, disclosures, appearance and output state. Do not revoke
permissions just to illustrate setup. Fixture exports in `docs/ui/bespoke-preview`
remain separately identified test evidence.

These images establish visible connection and permission state, not output latency,
physical key/button release behavior or assistive-technology acceptance. macOS
compatibility remains attributed to maintainer confirmation.

# Live interface captures

All twelve README screenshots were replaced on 2026-10-26 with captures of the
running, packaged app on macOS 27.2, build `26B118`. The installed arm64 ad-hoc build
identifies source revision `00145329950b5f519db639eaf97c40a3447bd6b9` from PR #94,
including the audit repairs and native Compass icon. The README heading uses
`Assets/PaddrIcon.png`, generated from the same Icon Composer source.

These are live screenshots, not test fixtures or HTML mockups. The maintainer
granted Input Monitoring and Accessibility to this installed copy. Workspace
captures show a real puck-connected controller reporting 100% battery, with mapped
output off. Screenshot examples were staged as unsaved drafts in the existing
World of Warcraft profile. They are not built-in presets. The drafts were discarded
and the saved profile and original dark appearance restored after capture.

Only `paddr-permissions.png` shows missing access. It captures the actual **Allow
access** setup sheet before the maintainer granted permissions; permissions were
not revoked or simulated to recreate this state.

## Capture method and sizing

Workspace and guide images are direct macOS window captures, including the active
titlebar, without window shadows or the computer-use cursor overlay. No UI elements,
status values, or permission messages were composited or retouched. The setup
sheet is a direct sheet capture from the same app before approval.

The production app controls configuration-window width and height. Opening Pointer
tuning grew the window from 571 to 793 points; changing both pads to Zones shrank
it to 617 points. Controls and the complete output footer remain visible in every
workspace capture. The guide retains its production 720 × 480 content layout plus
titlebar. The permission sheet has its own fitted size.

| Capture | PNG dimensions |
| --- | --- |
| Profile overview, light and dark | 1080 × 571 |
| Expanded Pointer tuning | 1080 × 793 |
| Both pads in Zones | 1080 × 617 |
| Connection details with access granted | 1080 × 571 |
| Radial, corners, left/right, top/bottom zone layouts | 1080 × 617 |
| 3 × 3 zone layout | 1080 × 571 |
| Guide welcome | 720 × 512 |
| Permission setup sheet | 560 × 335 |

- `paddr-profile-overview.png` and `paddr-profile-overview-light.png`: left Scroll,
  right Pointer at 2.0×, collapsed tuning, and rear bindings visible.
- `paddr-auto-sized-tuning.png`: left Pointer tuning expanded, right Zones, dark.
- `paddr-auto-sized-zones.png`: both pads in Zones, dark, shorter window.
- `paddr-zones-*.png`: all five left-trackpad layouts with right Pointer, light.
- `paddr-access-ready-light.png`: the Connection details popover confirms access,
  puck and controller readiness, output off, and the live battery level.
- `paddr-onboarding.png`: guide welcome page, light.
- `paddr-permissions.png`: real setup sheet before permission approval, dark.

## Updating these images

Use an installed build with its source revision recorded. Grant permissions through
macOS Settings and verify the controller state in the app. Stage example mappings
as unsaved drafts with output off. Let the app settle at its managed size and capture
the native window directly. Inspect every image for clipping, overlays, and private
data before replacing it. Restore the saved profile and appearance afterward.

Do not revoke working permissions merely to regenerate the setup illustration.
Capture that state during a genuine first launch or permission-approval workflow.

`FamilyConsoleLayoutEvidenceTests.testExportReadmeWindowEvidence` remains available
for deterministic offscreen layout regression evidence with inert dependencies:

```bash
PADDR_UI_EVIDENCE_DIR=/absolute/path/to/evidence \
swift test -Xswiftc -warnings-as-errors \
  --filter FamilyConsoleLayoutEvidenceTests/testExportReadmeWindowEvidence
```

Those fixture exports are separate from these live README images. The other
`testExportConfigurationRenderEvidence` exporter covers fixed-viewport stress cases.

The captures establish the visible live connection and permission state, not
mapping latency, physical key/button release behavior, or VoiceOver acceptance.
Released macOS 27 and macOS 27.2 release-candidate compatibility remain attributed
to maintainer confirmation. See [the implementation verification record](../ui/PADDR_REDESIGN_VALIDATION.md)
for earlier validation and its limits.

# Native interface evidence

All twelve README images were replaced on 2026-10-26 using production SwiftUI/AppKit
views on macOS 27.2, build `26B118`, with Xcode 27.0. The views come from merged PR #92
(`c211657d3dcff3e38e7835508993ce0cef966172`), with the footer alignment and transition-guidance
corrections in PR #93. The README exporter
is `FamilyConsoleLayoutEvidenceTests.testExportReadmeWindowEvidence`.

These are complete native window-frame renders, including the AppKit titlebar,
with inert in-memory example data. They are not HTML mockups or live controller
sessions. SwiftUI controls use key-window presentation; the offscreen AppKit
window chrome is inactive. No user profile, permission request, or mapped output
is involved.

Configuration captures use `ConfigurationView(managesWindowSize: true)` inside
an `NSHostingController` and the production window chrome and sizing helpers.
The exporter lets content measurements set the height, then checks that the scroll
viewport matches the full document within two points. A fixed-height canvas, extra
blank band, or screen too small for the complete document fails this check. The
capture includes the actual titlebar instead of an empty reserved titlebar area.

The guide uses its production 720 × 480 usable layout, plus titlebar. Its welcome
page intentionally has more space than its access page; the app's guide does not
use the configuration window's automatic sizing.

| Captures | Window image dimensions |
| --- | --- |
| Profile overview, light and dark | 1080 × 577 |
| Expanded Pointer tuning | 1080 × 799 |
| Both pads in Zones | 1080 × 623 |
| Access granted | 1080 × 577 |
| Radial, corners, left/right, top/bottom zone layouts | 1080 × 623 |
| 3 × 3 zone layout | 1080 × 577 |
| Guide welcome and access pages | 720 × 512 |

- `paddr-profile-overview.png` and `paddr-profile-overview-light.png`: editable
  example draft, left Scroll/right Pointer, collapsed tuning, rear bindings F1–F4.
- `paddr-auto-sized-tuning.png`: left Pointer tuning expanded, right Zones, dark.
- `paddr-auto-sized-zones.png`: both pads in Zones, dark, shorter content height.
- `paddr-zones-*.png`: all five left-trackpad layouts with right Pointer, light.
- `paddr-access-ready-light.png`: both permissions granted, no controller/puck
  connected, output off, light. This is simulated access state.
- `paddr-onboarding.png`: guide welcome page, light.
- `paddr-permissions.png`: guide page 3 using the shared permission controls, light.

Workspace examples have both permissions granted, no controller/puck connected,
and output off. Only `paddr-permissions.png` simulates permissions still needed. Its profile is named Editable. Bindings
are example drafts, not built-in presets.

Regenerate the README captures with:

```bash
PADDR_UI_EVIDENCE_DIR=/absolute/path/to/evidence \
swift test -Xswiftc -warnings-as-errors \
  --filter FamilyConsoleLayoutEvidenceTests/testExportReadmeWindowEvidence
```

Export names start with `readme-`. Copy `overview-{dark,light}` to the two profile
images, `expanded-dark` and `shorter-dark` to the auto-sized images,
`access-ready-light` to its matching image, and `guide-{welcome,permissions}-light`
to onboarding/permissions. The five `zones-*-light` images use enum raw names:
`radial-four`, `four-corners`, `horizontal-two`, `vertical-two`, and `grid-nine`.

The separate `testExportConfigurationRenderEvidence` retains fixed viewport
stress cases for responsive-layout checks; those exports are not README images.
Inspect replacements for clipping and private data before copying them here.

Maintainer confirmation establishes the reported released macOS 27 and macOS 27.2
release-candidate compatibility. These fixtures do not establish hardware
compatibility, latency, or manual VoiceOver/keyboard behavior; see
[the implementation verification record](../ui/PADDR_REDESIGN_VALIDATION.md).

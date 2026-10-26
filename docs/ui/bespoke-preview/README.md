# Bespoke control comparison

The after images are **WindowServer-composited native window captures** of the
existing inert in-memory configuration fixture, with system access granted. They
include SwiftUI's native Liquid Glass pass, which cached AppKit renders omit.
They are fixture evidence, not hardware captures or replacements for live README
screenshots. No personal profile, receiver or production app was opened.

Before: `d0c99d8` (published 1.1.0), preserved unchanged. After: the refinement
introduced by this commit, based directly on PR #96 candidate
`095fede96d07b4e22cbb0126661efed15ba52d59`. The same overview fixture uses
content-driven window sizing in light/dark. The dark accent is Compass North
`#78C7BD` from `Assets/AppIcon.icon/Assets/North.svg`; light keeps `#2859CF`.

Captured on macOS 27.2 (`26B118`), SDK 27.0, Swift 6.4, arm64. The existing
`FamilyConsoleLayoutEvidenceTests` exporter captures its own fixture window with
ScreenCaptureKit only when Screen Recording is already granted. It does not
request permission. These composited files use the window's reported native pixel
scale; the separate stroke samples exercise explicit 1x/2x cached raster scales.

| Appearance | Before | After |
| --- | --- | --- |
| Light | ![Before, light](before-light.png) | ![After, light](after-light.png) |
| Dark | ![Before, dark](before-dark.png) | ![After, dark](after-dark.png) |

The user's both-Zones scenario, with four corners and zero neutral radius:

| Light | Dark |
| --- | --- |
| ![Both Zones, light](zones-light.png) | ![Both Zones, dark](zones-dark.png) |

![Selection, hover, opaque fallback and expanded tuning](contact-sheet.png)

Full captures: `/tmp/paddr-glass-eeff8259/final/`. Final canonical test log:
`/tmp/paddr-glass-eeff8259-tests-complete.log`. The local handoff records the final
commit and exact-head package identity. Earlier `iteration-*` directories are
experiments; they are not acceptance evidence.

See [the validation record](../PADDR_BESPOKE_CONTROLS_VALIDATION.md) for commands,
source/rendered coverage and remaining manual gaps. Prior independent reviews
predate this new refinement; fresh review remains the parent's responsibility.

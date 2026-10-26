# Native interface evidence

Regenerated on 2026-10-26 from merged PR #92, commit
`c211657d3dcff3e38e7835508993ce0cef966172`, using production SwiftUI/AppKit views on macOS 27.2,
build `26B118`, with Xcode 27.0. These are native view captures from the existing
inert `FamilyConsoleLayoutEvidenceTests` fixture, not HTML mockups or live
controller sessions. They exclude the AppKit titlebar.

- `paddr-profile-overview.png`: dark appearance, editable example draft, left
  Scroll/right Pointer, collapsed tuning, and rear bindings F1–F4.
- `paddr-profile-overview-light.png`: the same workspace in light appearance.
- `paddr-auto-sized-tuning.png`: content-driven window with left Pointer tuning
  expanded, right Zones, and all rear bindings visible.
- `paddr-auto-sized-zones.png`: the same managed window after switching the left
  pad to Zones, showing the shorter content height. These managed captures include
  the content view's reserved titlebar area; AppKit titlebar controls are outside it.
- `paddr-zones-*.png`: all five left-trackpad layouts with right Pointer, light
  appearance. These example draft bindings are not built-in presets.
- `paddr-access-ready-light.png`: both permissions granted, no controller/puck
  connected, output off, light appearance. This is simulated access state, not a
  live permission or controller verification.
- `paddr-onboarding.png`: guide welcome page, light appearance.
- `paddr-permissions.png`: guide page 3 using the shared permission controls,
  light appearance.

Unless noted otherwise above, the example model has neither permission granted,
no controller/puck connected, and output off. It uses in-memory profiles and never emits mapped input. The
baseline workspace captures use a fixed 1080 × 640 fixture. The actual application
now measures its content height and fits the screen. Managed-window evidence is
exported as `managed-expanded-dark.png` and `managed-collapsed-dark.png`; its
profile/save and output controls remain fixed when screen limits require scrolling. An editable example profile
named Editable is used throughout.

The full exporter additionally covers 680 × 600 and 1600 × 900 workspaces,
complete scroll documents, dark zone/guide views, expanded pointer tuning, both
pads off, individual missing permissions, granted access, and enlarged text.
Regenerate it with:

```bash
PADDR_UI_EVIDENCE_DIR=/absolute/path/to/evidence \
swift test -Xswiftc -warnings-as-errors \
  --filter FamilyConsoleLayoutEvidenceTests
```

Inspect captures for clipping and private data before copying selected files here.
Update README alt text and this metadata to match. These fixtures do not establish
physical-controller compatibility, latency, or manual VoiceOver/keyboard behavior;
see [the implementation verification record](../ui/PADDR_REDESIGN_VALIDATION.md).

The existing eleven captures were regenerated and are byte-identical to those
merged in #92. The access-granted workspace is newly included here. The README
also now displays the managed expanded-tuning capture. Compatibility with released
macOS 27 and macOS 27.2 release candidate is maintainer-confirmed separately; this
export does not establish that hardware compatibility.

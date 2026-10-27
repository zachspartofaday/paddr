# Live interface captures

The three product screenshots were captured on 2026-10-26 from the running,
permission-approved arm64 app at source `da5d6d7576d4bff26ad4be66b5165816f198c5c7`,
the final bespoke-interface candidate merged in PR #96. Host: macOS 27.2 build
`26B118`. The captures represent the 2.0 design; the follow-up battery-refresh and
disclosure-label fixes do not change its appearance.

These are live macOS window captures, not fixtures or mockups. Input Monitoring
and Accessibility were granted, the puck-connected controller reported 96% battery,
and output was switched off for capture. The maintainer's saved World of Warcraft
profile was used without editing its mappings. Dark appearance and collapsed tuning
were restored afterward, along with the original enabled output setting.

| File | State | Dimensions |
| --- | --- | --- |
| `paddr-profile-overview.png` | Dark, left Zones / right Pointer | 996 × 598 |
| `paddr-profile-overview-light.png` | Same saved setup, light | 996 × 598 |
| `paddr-auto-sized-tuning.png` | Right Pointer tuning expanded, dark | 996 × 806 |

The app managed its own window size. Captures used `screencapture -x -o -l` with
the actual window ID to omit shadows and the computer-use cursor overlay. No
controls or status values were composited or retouched. All previous product
captures were replaced or removed; the streamlined README links to the mapping
guide instead of retaining a redundant screenshot gallery.

To update: use the permission-approved app, record its source revision and host,
keep mapped output off, let automatic sizing settle, and capture the native window.
Inspect for clipping, overlays and private data. Restore the user's profile,
disclosures, appearance and output state. Do not revoke permissions just to
illustrate setup. Fixture exports in `docs/ui/bespoke-preview` remain separately
identified test evidence.

These images establish visible connection and permission state, not output latency,
physical key/button release behavior or assistive-technology acceptance. macOS
compatibility remains attributed to maintainer confirmation.

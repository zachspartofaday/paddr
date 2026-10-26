# Native redesign verification

Implementation date: 2026-10-26. Source baseline:
`1e6b049fa57bc2acb1f7bedfbe1ffe2b5028890b`, branch `t3/28a1bb2c`.

The approved [design record](PADDR_REDESIGN_PLAN.md) is implemented in native
SwiftUI/AppKit. The HTML study is a planning artifact, not the implementation.

## Environment

- macOS 27.2, build `26B118`, arm64 host.
- Xcode 27.0, build `27A266a`, macOS SDK 27.0, Swift 6.4.
- Installed developer directory: `/Applications/Xcode.app/Contents/Developer`.
- Deployment target remains macOS 26.0; profile/configuration schema version is unchanged; additive fields are recorded below.
- MobileBuildMCP 2.7.1 guarded launcher was available. Validation uses the
  repository's canonical SwiftPM and shell commands, including its existing
  inert native view fixtures.

This environment record establishes build and presentation evidence, not new
physical-controller compatibility beyond the existing README compatibility note.

## Completed checks

| Check | Result |
| --- | --- |
| `swift test -Xswiftc -warnings-as-errors` with native evidence export enabled | Pass: 485 tests, zero failures (208 core, 5 CLI, 272 app-support) |
| `scripts/check-localization.sh` | Pass; catalog compiled and all extracted keys covered; implicit resource/conditional keys also checked |
| Release arm64 build with warnings-as-errors | Pass |
| Release arm64 `PaddrCLI` build and `scripts/test-cli.sh` | Pass |
| `scripts/test-release-identity.sh` | Pass |
| `scripts/test-release-production.sh` | Pass |
| `scripts/build-app.sh` using task-specific output directory | Pass; arm64 app packaged and ad-hoc signature verified |
| `git diff --check` | Pass |

Local testing artifact: `dist/native-redesign/Paddr.app`. It is ad-hoc signed and
identifies the working source as dirty. No release was published and no user
profile or existing app installation was replaced. The app was not launched
against the user's live configuration.

## Review and regression coverage

A fresh independent reviewer inspected the frozen production/resource candidate
against the approved design. The reviewer found weak secondary text in light
appearance. The affected guide text, numerical readouts, and related secondary
labels now use the explicit adaptive secondary-text role; picker labels also use
the primary-text tint for readable native pop-up controls in both appearances.
Secondary buttons likewise use the readable native label tint. Final light/dark
captures were refreshed after these corrections.

Existing model/core tests retain save-before-enable, failed-save draft retention,
profile switching/deletion guards, release-before-idle, observation while output
is off, and independent pad/rear mappings. UI coverage now checks:

- Native Enable output switch identity, pending-save guidance, and activation
  through the existing model boundary.
- Native profile/save controls outside the scrolling mapping document.
- Independent left/right editing and stable mounted controls across reflow.
- Per-pad tuning disclosure, enabled-value summaries, and read-only inspection.
- Shared permission actions and offline profile editing.
- Compact/default/wide geometry, accessibility text reflow, and adaptive contrast.

SwiftUI accessibility nodes are enabled through the public `accessibilityEnabled`
environment in relevant inert test hosts. This permits checking actual permission
button roles, labels, and visible frames, plus Save & Apply geometry before and
after scrolling, without changing host accessibility permissions or invoking
the live application. The same native output switch instance remains mounted.

## Native rendering

The existing `FamilyConsoleLayoutEvidenceTests` exporter renders production views
with an inert in-memory model. It covers light/dark at 680 × 600, 1080 × 640, and
1600 × 900, complete scroll documents, all five zone layouts, the guide, and an
expanded pointer editor. No controller reports or real user profiles are needed.

Selected captures are maintained in [the image evidence directory](../images/README.md).
The native window's profile header and output footer remain fixed while the
workspace scrolls when the screen cannot fit its content. The current window uses
1080 points as its preferred width and measures the content height automatically.
Manual resizing and Reset Window Size were removed at the operator's request.
Saved screen/position are retained; saved dimensions do not control the layout.

## Verification limits and manual follow-up

Automated fixtures and source review do not certify the whole assistive-technology
experience. The following real-use checks remain manual:

1. Use Tab/Shift-Tab, Space, and arrow keys through profile actions, both pads,
   tuning disclosures, rear bindings, setup, and Connection details. Focus should
   remain visible and return to the invoking control when a sheet closes.
2. With VoiceOver, verify labels, on/off and waiting state, pending-save guidance,
   reading order, selected zone, and guide text. Native accessibility-tree checks
   alone are insufficient to establish spoken behavior.
3. Verify real pointer, scroll, taps, held zone/rear actions, disabling while an
   output is held, and disconnect/reconnect. The mapping engine is unchanged,
   but inert fixtures do not establish physical behavior or latency.

The implementation does not claim these manual checks have been completed.

## Spacing refinement after operator review

The operator's native screenshots showed oversized preview bands, inconsistent
control gaps, and extra space from the longer pointer editor. The refinement
places common controls beside the pad maps at 940-point window widths, uses
labels above controls with a shared 16-point gutter, aligns header/footer content
with the workspace, and compacts the rear-button pairs. Fresh windows now use
1080 × 660 usable points. Native evidence includes both Scroll/Pointer and
Scroll/Off at 940 × 620, in light and dark appearance.

The full 485-test suite passed after the spacing changes. One earlier run timed
out in the existing reconnect-pressure test; the unchanged test passed on rerun.
The final 1080 × 660 geometry also passed all 74 presentation/layout tests with
fresh native evidence, and the ad-hoc arm64 package was rebuilt successfully.


## Permission footer and opening-size refinement

The operator's 08:25 screenshots showed permission guidance separated from output
and a tall opening window. The host's read-only preference check confirmed a v9
physical frame of 941 × 885, bypassing the smaller fresh-window default.

- Move setup into an actionable footer notice naming the missing grant(s), with
  a single Open setup action and reassurance that editing remains available.
- Keep explicit errors and system-prompt instructions. Suppress routine connection
  advice while the permission notice is the next action.
- Group state and save-before-enable guidance beside the native Enable output
  switch. Open connection details from the controller status; show battery in the
  summary only when data is available.
- Compact the profile selector around its text instead of centering it in a wide
  fixed frame. Keep the two editors and their native controls unchanged.
- Use 1080 × 640 usable points for the new v10 opening layout. Reset once on this
  layout revision; preserve resizing on subsequent openings. Add Reset Window Size.
  The zone editor retains its complete bottom workspace inset at this size.

Verification for this refinement:

| Check | Result |
| --- | --- |
| Focused layout, presentation, contrast, and window tests with warnings as errors | 94 passed, no skips |
| Native evidence export | Light/dark, minimum/default/wide, all zone layouts, both pads off, each missing permission, granted permissions, enlarged text |
| Opening and restored-window regression | Recommended initial geometry, custom subsequent size, and explicit reset passed |
| All 16 collapsed pad-mode combinations at opening size | Both editors, rear bindings, and bottom workspace inset fit the scroll viewport |
| Permission recovery and native output semantics | Setup stays reachable; unavailable battery omitted; save-before-enable and switch identity retained |
| Localization coverage | Passed |
| Arm64 release package, warnings as errors, ad-hoc signature verification | Passed; rebuilt `dist/native-redesign/Paddr.app` |

Logs: `/tmp/paddr-footer-tests.log`, `/tmp/paddr-footer-build.log`.
Native captures: `/tmp/paddr-footer-evidence/`; selected documentation images refreshed.
The earlier full 485-test run remains the engine baseline; this refinement ran the
94 focused tests above. No live controller output or user configuration was used.
Keyboard-only, VoiceOver, and physical-controller checks remain manual as listed above.


## Content-driven sizing follow-up

The operator requested automatic sizing and removal of manual resizing after the
expanded Pointer tuning controls extended below the fixed viewport. The current
implementation supersedes the earlier fixed/default-size and restored-size policy.
It measures the mounted header, mapping document, and footer, prefers 1080 points
in width, and fits the resulting frame to the current screen. Window movement,
minimization, and position restoration remain available. The guide is unchanged.

| Check | Result |
| --- | --- |
| Focused presentation, layout, contrast, and window tests, warnings as errors | 97 passed, no skips |
| Managed-window integration | Expanded tuning and rear bindings fit; switching to shorter content shrinks the same window; top edge and width stay stable |
| Saved frame policy | Saved dimensions ignored; configuration window is not manually resizable |
| Screen fitting | Real AppKit frame constrained to simulated small visible frame; pure geometry checks cover narrow/short screens |
| Constrained viewport | Existing fixed-size fixtures verify that mapping content scrolls while Save & Apply and output remain visible |
| Native evidence | Expanded pointer/zone and shorter zone/zone windows rendered and inspected |
| Localization coverage | Passed |
| Arm64 release package, warnings as errors, ad-hoc signature verification | Passed; `dist/native-redesign/Paddr.app` rebuilt |

The integration fixture seeds the existing disclosure state as expanded and
switches pad modes to exercise live growth/shrink through the production hosting
controller and sizing bridge. It does not synthesize a pointer click on the native
disclosure. Manual keyboard/VoiceOver interaction and physical multi-monitor
movement remain unverified. No live controller output or user profile writes were
used. The app was not launched against the user's configuration.

Logs: `/tmp/paddr-autosize-all-tests.log`, `/tmp/paddr-autosize-build.log`,
`/tmp/paddr-autosize-localization.log`. Evidence: `/tmp/paddr-autosize-evidence/`.
The selected managed-window captures are also in `docs/images/`.


## Acceleration switch and fixed selector widths

The operator requested an acceleration switch matching smoothing/stabilization,
and equal-width native selectors. `mouseAccelerationEnabled` now persists
independently of strength. Missing flags infer the previous behavior from strength;
both pointer-gain paths use zero acceleration when disabled. The UI retains the
configured amount when disabled and seeds 25% when enabling a zero-strength setup.
Collapsed summaries omit disabled acceleration. CLI numeric options preserve their
prior behavior by enabling nonzero acceleration and disabling zero explicitly.

All native selection pickers use a shared 192-point width with flexible native
button sizing, including profile selection, zone layout/area/action, touch taps,
and rear bindings. This expands the control bezel itself, not just its surrounding
SwiftUI frame. Both pad inspectors share the same width budget and the existing
automatic window sizing accommodates wrapped rear bindings on small screens.

Validation: all 493 tests passed with warnings as errors (210 core, 5 CLI, 278
app-support). New checks cover legacy decoding, disabled-strength round trips,
linear output while acceleration is disabled, native switch interaction, and pad
independence. Existing read-only tuning checks now expect four switches. The CLI
script also verifies numeric options set/clear the enable flag independently.
Light/dark native renders, all zone layouts, and expanded managed-window evidence
were inspected. Localization coverage, release app packaging, ad-hoc signature
verification, and `git diff --check` passed. Physical-controller and manual
assistive-technology checks remain outside this inert-fixture verification.

Logs: `/tmp/paddr-selectors-full-tests.log`, `/tmp/paddr-selectors-cli.log`,
`/tmp/paddr-selectors-localization.log`, `/tmp/paddr-selectors-build.log`.
Captures: `/tmp/paddr-selectors-evidence/`. The local app and selected docs images
were refreshed. Older binaries ignore the enable flag and use the numeric amount;
profile schema version remains 1.

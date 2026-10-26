# Bespoke controls verification

Historical initial implementation record, 2026-10-26. The current teal/glass
refinement and its verification are recorded at the end of this document.
Initial baseline: merged PR #95,
`d0c99d8d079e24c6ecf727b9a8d4247921ba0b06`. Isolated branch: `t3/99b216c7`.
The [approved plan](PADDR_BESPOKE_CONTROLS_PLAN.md) includes the pad extension.
This is implementer evidence; fresh independent review and operator acceptance remain separate.

## Scope and implementation

- SwiftUI Buttons keep their actions, shortcuts and roles, with a visible 32-point
  minimum surface, continuous 7-point corners and 12-point horizontal insets.
- All selection controls use a 192-point native NSPopUpButton with custom closed
  chrome. Profile actions use a 32-point native pull-down menu. Typed values,
  separators, checkmarks, raw codes, None, profile action order, disabled gates,
  pending-profile labels and destructive confirmation paths are retained.
- The 272-point native select-one mode group draws the approved 32/28-point shell
  and segments, with 2-point inset/gaps and 7/5-point corners. Its native radio-group
  cell and four radio-button children carry distinct left/right group names.
  Unmodified arrow keys change one selection; focus stays on the group.
- Tuning switches draw a 44 × 24 track, radius 7, and 18 × 18 thumb, radius 4,
  inside the 52 × 32 reservation. The 3-point inset leaves exactly 20-point travel.
  An NSButton switch cell owns binary state and dispatch; the accessible element
  exposes AXCheckBox with AXSwitch subrole, localized switch role description,
  integer value and localized On/Off description. Its backing cell is not a second
  accessibility stop. Click, Space and accessibility press share one action path.
- Enable output remains NSSwitch. Sliders, readout budgets, configuration bindings,
  remembered tuning amounts, both mounted editors, footer and sizing bridge are retained.
- A shared 190 × 182 pad shell uses radius 14 and one neutral outline, stronger with
  increased contrast. Exact contiguous regions and neutral-area geometry remain.
  Selection has the current accent fill and a 2-point outline; map focus uses an
  outside dashed cue. Binding plates keep their centers and 38/78-point widths,
  with a 24-point base height and 5-point corners. Long raw codes wrap vertically.
  Pointer tap regions remain ellipses, including the existing zero-radius behavior.

No dependency or upstream implementation was copied. The pinned Quilter/CoreKit
source evidence informed geometry only. No PaddrCore, output/controller lifecycle,
persistence, CLI, release script, package identity, icon, signed release, frozen tag,
installed app, user profile, TCC or global system setting was changed. The current
README images are preserved. Published 1.1.0 remains a separate immutable release; this candidate was not
pushed, published, tagged or merged.

## Environment and baseline

macOS 27.2 (`26B118`), arm64; developer directory
`/Applications/Xcode.app/Contents/Developer`; Apple Swift 6.4; macOS SDK 27.0.
Package tools remain 6.3 and deployment remains macOS 26.0. The checkout began clean
at the required baseline. All six selected skill files matched the supplied SHA-256
receipts. The accepted personal integration source was read with `git show` at
Platform `e306df32db241cc9b755702255d5bf3e6f056f03`. No agents were spawned.

Before edits, the canonical test run and both existing exporters passed: 507 tests
(216 core, 7 CLI, 284 app support), zero failures. Existing mounted tests recorded
native switch values/roles and click mutations, profile presentations, pad independence,
footer and sizing behavior. Baseline captures are under
`/tmp/paddr-bespoke-99b216c7/baseline/`; log: `baseline-tests.log` in the task directory.
A separate early baseline keyboard experiment did not complete (xctest signal 6,
`interaction-baseline.log`). It is not keyboard or VoiceOver proof. Its temporary
experiment was replaced by the explicit native-adapter tests below.

## Completed checks

All paths below are under `/tmp/paddr-bespoke-99b216c7/`. Commands used the developer
directory above. The shared `PADDR_UI_EVIDENCE_DIR` enables **both** existing exporters.

| Check | Result | Log |
| --- | --- | --- |
| `PADDR_UI_EVIDENCE_DIR=/tmp/paddr-bespoke-99b216c7/after swift test -Xswiftc -warnings-as-errors` | 517 tests, zero failures; one explicit host-dependent map-focus skip | `final-tests.log` |
| `scripts/check-localization.sh` | Pass; catalog extraction and compilation | `localization.log` |
| `swift build -c release -Xswiftc -warnings-as-errors --arch arm64` | Pass | `release-build.log` |
| `swift build -c release -Xswiftc -warnings-as-errors --arch arm64 --product PaddrCLI` | Pass | `cli-build.log` |
| `scripts/test-cli.sh "$(swift build -c release --arch arm64 --show-bin-path)/PaddrCLI"` | Pass | `cli-checks.log` |
| `scripts/test-release-identity.sh` | Pass | `release-identity.log` |
| `scripts/test-release-production.sh` | Pass; fixture-only publication/safety checks | `release-production.log` |
| `OUTPUT_DIR=/tmp/paddr-bespoke-99b216c7/package BUILD_SCRATCH_PATH=/tmp/paddr-bespoke-99b216c7/package-build scripts/build-app.sh` | Pass; local arm64 ad-hoc app, artifact smoke test and signature verification | `package-build.log` |
| `git diff --check` | Pass | Git working-tree/staged checks |

The local testing app is `package/Paddr.app`. It was not installed or launched
against production data. Its final source revision/signing receipt is in the packaging
log; earlier dirty builds and intermediate failure logs are diagnostic history.
Release-production tests use their own temporary fake tools; they do not publish.

## Behavioral evidence

`BespokeControlInteractionTests` exercises the replacements themselves, rather than
allowing class enumeration to succeed after controls disappear. It checks:

- Exact drawn switch/segment bounds, thumb travel and the action-menu target.
- One binding write per switch click, Space and accessibility press; disabled
  click/key/AX rejection; one binary accessibility stop with synchronized state.
- Native radio-group and child roles/names/selection, arrow selection, accessibility
  activation, disabled behavior and first-responder retention.
- Native pop-up role/value, None/raw-code retention, one typed selection write,
  checkmarks, disabled writes and long closed labels growing vertically.
- Opening the native menu, posting Escape into its tracking loop, closing without a
  binding write and returning focus. The test has a cancellation fallback and asserts
  that the fallback was not needed. This is synthetic event evidence, not a manual walk.
- Action-menu item gates and dispatch, plus eight tuning switches retaining their
  mounted identities and focus through 1080-to-680-point reflow, with independent bindings.

Existing presentation tests now inspect `PaddrTuningSwitchButton` for tuning while
continuing to require NSSwitch for Enable output. Their remembered-amount, legacy
tracking, disabled/read-only, per-pad, profile, output and footer assertions remain.
The sizing and screen-cap tests remain intact. Added geometry acceptance pins the
actual 14-point shell and selected outline while retaining internal dividers; existing
neutral-radius and region/navigation tests still run.

## Rendered evidence

These are inert in-memory fixtures and exported AppKit/SwiftUI renders, **not live
hardware screenshots**. No receiver, HID, user profile or production app is involved.
The existing exporters were extended; no standalone product screen was added.

Inspected light/dark outputs in `after/` include:

| Surface/state | Capture names |
| --- | --- |
| Managed full workspace | `readme-overview-light.png`, `readme-overview-dark.png` |
| Both expanded tuning panels | `readme-both-tuning-{light,dark}.png` |
| Constrained 680/940/default-width views | `both-tuning-{680,940,1080}-{light,dark}.png`, existing minimum/narrow/default workspace and document renders |
| Every zone layout, selected regions and neutral boundaries | `readme-zones-{radial-four,four-corners,horizontal-two,vertical-two,grid-nine}-{light,dark}.png` |
| Long profile names and raw code plates | `readme-long-labels-{light,dark}.png` |
| Disabled controls | `disabled-tuning-{light,dark}.png` |
| Increased contrast, reduced transparency/motion | `increased-contrast-tuning-{light,dark}.png`; existing adaptive environment matrix tests |
| Focused native controls | `focused-mode-{light,dark}.png`, `focused-switch-{light,dark}.png` |
| Circular pointer tap regions/zero radius | `pointer-radius-{0,60,100}-{light,dark}.png` |
| Off/Scroll | Existing `both-off`, `mixed-off`, and overview captures in both appearances |

`zone-contact-sheet.png` in the task directory is a cropped comparison of the ten
zone renders. Inspection corrected dark chevron contrast, native alignment insets,
a menu bezel ignored by SwiftUI's Menu style, and binding-label centering. Long names
and raw codes grow instead of clipping. Full expanded windows fit at the managed
size; constrained fixtures scroll while persistent actions remain outside the document.
The accessibility-size environment exercises reflow; it does not prove every macOS
system text/display setting. Hover/press handling is source-backed and uses restrained
static color changes; a complete live hover/press/inactive-state walk remains manual.

## Verification limits and manual follow-up

The command-line XCTest process refuses key-window status for the SwiftUI map fixture,
even after bounded activation attempts. `testZoneMapKeyboardFocusRemainsDistinctFromSelectedRegion`
skips on that explicit missing precondition; its selection/focus assertions remain in
place for a capable host. Failed preliminary captures are segregated in
`unverified-focus-attempt/` and are not focus evidence. The native-adapter focus tests
above pass, but a complete key loop and live SwiftUI map focus are not certified here.
No VoiceOver, Voice Control, Switch Control or physical controller walk was completed.

Before operator acceptance:

1. Tab/Shift-Tab through both editors, disclosures, profile/rear menus, setup and
   Connection details. Focus must stay visible across reflow, mode changes and sheets.
2. Open selectors by keyboard, move through items and press Escape. The checked value
   must remain unchanged on cancellation and focus must return to the trigger. Check
   pending/dirty/default profiles and long names without losing confirmation gates.
3. Use arrows in each independently named mode group. Exactly one mode must remain
   selected. Use Space on each tuning switch; one activation must change one binary
   state and preserve the remembered amount. Read-only mappings must remain disabled.
4. Focus the zone map: its dashed outside cue must differ from the solid selected
   region. Arrow keys must move selection without moving focus. The Selected area
   menu must provide the same areas to keyboard and assistive technology users.
5. With VoiceOver, verify switch names, switch role and On/Off value, radio-group
   identity/selection, menu values/checkmarks, reading order and focus restoration.
   Activate each tuning switch once with VO-Space. Verify Voice Control/Switch Control
   can name, reach and activate the same controls without duplicate stops.
6. Check real pointer/scroll/taps, held zone/rear actions and disable/disconnect release
   safety. Engine tests pass, but inert rendering does not establish hardware behavior
   or latency. Inspect live increased contrast, system text/display scaling and inactive,
   hovered/pressed states before accepting final screenshots.

Remaining risks are the unverified live assistive/input paths and macOS 26 rendering
(the host runs 27.2). The implementation changes presentation/adapters only and leaves
runtime safety tests intact; this does not replace independent review or manual proof.

## Independent review and selector-direction repair

A fresh GPT-6.1 Sol/high reviewer inspected the full candidate `8d4f31d` and
its supplied source/rendered evidence. The verdict approved those tiers with one
MEDIUM regression: the closed selector drew its value and chevrons in fixed LTR
positions. Live interaction acceptance remained incomplete, as recorded above.

The parent corrected the native pop-up adapter to receive SwiftUI layout direction.
The drawing uses mirrored value/chevron rectangles and leading text alignment;
menu contents, typed bindings and width remain unchanged. The icon-only action
menu receives the same direction without moving its centered icon. Tuning-switch
behavior is unchanged by this repair.

`testClosedMenuMirrorsContentWithoutChangingSelectionOrWidth` changes direction on
the same mounted selector and checks mirrored, non-overlapping content; stable
width/height and identity; and unchanged selected values/checkmarks. It covers
short, long and mixed Arabic/English/numeric values. With the previous drawing
restored, it failed 12 assertions (`/tmp/paddr-bespoke-rtl-before.log`); with the
repair it passes. The native menu Escape test now runs in both directions and
verifies opening/closing, no fallback cancellation, no binding write, and focus
return. These remain synthetic native-event checks, not a full manual key loop.

Light/dark LTR/RTL control captures are named `selector-{ltr,rtl}-{0,1,2}-{light,dark}.png`
in `/tmp/paddr-bespoke-rtl/` and the final evidence directory. Their appearance was
inspected, including wrapping and mixed-direction text. The full acceptance rerun
uses `/tmp/paddr-bespoke-final/` and `/tmp/paddr-bespoke-final-*.log`.

The separate frozen 1.1.0 release was subsequently notarized, stapled and published
from `d0c99d8` on 2026-10-26. No bespoke UI changes are included in that release.

Final parent rerun after the direction fix: **518 tests, 517 passed and the same
one key-window-dependent focus test skipped**, with both exporters enabled.
Localization, warnings-as-errors release app/CLI builds, CLI checks, release identity
and production fixtures all pass. Logs: `/tmp/paddr-bespoke-final-tests.log`,
`-localization.log`, `-build.log`, `-cli-build.log`, `-cli.log`, `-identity.log`,
`-production.log`. Fresh exact-commit ad-hoc packaging is recorded separately in
`/tmp/paddr-bespoke-final-package.log`. Manual gaps listed above remain open.

## Current operator refinement: teal, filled selection and native glass

Implemented on isolated branch `t3/eeff8259`, directly from exact PR #96 candidate
`095fede96d07b4e22cbb0126661efed15ba52d59`. The parent checkout and PR head were
not changed. Published 1.1.0 at `d0c99d8` remains immutable. This is implementer
validation; prior source/static/external reviews do **not** accept this new code.
Fresh independent review and operator acceptance remain outstanding.

The supplied screenshot's outline-only Zones selection and whole-control hover
motivated persistent filled segments and local neutral feedback. The operator's
subsequent clarification explicitly chose logo teal for dark mode. `PaddrStyle.action`
now resolves to Compass North `#78C7BD` in dark appearance, sourced from
`Assets/AppIcon.icon/Assets/North.svg`; South `#56AFA7` informed the family. The
selected pad fill is `#254C48`, and text/thumbs on teal use `#1C2630`. Primary
buttons, native slider tint, mode selection, tuning switches, zone captions,
selection outlines and focus all share that semantic accent. Light retains its
original `#2859CF` blue/white pair. Neutral surfaces and warning/error/success roles
are unchanged. No old dark-blue literals remain in PaddrMenu.

### Native composition and safeguards

`PaddrButtonSurface` uses the SDK's macOS 26 SwiftUI `glassEffect(.regular.interactive(...), in:)`
behind native controls. The NSViewRepresentable adapters remain the hit, action,
focus and accessibility owners. The material background is non-hit-testing and
accessibility-hidden; it adds no control or focus stop. Selected/On and primary
fills preserve stable text contrast while native glass supplies the surrounding
material/edge. Native control content does not paint an opaque neutral fill over
the glass in normal appearance. Reduce Transparency **or** Increased Contrast uses
an opaque semantic surface; Reduce Motion disables interactive glass motion while
retaining static state feedback and enabled controls. No gradients, third-party
dependencies or custom optical effects were added. AppKit's macOS 27-only
`effectIsInteractive` is not used, so the macOS 26 deployment floor is unchanged.

A discarded AppKit glass-subview experiment produced layout invalidation and
misregistered content. It is absent from the candidate. Its `iteration-1` through
`iteration-10` artifacts are diagnostic attempts, not accepted evidence. SwiftUI
composition corrected the layout and was then inspected through WindowServer.

The 32-point controls, 192-point selectors, 44 × 24 tuning tracks, 18 × 18 thumbs,
272-point mode groups, 190 × 182 maps, typography, paired editor identities,
auto-sizing, footer, permissions/profile gates, native output switch and native
slider behavior remain. Mode hover follows the individual segment and clears in
gaps/outside/disabled regions. Pressed feedback is local and the current fill stays
until native tracking commits. Pad outlines now use an inset 1.5-point stroke
(2-point increased contrast), without the previous .75-point padding; AppKit
outlines inset their path and corner radius together and explicitly antialias.
Selected key plates omit the fractional bright rim. Exact contiguous map regions,
neutral/tap geometry and separate outside map-focus cue remain intact.

### Final automated verification

Environment: macOS 27.2 (`26B118`), arm64, Xcode developer directory
`/Applications/Xcode.app/Contents/Developer`, Swift 6.4, SDK 27.0, deployment 26.0.
Selected skill SHA-256 receipts matched the assignment. No child agent was used.
All logs below are `/tmp/paddr-glass-eeff8259-<suffix>.log`.

| Command/check | Result | Log suffix |
| --- | --- | --- |
| `PADDR_UI_EVIDENCE_DIR=/tmp/paddr-glass-eeff8259/final swift test -Xswiftc -warnings-as-errors` | **525 tests: 524 passed, 1 existing key-window skip, zero failures**; both exporters enabled | `tests-complete` |
| `scripts/check-localization.sh` | Pass; catalog covers all extracted keys | `localization` |
| `swift build -c release -Xswiftc -warnings-as-errors --arch arm64` | Pass | `build` |
| Explicit release `--product PaddrCLI` build | Pass | `cli-build` |
| `scripts/test-cli.sh <release PaddrCLI>` | Pass | `cli` |
| `scripts/test-release-identity.sh` | Pass | `identity` |
| `scripts/test-release-production.sh` | Pass | `production` |
| Contrast pairs and sampled composited material | Pass for applicable text/non-text roles; see below | `contrast-samples` |
| Clean exact-head ad-hoc `scripts/build-app.sh` and `--artifact-smoke-test` | Recorded in the local handoff after this commit, including revision/dirty identity | `package`, `artifact-smoke` |

The first full attempt timed out in existing
`testProgressPressurePreservesReconnectedActiveStateAndLatestCounters` (four
assertions). Its unchanged targeted rerun passed (`reconnect-rerun`), followed by
passing full runs. A synthetic native-press fixture also exposed first-click
activation when its window was not key; it now makes the fixture window key before
tracking and never changes appearance during a press. Its dispatch and persistent
selection assertions were retained. Intermediate failures are preserved in `tests`,
`tests-final` and `focused-final`; only `tests-complete` is the final full result.

Focused regression coverage now checks adaptive role equality and exact logo/light
accent values; text contrast with normal/hovered/pressed filled selections; rendered
selected versus idle, hovered-other, hovered-selected and disabled segments;
segment pointer movement at visible edges and clearing in gaps/outside/disabled
segments; native press/release and one binding write; unchanged menu/switch values
under hover; native full-hierarchy hit owners and stable mounted controls/focus
through material preference changes; and explicit 1x/2x raster output. Existing
menu checkmarks/raw values/None, Escape and focus restoration, RTL/long/mixed labels,
radio/switch AX semantics, independent editor/reflow and geometry tests still pass.

The dark foreground/teal pair measures **7.82:1**, light white/blue **6.14:1**, and
dark selected outline/fill **4.85:1**. A blank composited selector-interior sample
measures primary text **6.53:1 dark / 13.44:1 light**, and the secondary-colored
chevrons **4.16:1 dark / 5.59:1 light**, exceeding their non-text 3:1 requirement.
These sampled fixtures supplement semantic contrast tests; they are not a claim
about every possible underlying scene or system display setting.

### Inspected rendered evidence and limits

Full captures: `/tmp/paddr-glass-eeff8259/final/`. Concise contact sheet:
`/tmp/paddr-glass-eeff8259/contact-sheet.png`, also checked in under
`docs/ui/bespoke-preview/`. The comparison's baseline before images remain unchanged;
its after images are updated native composited overview captures. Live README
images were not replaced.

The existing exporter now captures only its own inert window with ScreenCaptureKit
when Screen Recording is already granted; it never requests or changes access.
`*.composited.png` includes WindowServer's native glass pass at the filter's reported
pixel scale. Plain `*.png` files remain cached AppKit/SwiftUI renders. The separate
`stroke-samples-{1,2}x-{light,dark}.png` files are explicit pixel-per-point rasters,
not evidence of a physical Retina display. The host's composited capture resolution
is recorded by the image dimensions; no upsampled image is presented as 2x proof.

Inspected light/dark states include the user's both-Zones/four-corners/zero-neutral
case (`readme-both-zones-*`), selected+hovered different and same segments,
opaque increased-contrast/reduced-transparency/reduced-motion fallbacks, both
expanded tuning panels, Save & Apply/native slider accents in context, all zone
layouts, long/raw labels, RTL selectors, disabled controls, native focused controls,
native pressed-other/pressed-selected mode captures, and 1x/2x stroke samples.
The press/RTL/disabled/stroke fixtures are cached native renders; the full workspace,
hover and opaque/tuning matrices also have composited captures. Ordinary fixtures
have system access granted; missing access appears only in explicit permission
examples. Hover is deterministically injected into the native tracking state for
comparison captures; the pointer-edge tests separately dispatch native movement.

The map-focus XCTest still skips because its command-line host refuses the required
key-window precondition. Its assertions were not weakened. Composited fixture windows
show the separate dashed map-focus cue, but that does not certify the skipped
SwiftUI arrow-dispatch test. Full manual keyboard, VoiceOver, Voice Control, Switch
Control, physical controller/output, inactive/live pointer walks and macOS 26 native
glass rendering remain unverified. Follow the six manual checks above: Tab/Shift-Tab,
menu Escape/return, mode arrows, switch Space/VO-Space, map navigation and real
controller/disconnect safety; expect one semantic stop/activation, persistent
selection and visible focus throughout. This presentation change does not replace
those checks or fresh independent review.

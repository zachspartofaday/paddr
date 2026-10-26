# Paddr bespoke controls implementation plan

Status: Operator-approved on 2026-10-26; implemented candidate awaiting fresh independent review. Frozen 1.1.0 remains a separate release, pending Apple notarization; this work does not alter it.
Date: 2026-10-26
Implementation baseline: `d0c99d8d079e24c6ecf727b9a8d4247921ba0b06` (merged PR #95, frozen v1.1.0). Original council baseline: PR #92.

## Recommendation

Adapt Quilter's rounded control geometry to Paddr's compact desktop workspace:
32-point visible control surfaces, 7-point corners, restrained outlines, consistent
insets, and a clear selected/pressed/focused state. Keep Paddr's current colors,
paired editors, footer arrangement, and content-driven window sizing. Restyle the
pad maps as part of the same control family, preserving their input geometry.

The three council lanes covered reference geometry, Paddr proportions, and native
interaction/accessibility feasibility. They exchanged findings and challenged the
initial recommendations. All support the compact 32-point direction. Their main
objection is that bespoke segments and switches require deliberate native input
and accessibility work; matching a silhouette does not establish behavior parity.

## Approved controls

| Element | Proposed shape and size | Interaction contract |
| --- | --- | --- |
| Primary and secondary buttons | 32-point base/minimum visible height, continuous rounded rectangle with radius 7, 12-point horizontal insets. Icon-only actions use a 32-point square when appropriate. | Existing native Button actions, shortcuts, roles, disabled gates, and confirmation paths. Save & Apply retains existing primary emphasis. |
| Dropdown selectors | 192-point width, 32-point base/minimum height, radius 7; leading selected value and one trailing chevron pair, 12-point side insets. Apply to profile, layout, selected area, action, touch tap, and rear bindings. | Custom closed trigger with a system menu. Preserve typed selection, selected-item checkmarks, None/raw bindings, pending-profile labels, cancellation, and focus return. |
| Off / Pointer / Scroll / Zones | Preserve 272-point overall width; 32-point base height, radius 7, 2-point shell inset and gaps. Four equal segments (65.5 points at base size), 28-point inner height and radius 5. | Exactly one selected option; distinct left/right group identity, selected/disabled semantics, and native-equivalent keyboard navigation. No independent toggle interpretation. |
| Tuning switches | Squared rounded track: 44 × 24 points, radius 7; thumb 18 × 18, radius 4; 3-point inset and 20-point travel. Keep the current 52-point horizontal reservation and a 32-point row target. Apply to acceleration, smoothing, tap stabilization, and pointer tracking. | One accessible binary control, correct On/Off and disabled states, one binding write per activation. Retain strength when disabled and existing model behavior. |
| Enable output | Keep the current native switch with its visible label, status, and save-before-enable explanation. | Preserve the already approved operational control and its model setter. It stays visually recognizable as the app-wide output control. |
| Sliders and numerical readouts | Keep current native slider interaction and the 40-point readout column. | No changes to ranges, stepping, stored values, or output behavior in this styling pass. |

These are base dimensions, not permission to clip enlarged text. Controls may grow
vertically when text requires it. Within the 272-point mode group, fit real labels
using compact insets; do not shrink/truncate text merely to copy an upstream inset.

### Visual states

Use one-point normal outlines and a clearly visible two-point Paddr focus treatment
with sufficient reserved space. This is a local proposal, not a claim that every
Quilter control uses that focus width. Selection retains the existing Paddr blue;
control surfaces remain neutral. Pressed and hovered states use restrained changes
within existing color roles, with no new accent palette or decorative motion.
Disabled, selected, focused, and On/Off states must remain distinguishable without
relying on color alone. Decorations must not intercept input.

The paired pad maps remain the defining visual feature. No new cards, illustrations,
controller silhouette, sidebar, or permanent explanatory text is proposed.

## Pad visualizations — approved extension

The operator likes the squared tuning switches and requested matching pad styling.
The operator approved this extension together with the control family on 2026-10-26.

| Element | Proposed treatment | Preserve |
| --- | --- | --- |
| Shared pad surface | Keep the 190 × 182-point footprint and aligned placement. Tighten the outer corner radius from 30 to 14 points, with one neutral 1-point outline (stronger in increased contrast). Use the existing Paddr surface colors and no added shadow or bevel. | Same footprint across Pointer, Scroll, Off, and Zones; no additional padding or window growth. |
| Zone boundaries | Quiet 1-point dividers; selected region gets the existing blue fill and a 2-point outline. Use the same outline weight as focused controls, with focus outside the map so it remains distinct from selection. | Exact contiguous region geometry. No gutters or separately rounded tiles that imply nonexistent dead areas. |
| Binding labels | Replace the current 22-point-high pill labels with 24-point-high rounded key plates, radius 5. Retain current width budgets (38 for the nine-zone map, 78 otherwise), subject to checking the longest real binding labels. | Existing action text, label centers, selection contrast, and readable grid density. No new fake button affordance or focus stops. |
| Pointer | Shared pad shell; keep the circular/elliptical tap boundary and existing hand/cursor symbol. Match border weights and neutral surface treatment to the other pads. | Tap radius reflects the actual Euclidean hit area, including zero-radius behavior. Squaring the tap region would misrepresent runtime behavior. |
| Scroll / Off | Same shell and footprint. Retain four directional chevrons for Scroll and the quiet Off treatment with the adjacent Off selection and explanation. | Distinct modes without decorative animation, extra controls, or invented live touch feedback. |

The 14-point outer radius is an approved Paddr adaptation: twice the 7-point control
radius, appropriate for the much larger pad surface. It is not a Quilter token or
a claim about physical sensor shape. The 5-point key plates echo the inner mode
segments and squared toggle thumb. The pads remain the app's defining visual element.

Implementation adds a shared pad-surface treatment used by `PadModePreview.swift`
and `ZonePadMap.swift`, plus local tokens in `PaddrStyle.swift`. Drawing, clipping,
interaction/focus shapes, and selected-outline clipping must use the same radius.
Keep `PadMapper` region math, stored configuration, arrow-key navigation, and the
accessible Selected area picker unchanged. Validate corners and neutral boundaries
with existing geometry tests and native captures of every layout, light/dark,
selected/focused/disabled states, and the longest supported binding labels.

The approved representative component set includes this pad work. Both renderers
use the shared shell. The explicit implementation authorization covers the full pad
extension as well as the controls.

## What comes from Quilter/CoreKit

Pinned Quilter reference: `29b226c0dc03938ee2d2b831c0dbff46c36f3eba`.
Pinned CoreKit reference: `18b3dc83990ae5623926f61ee18bf2f20b2e099c`.

- [Quilter metrics](https://github.com/zachspartofaday/LimitlessQuilter/blob/29b226c0dc03938ee2d2b831c0dbff46c36f3eba/Sources/LimitlessQuilterApp/DesignSystem/DesignSystemTokens.swift#L348): standard controls are 38 points high, radius 7, outline 1; a 24-point toolbar variant establishes that density varies by context.
- [Menu selector](https://github.com/zachspartofaday/LimitlessQuilter/blob/29b226c0dc03938ee2d2b831c0dbff46c36f3eba/Sources/LimitlessQuilterApp/DesignSystem/DesignSystemMenuSelectorViews.swift#L17): native Menu with a custom trigger, default width 190, horizontal padding 12. Paddr retains its approved 192-point width.
- [Segmented controls](https://github.com/zachspartofaday/LimitlessQuilter/blob/29b226c0dc03938ee2d2b831c0dbff46c36f3eba/Sources/LimitlessQuilterApp/DesignSystem/DesignSystemPanelControlStylesSegmented.swift#L85): 2-point inset/gaps and a smaller-radius selected segment. Paddr adapts the 38-point shell to 32.
- [Checkbox toggle](https://github.com/zachspartofaday/LimitlessQuilter/blob/29b226c0dc03938ee2d2b831c0dbff46c36f3eba/Sources/LimitlessQuilterApp/DesignSystem/DesignSystemPanelControls.swift#L665): 17-point rounded checkbox, radius 4. The proposed Paddr track/thumb switch is a NEW design informed by those shapes, not a Quilter switch copied from source.
- [CoreKit registry](https://github.com/zachspartofaday/LimitlessQuilterCoreKit/blob/18b3dc83990ae5623926f61ee18bf2f20b2e099c/docs/UI_TOKEN_REGISTRY.md#L6): internal token data; the documented Quilter pin does not consume it. It is not a ready-made native UI package to import into Paddr.

Tracked caller references establish Quilter use of the menu selector in
`AppShell/SettingsAppearanceSection.swift:22`, segmented controls in
`PatternStudio/Core/PatternStudioMotifAlongSpinePanelPlacementControls.swift:79`,
and button styling in `Shared/Controls/PreviewDetailsPanelViews.swift:39` at the
same pinned revision. Source inspection establishes implementation geometry and
references, not visual/runtime accessibility parity.

No CoreKit dependency or changes to the Quilter/CoreKit repositories are proposed.
Implement small Paddr-owned styles/adapters. If implementation copies source rather
than adapting the design, verify its license and add the appropriate provenance;
existing BottleRocket notices are not blanket coverage for another repository.

## Alternatives considered

1. **Recommended: compact 32-point Paddr controls and squared tuning switches.**
   The strongest balance of family resemblance, continuity, and desktop density.
2. **Closer Quilter proportions: 38-point controls and checkbox-style tuning.**
   More faithful to the source, but increases vertical space and changes the binary
   control metaphor. This is a deliberate alternative, not the recommended default.
3. **Native-widget-only styling.** Lower interaction risk, but public AppKit styles
   cannot guarantee the proposed segment/switch silhouettes. It would only partially
   satisfy the request for bespoke controls.

The council revised an initial recommendation to keep all switches native: that
would not fully answer the requested tuning-toggle change. The recommended proposal
therefore includes bespoke tuning switches while keeping Enable output native.

## Implementation sequence

1. **Lock geometry and record native interaction baselines.** Add named local control
   roles separate from generic layout row metrics. Capture existing mode-group arrow
   behavior and menu/switch keyboard/focus/VoiceOver behavior before replacement.
   Primary files: `PaddrStyle.swift`, control-specific adapters.
2. **Build one representative set together.** Implement one styled Button, a custom
   192-point system-menu trigger, the four-choice mode adapter, and a squared tuning
   switch. Use existing inert fixtures. Check geometry and input semantics before
   migrating every call site. Revise any component that fails those checks; do not
   silently ship a visual compromise or weaken the acceptance tests.
3. **Apply the approved components consistently.** Update `ProfileControlsView`,
   `TopControlsView`, `KeyPicker`, `TapActionPicker`, `ButtonZoneConfigurationView`,
   the `PadModePicker` seam, and `ToggleValueSliderRow`. Preserve bindings, identifiers,
   profile guards, persistence, menu items, and action gates. No mapper/schema changes.
   Keep output's native switch, sliders, and the auto-sizing bridge intact.
4. **Validate the full workspace and commit for parent review.** Refresh native evidence
   and focused interaction tests, then run repository-required tests, localization,
   release/CLI checks, and independent review. Include before/after captures and exact
   manual coverage. Do not treat passing source-only tests as keyboard/VoiceOver proof.

### Acceptance checks

- Real visible controls share the geometry; it must not be just empty outer frames.
- Light/dark, active/inactive, hover/pressed/focused/disabled; increased contrast,
  reduced transparency and reduced motion remain usable.
- Profile pending/dirty/default states, long names, raw bindings, and every mode/zone
  layout preserve values and reachable actions.
- Mode group retains single selection and left/right identity. Menus preserve
  checkmarks, keyboard navigation, Escape, and focus return.
- Tuning switches expose a useful binary role/value and activate once by pointer,
  keyboard, VoiceOver, and supported alternate input. A generic Button saying On/Off
  is not sufficient evidence of toggle semantics.
- Keyboard focus stays visible and stable across mode changes, disclosures, sheets,
  and reflow. Do not clip focus rings or add decorative tab stops.
- Both tuning panels, expanded/collapsed modes, 680/940/default-width fixtures, and
  short/narrow screens preserve automatic growth/shrink and screen-limited scrolling.
- Update class-specific NSControl assertions if controls change implementation so
  tests cannot pass merely because the new controls disappeared from enumeration.

## Sequence and approval boundary

The council originally inspected PR #92 (`c211657d3dcff3e38e7835508993ce0cef966172`).
Implementation uses merged PR #95, `d0c99d8d079e24c6ecf727b9a8d4247921ba0b06`,
including the current palette, footer and content-driven sizing. The existing README
images remain the live documentation images until this UI is accepted. Frozen 1.1.0
will be released separately once Apple notarization works. No release, publication,
merge, push or PR creation is authorized by this implementation assignment.

## Implementation authorization update

The operator explicitly requested Sol subagents to implement this proposal, including the pad extension. Earlier proposed/pending-approval wording records the council history and no longer blocks this implementation. Preserve the current palette (including any changes since the council baseline); color examples in the original proposal are not authority to revert the current palette. Preserve v1.1.0 and its exact signed package. A fresh independent Sol review follows implementation.


## Implemented candidate

Paddr-owned SwiftUI button styling and small AppKit adapters implement the complete
family. Native pop-up/pull-down menus retain their system tracking and menu items;
NSSegmentedControl retains select-one radio-group semantics, with explicit arrow
navigation; an NSButton switch cell retains binary state and dispatch while exposing
one AXCheckBox/AXSwitch binary element with integer value and localized On/Off description. Enable output
remains NSSwitch and sliders remain native SwiftUI sliders. No upstream implementation
was copied and no package dependency was added.

`PaddrPadShape` and `PaddrPadSurface` share the 14-point shell across drawing,
clipping, hit/focus shapes and selected-outline geometry. Regions stay contiguous.
Binding plates retain their width budgets and centers; long raw codes wrap and can
grow taller than the 24-point base. Pointer tap areas remain Euclidean ellipses.

The implementation baseline and test/render results, exact commands, artifact paths,
manual follow-up and known limits are in
[PADDR_BESPOKE_CONTROLS_VALIDATION.md](PADDR_BESPOKE_CONTROLS_VALIDATION.md).
This author-owned verification is not independent acceptance.

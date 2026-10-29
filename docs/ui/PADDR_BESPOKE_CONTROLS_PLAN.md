# Paddr bespoke controls implementation plan

Current operator refinement, 2026-10-29: **Enable output** now uses the same
squared native NSButton switch adapter as tuning controls, retaining its visible
label, one binary accessibility target, model setter, disabled gate and
save-before-enable explanation. This supersedes the earlier NSSwitch exception
in the historical sections below. Redundant absent-controller advice is omitted
from the footer; actionable permission, error and transition guidance remains.


Status: Operator-approved on 2026-10-26; implemented candidate awaiting fresh independent review. Published 1.1.0 remains a separate immutable release; this work does not alter it.
Date: 2026-10-26
Implementation baseline: `d0c99d8d079e24c6ecf727b9a8d4247921ba0b06` (merged PR #95, frozen v1.1.0). Original council baseline: PR #92.

## Current operator refinement — flat accents, compact gutter and one rear row

Source baseline: `c3ec20aa977547a6b8d4b16f91ca0ca3de25ff8a`, 2026-10-26.
This direction supersedes selected/primary glass, surplus map-column width and
the earlier rear two-row/inspector-alignment proposal. The operator's latest
request is **one default rear row**, ordered **L4, L5, R4, R5**. Earlier sections
below record history; this section owns the current presentation contract.

Keep system type and the existing palette: light blue `#2859CF`, dark Compass
teal `#78C7BD`, dark canvas `#20262D`, workspace `#2B333C`, pale edge `#F0F4F8`
and foreground-on-teal `#1C2630`. Selected mode segments and Save & Apply are
**flat opaque accents**, with a fine white/pale stroke. Keep the selected mode's
4-point track inset, 2-point gaps, 3-point inner radius, local hover/press feedback,
separate focus and native radio semantics. Disabled primary actions remain flat
and subdued; their role does not become secondary when disabled. Centralize the
accent fill/stroke/foreground rules in `PaddrAppearance`. Secondary/menu/track
surfaces retain native glass and their opaque accessibility fallbacks.

The map stays **190 × 182** and the main mode/menu/readout family stays **240**.
`PaddrPadColumns` keeps a **190-point preview column** and **16-point gutter**;
only the existing 438–446-point constrained interval yields the gutter to 8–16.
Larger supplied fixtures leave surplus beyond the inspector. Both edges of modes,
menus and numerical rows stay aligned. The preferred usable window width is
computed from **2 × (190 + 16 + 240) + 24 + 2 × (24 + 16) = 996 points**.
Content-controlled height, screen cap, scrolling, non-resizable windows and mounted
identities remain unchanged. No sensor map expands to consume spare space.

Rear selectors share a separate **180-point** width. Four ordinary short-code
pairs plus 16-point inter-pair gaps fit comfortably inside the 916-point workspace;
192-point selectors would leave almost no spare width after measured labels and gaps. Use the existing
wrapping layout and preserve each complete label/menu pair, in logical order:

```text
Left trackpad           Right trackpad
190 map | 240 controls   190 map | 240 controls
        16 gutter               16 gutter
Rear buttons
L4 [180 menu]  L5 [180 menu]  R4 [180 menu]  R5 [180 menu]
```

Wrap whole rear pairs when width or enlarged text requires it; retain readable
native menu values, independent bindings, distinct AX names and focus identity.
SwiftUI mirrors the logical order once in RTL. The heading stays directly above
the row. Do not widen the window or pad gutter to fit four 240-point menus.

Critique: the flat accent gives selection/action clear emphasis without the rejected
shine; secondary material preserves the established control hierarchy. A compact
window and bounded gutter resolve the excess space at its source. The single rear
row is quieter and follows the operator's newest direction. Validate all four rear
selectors on one default row, containment and wrapping at narrow/accessibility sizes,
RTL, identity/focus and independent writes. Capture both appearances, Zones/tuning,
flat/disabled/focused states and native secondary material. Prior clean reviews do
not accept this candidate; fresh independent review remains required.

## Earlier operator refinement — shared edges, clean pads and inset glass

Source: `6b0551fe246a5be3ec12658e5a30e341653669fd`, 2026-10-26. This
refinement supersedes the 192-point menus, 272-point mode row, 2-point mode inset,
continuous pad path, 1.5-point normal pad rim and inverted-alpha pad shadow below.
The earlier sections remain historical rationale, not current numeric contracts.

Keep system type, light blue `#2859CF`, dark Compass teal `#78C7BD`, the neutral
canvas/workspace palette and 190 × 182 sensor maps. Use **240 points** for the mode
row, all selector variants and the complete slider/readout column. The native
slider and 40-point trailing numerical column consume that shared width; expanded
pointer tuning uses the same edges. Profile and rear selectors share the family.
Rear bindings wrap as complete label/selector pairs: two ~264-point rows plus a
16-point gap cannot fit a normal 488-point editor column. Do not compress menus
or clip their labels to retain the former single rear row.

```text
Title         | Off Pointer Scroll Zones | 240 points
190-point map | Label                    |
              | selector                 |
              | native slider      value |
```

`PaddrPadColumns` consumes the same width budget as the lower split. Surplus width
belongs to the map column. The inline minimum is **438 = 190 + 240 + 8** points;
the gutter grows to 16 by 446 points. Below 438 points, or at accessibility text
sizes, the same header and settings controls stack with a common leading edge.
Two full editors require **900 = 2 × 438 + 24** points of workspace, corresponding
to a 980-point configuration window with its current 40-point chrome insets. A
940-point window now stacks complete editors rather than squeezing the controls.
RTL mirrors the column placement once and mirrors native mode segments to match
the selected material; horizontal arrow navigation follows physical direction.

The selected segment has a **4-point track inset**, a separate **2-point gap**,
**56.5 × 24** base geometry and **3-point concentric corners** inside the 7-point
track. Drawn, hovered and mouse-activated segments use one shape; track borders,
gaps and rounded cutouts do not select. Release outside cancels. Retain native
select-one state, target/action, radio-group accessibility, keyboard focus and
menus. Enlarged native text grows vertically without truncation.

Selection uses an accent base under actual tinted native clear Liquid Glass,
with native text/hover/press drawing above it. Its material is never covered by
a second opaque selected fill. The outer track remains regular native glass.
Increased Contrast and Reduce Transparency retain filled opaque selection;
Reduce Motion retains the same selected silhouette without interactive glass
motion. No fake gradient or extra border is added.

Use an explicit **circular 14-point pad path**, matching the existing CGPath zone
outline. The previous continuous path produced a visible stroke spike where its
curve met the top straight edge. Clip the opaque content once. A **1-point**
normal rim (2 points in Increased Contrast) follows the same path. The shallow
18%/3-point/2-point-offset recess is cast from an explicit extended exterior,
rather than inverted alpha at the Canvas boundary. The 4-point-outset dashed
focus path grows its radius to 18 and remains distinct from zone selection.

Critique: stretching all controls to 272 would add width without improving the
four mode labels; 240 retains their readable native text and shares the change
between modes and menus. A heavier rim would conceal the reported seam without
fixing it. Explicit circular arcs and a real shadow exterior remove its causes.
Validate same-mounted edges and numerical columns across modes, both pad sides,
RTL, breakpoint widths and accessibility sizes; inspect native composited glass,
selected/hovered/disabled states and 1x/2x pad tangencies. This candidate requires
fresh independent review; earlier clean reviews cover only their original heads.

## Earlier operator refinement — alignment, rims and depth

Source: `ef6e53fcdb926297f4cee4d7a24b88a54b7d0f5f`, 2026-10-26. The new crops
identify the lower form column starting before the mode control, irregular control
rims, and a focus corner that does not follow the pad. The operator now explicitly
requests layered depth. This section supersedes older no-shadow/no-depth guidance
below; the teal/glass, geometry and interaction decisions remain.

Keep the six core palette roles: light blue `#2859CF`, dark Compass teal `#78C7BD`,
dark selected fill `#254C48`, dark neutral canvas `#20262D`, workspace `#2B333C`,
and foreground-on-teal `#1C2630`. Keep system type, fixed 192-point menus,
272-point mode control and 190 × 182 maps. Use semantic leading alignment:

```text
Title         | Off Pointer Scroll Zones
190-point map | Label
              | 192-point selector / native slider
```

The shared column rule gives surplus width to the map's *column*, never its sensor
shape: preview column = max(190, editor width − 272 − gutter). The gutter is
normally 16; it yields down to the existing 8-point spacing step only when that
keeps the complete map/control pair inline (470–478-point editor widths). Both
header and every mode's lower split consume it. At constrained widths the existing 414-point lower
split breakpoint stays; the header stacks when its complete 272-point control no
longer fits that column. Accessibility sizes stack both. Logical coordinates mirror
once through SwiftUI for RTL. This preserves mounted controls and compactness.

Use one concentric geometry for control rims and focus, with native glass inset
under a solid 2-point structural rim. This keeps its native material/light/depth
without a competing fractional edge. Primary actions put the approved accent
beneath native clear glass tinted with that same accent, retaining real material
above the color and readable text; secondary surfaces use regular glass. Opaque
fallbacks use the same silhouette;
Increased Contrast strengthens color rather than adding a second border. Grow the
pad focus path outward 4 points *and* grow its radius from 14 to 18, retaining its
corner centers and a distinct rounded-dash cue outside selected regions.

Depth has three roles: the existing neutral window, a workspace lifted by a quiet
6-point/2-point-offset 10% black shadow, and stable opaque pads with a shallow
3-point/2-point-offset 18% inner shadow. Native control glass supplies control depth.
No extra cards, glow, fake gradients, animation or map refraction. Reduce
Transparency and Increased Contrast omit decorative shadows; opaque surfaces,
selection, focus and enabled content remain. Reduce Motion still disables
interactive material motion.

Critique: a Zones-only 10-point inset would drift at other widths; the shared
column budget answers the actual layout cause. Expanding a focus rectangle alone
cannot produce concentric corners. Native edges alone were rendered as an option
but were too faint for the brief, so the final rim remains explicit and readable.
Depth stays on surface boundaries, rather than decorating every row or changing
sensor geometry. Validate actual native/composited light/dark, focused corners,
primary/secondary/Open setup, pointer tuning, fallbacks, RTL and 1x/2x rasters.

## Earlier operator refinement — teal and glass

This update supersedes the earlier flat/no-material and outline-only selection
recommendations below. The source candidate is `095fede96d07b4e22cbb0126661efed15ba52d59`.
The supplied dark screenshot shows a weak outline-only Zones selection, whole-row
hover that competes with selection, mixed dark accents, and fragile thin rims.

Keep the compact geometry, system typography, paired editors and neutral surfaces.
Light retains action `#2859CF`, canvas `#F3F5F7`, workspace `#FFFFFF` and white
prominent text. Dark uses the Compass North teal `#78C7BD` for action/selection/focus,
`#254C48` for selected pad fill, `#1C2630` for text on teal, and the existing neutral
canvas `#20262D` / workspace `#2B333C`. The source logo also uses South `#56AFA7`;
North provides the stronger readable dark action role. Warning/error/success roles
remain separate. Native output/slider controls keep their interaction behavior.

- Persistent filled mode selection, with secondary hover/press on the individual
  segment. Selection and keyboard focus remain separate cues.
- Actual native Liquid Glass beneath button, selector, mode and switch content.
  Use the SDK's macOS 26 SwiftUI `glassEffect`/`Glass.interactive` composition;
  keep native AppKit controls in front as the input and accessibility owners.
  Reduce Transparency and Increased Contrast use opaque surfaces; Reduce Motion
  suppresses interactive material motion without disabling controls.
- Stronger inset antialiased outlines, with no fractional .75-point pad-shell
  padding or bright hairline around selected key plates. Pads retain stable opaque
  content and exact sensor/zone geometry; no optical distortion or invented gaps.

Critique against the screenshot: filling the mode makes the current setting legible
before hover; local neutral feedback answers the pointer without changing the shell.
The logo teal resolves the operator's revised dark-mode preference while preserving
the light palette they liked. Glass is restrained to control surfaces, retaining the
recognizable paired maps and density rather than adding decorative panels/gradients.
Validate the actual native renders, contrast pairs, input/AX owners, fallbacks, RTL,
and 1x/2x outlines before claiming completion. Prior reviews predate this refinement.

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
| Dropdown selectors | Shared 240-point width, 32-point base/minimum height, radius 7; leading selected value and one trailing chevron pair, 12-point side insets. Apply to profile, layout, selected area, action, touch tap, and rear bindings. | Custom closed trigger with a system menu. Preserve typed selection, selected-item checkmarks, None/raw bindings, pending-profile labels, cancellation, and focus return. |
| Off / Pointer / Scroll / Zones | Shared 240-point overall width; 32-point base height, radius 7, 4-point shell inset and separate 2-point gaps. Four equal segments (56.5 points at base size), 24-point inner height and radius 3. | Exactly one selected option; distinct left/right group identity, selected/disabled semantics, and native-equivalent keyboard navigation. No independent toggle interpretation. |
| Tuning switches | Squared rounded track: 44 × 24 points, radius 7; thumb 18 × 18, radius 4; 3-point inset and 20-point travel. Keep the current 52-point horizontal reservation and a 32-point row target. Apply to acceleration, smoothing, tap stabilization, and pointer tracking. | One accessible binary control, correct On/Off and disabled states, one binding write per activation. Retain strength when disabled and existing model behavior. |
| Enable output | Keep the current native switch with its visible label, status, and save-before-enable explanation. | Preserve the already approved operational control and its model setter. It stays visually recognizable as the app-wide output control. |
| Sliders and numerical readouts | Keep current native slider interaction and the 40-point readout column. | No changes to ranges, stepping, stored values, or output behavior in this styling pass. |

These are base dimensions, not permission to clip enlarged text. Controls may grow
vertically when text requires it. Within the 240-point mode group, fit real labels
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
- [Menu selector](https://github.com/zachspartofaday/LimitlessQuilter/blob/29b226c0dc03938ee2d2b831c0dbff46c36f3eba/Sources/LimitlessQuilterApp/DesignSystem/DesignSystemMenuSelectorViews.swift#L17): native Menu with a custom trigger, default width 190, horizontal padding 12. Paddr originally used 192 points; the current shared-edge refinement uses 240 points.
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
   240-point system-menu trigger, the four-choice mode adapter, and a squared tuning
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

## Rear-row alignment refinement

The current direction keeps one default L4/L5/R4/R5 row with equal 180-point menus.
L5 shares the left pad inspector/menu/readout trailing edge; R5 shares the right edge.
One constant stride, derived from those shared pad-column edges, distributes all four
menus equally, including the middle interval. Labels remain attached to their menus.
The main 240-point controls, 190 × 182 maps, 16-point gutter and 996-point preferred
window stay unchanged.

The pad inspectors remain bounded inside wider columns. When their actual geometry
cannot accommodate four pairs with the two anchors and one stride, the same mounted
pairs wrap into at most two per row, then one as necessary. Stacked pad editors and
accessibility text use that fallback too. Placement uses logical coordinates for RTL;
there are no parallel copies of native menus or binding changes.

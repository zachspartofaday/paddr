# Paddr interface redesign

Approved design and implementation record, 2026-10-26.

Evidence baseline: `t3/28a1bb2c` at `1e6b049fa57bc2acb1f7bedfbe1ffe2b5028890b`.
The operator confirmed Paddr as the subject, simultaneous editing of both pads,
and an independent native light/dark identity, then approved implementation.
The native SwiftUI/AppKit application now implements this direction. The HTML
concept remains a historical planning artifact; native captures and validation
are described in [the implementation verification record](PADDR_REDESIGN_VALIDATION.md).

## Product brief

Paddr helps a Steam Controller 2 owner turn two trackpads and four rear buttons
into useful mouse and keyboard controls on macOS. Its everyday job is to make a
mapping understandable, adjust it, and deliberately put it into use. Profiles,
permissions, device connection, and output status support that job.

Design the window as a mapping workspace. The paired pad maps are its identifying
feature and its useful content. Use quiet Mac controls around them. The same
left/right relationship should hold for maps, forms, and rear buttons.

Operator refinement: the HTML concept demonstrates layout and interaction, not
final control styling. Implement the app with native SwiftUI/AppKit pickers,
segmented controls, sliders, switches, menus, sheets, and focus behavior. Custom
drawing belongs primarily to the pad maps. Do not reproduce browser-control
appearance in the native app. Use a persistent native switch labeled **Enable
output**, replacing the concept's earlier Mapped output label and alternate
Save & enable output button.

## Council decision

Three read-only council lanes examined workflow, visual identity, and implementation
feasibility at the same source revision. The workflow lane initially preferred
two overview maps with one selected-pad inspector. After a direct cross-critique,
the council recommended compact simultaneous editors: progressive disclosure
removes most pointer-setting density without adding selection navigation.

| Candidate | Benefit | Cost | Decision |
| --- | --- | --- | --- |
| Compact simultaneous editors | Compare and change both pads directly; retain independent editor state | Tall complex forms require scrolling in small windows | Selected by operator |
| Both maps with one detail inspector | More room for deep editing in small windows | Adds target selection and hides the other pad's controls | Not selected |

The council also rejected a full controller illustration as the organizing
surface: Paddr does not remap the whole controller, and the illustration would
take room from the controls it actually owns. A permanently visible profile
sidebar would likewise consume space without making the main mapping task easier.

## Evidence and scope

Current screenshots were captured on 2026-09-07; they are historical rendered
evidence, not captures of this planning session. Source and existing tests were
read at the baseline above. No current runtime, hardware, keyboard, or VoiceOver
verification was performed for this proposal.

| Observation | Evidence | Proposed response |
| --- | --- | --- |
| Save state and Save & Apply are inside scrolling content | `ConfigurationContentView.swift:10`, `TopControlsView.swift:42` | Put profile and commit controls in persistent chrome |
| The output switch has no visible label | `ApplyBarView.swift:128` | Keep Enable output visibly beside a native switch |
| Pointer mode exposes seven settings; Scroll exposes two | `PadConfigurationView.swift:113` | Keep sensitivity and touch tap visible; group the other five under Pointer tuning |
| Repeated card/section enclosures and stretched short forms compete with maps | `PadConfigurationView.swift:89`, `PaddrSettingsPrimitives.swift:10`, overview screenshot | One workspace surface, spacing within groups, natural content height |
| Default's Duplicate to Edit opens a menu | `ProfileControlsView.swift:35` | Make the primary duplication path a direct action |
| Appearance is forced dark in multiple layers | `ConfigurationView.swift:28`, `OnboardingGuideView.swift:39`, `AppDelegate.swift:781,877` | Follow macOS appearance throughout |
| Actual default geometry differs from the historical parity manifest | `PaddrStyle.swift:78` vs parity manifest | Reconcile documentation; validate a smaller fresh-window default |

These observations motivate a redesign. Documented aesthetic choices are not
being classified as software defects.

| Review domain | Coverage |
| --- | --- |
| Accessibility | Dedicated owner audit not performed; required during implementation |
| Focus | Dedicated owner audit not performed; required during implementation |
| Layout | Source and historical overview/zone screenshots |
| Writing | Profile, permissions, output, and draft-state source review |
| Typography and color | Shared style/appearance source and historical captures |
| Motion | Source policy only; runtime not verified |

## Composition

```text
Paddr
Profile [World of Warcraft v] [Profile actions]
Unsaved changes                                  [Save & Apply]
--------------------------------------------------------------
Left trackpad                      Right trackpad
[Off Pointer Scroll Zones]         [Off Pointer Scroll Zones]

        [pad map]                          [pad map]
  common mode controls               common mode controls
  touch-tap action                   touch-tap action
  > Pointer tuning                   > Pointer tuning
    summary of customized settings     summary of customized settings

Rear buttons
L4 [action]  L5 [action]             R4 [action]  R5 [action]
--------------------------------------------------------------
Controller connected     Battery 82%       Enable output [on]
Output active                              [Connection details]
```

Only the middle workspace scrolls. The profile/commit region and output/readiness
region remain available. The ASCII battery value and profile are illustrative.

- Align headings, labels, and form controls to leading edges; center each pad map
  in its allocated diagram area. Preserve left/right physical orientation.
- Use one structural separation between the pad workspaces, not nested card
  borders. At compact widths, stack the same mounted subtrees when their measured
  content requires it. Never substitute a new editor solely because width changed.
- At comfortable widths, place a map beside its common controls; at intermediate
  widths, place it above them. Do not stretch a short form to match the other form.
- Compact inspectors use labels above their controls and a 16-point map-to-control
  gutter. Header, workspace contents, and footer share the same leading/trailing
  alignment edges. Rear bindings use compact L4/L5 and R4/R5 pairs.
- Keep four mode choices in a native segmented control. Off keeps the pad's place
  in the layout and explains that the pad emits no mapped action.
- Pointer: sensitivity and touch tap remain visible. Pointer tuning contains
  acceleration, smoothing, tap stabilization, center tap radius, and pointer
  tracking within the radius. Preserve their existing ranges and relationships.
- Scroll: sensitivity and touch tap remain visible, with no empty tuning section.
- Zones: layout, selected area, action, and applicable neutral-zone control remain
  beside the map. Retain the native Selected area picker as a keyboard/VoiceOver
  alternative. Preserve all five layouts and runtime hit-test geometry.
- Show a concise, value-derived summary under collapsed tuning, such as
  “Smoothing 35%, tap stabilization 6 pt.” Show only enabled/relevant values;
  define the exact summary from existing configuration, not from a new preset.
- Keep rear controls in a single group, aligned L4/L5 under the left side and
  R4/R5 under the right. Do not hide them in an unrelated settings screen.
- The operator's latest decision makes the configuration window content-driven:
  prefer 1080 points wide, measure actual content height, cap to the current screen,
  and disable manual resizing. Scrolling is a screen-limit fallback. Preserve the
  top edge during expansion/collapse when it fits and retain saved position only.

## Design system

Six semantic roles with adaptive values form the proposed base palette. Status
uses system semantic colors rather than additional decorative brand colors.

| Token | Light | Dark | Role |
| --- | --- | --- | --- |
| Canvas | `#F3F5F7` | `#20262D` | Quiet surrounding chrome |
| Surface | `#FFFFFF` | `#2B333C` | Mapping workspace and native surface fallback |
| Primary text | `#1C2630` | `#F0F4F8` | Labels, bindings, essential state |
| Secondary text | `#52616E` | `#BAC6D2` | Explanations and tuning summaries |
| Boundary | `#CBD3DB` | `#536372` | Structural separation; not the sole focus/selection cue |
| Action/selection | `#2859CF` | `#8BB0FF` | Primary action and selected zone |

Use light text on the light-theme action fill and dark text on the dark-theme
action fill. Measure actual composited contrast before finalizing tokens; the
subtle boundary token is not sufficient for an interactive boundary by itself.
Selections include a distinct outline and label/state, never color alone.

Retain SF Pro through native system text styles deliberately: the dense Mac
editing task benefits from familiar control metrics and accessible scaling.
Use title/title2 for guide or pad headings, body for labels and values, callout
for secondary help. Indicative regular sizes are 22/17/13/12 points; semantic
styles, rather than hard-coded sizes, own scaling. Use semibold headings and
regular control text. Use monospaced digits only for changing numerical values.

Keep the useful 4/8/12/16/24-point spacing ladder. Use 24-point outer spacing,
16-point group gaps, 12-point row rhythm, 8-point inline gaps, and 4-point icon
gaps where the content fits. Native controls own their corner geometry; maps
retain their physical rounded-pad geometry. No blanket radius or shadow on every
group. Remove generic icons beside ordinary slider labels. SF Symbols should
identify an action, physical input, or state rather than decorate a row.

Follow system light/dark appearance in the editor, guide, setup sheets, and menus.
Do not add a theme preference unless the system-following behavior proves
insufficient. Motion responds to selection/disclosure and leaves a static state
cue; respect Reduce Motion, Reduce Transparency, and Increased Contrast.

### Self-critique before prototyping

A neutral Mac palette and blue controls alone could describe any settings app.
The first generic “cards for everything” composition was therefore rejected.
The proposal spends its visual identity on real paired pad geometry, visible zone
bindings, and rear-button alignment. This is useful physical correspondence,
already present in Paddr's app icon, rather than a decorative gaming theme.
The plan also replaces a dashboard-like row of equally emphasized subsystem pills
with one readable output region and inspectable connection details. Permission
problems remain visible when actionable.

## State and action contract

The UI must distinguish the selected profile, its editable draft, the saved
configuration, output intent, and actual output readiness. An enabled switch
does not prove that input is being emitted.

| State | Visible treatment and action |
| --- | --- |
| Default selected | Read-only mapping with direct Duplicate to Edit; output remains usable |
| Clean editable profile | Saved; primary commit action disabled as current model permits |
| Dirty, output enabled | Unsaved changes; Save & Apply commits and updates the mapping; turning output off remains available |
| Dirty, output off | Keep the Enable output switch; show “Turning on saves your pending changes.” beside it. Save & Apply still saves without enabling |
| Clean, output off | Enable output switch; turning on uses the current activation path |
| Enabled but waiting | Labeled output intent plus specific reason: access, controller, neutral input, or release completion |
| Releasing held output | Show current reason/progress and preserve model availability gates |
| Save failure | Keep the draft, display the failure and actionable recovery; never show Saved prematurely |
| Profile switch/delete/quit with edits | Preserve existing confirmation and persistence behavior |
| Controller missing with output off | Still report device observation; allow offline editing |

Enabling output with a dirty draft already persists it before activation:
`PaddrMenuModel.swift:1014,1199`, `MenuModelTests.swift:1346,1363`. Changing that
behavior is outside this redesign. Existing canEdit/canSave/canToggleOutput
decisions remain authoritative; do not invent a readiness gate that prevents
enabling while waiting. Pad-mode changes retain stored tuning. Maps show the
draft's configured geometry, not live touches or proof of active output.

The switch retains its Enable output label in both positions and never becomes a
button when edits are pending. Separate Active, Waiting, and Off status text
explains actual readiness; a switched-on control can still be waiting. The
pending-save hint is visible and included in the control's accessible description.
Use SwiftUI's native switch styling rather than a custom toggle drawing.

Keep menu-bar output wording consistent with the window and disclose the same
pending-save effect where enabling is available. Existing dirty-profile menu
switching restrictions remain in force.

## Setup and secondary surfaces

Replace the permanent pair of permission tiles in the editing header with a
conditional actionable footer notice naming the missing permissions. Open setup
reveals shared permission content with both Request and Open Settings actions
for each grant. The strip stays until both grants resolve, and missing access
does not prevent offline configuration. This adds one deliberate navigation step
to setup; it is a workflow change, not merely a visual substitution.

Reuse that permission content in the guide. Keep the existing guide launch
behavior for the first implementation; reconsider whether two first-launch
windows are necessary after the main workspace is evaluated. Use the same
typography, surfaces, and action wording in guide pages, profile sheets, errors,
and confirmations. Preserve the menu-bar lifecycle and Dock behavior.

## Implementation sequence

Keep one coherent UI owner across these dependent slices. Parallel research or
test work may have independent ownership; do not have multiple implementers
rewrite the shared shell simultaneously.

| Slice | Primary files | Completion evidence |
| --- | --- | --- |
| 1. Adaptive foundations | `PaddrStyle`, `PaddrAppearance`, `PanelBackgroundView`, `PaddrSettingsPrimitives`; dark locks in editor/guide/AppDelegate | Light/dark semantic tokens, native typography and controls, measured contrast; no hard dark-only surface |
| 2. Persistent shell and truthful state | `ConfigurationView`, `ConfigurationContentView`, `TopControlsView`, `ProfileControlsView`, `ApplyBarView`, `StatusCell`, relevant menu presentation | Save/output remain reachable while scrolling; clean/dirty/default/waiting/error states and dirty-enable action are accurate |
| 3. Mapping workspace | `DualPadConfigurationView`, `PadConfigurationView`, `ButtonZoneConfigurationView`, `RearButtonConfigurationView`, shared adaptive layouts | Common controls visible; tuning disclosed with summary; L/R independent; zone selection and focus survive resizing |
| 4. Consistent setup and copy | `PermissionTile`, `OnboardingGuideView`, profile sheets, `Resources/Localizable.xcstrings` | Shared permission content, both grant recovery paths, direct Default duplication, localized consistent wording |
| 5. Acceptance and documentation | App-support presentation/layout/contrast tests, README/screenshots, parity manifest | Native evidence for required states/sizes; preserved behavior tests; canonical checks pass; documentation matches final geometry |

Keep the configuration schema, profile storage, parser, output ledger, controller
I/O, and mapping engine unchanged. Changes to UI-only state/presentation helpers
are expected. The independent light/dark identity intentionally replaces selected
family-palette/surface requirements when implemented; update the historical
parity manifest explicitly and retain all MIT attribution. Continue the mounted
dual-editor and accessibility contracts. Do not remove an assertion merely to
make the new UI pass; replace it with a check of the chosen user-visible contract.

## Validation and acceptance

Use existing inert presentation fixtures and `PADDR_UI_EVIDENCE_DIR` export in
`FamilyConsoleLayoutEvidenceTests`; no live controller or production profile
mutation is needed for visual evidence.

- Inspect compact 680 × 600, candidate default 1080 × 640, current large default,
  and wider windows. Also inspect long profile names, 40% longer copy, all zone
  layouts on either/both pads, Off/Scroll/Pointer combinations, and expanded tuning.
- Capture light/dark, increased contrast, reduced transparency, right-to-left,
  standard/intermediate/accessibility text sizes. Keep actions reachable through
  scrolling and preserve full labels/values through accessible alternatives.
- Cover Default, clean/dirty drafts, output off/on/waiting/releasing, permissions
  missing/granted, disconnected controller, unknown/low battery, save failure,
  profile switching/deleting, and unsaved quit.
- Walk the editor, setup, profile actions, and zone selection with keyboard and
  VoiceOver using the dedicated accessibility/focus skills. Check focus visibility,
  reading order, disclosure state, and focus restoration after sheets and reflow.
- Revise old geometry/palette/surface assertions in `FamilyConsolePresentationTests`
  and `FamilyConsoleContrastTests`; retain contrast requirements. Replace equal-height
  expectations with readable natural-height composition while preserving mounted
  editor and selection assertions in the layout/presentation suites.
- Preserve model tests for dirty-enable save, failed-save draft retention, deferred
  rear edits and restore, dirty profile guards, observation while off, release
  before idle, and blocked reactivation while held output is still releasing.
- Run the canonical checks from CONTRIBUTING: warnings-as-errors Swift tests,
  localization, release arm64 app and CLI builds, CLI checks, release identity,
  and release production checks using the required Xcode toolchain.
- Verify relevant physical-controller actions before release; static fixtures
  cannot establish input latency, actual output, or hardware reconnection behavior.

The interactive HTML concept accompanies this document to inspect hierarchy and
sample states. It uses example data and the host's adaptive presentation tokens;
it is not native runtime evidence or the final token implementation.
The operator's later native-control and Enable output switch refinement above
supersedes the output-control treatment in that initial concept.

### Proposal verification record

- A fresh independent reviewer found no blocker in this implementation plan and
  identified two concept defects: cross-pad sample-value resets and unguarded
  profile switching with shared Default data. Both were corrected locally.
- Browser-executed concept checks passed for retained other-pad values and
  disclosure, guarded profile switching and cancellation, independent Default
  data, editable duplication, saved-profile restoration, dirty-enable saving,
  both permission grants, enabled-but-waiting output, and zone binding selection.
- JavaScript syntax validation passed. Concept captures were inspected in light
  and dark at 728 pixels and at a compact 360-pixel conversation width. This
  compact preview is not a claim of a mobile app or a new native minimum size.
- Calculated nominal palette contrast: secondary text is 5.83:1 on light canvas
  and 7.37:1 on dark surface; action text is 6.14:1 in light and 7.12:1 in dark.
  These calculations do not replace composited native contrast verification.

Proposal-analysis verdict: the council supports this direction within the inspected
scope. Accessibility/focus owner review, current native rendering, builds, and
hardware verification remain implementation work, not completed checks.

## Permission/footer refinement, 2026-10-26

The follow-up screenshots expose fragmented status: access setup above the editor,
connection guidance below it, an isolated Off label, and unavailable battery data.
The saved v9 frame on this host is 941 × 885 physical points; restoring it bypasses
all changes to the fresh-window default. The operator reports no manual resizing.

Keep the established native identity: canvas #F3F5F7 / #20262D, workspace
#FFFFFF / #2B333C, primary text #1C2630 / #F0F4F8, and the existing semantic
amber for missing access. Use SF body text for controls, semibold body for the
permission title, and secondary callout text for explanations. Retain the
4/8/12/16/24 spacing scale and the shared leading/trailing content alignment.

```text
Profile [name] [actions]                           Saved [Save & Apply]

Left trackpad editor                     Right trackpad editor
Rear buttons                             Rear buttons

[shield] Allow access to use your mappings              [Open setup…]
         Input Monitoring and Accessibility are needed.
--------------------------------------------------------------------
[controller] Not connected [details]         Off  Enable output [switch]
Connect the puck, then refresh.              Turning on saves changes.
```

Review against the brief: the paired trackpads remain the visual focus; no new
card styling or illustrative decoration. Permission setup belongs with output,
so it becomes one actionable footer notice and suppresses competing routine
connection guidance until access is granted. Errors and active system-prompt
instructions remain visible. The unavailable battery placeholder moves into
connection details. Output state and pending-save guidance stay beside the switch.

Fresh windows use 1080 × 640 usable points. Start a new v10 frame namespace once
for this revised composition, then preserve all subsequent user resizing. The old
v9 frame is retained in preferences, but cannot keep forcing the obsolete opening
shape. Add Window > Reset Window Size as an explicit route back to the recommended
screen-fitted size. Editing modes never resize the window automatically.


## Content-driven window sizing, 2026-10-26

The operator explicitly superseded the earlier resizable-window decision after
expanded Pointer tuning extended below the viewport. Paddr now owns both dimensions:
1080 points is the preferred width; header, mounted mapping document, and footer
measurements determine height. Changes to either disclosure, pad mode, permission
notice, or other wrapping content trigger a coalesced frame update after layout.

Keep the top edge in place while growing or shrinking, then constrain the entire
frame to the screen's visible area. On smaller screens narrow the workspace and
cap height; preserve the existing scroll view for unavoidable overflow. Screen
moves and display-configuration changes reapply this policy. Use immediate sizing
without decorative animation. Do not duplicate the editor to measure it.

The configuration window has no resizable style mask or Reset Window Size action.
Position may be restored; saved width and height never override content sizing.
The guide's separate window behavior is unchanged. `NSHostingController.sizingOptions`
is empty for this window so AppKit's intrinsic minimum does not compete with the
measured policy. Fixed-size test fixtures likewise explicitly disable intrinsic
window sizing where they need a constrained viewport.


## Acceleration and selector alignment follow-up

Use the existing native toggle/slider row for Pointer acceleration, with an
independent persisted enable flag and remembered amount. Preserve legacy profiles'
effective acceleration and numeric CLI semantics. Use 25% when enabling a
zero-strength setup. Omit disabled acceleration from the collapsed tuning summary.

Use one 192-point selector width across both pad inspectors, rear bindings, and
profile selection. Native flexible button sizing makes the actual control fill
that width. Leave segmented mode controls and the icon-only profile-actions menu
in their existing roles. Keep the 16-point map/inspector gutter and measure the
window from the resulting content as before.

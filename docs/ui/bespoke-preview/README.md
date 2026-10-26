# Bespoke control comparison

After images are **WindowServer-composited inert fixture windows**, with system
access granted and existing Screen Recording permission. They include the retained
secondary/menu/track glass. Selected modes and Save & Apply are now **flat** light
blue / dark Compass teal with fine pale edges. Native captures use the host's
reported 1x output. Cached 1x/2x rasters establish geometry, not physical Retina proof.
No production app, personal profile or receiver was opened; no TCC/global settings
changed. Live README screenshots and original published-release before images remain
untouched.

Current candidate starts at `c3ec20aa977547a6b8d4b16f91ca0ca3de25ff8a` (PR #96).
The newest operator direction supersedes selected glass and rear two-row alignment:

- 996-point preferred usable window, derived from two 190 + 16 + 240-point editors,
  their 24-point separation and existing card/window insets.
- 16-point pad/options gutter, yielding only to 8–16 at the constrained inline threshold.
  Mode/menu/readout edges still align; sensor maps remain 190 × 182.
- One default rear row in L4, L5, R4, R5 order, with equal 180-point selectors.
  Whole code/menu pairs wrap at constrained widths; logical RTL order and identity remain.
- Flat selected/action fills, 4-point segment inset, 2-point gaps, local feedback,
  distinct focus and opaque accessibility fallbacks. Secondary glass remains native.

| Appearance | Published 1.1.0 before | Current candidate |
| --- | --- | --- |
| Light | ![Before, light](before-light.png) | ![After, light](after-light.png) |
| Dark | ![Before, dark](before-dark.png) | ![After, dark](after-dark.png) |

| Surface | Light | Dark |
| --- | --- | --- |
| Both Zones | ![Zones, light](zones-light.png) | ![Zones, dark](zones-dark.png) |
| One rear row | ![Rear, light](rear-row-light.png) | ![Rear, dark](rear-row-dark.png) |
| Flat inset selection | ![Selection, light](selected-mode-light.png) | ![Selection, dark](selected-mode-dark.png) |
| Flat Save & Apply | ![Primary, light](primary-light.png) | ![Primary, dark](primary-dark.png) |
| Mirrored layout | ![RTL, light](rtl-light.png) | ![RTL, dark](rtl-dark.png) |
| Inspector edges | ![Controls, light](aligned-controls-light.png) | ![Controls, dark](aligned-controls-dark.png) |
| Pointer surround | ![Pointer, light](pointer-surround-light.png) | ![Pointer, dark](pointer-surround-dark.png) |
| Separate pad focus | ![Focus, light](focus-corner-light.png) | ![Focus, dark](focus-corner-dark.png) |

![Zones, tuning, rear row, flat accents, RTL, narrow, accessibility and opaque fallbacks](contact-sheet.png)

Full captures and canonical receipts: `/tmp/paddr-flat-535f91b9/`. Direct crops
preserve native pixels; enlarged detail cells in the contact sheet use nearest
sampling. `final/readme-narrow-{top,lower}-*.composited.png` is a 680-point fixture;
`final/readme-accessibility-{top,lower}-*.composited.png` exercises accessibility5
reflow and screen-capped scrolling. `readme-both-zones-opaque-*` exercises Increased
Contrast, Reduce Transparency and Reduce Motion together. Disabled primary fills
also have cached semantic pixel checks in both appearances and all fallback states.

The older `setup-rim-*.png` captures are retained from the preceding shared-edge
candidate because this secondary control is unchanged. They are not new-candidate
capture evidence. Before images retain their original cached-release provenance.
See [the current validation record](../PADDR_BESPOKE_CONTROLS_VALIDATION.md) for
commands, failures/reruns, source/settings receipts, limits and manual follow-up.
Fresh Sol review at `3e95637` found no actionable interface regression. Its
pre-existing pressure-fixture finding is repaired with a deterministic regression;
see the validation record for scope and receipts. Full manual accessibility/keyboard,
hardware/output/disconnect, inactive pointer feel, physical Retina and macOS 26
runtime proof remain unverified. The map-focus key-window skip remains, and the
earlier reconnect-timeout receipt is retained without claiming its precise ordering
was reconstructed by the fixture repair.

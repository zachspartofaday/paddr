# Bespoke control comparison

These four native window renders use the existing inert in-memory configuration
fixture with system access granted. They are comparison evidence, not hardware
captures or replacements for the live README screenshots.

Before: `d0c99d8` (the frozen 1.1.0 release). After: `eb4f6c3` (bespoke controls and
right-to-left selector repair). Both show the same overview fixture in light/dark
appearance, using content-driven window sizing.

| Appearance | Before | After |
| --- | --- | --- |
| Light | ![Before, light](before-light.png) | ![After, light](after-light.png) |
| Dark | ![Before, dark](before-dark.png) | ![After, dark](after-dark.png) |

The full state matrix, commands and remaining manual checks are recorded in
[the validation record](../PADDR_BESPOKE_CONTROLS_VALIDATION.md).

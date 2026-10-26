# Contributing to Paddr

Bug reports, compatibility notes, documentation improvements, and focused pull requests are welcome. Paddr sits on top of controller support that first appeared in a macOS beta, so the most useful contributions explain the exact environment and behavior they exercised.

## Before you start

Small fixes and documentation changes can go straight to a pull request. For a larger feature, a stored-configuration change, or work that touches controller I/O, please open an issue first. That gives us a chance to agree on scope and avoid asking you to rework hardware-sensitive code after the fact.

Keep one coherent change together. A fix may need several files; that is still one change. Avoid parallel pull requests that redesign the same runtime, configuration, or SwiftUI surface.

## What to include in a report

For controller or compatibility bugs, include:

- the macOS version and build;
- whether the controller is connected through the puck, Bluetooth, or USB;
- the Paddr version, build, source revision, and whether it is ad-hoc signed, Developer ID signed,
  or locally built;
- the trackpad mode and relevant bindings; and
- concise steps that reproduce the problem.

Remove controller serial numbers, local IOHID paths, private filesystem paths, signing details, and account information. Do not attach raw hardware captures unless they have been deliberately redacted.

Permission behavior depends on the app's bundle identity, path, and signature. If macOS requested Accessibility again after an update, mention whether the app moved and how both builds were signed.

## Quality bar

Behavioral tests should pin the behavior being changed: reverting the fix should make at least one test fail. Prefer the existing runtime, session, configuration, and app-support seams over adding a parallel abstraction. When a stored value changes, account for existing `~/.config/Paddr/config.json` files and the documented legacy migration paths.

Controller removal must release every held key and mouse button. Lifecycle changes must preserve the one-worker invariant and reject stale events. UI changes must remain keyboard-operable, expose meaningful native accessibility semantics, use system text styles, and keep known user-facing text in the String Catalog.

## Development

Paddr requires Xcode 27 and keeps macOS 26.0 as its deployment target. Distribution is arm64-only.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test -Xswiftc -warnings-as-errors
scripts/check-localization.sh
swift build -c release -Xswiftc -warnings-as-errors --arch arm64
swift build -c release -Xswiftc -warnings-as-errors --arch arm64 --product PaddrCLI
scripts/test-cli.sh "$(swift build -c release --arch arm64 --show-bin-path)/PaddrCLI"
scripts/test-release-identity.sh
scripts/test-release-production.sh
```

To assemble a local ad-hoc app without touching the repository's `dist` directory:

```bash
OUTPUT_DIR="$(mktemp -d)/output" \
BUILD_SCRATCH_PATH="$(mktemp -d)/build" \
scripts/build-app.sh
```

Release packaging runs `Paddr --artifact-smoke-test`, which checks executable startup and built-in configuration encoding without constructing the app, loading personal profiles, requesting permissions, or probing HID. The separate `--smoke-test` diagnostic reads configuration and probes the receiver; it is not an inert packaging check.

If your change affects a physical launch path, say what you tested manually. Useful checks include pointer movement, scroll, keyboard and mouse-button zones, touch taps, permission refresh, closing and reopening the configuration window, and puck unplug/replug while an output is held.

## Pull requests

Before opening a pull request:

- run the test, localization, and release-build commands above;
- keep generated build products, credentials, certificates, private keys, and unredacted captures out of the repository;
- update README or contributor documentation when behavior or workflow changes; and
- describe anything you could not test directly, especially physical-controller and assistive-technology behavior.

The repository does not publish, notarize, or upload artifacts from contributor pull requests. Never run release publication against this project unless the maintainer has explicitly coordinated it.

## Brand assets

`Assets/AppIcon.icon` is the editable Icon Composer source for the Compass app icon.
Its four SVG zones retain the grey/teal palette, while the system renders Liquid Glass
highlights, refraction, translucency, and shadows. Edit the source with Icon Composer
from Xcode 27; keep masks, baked lighting, and shadows out of the SVG layers.

The app build compiles the layered source alongside `Assets/Assets.xcassets`, selecting
`AppIcon`. The layered source takes precedence; macOS chooses the appropriate appearance
and design generation. Refraction is a generation-27 effect and has no visible effect
on macOS 26.

Regenerate the checked-in flattened `Assets/PaddrIcon.png` and fallback AppIcon catalog
after changing the layered source:

```bash
scripts/generate-app-icon.sh
```

The generator requires the selected Xcode 27 installation (or `DEVELOPER_DIR`) and its
Icon Composer tools. It renders the Default appearance using design generation 27,
adds a transparent macOS canvas inset, and regenerates the catalog's declared sizes.
The PNG and catalog are flattened fallbacks, not the source of native glass behaviour.
Preview Default, Dark, and Mono appearances and small icon sizes in Icon Composer
before accepting artwork changes.

See Apple's [Icon Composer documentation](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
for layer preparation, appearance variants, and compatibility behaviour.

`@zachspartofaday` is the code owner and sole merge authority. Community review is welcome, but only the maintainer approves and merges changes.

Thanks for helping make Paddr safer and more useful.

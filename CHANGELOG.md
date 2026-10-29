# Changelog

User-visible changes to Paddr are recorded here. Release entries describe confirmed behavior at the time of each release; later entries may supersede earlier limitations.

## Unreleased

- Add opt-in gyro-to-mouse aiming with touch activation, sensitivity, inversion,
  smoothing, controller holding-angle compensation and session-local stationary
  calibration started explicitly from a hold-still preparation prompt. Provide
  Calibrate Again after calibration.
- Add independent left/right grip-contact key and mouse-button bindings, with
  live contact and motion availability indicators while output is off. Align the
  controller settings with the pad inspectors, move explanatory copy into circled
  info buttons and make calibration state prominent.
- Give gyro a section heading above calibration and Activation. Match Enable
  output to the squared switch family and omit repeated connection advice.
- Keep sensor output inside the existing output gate and held-action ownership;
  reject stale motion and release grip actions when their reports expire.
- Add native profile settings and CLI options. Read existing profile documents
  with Off/None defaults and save schema version 2 to prevent older writers from
  silently discarding the new settings.
- Sensor support remains passive: no IMU setting writes, analog grip pressure,
  virtual gamepad output, direct USB transport or tilt driving is introduced.

## 2.0.1 — 2026-10-27

- Soften button, selector, mode and tuning-switch outlines to 50% opacity in the
  standard appearance, retaining full-strength focus and increased-contrast edges.
- Refresh the product screenshots from the permission-approved build in light and
  dark appearance, including the automatically fitted expanded-tuning window.

## 2.0.0 — 2026-10-26

### Bespoke mapping workspace

- Introduce a unified compact control family: squared tuning switches, native-menu
  selectors, buttons, and inset filled mode selections. Keep Enable output and
  sliders native, with clear keyboard focus and accessible control semantics.
- Use Compass teal accents in dark mode and blue in light mode. Keep selected modes
  and Save & Apply flat with a pale rim; secondary surfaces use native Liquid Glass
  with reduced-transparency and increased-contrast fallbacks.
- Match pad maps to the controls with smoother outlines, repaired tangent seams,
  concentric focus rings, and restrained surface depth.
- Align mode selectors, menus and percentage readouts to shared 240-point edges.
  Tighten pad/inspector spacing and use a 996-point preferred window width, retaining
  automatic height adjustment and constrained-screen scrolling.
- Put rear-button selectors in one evenly spaced row. L5 and R5 align with the
  inspector edges above; whole label/menu pairs wrap when space is limited.

### Interaction fixes

- Make the Pointer tuning label clickable as well as its disclosure indicator.
- Show a battery placeholder as soon as the controller connects, then update it
  when the first battery report arrives without opening Connection details.
- Mirror menu text, chevrons, mode tracking and tuning-switch thumbs in right-to-left
  layouts. Keep selection, bindings and focus stable when layout direction changes.
- Clear stale hover feedback while dragging between mode segments or across gaps.
- Repair an idle-stop test fixture so stopping an empty session cannot release a
  future run, with deterministic stop-before-start coverage.

### Documentation

- Replace the previous product screenshots with fresh light/dark native captures
  and an automatically fitted expanded-tuning view, with permissions granted.
- Streamline the README and move mapping details, CLI/configuration reference and
  build instructions into linked guides. Remove the obsolete UI parity document
  while preserving required third-party attribution.

No profile migration is required. Existing mappings and output safety behavior are
preserved. Confirmed connection remains Steam Controller 2 through its puck on
released macOS 27 and macOS 27.2 release candidate; Bluetooth/direct USB remain
unvalidated.

## 1.1.0 — 2026-10-26

### Redesigned mapping workspace

- Give Paddr its own native light/dark interface, with both trackpads independently
  editable and common controls visible beside their maps. Advanced pointer settings
  live in per-pad Pointer tuning disclosures with summaries of enabled settings.
- Keep profile selection and Save & Apply above the scrolling workspace, with a
  persistent **Enable output** switch and separate output readiness below it.
  Explain when enabling output will save pending edits.
- Automatically grow and shrink the configuration window to fit its contents,
  including expanded tuning. Preserve its position, fit the current screen, and
  scroll when necessary. Manual resizing is disabled.
- Align profile, zone, touch-tap, and rear-button selectors at a shared width, and
  correct battery-percentage alignment in the footer.
- Consolidate missing-permission guidance into an actionable Open setup notice,
  share permission controls with the guide, and make Duplicate to Edit a direct
  action for the built-in Default profile.
- Introduce the grey/teal Compass icon with native Liquid Glass layers and adaptive
  appearances, plus flattened fallbacks for earlier system rendering.

### Pointer controls and output feedback

- Add a per-pad Pointer acceleration switch that remembers its strength while
  disabled. Existing profiles retain their effective acceleration; CLI numeric
  options continue to enable nonzero acceleration and disable zero.
- Prevent brief orange guidance flashes and footer resizing when output is enabled
  or disabled. Sustained preparation, neutral-input, and output-release waits show
  matching guidance after 250 ms; errors and permission guidance remain immediate.
- Describe profile preparation accurately when enabling during a pending save.
  Profile operations alongside an enabled session preserve neutral-input guidance
  while that session can still arm.

### Safety and reliability

- Keep CLI cleanup alive until macOS accepts releases for held keys and mouse
  buttons, retrying failed releases and reporting pending and recovered cleanup.
- Prevent cooperating GUI and CLI writers from overwriting profiles changed since
  they were loaded. Compare the loaded file under a shared lock before replacing
  it; conflicts preserve external changes and the GUI's unsaved draft. Explicit
  exports still deliberately replace their destination.
- Make release-package startup checks inert: they verify executable startup and
  built-in configuration encoding without reading personal profiles, requesting
  permissions, or probing the controller.
- Correct lifecycle test fixtures to require explicit neutral-input arming and
  cover both startup orderings while preserving stop/save/start serialization.

### Compatibility and documentation

- Record maintainer-confirmed operation with a puck-connected Steam Controller 2
  on released macOS 27 and macOS 27.2 release candidate. Bluetooth and direct USB
  remain unvalidated; historical beta-only caveats below no longer describe the
  current release.
- Replace all twelve README screenshots with live native captures, including both
  appearances and content-fitted window sizes. Ordinary workspace captures have
  permissions granted; only the dedicated setup capture shows missing access.
- Add Compass branding to the README and update local build instructions for Xcode 27.

## 1.0.0 — 2026-09-07

### Rear buttons and mapped input

- Added optional L4, L5, R4, and R5 keyboard or mouse-button mappings, saved with each
  profile. Hold a rear button to hold its assigned action; unassigned buttons send no input.
- Preserved rear-button bindings through CLI profile selection and import/export. Profiles
  created before rear-button support load with all four bindings unassigned.
- Preserved fractional scroll movement until it accumulates to a whole point, rejected stale
  controller reports, and required fresh neutral input before mapped output resumes.
- Kept profile schema version 1. Older binaries can discard rear-button bindings when saving;
  export a backup before downgrading.

### Configuration and quit behavior

- Expanded the default configuration window to 1380 × 1040 usable points, with both
  trackpads, Rear buttons, and the footer visible when the screen allows. Fresh and migrated
  defaults fit the screen; custom restored sizes are preserved.
- Kept the 680 × 600 minimum, responsive layouts, and vertical scrolling. Simplified rear-button
  instructions into localized picker help.
- Improved narrow layouts, permission visibility, window restoration, and unsaved-quit handling,
  including saves already in progress and recovery after a failed save.

### Compatibility and documentation

- Confirmed macOS 27 Developer Beta 8 (build `26A5425a`) compatibility with a puck-connected
  Steam Controller 2 on the maintainer's current setup. Other beta builds remain unconfirmed
  unless explicitly recorded; the Developer Beta 5 confirmation remains historical evidence.
- Refreshed the README and all eight screenshots for the expanded configuration window,
  rear-button mappings, pointer tuning, and current permission guide.

### Trackpad feel

- Added per-trackpad tap stabilization. It is enabled by default and holds the cursor steady through
  small lift motion, while deliberate movement beyond the adjustable tolerance cancels the tap and
  transitions to normal pointer tracking without a catch-up jump
  ([#83](https://github.com/zachspartofaday/Paddr/issues/83)).
- Added optional, adjustable pointer smoothing. The speed-adaptive filter reduces slow jitter while
  retaining fast response, preserves sustained slow motion below the per-report noise gate, remains
  off by default, and can be tuned independently for each pad.

## 0.11.0 — 2026-08-24

### New family interface

- Rebuilt the configuration window, setup guide, status bar, permissions, and menu as a polished
  dark console shared with Paddr's sister application. The blended macOS titlebar, consistent card
  spacing, stronger type hierarchy, and native controls now read as one intentional system
  ([#76](https://github.com/zachspartofaday/Paddr/issues/76),
  [#78](https://github.com/zachspartofaday/Paddr/issues/78)).
- Kept both trackpad editors visible side by side at the default window size. Each card puts its
  mode selector beside the trackpad title, keeps the pad preview and settings together, and adapts
  cleanly to narrow windows and Accessibility text sizes
  ([#77](https://github.com/zachspartofaday/Paddr/issues/77)).
- Redesigned the bottom status bar around a clear setup sequence: Access, Puck, Controller, Output,
  and Battery. Ready states collapse to compact green icons; battery percentage remains visible and
  changes from green to amber to red as charge falls.

### Trackpads and controller

- Decoupled pointer tracking from the center tap radius. Pointer mode now tracks across the full pad
  by default while taps remain confined to the chosen radius; **Track pointer inside tap radius**
  restores the former dead-zone behavior when desired
  ([#50](https://github.com/zachspartofaday/Paddr/issues/50)).
- Added the controller's reported battery percentage and charging state to the configuration window
  and status menu ([#54](https://github.com/zachspartofaday/Paddr/issues/54)).
- Fixed controllers that remained **Not found** on some pucks by listening to all four exposed
  controller slots, accepting the shorter reports used by some firmware, and responding immediately
  to wireless connect and disconnect events
  ([#52](https://github.com/zachspartofaday/Paddr/issues/52)).
- Added **Input Monitoring** to first-run setup ahead of Accessibility. macOS can withhold puck
  reports without it, which previously looked like a missing controller.

### Safety and reliability

- Hardened held key and mouse-button cleanup. Paddr now keeps release obligations until macOS
  accepts the matching up events, retries cleanup after output is disabled or a controller is lost,
  and prevents a replacement output session or app quit from abandoning unresolved input.
- Added deterministic readiness guidance and clearer disabled reasons throughout the window and
  menu, including a wait state while profile operations temporarily pause output.
- Kept **Open Source Notices…** available in packaged and supported source-checkout launches, with
  validation around the source fallback.
- Release bundles now record their exact Git revision and source state. Packaging requires a clean
  annotated version tag and verifies the tag, source plist, app, archive, version, build, and source
  revision before publishing.

## 0.9.11 — 2026-08-14

### Controller status and output

- Fixed the bottom controller status staying **Not found** until Trackpad Output was enabled ([#46](https://github.com/zachspartofaday/Paddr/issues/46) — thanks to [@redeemer666](https://github.com/redeemer666) for reporting it). Paddr now observes the controller continuously from launch, so controller presence is accurate while output is off.
- Split the bottom status into separate **Puck** and **Controller** indicators: **Puck Connected** comes from passive receiver discovery alone, and **Controller Connected** comes only from accepted live controller reports.
- Made the Trackpad Output toggle control mapped mouse, scroll, and keyboard emission only. Disabling output releases held keys and mouse buttons before **Output** reads **Idle** (via a brief **Releasing** state), keeps observing the controller, and re-enabling waits for neutral pads before arming.
- Kept the **Puck** indicator truthful when the receiver is visible but cannot be opened (for example while a permission is missing): passive discovery drives the indicator instead of the failed open.
- Detected puck hot-plug while output is off, including when Paddr starts with no puck attached.
- Because Paddr now opens the puck at launch rather than on first enable, any device-access prompt appears at first launch instead of when output is first enabled.

### Interface

- Moved **Save & Apply** and the saved-state indicator into the top profile card, and moved **Restore Defaults** into the profile actions menu. The bottom bar is now a stable status-only row, so it no longer reflows when statuses change.
- **Save & Apply** is enabled only while there are unsaved changes.

### Known issues

- In Pointer mode, **Center tap radius** currently doubles as a tracking dead zone: touch taps register only inside the radius, and pointer tracking responds only outside it, so the pad's center cannot move the pointer while a radius is set. A radius of 0% keeps taps and tracking available across the whole pad. Decoupling these — full-pad tracking with taps confined to the radius, as a togglable default — is planned ([#50](https://github.com/zachspartofaday/Paddr/issues/50)).

## 0.9.9 — 2026-08-13

### Profiles and setup

- Added named profiles for complete left- and right-pad configurations. Profiles can be created, duplicated, renamed, selected, and deleted from the configuration window, with quick switching between saved profiles from the status menu.
- Kept the built-in **Default** profile immutable: it always provides left Scroll and right Pointer, and it cannot be renamed, edited, or deleted. Duplicate it to create an editable profile.
- Existing configurations migrate automatically. An unchanged configuration selects Default, while customized settings become a **Previous configuration** profile; a failed migration leaves the original file intact.
- Protected unsaved work during profile changes. Window switching asks before discarding edits, and status-menu switching pauses until the draft is saved or explicitly discarded.
- Added a native four-step first-launch guide covering connection, Accessibility, pad setup, and everyday use. The guide can be reopened from Help or the status menu and does not request permission, enable output, or change a profile on its own.

### Trackpads and controller status

- Added an independent **Pointer acceleration** control for each pad, alongside the existing per-pad pointer and scroll sensitivity controls. The default of zero preserves the previous pointer response.
- Confirmed that both pads can use **Zones** at the same time, including independent layouts and bindings.
- Made **Controller Connected** reflect live controller reports rather than receiver presence alone. Turning off or losing the controller now releases held mapped keys and mouse buttons, marks the controller unavailable, and waits for neutral pad input before safely resuming after reconnect.
- Kept direct-launch use independent of Steam: Paddr does not require Steam, Steam Input, or Steam Overlay, so mapped trackpad input remains available to games launched normally.

### Interface

- Showed Paddr in the Dock and Command-Tab while the guide or configuration window is open, then returned it to menu-bar-only operation after both windows close.
- Refined the top card around profiles and status: profile controls remain in a stable location, selectors use a fixed width and stronger adaptive contrast, and Default presents a clear **Duplicate to Edit** path.
- Kept both expanded pad cards equal in height across their different modes, while preserving a compact collapsed layout and smooth profile switching without control flicker.

### Compatibility and validation notes

- macOS 27 Developer Beta 5 remains the confirmed environment. macOS 27 Public Beta 3 has been released and is likely compatible; public betas typically correspond to the preceding developer beta, but this specific build identity and Paddr compatibility have not yet been confirmed.
- Puck-connected Steam Controller 2 hardware using the tested receiver remains the confirmed connection. Bluetooth, direct USB, and the alternate receiver product remain unvalidated.
- Final attended coverage is still needed for pointer-acceleration feel; held outputs across controller loss, profile changes, sleep/wake, and reconnect; keyboard and VoiceOver navigation; the largest Zones layout; and a broader range of games and hardware.
- Paddr emits mouse, scroll, and keyboard events rather than native gamepad axes. Games that switch prompts according to the most recent input may alternate between controller and keyboard/mouse glyphs.

## 0.9 — 2026-08-12

Paddr 0.9 was the first Developer ID-signed, notarized, and stapled release.

- Reduced setup to one Accessibility grant for reading pad reports and emitting mapped input.
- Added independent per-pad scroll and pointer sensitivity, with matching command-line controls.
- Refined the compact two-card configuration window and its connection, output, and access status guidance.
- Improved everyday safety and reliability: quitting or losing a session releases held input, directional Zones follow the pressed direction, and delayed loads, saves, or device checks cannot replace newer user choices.
- Strengthened archive and checksum verification for the distributed app.

At the time of the 0.9 release, controller status tracked the receiver, only one pad was documented for Zones, and the configuration window did not appear in the Dock. Those limitations are superseded by 0.9.9.

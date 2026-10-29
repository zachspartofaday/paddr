# Gyro mouse and grip-touch validation

Implementation scope: [issue #101](https://github.com/zachspartofaday/paddr/issues/101).
The feature adds passive gyro mouse aiming and two capacitive grip-contact bindings.
Keyboard tilt driving and virtual gamepad output are excluded.

## Contracts

- Existing configurations default to gyro Off and grips None. Schema-1 profile
  documents remain readable; successful new saves use schema 2. Unsupported future
  schemas fail before writes. Exact-byte conflict detection and atomic saves remain.
- One controller slot, runtime, output gate and held-output ledger own all input.
  Left and right grip actions have separate arbiter owners, including shared
  key/mouse bindings with pads and rear buttons.
- A mapped grip requires fresh release before arming. A grip used only for gyro
  activation does not block pad output. Gyro activation requires release before
  contact activation; Always starts only after stationary calibration.
- Motion and grip freshness use a conservative 100 ms limit, separate from the
  one-second controller-link timeout. This is a safety bound, not a hardware timing guarantee. Stale motion resets integration/calibration and stale
  grips release their ownership.
- Recalibration uses an independent request revision in the existing output gate.
  It resets gyro calibration/activation/filtering and relative mouse remainder,
  without replacing the session, changing the output revision, saving a profile,
  or releasing pad/rear/grip owners. It requires an enabled saved gyro session and
  fresh motion; requests during disabled output do nothing.
- Holding-angle compensation is a profile value from 0° flat to 90° upright.
  It projects yaw/roll using the selected right-handed pitch convention, leaving
  pitch as vertical aiming. Existing profiles use 0°; no sensor bias is saved.
- Calibration requires at least 500 ms and 50 fresh samples, low stable angular
  velocity and stable acceleration near gravity. The app requires an explicit
  guided request; enabling output never requests calibration. Completed bias lost
  to stale motion or a clock discontinuity requires another request. The headless
  CLI explicitly selects stationary-start calibration. Bias belongs to the output epoch
  and is never persisted. Physical drift and axis-direction checks remain necessary.
- Relative mouse deltas retain signed fractional remainder before integer CGEvent
  fields are emitted. Absolute cursor positions and held-button dragging remain.
  Synthetic-event support in raw-input games is not established by these tests.

## Protocol evidence

The source is pinned SDL Triton
[`3dde1dd08d0cd854a900f3a7f305e066bfdf88cc`](https://github.com/libsdl-org/SDL/blob/3dde1dd08d0cd854a900f3a7f305e066bfdf88cc/src/joystick/hidapi/SDL_hidapi_steam_triton.c).
Offsets include report ID: grip masks `0x20000000`/`0x10000000` at byte 2;
acceleration at 34/36/38 and gyro at 40/42/44. Complete motion needs 46 bytes;
shorter pad reports remain supported. The optional quaternion is unused.

The `0x42`/`0x45` clock is UInt32 microseconds at byte 30. The `0x47` clock is
UInt16 ticks at byte 32, each 32 µs. Subtraction occurs in the clock's wire width
before scaling; `65535 → 0` is 32 µs. Values convert to rad/s and m/s² with SDL
axes `(raw X, raw Z, −raw Y)`. Horizontal aiming uses yaw and vertical uses pitch;
physical ergonomic signs remain unverified.

The installed SDK defines mouse delta fields as integer-valued. A game's raw
GameController/GCMouse path may bypass synthetic mouse events entirely. Actual
captured-camera, recentering and screen-edge acceptance requires target-game tests.

## Physical evidence and remaining acceptance

A five-second passive check on 2026-10-28 opened the puck successfully but received
no input reports. It performed no feature reads/writes, seizing or mapped output.
After the operator woke the controller, another five-second passive capture
received 1,344 complete 54-byte `0x42` state reports, 1,245 fresh sensor timestamps
and 98 duplicate timestamps. Fresh timestamp steps were 3,864 µs (1,235 samples)
and 7,728 µs (10 samples). Both grip bits were released; angular rates were near
zero and acceleration near gravity. This establishes current awake-session motion
availability, not cold-start/reconnect behavior or physical direction/contact
correlation. The earlier planning capture observed right-grip contact on this puck.
A later ten-second grip-only check, with the operator holding both handles,
received 2,694 state reports with both grip bits set throughout. This confirms both
contact flags are available. Those captures did not independently correlate
left/right transitions or axis signs; subsequent live app checks below confirmed
the separate grip contacts. The timed movement prompts were not synchronized well
enough to establish axis directions. No settings or mapped output were changed by any
of these captures.

Before calling the hardware feature accepted, verify:

1. Yaw/pitch direction, recalibration, stationary drift, slow aiming and touch gating.
2. Desktop movement and target-game aiming with cursor capture/recentering, screen
   edges and held mouse buttons. Record games/backends that reject synthetic input.
3. Shared-action holds, disable, permission loss, controller sleep/disconnect and
   reconnect, with no stuck input or stale-motion jump.
4. Cold start and Steam present/absent sensor availability. No IMU enable writes
   are implemented; an unavailable stream stays visibly unavailable.
5. Keyboard, VoiceOver and constrained-screen/RTL behavior of the new settings.

Automated checks and independent review receipts are recorded below after the
candidate is frozen. Fixture renders establish sampled layout, not hardware or
assistive-technology acceptance.

## Automated and live verification

The completed source review covers base `95ea61b` through `56a0094`, with the
bounded accessibility correction `46c0789` independently inspected as a fix delta.
One confirmed P2 at the reviewed head—tuning sliders inheriting the disclosure's
accessible name—was repaired using the native text label and a hidden pointer
activation overlay. Its semantic regression failed before the change and passed
afterward, including individual slider names and one named native disclosure.
Packaged AX inspection confirmed the corrected names and disclosure state.
No additional actionable defect was established in the independent review.

The full canonical test run at `56a0094` completed 563 tests: 562 passed and the
existing key-window-dependent map-focus test was skipped. All image exporters ran.
Seven affected UI/window tests passed after `46c0789`, including the new semantic
regression and full-label disclosure interaction. Localization, arm64 release app
and CLI builds, CLI configuration checks, release identity and production fixture
checks passed. A clean-source Developer ID-signed preview at `46c0789` passed strict
signature verification and the inert artifact smoke test. It is a local preview,
not a notarized release. No release tag/version was changed.

The first full run retained failed old fixed-height layout expectations. Tests
were corrected to check the production measured-height contract and individual
rear-control visibility in intentionally constrained captures; sensor content below
that rear row may scroll. A guessed CLI output path also failed before rerunning
against Swift's actual build-products path. These failures were not treated as passes.

Post-review live checks with the updated signed preview confirmed left-only contact
as Left Touching/Right Released, then right-only contact as Left Released/Right
Touching. Disconnected/asleep intervals cleared availability; a Steam-button wake
restored reports. This is not an exhaustive cold-start/reconnect or output-loss test.

A real five-second observe-only runtime check received 1,332 state reports,
completed stationary calibration and reached Active with no mapped actions at rest.
An earlier five-second check stayed Calibrating while the controller was being put
down. Two earlier three-second checks received no reports during an unavailable
interval. Observe-only checks posted no mouse or key events and wrote no controller
settings. Actual mouse aiming and grip-held mapped output still require attended
acceptance, along with the target-game and assistive-technology scenarios above.

## Follow-up interaction refinement

The operator reported that the initial feature worked, then requested aligned
controller-wide controls, circled hover/click information, more prominent
calibration state, an explicit recalibration action and holding-angle tuning.
They selected controller flat-to-upright compensation rather than desktop-axis
rotation. This does not establish exhaustive game, drift or output-loss acceptance.

The follow-up preserves default 0° aiming and adds a separate calibration request
channel to the same runtime. Generic explanation lives in native help/popovers;
current calibration state stays in a row below the Gyro to mouse heading; its immediate instruction remains available through status help. The summary row also holds Calibrate or Calibrate Again, aligned to the left selector edge, with ready state labeled Calibrated, Ready. Activation shares the calibration row and aligns with Right grip. Tuning holds the nine tuning controls across two columns and five logical rows, including sensitivity and horizontal tilt selection. Contact labels are hidden when that grip action is None, without changing sensor observation or gyro activation. Verification
of the refinement and its exact candidate is recorded with the PR evidence.


## Guided calibration and shared activation refinement

The app now waits for an explicit calibration request. The initial action is
**Calibrate**; after Ready or Aiming it is **Calibrate Again**. Both open a native
preparation popover asking the user to put the controller on a stable surface or
hold it still, then press **Calibrate**. Opening, canceling or dismissing the
prompt does not start a measurement. The request still uses the independent gate
revision, with the existing profile, output, freshness and neutral-admission checks.

The target/status icon is removed, information buttons use secondary caption
styling, and **Activation** aligns with **Right grip**. These changes retain
collapsed tuning, individual native control names and responsive RTL layout.

Source inspection confirms that a grip binding and gyro activation read the same
contact independently. The combined runtime regression covers right-grip activation
with a key, left mouse button and right mouse button, including initial held
admission, explicit calibration, recalibration while held, release/re-touch,
disable, disconnect and stale-input cleanup. Its injected CGEvent sink checks
button down → dragged movement → button up without posting physical input. This
establishes runtime/event composition, not a particular game's camera behavior.
Physical recalibration, holding-angle sweeps and full assistive-technology
acceptance remain pending.

Validation of this refinement covered 591 distinct tests: 590 passed and the
existing key-window-dependent map-focus test remained skipped. The full run
initially skipped the compact exporter because its opt-in directory was unset;
that exporter then passed separately with the directory supplied. Both other
exporters ran in the full suite. The automatic-start mutation failed the new
manual-calibration/combined-grip regressions; restored source passed. Localization,
arm64 release app/CLI builds, CLI checks, and release identity/production fixtures
passed. Native fixture captures cover light/dark, RTL, narrow and calibration
states. The running personal preview had an unsaved draft and was left untouched;
these checks did not enable live output or alter saved mappings.


## Section hierarchy and footer refinement — 2026-10-29

Gyro to mouse has its own heading row with its information button. Enable and
the existing squared switch start the row below, followed by the tightly grouped
calibration status and Calibrate, then Activation. Calibrate retains the left inspector trailing edge;
Activation retains the Right grip label and selector edges. Manual calibration
and all model/runtime behavior are unchanged.

Enable output uses the same squared NSButton switch adapter as tuning controls,
with one binary accessibility target, native Space/press activation and the
existing model setter, disabled gate and save-before-enable flow. Its visible
label is also clickable without becoming a second keyboard/accessibility stop.
The footer omits the repeated Connect the controller through the puck instruction
when the connection summary already says Controller not connected. Missing-puck,
permission, failure and sustained-transition guidance keep their existing paths.

Automated validation: 592 tests, 591 passed and one existing key-window/map-focus
skip, with all exporters enabled. Reverting the three presentation files to the
previous head fails the heading, output-control and redundant-guidance regressions.
The initial focused run exposed an incorrectly changed missing-puck expectation;
it was corrected to retain that actionable advice. A separate check exposed absent
native AXHelp on the new switch; explicit native help propagation repaired it.
The full suite then passed. Localization, release app/CLI, CLI configuration and
release identity/production fixtures passed.

Manual acceptance still needs Tab/Shift-Tab through the gyro and output controls,
Space/VoiceOver press toggling once, one named Enable output switch with its
On/Off/disabled state and current save/permission help, and correct focus after
calibration cancellation. Native fixture checks cover role, value, identity,
control bounds, help updates and disabled gates; they do not establish complete
VoiceOver or alternate-input acceptance. The current personal preview had an
unsaved draft and was left untouched.


## Visible-edge and calibration grouping refinement — 2026-10-29

The drawn output-switch track shares the Save & Apply trailing edge, excluding
the switch's invisible focus/hit reservation. The complete control stays within
the window, with its existing focus and activation behavior. The output group
uses the same trailing anchor when the footer reflows. Off uses the existing
amber warning token, matching Unsaved changes.

The standalone gyro heading now has no switch beside it. The lower row begins
with Enable and the squared switch, followed by a tightly grouped caption-size
calibration status immediately before Calibrate. Non-ready calibration state uses
the same amber token; Ready/Aiming retain teal. Calibration and Activation retain
their existing inspector anchors and prompt behavior.

Validation: 594 tests, 593 passed and the existing key-window/map-focus skip;
all exporters ran. The mounted geometry check compares the drawn track directly
with Save & Apply across four widths, LTR/RTL and standard/accessibility layouts,
while checking the complete hit reservation stays inside the window. The initial
label-click fixture used an unobserved captured variable, leaving its mounted
switch stale; an observed draft fixture now verifies the same native control
updates after the label click, writes once per action and sends no calibration
request. Both editable and read-only cases pass in both directions. Localization,
arm64 release app/CLI builds, CLI checks and release identity/production fixtures
passed. These are fixture/source checks; hardware and full assistive-technology
acceptance remain pending.


## Horizontal tilt selection — 2026-10-29

Gyro tuning adds **Tilt for horizontal aiming** in the previously empty fourth
left cell, retaining two columns and four rows. The profile boolean
`gyro.horizontalUsesTilt` defaults false for omitted/null values, so existing
profiles retain turning. It participates in normal draft, save/apply, raw export
and profile encoding. CLI parity is `--gyro-horizontal-tilt on|off`.

The initial implementation assigned turning to `rate.y*cos(angle) - rate.z*sin(angle)`
and tilt to `rate.y*sin(angle) + rate.z*cos(angle)`. The subsequent operator
observation below corrects the reversed physical mode assignments. Both
feed the existing negative horizontal mouse convention; forward/back pitch,
scaling, inversion, noise cutoff, smoothing, activation and manual calibration
remain unchanged. The later physical-mode correction changes which of the two projections
the selector uses; the parser’s SI conversion stays unchanged. Independent endpoint/45° cancellation oracles and a wire-report
runtime test cover the selection. Physical tilt direction and ergonomic gain
remain attended checks; automated axes do not establish live game acceptance.

Tilt validation completed 598 tests: 597 passed and the existing map-focus skip,
with all exporters enabled. Targeted sensor/runtime/UI checks passed. Replacing
the new axis selection with the previous turn-only projection fails the new
independent axis and wire-report regressions; restoring the feature passes the
full suite. Raw/profile round-trips, omitted/null defaults, malformed types,
UI draft isolation/read-only semantics, and CLI on/off/retention/error paths
passed. Localization, arm64 release app/CLI and release identity/production
checks passed. Physical direction, comfort/gain and live game acceptance remain
pending; no live output was posted by these fixtures.


## Operator-reported axis reversal and horizontal gain — 2026-10-29

The maintainer reported that enabling Tilt for horizontal aiming selected turning,
and explicitly directed using that observed reversal rather than waiting for a
new timed capture. The app’s Holding angle was 0°. The selector assignments are
swapped: Tilt On uses `rate.y*cos(angle) - rate.z*sin(angle)`, Tilt Off uses
`rate.y*sin(angle) + rate.z*cos(angle)`. At flat this makes Tilt follow wire Z
and turning follow negative wire Y. The parser’s SDL-basis conversion is
unchanged. This uses operator observation, not a new instrumented physical test.

The earlier source tests established perpendicular projections and expected wire
values, but did not independently establish which physical hand motion each
mode name described. Regressions now pin the operator-directed assignments and
retain holding-angle endpoint/cancellation, inversion and vertical checks.

Horizontal sensitivity adds `gyro.horizontalScale` from 0.1–8, default 2 for new
and omitted/null values. The multiplier applies only after horizontal projection
and filtering; vertical gain and stored base sensitivity remain unchanged.
Explicit stored multipliers are retained. UI pairs Horizontal sensitivity with
Vertical sensitivity, making nine tuning controls across two columns/five rows.
CLI parity is `--gyro-horizontal-scale`. The normal save/apply and manual
calibration lifecycle remains. Physical direction/gain and game acceptance still
need an attended check of the corrected build.


Validation for the corrected axes and independent gain completed 601 tests:
600 passed and the existing key-window/map-focus test skipped. All three image
exporters ran. The targeted Core and sensor-presentation checks passed. Restoring
the earlier reversed projections and removing horizontal gain compiled, then
failed the new behavioral regressions; restored source passed the full suite.
Localization, arm64 release app/CLI builds, CLI checks, and release
identity/production fixtures passed. These checks use injected input and event
sinks; they do not establish physical direction, comfortable gain, live games or
complete assistive-technology behavior.


## Maintainer-tested defaults and live showcase — 2026-10-29

After trying the corrected preview, the maintainer reported that it works well
and selected the saved screenshot's gyro tuning as the new defaults: sensitivity
10 pt/°, horizontal and vertical scale 2.5×, holding angle 45°, tilt aiming On,
smoothing 0.25 and noise threshold 1°/s. Activation remains right grip, inversion
Off and gyro disabled by default. Initializer and absent/null decode defaults
share one source; explicit saved settings, including zero/false and the earlier
starting tuning, remain intact. No mapper, activation or calibration algorithm
changed. Exact-projection fixtures now name their angle/mode/gain rather than
implicitly relying on product defaults.

The new literal-value regression covers fresh and missing/null configurations,
old explicit tuning and profile round-trips. Replacing the new defaults with the
previous implementation compiles and fails that regression. The initial test
incorrectly passed an empty object to the raw/profile format sniffer, which
intentionally rejects unidentified configuration; it now uses the configuration
decoder for that missing-field case. The corrected focused run passed.

Live captures use the existing calibrated preview, not a relaunched build.
Saved mappings and output were left unchanged; a temporary unsaved Pointer
example was restored to Scroll, returning Configuration saved. Dark appearance
and expanded gyro tuning were restored. Capture identity, image dimensions and
the uniform title-bar crop are recorded in ../images/README.md. The maintainer's
positive report is attended feedback, not a full holding-angle/game/AT sweep.


Final validation: 602 tests, 601 passed and one existing key-window/map-focus
skip, with all three exporters enabled. Localization, arm64 release app/CLI
builds, CLI default/retention checks, and release identity/production fixtures
passed. The README, mapping guide, CLI reference and capture notes have resolving
local links. All four product images are PNG with the documented dimensions and
were visually inspected. Full keyboard/AT, cold-start/reconnect/sleep and macOS
26 acceptance remain open; the maintainer's favorable aiming report does not
close those broader checks.

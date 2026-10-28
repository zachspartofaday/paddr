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
current calibration state stays in the single summary row beside the gyro toggle; its immediate instruction remains available through status help. The summary row also holds Calibrate or Calibrate Again, aligned to the left selector edge, with ready state labeled Calibrated, Ready. Activation is on a separate row aligned with Left grip. Tuning holds the remaining seven controls across two columns and four logical rows, including sensitivity. Contact labels are hidden when that grip action is None, without changing sensor observation or gyro activation. Verification
of the refinement and its exact candidate is recorded with the PR evidence.


## Guided calibration and shared activation refinement

The app now waits for an explicit calibration request. The initial action is
**Calibrate**; after Ready or Aiming it is **Calibrate Again**. Both open a native
preparation popover asking the user to put the controller on a stable surface or
hold it still, then press **Calibrate**. Opening, canceling or dismissing the
prompt does not start a measurement. The request still uses the independent gate
revision, with the existing profile, output, freshness and neutral-admission checks.

The target/status icon is removed, information buttons use secondary caption
styling, and **Activation** aligns with **Left grip**. These changes retain
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

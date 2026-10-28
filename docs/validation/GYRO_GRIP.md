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
- Calibration requires at least 500 ms and 50 fresh samples, low stable angular
  velocity and stable acceleration near gravity. Bias belongs to the output epoch
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
contact flags are available. Separate left/right transitions and correlated axis
signs remain pending: the earlier timed movement prompts were not synchronized
well enough to establish them. No settings or mapped output were changed by any
of these captures.

Before calling the hardware feature accepted, verify:

1. Independent left/right grip contact and release, including both hands together.
2. Yaw/pitch direction, calibration, stationary drift, slow aiming and touch gating.
3. Desktop movement and target-game aiming with cursor capture/recentering, screen
   edges and held mouse buttons. Record games/backends that reject synthetic input.
4. Shared-action holds, disable, permission loss, controller sleep/disconnect and
   reconnect, with no stuck input or stale-motion jump.
5. Cold start and Steam present/absent sensor availability. No IMU enable writes
   are implemented; an unavailable stream stays visibly unavailable.
6. Keyboard, VoiceOver and constrained-screen/RTL behavior of the new settings.

Automated checks and independent review receipts are recorded below after the
candidate is frozen. Fixture renders establish sampled layout, not hardware or
assistive-technology acceptance.

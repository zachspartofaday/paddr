<p align="center">
  <img src="Assets/PaddrIcon.png" width="112" height="112" alt="Paddr Compass app icon">
</p>
<h1 align="center">Paddr</h1>

Pointer, scroll, and keyboard mappings for the **Steam Controller 2 on macOS**, without Steam Input. Configure both trackpads, all four rear buttons, gyro mouse aiming and grip-touch actions while Apple's native controller service handles the buttons, sticks, and triggers.

[Download Paddr](https://github.com/zachspartofaday/Paddr/releases/latest) · [Mapping guide](docs/USING.md) · [Release notes](CHANGELOG.md)

![Paddr's dark mapping workspace with two trackpad editors and rear-button selectors](docs/images/paddr-profile-overview.png)

## Install

Paddr requires an **Apple silicon Mac running macOS 27 or later** and a **Steam Controller 2 connected through its puck**. The maintainer has confirmed released macOS 27 and macOS 27.2 release candidate. Bluetooth and direct USB remain unvalidated.

1. Download `Paddr.zip` from [Releases](https://github.com/zachspartofaday/Paddr/releases/latest), unzip it, and move `Paddr.app` to Applications.
2. Launch Paddr and grant **Input Monitoring** to read the controller and **Accessibility** to send mapped input. The guide and **Open setup** link to the relevant macOS settings.
3. Choose **Duplicate to Edit** for the built-in Default profile, configure your mappings, and choose **Save & Apply**.
4. Turn on **Enable output**, then release the pads, assigned rear buttons and assigned grips so output can activate.

Saving does not enable output. Closing the window leaves Paddr in the menu bar; reopen the guide from Help at any time.

## Make the pads yours

- **Pointer:** independent sensitivity, acceleration, smoothing, and tap stabilization.
- **Scroll:** adjustable sensitivity on either pad.
- **Zones:** five layouts, from two large regions to a nine-button grid, with a keyboard or mouse action for each area.
- **Touch taps and rear buttons:** assign clicks or keys, including L4, L5, R4, and R5.
- **Gyro mouse and grip touch:** aim with motion and assign independent contact-held keys or mouse buttons. Requires sensor reports from the puck; [calibration and availability](docs/USING.md#gyro-mouse-and-grip-touch).
- **Profiles:** save complete setups and switch from the window or menu bar.

Both pads stay editable together. The window fits its contents automatically, including expanded tuning, and scrolls on smaller screens. Light mode uses blue accents; dark mode uses the Compass icon's teal.

![Paddr's light mapping workspace](docs/images/paddr-profile-overview-light.png)

See the [mapping guide](docs/USING.md) for profiles, Zones, advanced tuning, and output behavior. [Screenshot notes](docs/images/README.md) record how the captures were made.

## Play without a Steam launch path

Paddr works with directly launched games such as **World of Warcraft**. Steam, Steam Input, and Steam Overlay are not required. It emits ordinary mouse, scroll, and keyboard events and does not inject into games, change controller firmware, or remap Apple's native gamepad inputs.

Games may alternate controller and keyboard/mouse prompts. Compatibility depends on Apple's native controller service and the puck; broader hardware and game testing remains welcome. Per-app profiles and additional/custom zone layouts are planned.

## Documentation and development

- [Mapping guide](docs/USING.md)
- [CLI and configuration reference](docs/CLI.md)
- [Build from source](docs/BUILDING.md)
- [Contributing and validation](CONTRIBUTING.md)
- [Report a problem](https://github.com/zachspartofaday/Paddr/issues)

## License

[MIT](LICENSE), with required third-party attribution in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

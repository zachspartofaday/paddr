import AppKit
import SwiftUI
import XCTest
import PaddrCore
@testable import PaddrMenu

@MainActor
final class BespokeControlInteractionTests: XCTestCase {
    func testSquaredSwitchHasBinarySemanticsAndExactlyOneWritePerActivation() async throws {
        var value = false
        var writes = 0
        let host = NSHostingView(rootView: PaddrTuningSwitch(title: "Pointer smoothing",
            isOn: Binding(get: { value }, set: { value = $0; writes += 1 }),
            accessibilityIdentifier: "test.tuning"))
        let window = window(host, width: 52, height: 32)
        defer { window.close() }
        await settle(host)
        let control = try XCTUnwrap(descendants(PaddrTuningSwitchButton.self, host).first)
        XCTAssertEqual(control.bounds.size, NSSize(width: 52, height: 32))
        XCTAssertTrue(window.makeFirstResponder(control))
        try export(host, name: "focused-switch")
        XCTAssertEqual(control.trackRect.size, NSSize(width: 44, height: 24))
        XCTAssertEqual(control.thumbRect.size, NSSize(width: 18, height: 18))
        XCTAssertEqual(control.thumbRect.minX - control.trackRect.minX, 3)
        XCTAssertEqual(control.accessibilityRole(), .checkBox)
        XCTAssertEqual(control.accessibilitySubrole(), .switch)
        XCTAssertEqual(control.accessibilityRoleDescription(), "switch")
        XCTAssertNil(control.accessibilityChildren(), "One binary control must not expose its backing cell as a second stop")
        XCTAssertEqual(control.accessibilityValueDescription(), "Off")
        XCTAssertEqual(control.accessibilityLabel(), "Pointer smoothing")
        XCTAssertEqual((control.accessibilityValue() as? NSNumber)?.intValue, 0)
        control.performClick(nil)
        XCTAssertTrue(value)
        XCTAssertEqual(writes, 1)
        await settle(host)
        XCTAssertEqual(control.thumbRect.minX - control.trackRect.minX, 23)
        XCTAssertTrue(control.accessibilityPerformPress())
        XCTAssertFalse(value)
        XCTAssertEqual(writes, 2)
        control.keyDown(with: try key(" ", code: 49))
        XCTAssertTrue(value)
        XCTAssertEqual(writes, 3)
        control.isEnabled = false
        control.performClick(nil)
        XCTAssertFalse(control.accessibilityPerformPress())
        control.keyDown(with: try key(" ", code: 49))
        XCTAssertEqual(writes, 3)
        XCTAssertFalse(control.isAccessibilityEnabled())
    }

    func testTuningSwitchMirrorsBothStatesWithoutRemountingOrWriting() async throws {
        for initialValue in [false, true] {
            var value = initialValue
            var writes = 0
            let toggle = PaddrTuningSwitch(title: "Pointer smoothing",
                isOn: Binding(get: { value }, set: { value = $0; writes += 1 }),
                accessibilityIdentifier: "test.tuning.rtl")
            let host = NSHostingView(rootView: toggle.environment(\.layoutDirection, .leftToRight))
            let window = window(host, width: 52, height: 32)
            defer { window.close() }
            await settle(host)
            let control = try XCTUnwrap(descendants(PaddrTuningSwitchButton.self, host).first)
            XCTAssertTrue(window.makeFirstResponder(control))
            let ltrThumb = control.thumbRect
            XCTAssertEqual(ltrThumb.minX - control.trackRect.minX, initialValue ? 23 : 3)

            host.rootView = toggle.environment(\.layoutDirection, .rightToLeft)
            await settle(host)
            XCTAssertTrue(descendants(PaddrTuningSwitchButton.self, host).first === control)
            XCTAssertTrue(window.firstResponder === control)
            XCTAssertEqual(control.thumbRect.minX, control.bounds.width - ltrThumb.maxX)
            XCTAssertEqual(value, initialValue)
            XCTAssertEqual(writes, 0, "Changing direction must not mutate the setting")
            XCTAssertEqual((control.accessibilityValue() as? NSNumber)?.boolValue, initialValue)
            try export(control, name: "switch-rtl-\(initialValue ? "on" : "off")")

            XCTAssertTrue(control.accessibilityPerformPress())
            await settle(host)
            XCTAssertEqual(value, !initialValue)
            XCTAssertEqual(writes, 1)
            XCTAssertEqual(control.thumbRect.minX - control.trackRect.minX, value ? 3 : 23)
            control.keyDown(with: try key(" ", code: 49))
            await settle(host)
            XCTAssertEqual(value, initialValue)
            XCTAssertEqual(writes, 2)
            XCTAssertTrue(window.firstResponder === control)

            host.rootView = toggle.environment(\.layoutDirection, .leftToRight)
            await settle(host)
            XCTAssertTrue(descendants(PaddrTuningSwitchButton.self, host).first === control)
            XCTAssertEqual(control.thumbRect, ltrThumb)
            XCTAssertEqual(writes, 2)
        }
    }

    func testModeGroupArrowsRemainSingleSelectionAndRetainFirstResponder() async throws {
        var mode = PadMode.mouse
        var writes = 0
        let host = NSHostingView(rootView: PadModePicker(selection: Binding(get: { mode },
            set: { mode = $0; writes += 1 }), accessibilityIdentifier: "paddr.pad-mode.left"))
        let window = window(host, width: 272, height: 32)
        defer { window.close() }
        await settle(host)
        let control = try XCTUnwrap(descendants(PaddrModeSegmentedControl.self, host).first)
        XCTAssertEqual(control.bounds.size, NSSize(width: 272, height: 32))
        XCTAssertEqual(control.segmentRect(0).size, NSSize(width: 65.5, height: 28))
        XCTAssertEqual(control.segmentRect(1).minX - control.segmentRect(0).maxX, 2)
        XCTAssertEqual(control.trackingMode, .selectOne)
        XCTAssertEqual(control.accessibilityLabel(), "Left trackpad behavior")
        XCTAssertTrue(window.makeFirstResponder(control))
        try export(host, name: "focused-mode")
        control.keyDown(with: try key("\u{F703}", code: 124))
        XCTAssertEqual(mode, .scroll)
        XCTAssertEqual(writes, 1)
        control.keyDown(with: try key("\u{F702}", code: 123))
        XCTAssertEqual(mode, .mouse)
        XCTAssertEqual(writes, 2)
        XCTAssertEqual((0..<4).filter { control.isSelected(forSegment: $0) }, [1])
        XCTAssertTrue(window.firstResponder === control)
        let cell = try XCTUnwrap(control.cell as? NSSegmentedCell)
        XCTAssertEqual(cell.accessibilityRole(), .radioGroup)
        XCTAssertEqual(cell.accessibilityLabel(), "Left trackpad behavior")
        let children = try XCTUnwrap(cell.accessibilityChildren())
        XCTAssertEqual(children.count, 4)
        XCTAssertEqual(children.compactMap { ($0 as AnyObject).accessibilityRole?() }, Array(repeating: .radioButton, count: 4))
        XCTAssertEqual(children.compactMap { ($0 as AnyObject).accessibilityLabel?() }, ["Off", "Pointer", "Scroll", "Zones"])
        let selected = children.compactMap { object -> NSNumber? in
            (object as? NSObject)?.perform(NSSelectorFromString("accessibilityValue"))?.takeUnretainedValue() as? NSNumber
        }
        XCTAssertEqual(selected.map(\.intValue), [0, 1, 0, 0])
        let zones = children[3] as AnyObject
        // AppKit's private NSAccessibilitySegment proxy responds to the public
        // selector but does not declare the modern Bool-returning protocol.
        // Verify its observable action/state rather than an untyped return ABI.
        let proxy = try XCTUnwrap(zones as? NSObject)
        let press = NSSelectorFromString("accessibilityPerformPress")
        XCTAssertTrue(proxy.responds(to: press))
        _ = proxy.perform(press)
        XCTAssertEqual(mode, .dpad)
        XCTAssertEqual(writes, 3)
        control.isEnabled = false
        control.keyDown(with: try key("\u{F703}", code: 124))
        let off = try XCTUnwrap(children[0] as? NSObject)
        _ = off.perform(press)
        XCTAssertEqual(control.selectedSegment, 3)
        XCTAssertEqual(mode, .dpad)
        XCTAssertEqual(writes, 3)
    }

    func testNativeMenusPreserveNoneRawCheckmarksAndOneTypedWrite() async throws {
        var value: String? = "code:123"
        var writes = 0
        let host = NSHostingView(rootView: OptionalOutputBindingPicker(
            selection: Binding(get: { value }, set: { value = $0; writes += 1 }), title: "Touch tap action"))
        let window = window(host, width: 192, height: 100)
        defer { window.close() }
        await settle(host)
        let control = try XCTUnwrap(descendants(PaddrPopUpButton.self, host).first)
        XCTAssertEqual(control.bounds.width, 192, accuracy: 0.5)
        XCTAssertEqual(control.bounds.height, 32, accuracy: 0.5)
        XCTAssertEqual(control.itemArray.filter { $0.state == .on }.count, 1)
        XCTAssertEqual(control.titleOfSelectedItem, OutputBindingText.string(for: "code:123"))
        XCTAssertTrue(window.makeFirstResponder(control))
        control.selectItem(at: 0)
        _ = control.sendAction(control.action, to: control.target)
        XCTAssertNil(value)
        XCTAssertEqual(writes, 1)
        await settle(host)
        XCTAssertEqual(control.titleOfSelectedItem, "None")
        XCTAssertEqual(control.selectedItem?.state, .on)
        XCTAssertTrue(window.firstResponder === control)
        XCTAssertNotNil(control.menu)
        let cell = try XCTUnwrap(control.cell as? NSPopUpButtonCell)
        XCTAssertEqual(cell.accessibilityRole(), .popUpButton)
        XCTAssertEqual(cell.accessibilityLabel(), "Touch tap action")
        XCTAssertEqual(cell.accessibilityValue() as? String, "None")
    }

    func testNativeMenuEscapeCancelsWithoutWriteAndRestoresFocus() async throws {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let app = NSApplication.shared
            var value = 0
            var writes = 0
            let host = NSHostingView(rootView: PaddrMenuPicker(title: "Profile",
                selection: Binding(get: { value }, set: { value = $0; writes += 1 }),
                options: [.init(value: 0, title: "Default"), .init(value: 1, title: "Editable")])
                .environment(\.layoutDirection, direction))
            let window = window(host, width: 192, height: 32)
            defer { window.close() }
            await settle(host)
            let control = try XCTUnwrap(descendants(PaddrPopUpButton.self, host).first)
            let menu = try XCTUnwrap(control.menu)
            let observer = EscapeMenuObserver(app: app, window: window)
            menu.delegate = observer
            XCTAssertTrue(window.makeFirstResponder(control))
            window.orderFront(nil)
            // Post Escape into the native menu loop; fallback prevents a hung test.
            control.performClick(nil)
            XCTAssertTrue(observer.opened)
            XCTAssertTrue(observer.closed)
            XCTAssertFalse(observer.usedFallback)
            XCTAssertEqual(value, 0)
            XCTAssertEqual(writes, 0)
            XCTAssertTrue(window.firstResponder === control)
        }
    }

    func testClosedMenuMirrorsContentWithoutChangingSelectionOrWidth() async throws {
        let values = ["None", "A deliberately long profile name that must wrap without covering its chevrons",
                      "ملف World of Warcraft 123"]
        for (index, value) in values.enumerated() {
            let picker = PaddrMenuPicker(title: "Profile", selection: .constant(0),
                options: [.init(value: 0, title: value), .init(value: 1, title: "Default")])
            let host = NSHostingView(rootView: picker.environment(\.layoutDirection, .leftToRight))
            let window = window(host, width: 192, height: 160)
            defer { window.close() }
            await settle(host)
            let control = try XCTUnwrap(descendants(PaddrPopUpButton.self, host).first)
            let ltrText = control.valueRect
            let ltrChevron = control.chevronRect
            let height = control.bounds.height
            XCTAssertEqual(control.userInterfaceLayoutDirection, .leftToRight)
            XCTAssertEqual(control.valueAlignment, .left)
            XCTAssertLessThan(ltrText.maxX, ltrChevron.minX)
            try export(control, name: "selector-ltr-\(index)")

            // Change the environment on the same mounted selector.
            host.rootView = picker.environment(\.layoutDirection, .rightToLeft)
            await settle(host)
            XCTAssertTrue(descendants(PaddrPopUpButton.self, host).first === control)
            XCTAssertEqual(control.userInterfaceLayoutDirection, .rightToLeft)
            XCTAssertEqual(control.valueAlignment, .right)
            XCTAssertEqual(control.bounds.width, 192, accuracy: 0.5)
            XCTAssertEqual(control.bounds.height, height, accuracy: 0.5)
            XCTAssertEqual(control.valueRect.minX, control.bounds.width - ltrText.maxX)
            XCTAssertEqual(control.chevronRect.minX, control.bounds.width - ltrChevron.maxX)
            XCTAssertLessThan(control.chevronRect.maxX, control.valueRect.minX)
            XCTAssertEqual(control.titleOfSelectedItem, value)
            XCTAssertEqual(control.selectedItem?.state, .on)
            XCTAssertEqual(control.itemArray.filter { $0.state == .on }.count, 1)
            try export(control, name: "selector-rtl-\(index)")
        }
    }

    func testLongMenuValueGrowsAndDisabledSelectionCannotWrite() async throws {
        var value = 0
        var writes = 0
        let long = "A profile with a deliberately long name that must remain fully readable in its closed selector"
        let host = NSHostingView(rootView: PaddrMenuPicker(title: "Profile",
            selection: Binding(get: { value }, set: { value = $0; writes += 1 }),
            options: [.init(value: 0, title: long), .init(value: 1, title: "Default")]).disabled(true))
        host.frame = NSRect(x: 0, y: 0, width: 192, height: 160)
        await settle(host)
        let control = try XCTUnwrap(descendants(PaddrPopUpButton.self, host).first)
        XCTAssertGreaterThan(control.bounds.height, 32)
        XCTAssertEqual(control.bounds.height, control.height(for: 192), accuracy: 0.5)
        control.selectItem(at: 1)
        _ = control.sendAction(control.action, to: control.target)
        XCTAssertEqual(value, 0)
        XCTAssertEqual(writes, 0)
    }

    func testActionMenuRetainsItemGatesAndIts32PointVisibleTarget() async throws {
        var calls = 0
        let host = NSHostingView(rootView: PaddrActionMenu(title: "Profile actions", systemImage: "ellipsis.circle",
            actions: [.init(title: "Rename Profile", isEnabled: false) { calls += 100 },
                      .separator, .init(title: "New Profile") { calls += 1 }],
            accessibilityIdentifier: "test.actions", accessibilityValue: "Editable profile"))
        host.frame = NSRect(x: 0, y: 0, width: 32, height: 32)
        await settle(host)
        let control = try XCTUnwrap(descendants(PaddrPopUpButton.self, host).first)
        XCTAssertEqual(control.bounds.size, NSSize(width: 32, height: 32))
        XCTAssertEqual(control.iconName, "ellipsis.circle")
        let menu = try XCTUnwrap(control.menu)
        XCTAssertFalse(menu.items[1].isEnabled)
        menu.performActionForItem(at: 1)
        XCTAssertEqual(calls, 0)
        menu.performActionForItem(at: 3)
        XCTAssertEqual(calls, 1)
    }

    func testBothExpandedEditorsKeepTheirSwitchesMountedAndFocusedAcrossReflow() async throws {
        var configuration = PaddrConfiguration.default
        configuration.left.mode = .mouse
        configuration.right.mode = .mouse
        let host = NSHostingView(rootView: DualPadConfigurationView(
            configuration: Binding(get: { configuration }, set: { configuration = $0 }),
            appearsEnabled: true, isEditable: true, initialTuningExpanded: true))
        let window = window(host, width: 1080, height: 1400)
        defer { window.close() }
        await settle(host)
        let original = descendants(PaddrTuningSwitchButton.self, host)
        XCTAssertEqual(original.count, 8)
        let focused = try XCTUnwrap(original.first { $0.identifier?.rawValue == "paddr.pad.left.pointer-smoothing" })
        XCTAssertTrue(window.makeFirstResponder(focused))
        host.frame.size.width = 680
        await settle(host)
        let reflowed = descendants(PaddrTuningSwitchButton.self, host)
        XCTAssertEqual(Set(original.map(ObjectIdentifier.init)), Set(reflowed.map(ObjectIdentifier.init)))
        XCTAssertTrue(window.firstResponder === focused)
        focused.keyDown(with: try key(" ", code: 49))
        XCTAssertTrue(configuration.left.pointerSmoothingEnabled)
        XCTAssertFalse(configuration.right.pointerSmoothingEnabled)
    }

    func testZoneMapKeyboardFocusRemainsDistinctFromSelectedRegion() async throws {
        var zone = ButtonZone.topLeft
        let host = NSHostingView(rootView: ZonePadMap(layout: .gridNine, deadzone: 0,
            configuration: PadConfiguration(mode: .dpad),
            selection: Binding(get: { zone }, set: { zone = $0 }))
            .frame(width: 190, height: 182).padding(8))
        let window = window(host, width: 206, height: 198)
        defer { window.close() }
        await settle(host)
        let app = NSApplication.shared
        let policy = app.activationPolicy()
        XCTAssertTrue(app.setActivationPolicy(.accessory))
        defer { app.setActivationPolicy(policy) }
        app.activate()
        window.makeKeyAndOrderFront(nil)
        for _ in 0..<100 {
            if window.isKeyWindow { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard window.isKeyWindow else {
            throw XCTSkip("This XCTest host refuses key-window status; live SwiftUI zone-map focus and arrow dispatch remain manual checks")
        }
        window.selectNextKeyView(nil)
        await settle(host)
        let responder = try XCTUnwrap(window.firstResponder)
        responder.keyDown(with: try key("\u{F703}", code: 124))
        await settle(host)
        XCTAssertEqual(zone, .up)
        XCTAssertTrue(window.firstResponder === responder)
        try export(host, name: "focused-zone-map")
    }

    func testFilledModeSelectionAndLocalHoverSurviveMaterialAndOpaqueFallbacks() async throws {
        let host = NSHostingView(rootView: PadModePicker(selection: .constant(.dpad),
            accessibilityIdentifier: "paddr.pad-mode.left")
            .environment(\._accessibilityReduceTransparency, false)
            .environment(\._accessibilityReduceMotion, false))
        let window = window(host, width: 272, height: 32)
        defer { window.close() }
        await settle(host)
        let control = try XCTUnwrap(descendants(PaddrModeSegmentedControl.self, host).first)
        for theme in [NSAppearance.Name.aqua, .darkAqua] {
            host.appearance = NSAppearance(named: theme)
            for fallback in [false, true] {
                host.rootView = PadModePicker(selection: .constant(.dpad), accessibilityIdentifier: "paddr.pad-mode.left")
                    .environment(\._accessibilityReduceTransparency, fallback)
                    .environment(\._accessibilityReduceMotion, fallback)
                await settle(host)
                control.updateHover(at: CGPoint(x: -1, y: -1))
                let before = try raster(control)
                let selectedPoint = CGPoint(x: control.segmentRect(3).midX, y: 6)
                let otherPoint = CGPoint(x: control.segmentRect(1).midX, y: 6)
                let selected = try sample(before, selectedPoint)
                let other = try sample(before, otherPoint)
                XCTAssertGreaterThan(distance(selected, other), 0.3, "Selection must be filled, not outline-only")
                control.updateHover(at: CGPoint(x: control.segmentRect(1).midX, y: 16))
                let different = try raster(control)
                XCTAssertLessThan(distance(selected, try sample(different, selectedPoint)), 0.01,
                    "Hovering Pointer must leave selected Zones intact")
                XCTAssertGreaterThan(distance(other, try sample(different, otherPoint)), 0.01)
                try export(host, name: "mode-hover-other-\(fallback ? "opaque" : "glass")")
                control.updateHover(at: CGPoint(x: control.segmentRect(3).midX, y: 16))
                let same = try raster(control)
                XCTAssertGreaterThan(distance(selected, try sample(same, selectedPoint)), 0.01)
                XCTAssertGreaterThan(distance(try sample(same, selectedPoint), other), 0.3)
                try export(host, name: "mode-hover-selected-\(fallback ? "opaque" : "glass")")
                control.isEnabled = false
                let disabled = try raster(control)
                XCTAssertGreaterThan(distance(try sample(disabled, selectedPoint), try sample(disabled, otherPoint)), 0.1)
                try export(host, name: "mode-disabled-\(fallback ? "opaque" : "glass")")
                control.isEnabled = true
            }
        }
    }

    func testMaterialFallbackRetainsNativeHitAccessibilityAndFocusOwners() async throws {
        let host = NSHostingView(rootView: materialFixture(PaddrAppearance()))
        let window = window(host, width: 540, height: 40)
        defer { window.close() }
        await settle(host)
        let menu = try XCTUnwrap(descendants(PaddrPopUpButton.self, host).first)
        let toggle = try XCTUnwrap(descendants(PaddrTuningSwitchButton.self, host).first)
        let mode = try XCTUnwrap(descendants(PaddrModeSegmentedControl.self, host).first)
        for appearance in [PaddrAppearance(), PaddrAppearance(reduceTransparency: true),
                           PaddrAppearance(colorSchemeContrast: .increased), PaddrAppearance(reduceMotion: true)] {
            host.rootView = materialFixture(appearance)
            await settle(host)
            XCTAssertTrue(descendants(PaddrPopUpButton.self, host).first === menu)
            XCTAssertTrue(descendants(PaddrTuningSwitchButton.self, host).first === toggle)
            XCTAssertTrue(descendants(PaddrModeSegmentedControl.self, host).first === mode)
            XCTAssertEqual(mode.controlAppearance, appearance)
            XCTAssertEqual(appearance.usesControlGlass, !appearance.usesOpaqueFallback && !appearance.hasIncreasedContrast)
            for control in [menu as NSControl, toggle, mode] {
                XCTAssertTrue(window.makeFirstResponder(control))
                XCTAssertTrue(window.firstResponder === control)
                let point = CGPoint(x: control.bounds.midX, y: control.bounds.midY)
                XCTAssertTrue(host.hitTest(host.convert(point, from: control)) === control,
                    "Material backgrounds must leave the native control as the full hierarchy hit owner")
            }
            XCTAssertNil(toggle.accessibilityChildren())
            XCTAssertEqual((mode.cell?.accessibilityChildren())?.count, 4)
            XCTAssertEqual(menu.titleOfSelectedItem, "Editable")
            XCTAssertEqual(toggle.state, .on)
            XCTAssertEqual(mode.selectedSegment, 3)
        }
    }

    private func materialFixture(_ appearance: PaddrAppearance) -> some View {
        HStack {
            PaddrMenuPicker(title: "Profile", selection: .constant(0), options: [.init(value: 0, title: "Editable")])
            PaddrTuningSwitch(title: "Smoothing", isOn: .constant(true), accessibilityIdentifier: "test.switch")
            PadModePicker(selection: .constant(.dpad), accessibilityIdentifier: "paddr.pad-mode.left")
        }
        .environment(\._accessibilityReduceTransparency, appearance.usesOpaqueFallback)
        .environment(\._colorSchemeContrast, appearance.hasIncreasedContrast ? .increased : .standard)
        .environment(\._accessibilityReduceMotion, appearance.reducesMotion)
    }

    func testModePointerTrackingUsesLocalSegmentAndClearsAtEdgesWithoutWriting() async throws {
        var writes = 0
        let host = NSHostingView(rootView: PadModePicker(selection: Binding(get: { .dpad }, set: { _ in writes += 1 }),
            accessibilityIdentifier: "paddr.pad-mode.left"))
        let window = window(host, width: 272, height: 32)
        defer { window.close() }
        await settle(host)
        let control = try XCTUnwrap(descendants(PaddrModeSegmentedControl.self, host).first)
        for index in 0..<4 {
            let rect = control.segmentRect(index)
            for point in [CGPoint(x: rect.minX + 0.01, y: rect.midY), CGPoint(x: rect.maxX - 0.01, y: rect.midY)] {
                let location = control.convert(point, to: nil)
                let event = try XCTUnwrap(NSEvent.mouseEvent(with: .mouseMoved, location: location,
                    modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
                    eventNumber: 0, clickCount: 0, pressure: 0))
                control.mouseMoved(with: event)
                XCTAssertEqual(control.hoveredSegment, index)
            }
        }
        for point in [CGPoint(x: -1, y: 16), CGPoint(x: 273, y: 16), CGPoint(x: 80, y: -1),
                      CGPoint(x: 80, y: 33), CGPoint(x: 68.5, y: 16)] {
            control.updateHover(at: point)
            XCTAssertNil(control.hoveredSegment)
        }
        control.setEnabled(false, forSegment: 1)
        control.updateHover(at: CGPoint(x: 100, y: 16))
        XCTAssertNil(control.hoveredSegment)
        control.isEnabled = false
        control.updateHover(at: CGPoint(x: 200, y: 16))
        XCTAssertNil(control.hoveredSegment)
        XCTAssertEqual(control.selectedSegment, 3)
        XCTAssertEqual(writes, 0)
        control.updateTrackingAreas()
        XCTAssertTrue(control.trackingAreas.contains { $0.owner === control && $0.options.contains(.mouseMoved) })
    }

    func testNativeModePressKeepsPersistentSelectionAndDispatchesOnce() async throws {
        for (theme, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            var value = PadMode.dpad
            var writes = 0
            let host = NSHostingView(rootView: PadModePicker(selection: Binding(get: { value }, set: { value = $0; writes += 1 }),
                accessibilityIdentifier: "paddr.pad-mode.left"))
            host.appearance = NSAppearance(named: appearance)
            let window = window(host, width: 272, height: 32)
            defer { window.close() }
            window.makeKeyAndOrderFront(nil)
            await settle(host)
            let control = try XCTUnwrap(descendants(PaddrModeSegmentedControl.self, host).first)
            XCTAssertTrue(window.makeFirstResponder(control))
            // An inactive CLI host can consume its first native mouse event for
            // activation. Prime with the already-selected item; counted presses
            // below still require exactly one dispatch and the expected value.
            for (state, index) in [("activation", 3), ("other", 1), ("selected", 1)] {
                let initial = control.selectedSegment
                let location = control.convert(CGPoint(x: control.segmentRect(index).midX, y: 16), to: nil)
                let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: location,
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
                let up = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: location,
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime + 0.1, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 2, clickCount: 1, pressure: 0))
                var observedPress = false
                let beforeWrites = writes
                let observer = NativePressObserver { [self] in
                    observedPress = control.pressedSegment == index
                    XCTAssertEqual(control.selectedSegment, initial, "The filled current mode remains until commit")
                    // Never change appearance or relayout inside native mouse tracking.
                    if let path = ProcessInfo.processInfo.environment["PADDR_UI_EVIDENCE_DIR"] {
                        do {
                            let bitmap = try raster(control)
                            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                            try png.write(to: URL(fileURLWithPath: path)
                                .appendingPathComponent("mode-pressed-\(state)-\(theme).png"))
                        } catch { XCTFail("\(error)") }
                    }
                    NSApplication.shared.postEvent(up, atStart: true)
                }
                let releaseTimer = Timer(timeInterval: 0.05, target: observer, selector: #selector(NativePressObserver.fire),
                    userInfo: nil, repeats: false)
                RunLoop.main.add(releaseTimer, forMode: .eventTracking)
                RunLoop.main.add(releaseTimer, forMode: .default)
                control.mouseDown(with: down)
                XCTAssertTrue(observedPress)
                XCTAssertNil(control.pressedSegment)
                XCTAssertEqual(value, state == "activation" ? .dpad : .mouse,
                    "\(theme)/\(state), key=\(window.isKeyWindow)")
                if state != "activation" {
                    XCTAssertEqual(writes, beforeWrites + 1, "\(theme)/\(state)")
                }
                XCTAssertEqual(control.selectedSegment, index, "\(theme)/\(state)")
            }
        }
    }

    func testSelectorAndSwitchHoverRemainSecondaryWithoutChangingValues() async throws {
        let host = NSHostingView(rootView: materialFixture(PaddrAppearance()))
        let window = window(host, width: 540, height: 40)
        defer { window.close() }
        await settle(host)
        let menu = try XCTUnwrap(descendants(PaddrPopUpButton.self, host).first)
        let toggle = try XCTUnwrap(descendants(PaddrTuningSwitchButton.self, host).first)
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            host.appearance = NSAppearance(named: name)
            for control in [menu as NSControl, toggle] {
                let point = CGPoint(x: control.bounds.midX, y: 6)
                let idle = try sample(raster(control), point)
                let event = try XCTUnwrap(NSEvent.enterExitEvent(with: .mouseEntered, location: .zero,
                    modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
                    eventNumber: 0, trackingNumber: 0, userData: nil))
                control.mouseEntered(with: event)
                let hover = try sample(raster(control), point)
                XCTAssertGreaterThan(distance(idle, hover), 0.01)
                try export(host, name: control === menu ? "selector-hover" : "switch-hover")
                control.mouseExited(with: event)
                XCTAssertLessThan(distance(idle, try sample(raster(control), point)), 0.01)
            }
            XCTAssertEqual(menu.titleOfSelectedItem, "Editable")
            XCTAssertEqual(toggle.state, .on)
        }
    }

    func testPadAndControlStrokeSamplesAtOneAndTwoPixelsPerPoint() async throws {
        let host = NSHostingView(rootView: VStack(spacing: 16) {
            PadModePicker(selection: .constant(.dpad), accessibilityIdentifier: "paddr.pad-mode.left")
            PadModePreview(mode: .scroll, deadzone: 0).frame(width: 190, height: 182)
                .overlay { PaddrPadFocusRing() }
            HStack {
                Button("Save & Apply") {}.paddrActionButton(.primary)
                Button("Open setup…") {}.paddrActionButton(.secondary)
            }
        }
        // Explicit opaque geometry evidence: cached AppKit display cannot capture
        // a mixed regular/clear native glass composition. Normal material is
        // verified by the WindowServer exporter, never inferred from these PNGs.
        .environment(\._accessibilityReduceTransparency, true))
        let window = window(host, width: 272, height: 278)
        defer { window.close() }
        await settle(host)
        for (theme, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            host.appearance = NSAppearance(named: appearance)
            for scale in [1, 2] {
                let bitmap = try raster(host, scale: scale)
                XCTAssertEqual(bitmap.pixelsWide, 272 * scale)
                XCTAssertEqual(bitmap.pixelsHigh, 278 * scale)
                var rimColor: NSColor?
                host.effectiveAppearance.performAsCurrentDrawingAppearance {
                    rimColor = NSColor(PaddrStyle.textSecondary).usingColorSpace(.sRGB)
                }
                let expectedRim = try XCTUnwrap(rimColor)
                for y in [CGFloat(0.5), 1.5] {
                    XCTAssertLessThan(distance(try sample(bitmap, CGPoint(x: 136, y: y)), expectedRim), 0.06,
                        "The structural rim must cover both complete pixels/points without a fractional ghost seam")
                }
                let selected = try sample(bitmap, CGPoint(x: 238, y: 6))
                let idle = try sample(bitmap, CGPoint(x: 102, y: 6))
                XCTAssertGreaterThan(distance(selected, idle), 0.3)
                if let path = ProcessInfo.processInfo.environment["PADDR_UI_EVIDENCE_DIR"] {
                    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    try png.write(to: URL(fileURLWithPath: path)
                        .appendingPathComponent("stroke-samples-opaque-\(scale)x-\(theme).png"))
                }
            }
        }
    }

    private func raster(_ view: NSView, scale: Int = 2) throws -> NSBitmapImageRep {
        view.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: Int(view.bounds.width) * scale, pixelsHigh: Int(view.bounds.height) * scale,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        bitmap.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }
    private func sample(_ bitmap: NSBitmapImageRep, _ point: CGPoint) throws -> NSColor {
        try XCTUnwrap(bitmap.colorAt(x: Int(point.x * CGFloat(bitmap.pixelsWide) / bitmap.size.width),
            y: Int(point.y * CGFloat(bitmap.pixelsHigh) / bitmap.size.height))?.usingColorSpace(.sRGB))
    }
    private func distance(_ a: NSColor, _ b: NSColor) -> CGFloat {
        abs(a.redComponent - b.redComponent) + abs(a.greenComponent - b.greenComponent) + abs(a.blueComponent - b.blueComponent)
    }

    private func export(_ view: NSView, name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["PADDR_UI_EVIDENCE_DIR"] else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let original = view.appearance
        defer { view.appearance = original }
        for (theme, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            view.appearance = NSAppearance(named: appearance)
            view.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: directory.appendingPathComponent("\(name)-\(theme).png"))
        }
    }

    private func key(_ characters: String, code: UInt16) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code))
    }
    private func window(_ host: NSView, width: CGFloat, height: CGFloat) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.contentView = host
        return window
    }
    private func settle(_ view: NSView) async {
        for _ in 0..<12 { view.layoutSubtreeIfNeeded(); await Task.yield() }
    }
    private func descendants<T: NSView>(_ type: T.Type, _ view: NSView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, $0) }
    }
}

@MainActor
private final class EscapeMenuObserver: NSObject, NSMenuDelegate {
    let app: NSApplication
    let window: NSWindow
    var opened = false
    var closed = false
    var usedFallback = false
    init(app: NSApplication, window: NSWindow) { self.app = app; self.window = window }
    private weak var trackingMenu: NSMenu?
    private var escapeTimer: Timer?
    private var fallbackTimer: Timer?
    func menuWillOpen(_ menu: NSMenu) {
        opened = true
        trackingMenu = menu
        let escape = Timer(timeInterval: 0.05, target: self, selector: #selector(postEscape), userInfo: nil, repeats: false)
        let fallback = Timer(timeInterval: 1, target: self, selector: #selector(cancelIfStillOpen), userInfo: nil, repeats: false)
        escapeTimer = escape
        fallbackTimer = fallback
        // Main-queue callbacks aren't guaranteed inside AppKit's nested menu loop.
        // Its documented event-tracking run-loop mode must deliver the actual key.
        for timer in [escape, fallback] {
            RunLoop.main.add(timer, forMode: .eventTracking)
            RunLoop.main.add(timer, forMode: .default)
        }
    }
    @objc private func postEscape() {
        if let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}", isARepeat: false, keyCode: 53) {
            app.postEvent(escape, atStart: true)
        }
    }
    @objc private func cancelIfStillOpen() {
        if !closed { usedFallback = true; trackingMenu?.cancelTracking() }
    }
    func menuDidClose(_ menu: NSMenu) {
        closed = true
        escapeTimer?.invalidate()
        fallbackTimer?.invalidate()
    }
}

@MainActor
private final class NativePressObserver: NSObject {
    let callback: () -> Void
    init(_ callback: @escaping () -> Void) { self.callback = callback }
    @objc func fire() { callback() }
}

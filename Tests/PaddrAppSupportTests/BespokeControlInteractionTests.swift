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
    func menuWillOpen(_ menu: NSMenu) {
        opened = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            if let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "\u{1B}",
                charactersIgnoringModifiers: "\u{1B}", isARepeat: false, keyCode: 53) {
                app.postEvent(escape, atStart: true)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
            if !closed { usedFallback = true; menu.cancelTracking() }
        }
    }
    func menuDidClose(_ menu: NSMenu) { closed = true }
}

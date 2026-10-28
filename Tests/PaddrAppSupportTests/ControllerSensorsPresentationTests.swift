import AppKit
import SwiftUI
import XCTest
import PaddrAppSupport
import PaddrCore
@testable import PaddrMenu

@MainActor
final class ControllerSensorsPresentationTests: XCTestCase {
    func testSensorPresentationDistinguishesUnavailableReleasedAndTouched() {
        XCTAssertEqual(String(localized: ControllerSensorPresentation.gripState(nil)), "Unavailable")
        XCTAssertEqual(String(localized: ControllerSensorPresentation.gripState(false)), "Released")
        XCTAssertEqual(String(localized: ControllerSensorPresentation.gripState(true)), "Touching")
        XCTAssertTrue(String(localized: ControllerSensorPresentation.gyroState(nil, configured: true))
            .contains("unavailable"))
        let calibrating = ControllerSensorStatus(grips: .init(leftTouched: false, rightTouched: false),
            motionAvailable: true, gyroStatus: .calibrating)
        XCTAssertEqual(String(localized: ControllerSensorPresentation.gyroState(calibrating, configured: true)),
            "Calibrating. Keep the controller still.")
        XCTAssertTrue(String(localized: ControllerSensorPresentation.gyroState(calibrating, configured: false))
            .contains("off in this draft"))
        let awaitingNeutral = ControllerSensorStatus(motionAvailable: true, gyroStatus: .unavailable)
        XCTAssertEqual(String(localized: ControllerSensorPresentation.gyroState(awaitingNeutral, configured: true)),
            "Waiting for output to arm before calibration.")
        XCTAssertEqual(String(localized: ControllerSensorPresentation.activationTitle(.rightGrip)), "Right grip touched")
        XCTAssertEqual(String(localized: ControllerSensorPresentation.activationTitle(.leftGrip)), "Left grip touched")
        XCTAssertEqual(String(localized: ControllerSensorPresentation.activationTitle(.eitherGrip)), "Either grip touched")
        XCTAssertEqual(String(localized: ControllerSensorPresentation.activationTitle(.eitherPad)), "Either trackpad touched")
        XCTAssertEqual(String(localized: ControllerSensorPresentation.activationTitle(.always)), "Always")
    }

    func testControllerSettingsFitNarrowWideRTLAndReadOnlyLayouts() async throws {
        for width in [CGFloat(560), 916] {
            for direction in [LayoutDirection.leftToRight, .rightToLeft] {
                for scheme in [ColorScheme.light, .dark] {
                    let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
                        gyro: .constant(.init()), gripTouch: .constant(.unassigned),
                        sensorStatus: nil, isEditable: false, initialTuningExpanded: true)
                        .frame(width: width)
                        .environment(\.layoutDirection, direction)
                        .environment(\.colorScheme, scheme)
                        .environment(\.accessibilityEnabled, true))
                    let window = makeWindow(host, width: width, height: 1200)
                    defer { window.close() }
                    await settle(host)
                    XCTAssertLessThanOrEqual(host.fittingSize.width, width + 0.5)
                    XCTAssertGreaterThan(host.fittingSize.height, 100)
                    XCTAssertLessThan(host.fittingSize.height, 1100)
                    let menus = descendants(PaddrPopUpButton.self, in: host)
                    XCTAssertEqual(menus.count, 3, "Two independent grip menus and one activation menu")
                    let names = Set(menus.compactMap { $0.accessibilityLabel() })
                    XCTAssertEqual(names, ["Left grip touch action", "Right grip touch action", "Gyro activation"])
                    for menu in menus {
                        XCTAssertFalse(menu.isEnabled)
                        assertFits(menu, in: host)
                    }
                    let switches = descendants(PaddrTuningSwitchButton.self, in: host)
                    XCTAssertEqual(switches.count, 3)
                    for control in switches {
                        XCTAssertFalse(control.isEnabled)
                        XCTAssertEqual(control.accessibilitySubrole(), .switch)
                        assertFits(control, in: host)
                    }
                    let activation = try XCTUnwrap(menus.first { $0.accessibilityLabel() == "Gyro activation" })
                    XCTAssertEqual(activation.itemTitles,
                        ["Right grip touched", "Left grip touched", "Either grip touched", "Either trackpad touched", "Always"])
                    let gripMenus = menus.filter { $0.accessibilityLabel() != "Gyro activation" }
                    XCTAssertEqual(gripMenus[0].bounds.width, gripMenus[1].bounds.width, accuracy: 0.5)
                }
            }
        }
    }

    func testGyroToggleAndGripMenusWriteOnlyTheirOwnDraftBindings() async throws {
        var gyro = GyroConfiguration()
        var grips = GripTouchConfiguration.unassigned
        let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
            gyro: Binding(get: { gyro }, set: { gyro = $0 }),
            gripTouch: Binding(get: { grips }, set: { grips = $0 }),
            sensorStatus: nil, isEditable: true))
        let window = makeWindow(host, width: 916, height: 700)
        defer { window.close() }
        await settle(host)
        let toggle = try XCTUnwrap(descendants(PaddrTuningSwitchButton.self, in: host).first)
        XCTAssertFalse(gyro.enabled)
        XCTAssertTrue(toggle.accessibilityPerformPress())
        await settle(host)
        XCTAssertTrue(gyro.enabled)
        XCTAssertNil(grips.left)
        XCTAssertNil(grips.right)
        let menus = descendants(PaddrPopUpButton.self, in: host)
        let left = try XCTUnwrap(menus.first { $0.accessibilityLabel() == "Left grip touch action" })
        let right = try XCTUnwrap(menus.first { $0.accessibilityLabel() == "Right grip touch action" })
        left.selectItem(withTitle: "Left click")
        XCTAssertTrue(left.sendAction(left.action, to: left.target))
        await settle(host)
        XCTAssertEqual(grips.left, TapBindingCatalog.leftMouseButton)
        XCTAssertNil(grips.right)
        right.selectItem(withTitle: "Right click")
        XCTAssertTrue(right.sendAction(right.action, to: right.target))
        await settle(host)
        XCTAssertEqual(grips.left, TapBindingCatalog.leftMouseButton)
        XCTAssertEqual(grips.right, TapBindingCatalog.rightMouseButton)
        XCTAssertEqual(gyro.activation, .rightGrip)
    }

    func testExpandedGyroSlidersKeepIndividualAccessibleNames() async throws {
        let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
            gyro: .constant(.init()), gripTouch: .constant(.unassigned),
            sensorStatus: nil, isEditable: true, initialTuningExpanded: true)
            .environment(\.accessibilityEnabled, true))
        let window = makeWindow(host, width: 916, height: 900)
        defer { window.close() }
        await settle(host)
        var visited = Set<ObjectIdentifier>()
        var sliderLabels: [String] = []
        var disclosureLabels: [String] = []
        func collect(_ element: AnyObject) {
            guard visited.insert(ObjectIdentifier(element)).inserted else { return }
            if element.accessibilityRole?() == .slider {
                sliderLabels.append(element.accessibilityLabel?() ?? "")
            }
            if element.accessibilityRole?() == .disclosureTriangle {
                disclosureLabels.append(element.accessibilityLabel?() ?? "")
            }
            for child in element.accessibilityChildren?() as? [Any] ?? [] {
                collect(child as AnyObject)
            }
        }
        collect(host)
        XCTAssertEqual(Set(sliderLabels), ["Gyro sensitivity", "Vertical sensitivity", "Gyro smoothing", "Noise threshold"],
            "The disclosure's name must not replace its child controls' accessible labels")
        XCTAssertEqual(sliderLabels.count, 4)
        XCTAssertEqual(disclosureLabels, ["Gyro tuning"],
            "The group must keep one correctly named native disclosure control: " + accessibilityTree(host))
    }

    func testGyroTuningLabelExpandsAndCollapsesInReadOnlyProfileWithoutEditing() async throws {
        var gyro = GyroConfiguration()
        var writes = 0
        let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
            gyro: Binding(get: { gyro }, set: { gyro = $0; writes += 1 }),
            gripTouch: .constant(.unassigned), sensorStatus: nil, isEditable: false)
            .environment(\.accessibilityEnabled, true).padding(20))
        let window = makeWindow(host, width: 916, height: 900)
        defer { window.close() }
        window.makeKeyAndOrderFront(nil)
        await settle(host)
        for expectedSwitchCount in [3, 1] {
            let disclosure = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.gyro.tuning"), accessibilityTree(host))
            let frame = try XCTUnwrap(disclosure.accessibilityFrame?())
            let location = window.convertPoint(fromScreen: CGPoint(x: frame.minX + 65, y: frame.maxY - 8))
            for (kind, pressure) in [(NSEvent.EventType.leftMouseDown, Float(1)), (.leftMouseUp, Float(0))] {
                let event = try XCTUnwrap(NSEvent.mouseEvent(with: kind, location: location, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 1, clickCount: 1, pressure: pressure))
                window.sendEvent(event)
            }
            await settle(host)
            let switches = descendants(PaddrTuningSwitchButton.self, in: host)
            XCTAssertEqual(switches.count, expectedSwitchCount)
            XCTAssertTrue(switches.allSatisfy { !$0.isEnabled })
            XCTAssertEqual(writes, 0)
        }
    }

    func testExportControllerSensorEvidence() async throws {
        guard let path = ProcessInfo.processInfo.environment["PADDR_SENSOR_UI_EVIDENCE_DIR"] else {
            throw XCTSkip("Set PADDR_SENSOR_UI_EVIDENCE_DIR to export sensor UI evidence")
        }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var gyro = GyroConfiguration()
        gyro.enabled = true
        let status = ControllerSensorStatus(grips: .init(leftTouched: false, rightTouched: true),
            motionAvailable: true, gyroStatus: .active)
        for (name, scheme, appearance) in [("light", ColorScheme.light, NSAppearance.Name.aqua),
                                          ("dark", ColorScheme.dark, NSAppearance.Name.darkAqua)] {
            for (suffix, width, direction) in [("wide", CGFloat(916), LayoutDirection.leftToRight),
                                                ("narrow-rtl", CGFloat(560), .rightToLeft)] {
                let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
                    gyro: .constant(gyro), gripTouch: .constant(.init(left: "space", right: "mouse-right")),
                    sensorStatus: status, isEditable: true, initialTuningExpanded: true)
                    .padding(20).environment(\.colorScheme, scheme).environment(\.layoutDirection, direction)
                    .foregroundStyle(PaddrStyle.textPrimary).tint(PaddrStyle.controlTint)
                    .background(PanelBackgroundView()))
                let window = makeWindow(host, width: width + 40, height: 1200)
                defer { window.close() }
                host.appearance = NSAppearance(named: appearance)
                await settle(host)
                host.frame.size.height = host.fittingSize.height
                await settle(host)
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try data.write(to: directory.appendingPathComponent("sensor-settings-\(name)-\(suffix).png"))
            }
        }
    }

    private func makeWindow(_ host: NSView, width: CGFloat, height: CGFloat) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: width, height: height),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        return window
    }

    private func settle(_ view: NSView) async {
        for _ in 0..<8 {
            view.layoutSubtreeIfNeeded()
            await Task.yield()
        }
    }

    private func descendants<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, in: $0) }
    }

    private func assertFits(_ control: NSView, in host: NSView, file: StaticString = #filePath, line: UInt = #line) {
        let frame = control.convert(control.bounds, to: host)
        XCTAssertGreaterThanOrEqual(frame.minX, -0.5, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minY, -0.5, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, host.bounds.maxX + 0.5, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxY, host.bounds.maxY + 0.5, file: file, line: line)
    }

    private func accessibilityTree(_ view: NSView) -> String {
        var visited = Set<ObjectIdentifier>()
        func describe(_ object: AnyObject) -> String {
            guard visited.insert(ObjectIdentifier(object)).inserted else { return "" }
            let label = object.accessibilityLabel?() ?? ""
            let identifier = object.accessibilityIdentifier?() ?? ""
            return "\(type(of: object)) [\(identifier)] \(label)\n" + (object.accessibilityChildren?() as? [Any] ?? [])
                .map { describe($0 as AnyObject) }.joined()
        }
        return describe(view)
    }

    private func accessibilityElement(in view: NSView, identifier: String) -> AnyObject? {
        var visited = Set<ObjectIdentifier>()
        func find(_ object: AnyObject) -> AnyObject? {
            guard visited.insert(ObjectIdentifier(object)).inserted else { return nil }
            if object.accessibilityIdentifier?() == identifier { return object }
            for child in object.accessibilityChildren?() as? [Any] ?? [] {
                if let result = find(child as AnyObject) { return result }
            }
            return nil
        }
        return find(view)
    }
}

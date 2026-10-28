import AppKit
import SwiftUI
import XCTest
import PaddrAppSupport
import PaddrCore
@testable import PaddrMenu

@MainActor
final class ControllerSensorsPresentationTests: XCTestCase {
    func testSensorPresentationDistinguishesContactAndCalibrationStates() {
        XCTAssertEqual(String(localized: ControllerSensorPresentation.gripState(nil)), "Unavailable")
        XCTAssertEqual(String(localized: ControllerSensorPresentation.gripState(false)), "Released")
        XCTAssertEqual(String(localized: ControllerSensorPresentation.gripState(true)), "Touching")
        XCTAssertEqual(String(localized: ControllerSensorPresentation.gyroPresentation(nil,
            draftEnabled: false, savedEnabled: false, isOutputEnabled: false).title), "Off")
        XCTAssertNil(ControllerSensorPresentation.gyroPresentation(nil,
            draftEnabled: false, savedEnabled: false, isOutputEnabled: false).instruction, "Off state has no permanent explanatory paragraph")
        for motionAvailable in [true, false] {
            let status = ControllerSensorStatus(motionAvailable: motionAvailable, gyroStatus: .off)
            XCTAssertEqual(String(localized: ControllerSensorPresentation.gyroPresentation(status,
                draftEnabled: true, savedEnabled: true, isOutputEnabled: false).title), "Calibration needed")
        }
        for (status, title, needsInstruction) in [(GyroStatus.calibrating, "Calibrating—hold still", true),
                                                (.ready, "Ready", false), (.active, "Aiming", false),
                                                (.unavailable, "Calibration needed", true)] {
            let presentation = ControllerSensorPresentation.gyroPresentation(.init(motionAvailable: true, gyroStatus: status),
                draftEnabled: true, savedEnabled: true, isOutputEnabled: true)
            XCTAssertEqual(String(localized: presentation.title), title)
            XCTAssertEqual(presentation.instruction != nil, needsInstruction)
        }
        let draftOnly = ControllerSensorPresentation.gyroPresentation(.init(motionAvailable: true, gyroStatus: .off),
            draftEnabled: true, savedEnabled: false, isOutputEnabled: true)
        XCTAssertEqual(String(localized: draftOnly.title), "Save & Apply needed")
        XCTAssertEqual(draftOnly.instruction.map { String(localized: $0) }, "Choose Save & Apply to enable gyro calibration.")
        let unsavedDisable = ControllerSensorPresentation.gyroPresentation(.init(motionAvailable: true, gyroStatus: .active),
            draftEnabled: false, savedEnabled: true, isOutputEnabled: true)
        XCTAssertEqual(String(localized: unsavedDisable.title), "Aiming", "Unsaved edits must not misrepresent the active runtime")
        XCTAssertEqual(String(localized: ControllerSensorPresentation.activationTitle(.rightGrip)), "Right grip touched")
        XCTAssertEqual(String(localized: ControllerSensorPresentation.activationTitle(.leftGrip)), "Left grip touched")
        XCTAssertEqual(String(localized: ControllerSensorPresentation.activationTitle(.eitherGrip)), "Either grip touched")
        XCTAssertEqual(String(localized: ControllerSensorPresentation.activationTitle(.eitherPad)), "Either trackpad touched")
        XCTAssertEqual(String(localized: ControllerSensorPresentation.activationTitle(.always)), "Always")
        XCTAssertEqual(ControllerSensorPresentation.angle(90, locale: Locale(identifier: "en_US")), "90°")
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
                        .environment(\.dynamicTypeSize, width == 560 ? .accessibility5 : .large)
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

    func testSensorSelectorsSharePadInspectorEdgesInLTRAndRTL() async throws {
        for width in [CGFloat(916), 1080] {
            let edges = try XCTUnwrap(PaddrPadColumns.workspaceInspectorTrailingEdges(in: width))
            for direction in [LayoutDirection.leftToRight, .rightToLeft] {
                let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
                    gyro: .constant(.init()), gripTouch: .constant(.unassigned), sensorStatus: nil,
                    isEditable: true).frame(width: width).environment(\.layoutDirection, direction))
                let window = makeWindow(host, width: width, height: 900)
                defer { window.close() }
                await settle(host)
                let menus = descendants(PaddrPopUpButton.self, in: host)
                for (name, logicalEnd) in [("Left grip touch action", edges.left),
                                            ("Right grip touch action", edges.right),
                                            ("Gyro activation", edges.right)] {
                    let menu = try XCTUnwrap(menus.first { $0.accessibilityLabel() == name })
                    let frame = menu.convert(menu.bounds, to: host)
                    XCTAssertEqual(frame.width, PaddrStyle.Width.control, accuracy: 0.5)
                    if direction == .leftToRight {
                        XCTAssertEqual(frame.maxX, logicalEnd, accuracy: 0.5, name)
                    } else {
                        XCTAssertEqual(frame.minX, width - logicalEnd, accuracy: 0.5, name)
                    }
                }
            }
        }
    }

    func testRuntimeCalibrationActionRemainsAvailableInReadOnlySettings() async throws {
        var writes = 0
        var requests = 0
        var gyro = GyroConfiguration(enabled: true)
        let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
            gyro: Binding(get: { gyro }, set: { gyro = $0; writes += 1 }),
            gripTouch: .constant(.unassigned), sensorStatus: .init(motionAvailable: true, gyroStatus: .ready),
            isEditable: false, isOutputEnabled: true, savedGyroEnabled: true,
            canRecalibrate: true, recalibrate: { requests += 1 })
            .environment(\.accessibilityEnabled, true))
        let window = makeWindow(host, width: 916, height: 600)
        defer { window.close() }
        await settle(host)
        XCTAssertTrue(descendants(PaddrPopUpButton.self, in: host).allSatisfy { !$0.isEnabled })
        XCTAssertTrue(descendants(PaddrTuningSwitchButton.self, in: host).allSatisfy { !$0.isEnabled })
        let button = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.gyro.calibrate"), accessibilityTree(host))
        XCTAssertEqual(button.accessibilityLabel?(), "Calibrate Again")
        XCTAssertEqual(button.accessibilityPerformPress?(), true)
        await settle(host)
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(writes, 0)
    }

    func testDisabledCalibrationExplainsItsReasonWithoutEditingOrRequesting() async throws {
        var requests = 0
        let reason: LocalizedStringResource = "Enable output before calibrating gyro."
        let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
            gyro: .constant(.init(enabled: true)), gripTouch: .constant(.unassigned),
            sensorStatus: .init(motionAvailable: true, gyroStatus: .off), isEditable: false,
            savedGyroEnabled: true, calibrationUnavailableReason: reason,
            recalibrate: { requests += 1 }).environment(\.accessibilityEnabled, true))
        let window = makeWindow(host, width: 916, height: 500)
        defer { window.close() }
        await settle(host)
        let button = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.gyro.calibrate"), accessibilityTree(host))
        XCTAssertEqual(button.accessibilityHelp?(), String(localized: reason))
        _ = button.accessibilityPerformPress?()
        await settle(host)
        XCTAssertEqual(requests, 0)
        let status = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.gyro.status"))
        XCTAssertEqual(status.accessibilityLabel?(), "Calibration needed", accessibilityTree(host))
    }

    func testInfoButtonIsNamedAndEscapeDismissesItsPopover() async throws {
        let oldWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let message: LocalizedStringResource = "Touching a grip holds its assigned action."
        let host = NSHostingView(rootView: ControllerSensorInfoButton(title: "About grip touch",
            message: message, identifier: "test-grip-info")
            .environment(\.accessibilityEnabled, true).padding(20))
        let window = makeWindow(host, width: 360, height: 120)
        defer { window.close() }
        window.makeKeyAndOrderFront(nil)
        await settle(host)
        let button = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.test-grip-info"), accessibilityTree(host))
        XCTAssertEqual(button.accessibilityLabel?(), "About grip touch")
        XCTAssertEqual(button.accessibilityRole?(), .button)
        XCTAssertEqual(button.accessibilityHelp?(), String(localized: message))
        XCTAssertEqual(button.accessibilityPerformPress?(), true)
        await settle(host)
        let popover = try XCTUnwrap(NSApp.windows.first {
            $0 !== window && !oldWindows.contains(ObjectIdentifier($0)) && $0.isVisible
        }, "Activating the information button should show its native popover")
        let content = try XCTUnwrap(popover.contentView)
        await settle(content)
        XCTAssertTrue(accessibilityTree(content).contains("Done"), "Popover content needs an explicit keyboard-accessible dismissal")
        let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: popover.windowNumber,
            context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
        popover.sendEvent(escape)
        await settle(host)
        XCTAssertFalse(popover.isVisible)
        XCTAssertNotNil(accessibilityElement(in: host, identifier: "paddr.test-grip-info"))
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
        XCTAssertEqual(Set(sliderLabels), ["Gyro sensitivity", "Holding angle", "Vertical sensitivity", "Gyro smoothing", "Noise threshold"],
            "The disclosure's name must not replace its child controls' accessible labels")
        XCTAssertEqual(sliderLabels.count, 5)
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
                    sensorStatus: status, isEditable: true, initialTuningExpanded: true,
                    isOutputEnabled: true, savedGyroEnabled: true, canRecalibrate: true)
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
        for (name, gyroStatus, outputEnabled) in [("needed", GyroStatus.off, false),
                                                  ("calibrating", .calibrating, true),
                                                  ("ready", .ready, true), ("aiming", .active, true)] {
            for (theme, scheme, appearance) in [("light", ColorScheme.light, NSAppearance.Name.aqua),
                                               ("dark", ColorScheme.dark, NSAppearance.Name.darkAqua)] {
                var extremes = gyro
                extremes.sensitivity = 40
                extremes.verticalScale = 4
                extremes.holdingAngleDegrees = 90
                extremes.noiseThreshold = 5
                extremes.smoothing = 1
                let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
                    gyro: .constant(extremes), gripTouch: .constant(.init(left: "code:65535", right: "mouse-right")),
                    sensorStatus: .init(motionAvailable: true, gyroStatus: gyroStatus), isEditable: true,
                    initialTuningExpanded: true, isOutputEnabled: outputEnabled, savedGyroEnabled: true,
                    canRecalibrate: outputEnabled && gyroStatus != .calibrating)
                    .padding(20).environment(\.colorScheme, scheme)
                    .foregroundStyle(PaddrStyle.textPrimary).tint(PaddrStyle.controlTint)
                    .background(PanelBackgroundView()))
                let window = makeWindow(host, width: 956, height: 1000)
                defer { window.close() }
                host.appearance = NSAppearance(named: appearance)
                await settle(host)
                host.frame.size.height = host.fittingSize.height
                await settle(host)
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try data.write(to: directory.appendingPathComponent("sensor-\(name)-extremes-\(theme).png"))
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

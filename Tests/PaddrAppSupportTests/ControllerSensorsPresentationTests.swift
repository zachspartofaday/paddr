import AppKit
import Observation
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
                                                (.ready, "Calibrated, Ready", false), (.active, "Aiming", false),
                                                (.unavailable, "Calibration needed", true),
                                                (.calibrationNeeded, "Calibration needed", true)] {
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
        var calibrationRequests = 0
        let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
            gyro: Binding(get: { gyro }, set: { gyro = $0 }),
            gripTouch: Binding(get: { grips }, set: { grips = $0 }),
            sensorStatus: nil, isEditable: true, recalibrate: { calibrationRequests += 1 }))
        let window = makeWindow(host, width: 916, height: 700)
        defer { window.close() }
        await settle(host)
        let toggle = try XCTUnwrap(descendants(PaddrTuningSwitchButton.self, in: host).first)
        XCTAssertFalse(gyro.enabled)
        XCTAssertTrue(toggle.accessibilityPerformPress())
        await settle(host)
        XCTAssertTrue(gyro.enabled)
        XCTAssertEqual(calibrationRequests, 0, "Enabling gyro edits the draft without starting calibration")
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

    func testGyroEnableLabelAndSwitchShareOneDraftActionWithoutCalibration() async throws {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            for isEditable in [true, false] {
                let draft = ControllerSensorDraftFixture()
                var writes = 0
                var calibrationRequests = 0
                let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
                    gyro: Binding(get: { draft.gyro }, set: { draft.gyro = $0; writes += 1 }),
                    gripTouch: .constant(.unassigned), sensorStatus: nil, isEditable: isEditable,
                    recalibrate: { calibrationRequests += 1 })
                    .environment(\.layoutDirection, direction)
                    .environment(\.accessibilityEnabled, true))
                let window = makeWindow(host, width: 916, height: 700)
                defer { window.close() }
                window.makeKeyAndOrderFront(nil)
                await settle(host)
                let switches = descendants(PaddrTuningSwitchButton.self, in: host)
                let toggle = try XCTUnwrap(switches.first)
                XCTAssertEqual(switches.count, 1)
                XCTAssertEqual(toggle.accessibilityLabel(), "Gyro to mouse")
                XCTAssertEqual(toggle.accessibilitySubrole(), .switch)
                XCTAssertNil(toggle.accessibilityChildren())
                let frame = toggle.convert(toggle.bounds, to: nil)
                let labelX = direction == .leftToRight
                    ? frame.minX - PaddrStyle.Spacing.s2 - 14
                    : frame.maxX + PaddrStyle.Spacing.s2 + 14
                for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                    let event = try XCTUnwrap(NSEvent.mouseEvent(with: type,
                        location: NSPoint(x: labelX, y: frame.midY), modifierFlags: [],
                        timestamp: 0, windowNumber: window.windowNumber, context: nil,
                        eventNumber: 1, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0))
                    window.sendEvent(event)
                }
                await settle(host)
                XCTAssertEqual(draft.gyro.enabled, isEditable, "The visible Enable label shares the guarded draft action")
                XCTAssertEqual(writes, isEditable ? 1 : 0)
                XCTAssertEqual(toggle.state, isEditable ? .on : .off,
                    "The observed draft must update the same mounted switch after a label click")
                XCTAssertTrue(toggle === descendants(PaddrTuningSwitchButton.self, in: host).first)
                XCTAssertEqual(toggle.accessibilityPerformPress(), isEditable)
                await settle(host)
                XCTAssertFalse(draft.gyro.enabled)
                XCTAssertEqual(writes, isEditable ? 2 : 0)
                XCTAssertEqual(calibrationRequests, 0, "Neither label nor switch requests calibration")
            }
        }
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
        window.makeKeyAndOrderFront(nil)
        await settle(host)
        XCTAssertTrue(descendants(PaddrPopUpButton.self, in: host).allSatisfy { !$0.isEnabled })
        XCTAssertTrue(descendants(PaddrTuningSwitchButton.self, in: host).allSatisfy { !$0.isEnabled })
        let button = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.gyro.calibrate"), accessibilityTree(host))
        XCTAssertEqual(button.accessibilityLabel?(), "Calibrate Again")
        XCTAssertEqual(button.accessibilityPerformPress?(), true)
        await settle(host)
        XCTAssertEqual(requests, 0, "Opening preparation must not start calibration")
        let guide = try XCTUnwrap(NSApp.windows.first { candidate in
            candidate !== window && candidate.isVisible
                && candidate.contentView.flatMap { accessibilityElement(in: $0, identifier: "paddr.gyro.calibration-start") } != nil
        })
        let start = try XCTUnwrap(guide.contentView.flatMap { accessibilityElement(in: $0, identifier: "paddr.gyro.calibration-start") })
        XCTAssertEqual(start.accessibilityPerformPress?(), true)
        await settle(host)
        XCTAssertEqual(requests, 1)
        XCTAssertFalse(guide.isVisible)
        XCTAssertEqual(writes, 0)
    }

    func testInitialCalibrationGuideRequiresPreparationAndExplicitConfirmation() async throws {
        var requests = 0
        let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
            gyro: .constant(.init(enabled: true)), gripTouch: .constant(.unassigned),
            sensorStatus: .init(motionAvailable: true, gyroStatus: .calibrationNeeded),
            isEditable: true, isOutputEnabled: true, savedGyroEnabled: true,
            canRecalibrate: true, recalibrate: { requests += 1 })
            .environment(\.accessibilityEnabled, true))
        let window = makeWindow(host, width: 916, height: 600)
        defer { window.close() }
        window.makeKeyAndOrderFront(nil)
        await settle(host)
        let button = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.gyro.calibrate"))
        XCTAssertEqual(button.accessibilityLabel?(), "Calibrate")
        XCTAssertEqual(requests, 0)
        for shouldStart in [false, true] {
            XCTAssertEqual(button.accessibilityPerformPress?(), true)
            await settle(host)
            let guide = try XCTUnwrap(NSApp.windows.first { candidate in
                candidate !== window && candidate.isVisible
                    && candidate.contentView.flatMap { accessibilityElement(in: $0, identifier: "paddr.gyro.calibration-start") } != nil
            })
            let content = try XCTUnwrap(guide.contentView)
            await settle(content)
            XCTAssertEqual(requests, 0, "Opening the guide must never measure calibration")
            let instruction = try XCTUnwrap(accessibilityElement(in: content, identifier: "paddr.gyro.calibration-instruction"))
            let instructionValue: String? = instruction.accessibilityValue?()
            XCTAssertEqual(instruction.accessibilityLabel?() ?? instructionValue,
                "Put the controller down on a stable surface, or hold it still. Choose Calibrate, then keep it still until Calibrated, Ready appears.")
            let action = try XCTUnwrap(accessibilityElement(in: content,
                identifier: shouldStart ? "paddr.gyro.calibration-start" : "paddr.gyro.calibration-cancel"))
            XCTAssertEqual(action.accessibilityPerformPress?(), true)
            await settle(host)
            XCTAssertEqual(requests, shouldStart ? 1 : 0)
            XCTAssertFalse(guide.isVisible)
        }
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
        XCTAssertEqual(status.accessibilityHelp?(), "Enable output, then choose Calibrate.")
        XCTAssertNil(accessibilityElement(in: host, identifier: "paddr.gyro.calibration-instruction"))
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

    func testUnassignedGripContactsStayHiddenAcrossDraftChangesAndGyroActivation() async throws {
        var gyro = GyroConfiguration(enabled: true, activation: .rightGrip)
        var grips = GripTouchConfiguration.unassigned
        var sensors = ControllerSensorStatus(grips: .init(leftTouched: false, rightTouched: true),
            motionAvailable: true, gyroStatus: .active)
        let view = {
            ControllerSensorsConfigurationView(gyro: Binding(get: { gyro }, set: { gyro = $0 }),
                gripTouch: Binding(get: { grips }, set: { grips = $0 }), sensorStatus: sensors,
                isEditable: true, isOutputEnabled: true, savedGyroEnabled: true)
                .environment(\.accessibilityEnabled, true)
        }
        let host = NSHostingView(rootView: view())
        let window = makeWindow(host, width: 916, height: 600)
        defer { window.close() }
        for (left, right) in [(false, true), (true, false), (false, false)] {
            sensors.grips = .init(leftTouched: left, rightTouched: right)
            host.rootView = view()
            await settle(host)
            XCTAssertNil(accessibilityElement(in: host, identifier: "paddr.grip.left.state"))
            XCTAssertNil(accessibilityElement(in: host, identifier: "paddr.grip.right.state"))
            XCTAssertEqual(gyro.activation, .rightGrip, "A None binding must not remove gyro touch activation")
            XCTAssertEqual(accessibilityElement(in: host, identifier: "paddr.gyro.status")?.accessibilityLabel?(), "Aiming")
        }
        grips.left = "space"
        host.rootView = view()
        await settle(host)
        XCTAssertNotNil(accessibilityElement(in: host, identifier: "paddr.grip.left.state"),
            "An assigned draft displays its live state before it is saved")
        XCTAssertNil(accessibilityElement(in: host, identifier: "paddr.grip.right.state"))
        grips.left = nil
        grips.right = "mouse-right"
        sensors.grips = nil
        host.rootView = view()
        await settle(host)
        XCTAssertNil(accessibilityElement(in: host, identifier: "paddr.grip.left.state"),
            "Unassigning the draft removes the state immediately")
        XCTAssertNotNil(accessibilityElement(in: host, identifier: "paddr.grip.right.state"),
            "An assigned grip still distinguishes missing telemetry from release")
    }

    func testCollapsedGyroHeadingSitsAboveEnableAndAttachedCalibrationWithRightGripActivation() async throws {
        for width in [CGFloat(916), 1080] {
            for direction in [LayoutDirection.leftToRight, .rightToLeft] {
                let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
                    gyro: .constant(.init(enabled: true)), gripTouch: .constant(.unassigned),
                    sensorStatus: .init(motionAvailable: true, gyroStatus: .ready), isEditable: true,
                    isOutputEnabled: true, savedGyroEnabled: true, canRecalibrate: true)
                    .frame(width: width).environment(\.layoutDirection, direction)
                    .environment(\.accessibilityEnabled, true))
                let window = makeWindow(host, width: width, height: 700)
                defer { window.close() }
                await settle(host)
                let controls = descendants(PaddrTuningSwitchButton.self, in: host)
                let toggle = try XCTUnwrap(controls.first { $0.accessibilityLabel() == "Gyro to mouse" })
                XCTAssertEqual(controls.count, 1, "Collapsed tuning exposes only its main gyro switch")
                let activation = try XCTUnwrap(descendants(PaddrPopUpButton.self, in: host)
                    .first { $0.accessibilityLabel() == "Gyro activation" })
                let status = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.gyro.status"))
                let calibration = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.gyro.calibrate"))
                let info = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.gyro-info"))
                let headingFrame = try XCTUnwrap(info.accessibilityFrame?())
                XCTAssertGreaterThan(headingFrame.minY, toggle.accessibilityFrame().maxY,
                    "The standalone section heading stays above the Enable row")
                let frames = [toggle.accessibilityFrame(), try XCTUnwrap(status.accessibilityFrame?()),
                    try XCTUnwrap(calibration.accessibilityFrame?()), activation.accessibilityFrame()]
                for frame in frames.dropFirst() {
                    XCTAssertEqual(frame.midY, frames[0].midY, accuracy: 1,
                        "Enable, attached calibration status/action and Activation share the row below the heading")
                }
                let activationLabel = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.gyro.activation-label"))
                let gripLabel = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.grip.right.label"))
                let labelFrame = try XCTUnwrap(activationLabel.accessibilityFrame?())
                let gripFrame = try XCTUnwrap(gripLabel.accessibilityFrame?())
                XCTAssertEqual(activationLabel.accessibilityLabel?(), "Activation")
                if direction == .leftToRight {
                    XCTAssertEqual(labelFrame.minX, gripFrame.minX, accuracy: 0.5)
                } else {
                    XCTAssertEqual(labelFrame.maxX, gripFrame.maxX, accuracy: 0.5)
                }
                XCTAssertEqual(labelFrame.midY, activation.accessibilityFrame().midY, accuracy: 0.5)
                XCTAssertEqual(labelFrame.midY, frames[0].midY, accuracy: 1,
                    "Activation shares the calibration row and the Right grip column")
                XCTAssertEqual(status.accessibilityLabel?(), "Calibrated, Ready")
                XCTAssertFalse(accessibilityTree(host).contains("Gyro sensitivity"))
                XCTAssertNil(accessibilityElement(in: host, identifier: "paddr.gyro.calibration-instruction"),
                    "Guidance belongs in help and the information popover, not a permanent extra row")
            }
        }
    }

    func testSummaryCalibrationButtonUsesActualLeftInspectorEdgeForEveryStateAndDirection() async throws {
        let states: [(String, Bool, Bool, Bool, GyroStatus)] = [
            ("Off", false, false, false, .off),
            ("Calibrated, Ready", true, true, true, .ready),
            ("Calibration needed", true, true, true, .calibrationNeeded),
            ("Calibrating—hold still", true, true, true, .calibrating),
            ("Save & Apply needed", true, false, true, .off)
        ]
        for width in [CGFloat(916), 1080] {
            let edges = try XCTUnwrap(PaddrPadColumns.workspaceInspectorTrailingEdges(in: width))
            for direction in [LayoutDirection.leftToRight, .rightToLeft] {
                for (title, draft, saved, output, statusValue) in states {
                    let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
                        gyro: .constant(.init(enabled: draft)), gripTouch: .constant(.unassigned),
                        sensorStatus: .init(motionAvailable: true, gyroStatus: statusValue), isEditable: true,
                        isOutputEnabled: output, savedGyroEnabled: saved,
                        canRecalibrate: output && saved && statusValue == .ready)
                        .frame(width: width).environment(\.layoutDirection, direction)
                        .environment(\.accessibilityEnabled, true))
                    let window = makeWindow(host, width: width, height: 600)
                    defer { window.close() }
                    await settle(host)
                    let calibration = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.gyro.calibrate"))
                    XCTAssertEqual(calibration.accessibilityRole?(), .button)
                    XCTAssertEqual(calibration.accessibilityLabel?(), statusValue == .ready || statusValue == .active ? "Calibrate Again" : "Calibrate")
                    let screenFrame = try XCTUnwrap(calibration.accessibilityFrame?())
                    let frame = host.convert(window.convertFromScreen(screenFrame), from: nil)
                    let menu = try XCTUnwrap(descendants(PaddrPopUpButton.self, in: host)
                        .first { $0.accessibilityLabel() == "Gyro activation" })
                    let menuFrame = menu.convert(menu.bounds, to: host)
                    if direction == .leftToRight {
                        XCTAssertEqual(frame.maxX, edges.left, accuracy: 0.5, title)
                        XCTAssertEqual(menuFrame.maxX, edges.right, accuracy: 0.5, title)
                    } else {
                        XCTAssertEqual(frame.minX, width - edges.left, accuracy: 0.5, title)
                        XCTAssertEqual(menuFrame.minX, width - edges.right, accuracy: 0.5, title)
                    }
                    let status = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.gyro.status"))
                    XCTAssertEqual(status.accessibilityLabel?(), title)
                    let statusFrame = try XCTUnwrap(status.accessibilityFrame?())
                    let toggle = try XCTUnwrap(descendants(PaddrTuningSwitchButton.self, in: host).first)
                    XCTAssertEqual(toggle.accessibilityFrame().midY, screenFrame.midY, accuracy: 0.5, title)
                    XCTAssertEqual(screenFrame.midY, statusFrame.midY, accuracy: 0.5, title)
                    if direction == .leftToRight {
                        XCTAssertEqual(screenFrame.minX - statusFrame.maxX, PaddrStyle.Spacing.s2,
                            accuracy: 0.5, "Status attaches immediately before its action: \(title)")
                    } else {
                        XCTAssertEqual(statusFrame.minX - screenFrame.maxX, PaddrStyle.Spacing.s2,
                            accuracy: 0.5, "Status/action grouping mirrors in RTL: \(title)")
                    }
                    let controlFrames = [screenFrame, statusFrame, toggle.accessibilityFrame(), menu.accessibilityFrame()]
                    for index in controlFrames.indices {
                        for other in controlFrames.indices where other > index {
                            XCTAssertFalse(controlFrames[index].intersects(controlFrames[other]),
                                "The full status and pinned controls must remain distinct: \(title)")
                        }
                    }
                    XCTAssertNil(accessibilityElement(in: host, identifier: "paddr.grip.left.state"))
                    XCTAssertNil(accessibilityElement(in: host, identifier: "paddr.grip.right.state"))
                    XCTAssertFalse(accessibilityTree(host).contains("Gyro sensitivity"))
                }
            }
        }
    }

    func testSummaryNativeIdentityFocusAndBindingsSurviveWidthReflow() async throws {
        var activation = GyroConfiguration(enabled: true)
        var grips = GripTouchConfiguration.unassigned
        var calibrationRequests = 0
        let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
            gyro: Binding(get: { activation }, set: { activation = $0 }),
            gripTouch: Binding(get: { grips }, set: { grips = $0 }),
            sensorStatus: .init(motionAvailable: true, gyroStatus: .ready), isEditable: true,
            isOutputEnabled: true, savedGyroEnabled: true, canRecalibrate: true,
            recalibrate: { calibrationRequests += 1 }).environment(\.accessibilityEnabled, true))
        let window = makeWindow(host, width: 916, height: 700)
        defer { window.close() }
        window.makeKeyAndOrderFront(nil)
        await settle(host)
        let menu = try XCTUnwrap(descendants(PaddrPopUpButton.self, in: host)
            .first { $0.accessibilityLabel() == "Gyro activation" })
        let toggle = try XCTUnwrap(descendants(PaddrTuningSwitchButton.self, in: host)
            .first { $0.accessibilityLabel() == "Gyro to mouse" })
        XCTAssertTrue(window.makeFirstResponder(menu))
        for width in [CGFloat(560), 1080, 916] {
            window.setContentSize(NSSize(width: width, height: 700))
            await settle(host)
            XCTAssertTrue(descendants(PaddrPopUpButton.self, in: host)
                .first { $0.accessibilityLabel() == "Gyro activation" } === menu)
            XCTAssertTrue(descendants(PaddrTuningSwitchButton.self, in: host)
                .first { $0.accessibilityLabel() == "Gyro to mouse" } === toggle)
            XCTAssertTrue(window.firstResponder === menu)
            XCTAssertEqual(activation.activation, .rightGrip)
            XCTAssertTrue(activation.enabled)
            XCTAssertNil(grips.left)
            XCTAssertNil(grips.right)
            XCTAssertEqual(calibrationRequests, 0, "Reflow must not invoke runtime actions")
            assertFits(menu, in: host)
            assertFits(toggle, in: host)
        }
    }

    func testExpandedTuningKeepsSevenControlsOnSharedInspectorEdges() async throws {
        for width in [CGFloat(916), 1080] {
            let edges = try XCTUnwrap(PaddrPadColumns.workspaceInspectorTrailingEdges(in: width))
            for direction in [LayoutDirection.leftToRight, .rightToLeft] {
                let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
                    gyro: .constant(.init(enabled: true)), gripTouch: .constant(.unassigned),
                    sensorStatus: .init(motionAvailable: true, gyroStatus: .ready), isEditable: true,
                    initialTuningExpanded: true, isOutputEnabled: true, savedGyroEnabled: true,
                    canRecalibrate: true).frame(width: width).environment(\.layoutDirection, direction)
                    .environment(\.accessibilityEnabled, true))
                let window = makeWindow(host, width: width, height: 900)
                defer { window.close() }
                await settle(host)
                var elements: [String: AnyObject] = [:]
                var visited = Set<ObjectIdentifier>()
                func collect(_ object: AnyObject) {
                    guard visited.insert(ObjectIdentifier(object)).inserted else { return }
                    if object.accessibilityRole?() == .slider, let label = object.accessibilityLabel?() {
                        elements[label] = object
                    }
                    for child in object.accessibilityChildren?() as? [Any] ?? [] { collect(child as AnyObject) }
                }
                collect(host)
                XCTAssertEqual(elements.count, 5)
                for (label, end, readout) in [("Gyro sensitivity", edges.left, PaddrStyle.Width.gyroReadout),
                                             ("Vertical sensitivity", edges.left, PaddrStyle.Width.readout),
                                             ("Gyro smoothing", edges.right, PaddrStyle.Width.readout),
                                             ("Noise threshold", edges.right, PaddrStyle.Width.gyroReadout)] {
                    let slider = try XCTUnwrap(elements[label])
                    let screenFrame = try XCTUnwrap(slider.accessibilityFrame?())
                    let frame = host.convert(window.convertFromScreen(screenFrame), from: nil)
                    if direction == .leftToRight {
                        XCTAssertEqual(frame.maxX + readout + PaddrStyle.Spacing.s2, end, accuracy: 0.5, label)
                    } else {
                        XCTAssertEqual(frame.minX - readout - PaddrStyle.Spacing.s2, width - end, accuracy: 0.5, label)
                    }
                }
                let switches = descendants(PaddrTuningSwitchButton.self, in: host)
                    .filter { $0.accessibilityLabel() != "Gyro to mouse" }
                XCTAssertEqual(switches.count, 2, "Five sliders and two inversion switches are the seven tuning controls")
                for control in switches {
                    let frame = control.convert(control.bounds, to: host)
                    if direction == .leftToRight {
                        XCTAssertEqual(frame.maxX, edges.right, accuracy: 0.5)
                    } else {
                        XCTAssertEqual(frame.minX, width - edges.right, accuracy: 0.5)
                    }
                }
                let sensitivityY = try XCTUnwrap(elements["Gyro sensitivity"]?.accessibilityFrame?()).midY
                let smoothingY = try XCTUnwrap(elements["Gyro smoothing"]?.accessibilityFrame?()).midY
                XCTAssertEqual(sensitivityY, smoothingY, accuracy: 0.5)
                let verticalY = try XCTUnwrap(elements["Vertical sensitivity"]?.accessibilityFrame?()).midY
                let horizontalSwitch = try XCTUnwrap(switches.first { $0.accessibilityLabel() == "Invert horizontal" })
                XCTAssertEqual(verticalY, horizontalSwitch.accessibilityFrame().midY, accuracy: 0.5)
            }
        }
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
        for (name, gyroStatus, outputEnabled, draftEnabled, savedEnabled) in [
            ("off", GyroStatus.off, false, false, false),
            ("draft-only", .off, true, true, false),
            ("needed", .calibrationNeeded, true, true, true),
            ("calibrating", .calibrating, true, true, true),
            ("ready", .ready, true, true, true),
            ("aiming", .active, true, true, true)
        ] {
            for (theme, scheme, appearance) in [("light", ColorScheme.light, NSAppearance.Name.aqua),
                                               ("dark", ColorScheme.dark, NSAppearance.Name.darkAqua)] {
                var extremes = gyro
                extremes.sensitivity = 40
                extremes.verticalScale = 4
                extremes.holdingAngleDegrees = 90
                extremes.noiseThreshold = 5
                extremes.smoothing = 1
                extremes.enabled = draftEnabled
                for (directionName, direction) in [("ltr", LayoutDirection.leftToRight), ("rtl", .rightToLeft)] {
                    let host = NSHostingView(rootView: ControllerSensorsConfigurationView(
                        gyro: .constant(extremes), gripTouch: .constant(.init(left: "code:65535", right: "mouse-right")),
                        sensorStatus: .init(motionAvailable: true, gyroStatus: gyroStatus), isEditable: true,
                        initialTuningExpanded: true, isOutputEnabled: outputEnabled, savedGyroEnabled: savedEnabled,
                        canRecalibrate: outputEnabled && savedEnabled && gyroStatus != .calibrating)
                        .padding(20).environment(\.colorScheme, scheme).environment(\.layoutDirection, direction)
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
                    try data.write(to: directory.appendingPathComponent("sensor-\(name)-extremes-\(theme)-\(directionName).png"))
                }
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

@MainActor
@Observable
private final class ControllerSensorDraftFixture {
    var gyro = GyroConfiguration()
}

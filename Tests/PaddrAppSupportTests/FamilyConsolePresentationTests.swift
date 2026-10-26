import AppKit
import SwiftUI
import XCTest

import PaddrAppSupport
import PaddrCore
@testable import PaddrMenu

@MainActor
final class FamilyConsolePresentationTests: XCTestCase {
    func testNativeWorkspaceGeometryMatchesApprovedContract() {
        XCTAssertEqual(PaddrStyle.Metrics.defaultWindowSize, NSSize(width: 1_080, height: 640))
        XCTAssertEqual(PaddrStyle.Metrics.minimumWindowSize, NSSize(width: 680, height: 600))
        XCTAssertEqual(PaddrStyle.Metrics.outerSpacing, 24)
        XCTAssertEqual(PaddrStyle.Inset.window, 24)
        XCTAssertEqual(PaddrStyle.Inset.card, 16)
        XCTAssertEqual(PaddrStyle.Inset.control, 12)
        XCTAssertEqual(PaddrStyle.cardSpacing, 16)
        XCTAssertEqual(PaddrStyle.Metrics.defaultContentWidth,
            PaddrStyle.Metrics.defaultWindowSize.width - (2 * PaddrStyle.Inset.window))
        XCTAssertGreaterThan(PaddrStyle.Metrics.defaultContentWidth,
            PaddrStyle.Metrics.padEditorColumnsBreakpoint)
        XCTAssertGreaterThanOrEqual(PaddrStyle.Metrics.padEditorColumnsBreakpoint,
            (2 * PaddrStyle.minimumPadColumnWidth) + PaddrStyle.cardSpacing)
        XCTAssertEqual(PaddrStyle.padColumnWidth,
            (PaddrStyle.Metrics.defaultContentWidth - PaddrStyle.cardSpacing) / 2)
        XCTAssertGreaterThanOrEqual(PaddrStyle.Metrics.controlHeight, 28)
        XCTAssertLessThanOrEqual(PaddrStyle.Metrics.controlHeight, 38)
    }

    func testBespokeControlFamilyUsesApprovedBaseDimensions() {
        XCTAssertEqual(PaddrStyle.Control.height, 32)
        XCTAssertEqual(PaddrStyle.Control.radius, 7)
        XCTAssertEqual(PaddrStyle.Control.sideInset, 12)
        XCTAssertEqual(PaddrStyle.Control.focusWidth, 2)
        XCTAssertEqual(PaddrStyle.behaviorPickerWidth, 240)
        XCTAssertEqual(PaddrStyle.Width.control, 240)
        XCTAssertEqual(PaddrStyle.Control.segmentInset, 4)
        XCTAssertEqual(PaddrStyle.Control.segmentRadius, 3)
        XCTAssertEqual(PaddrStyle.Control.bindingPlateHeight, 24)
        XCTAssertEqual(PaddrStyle.Control.bindingPlateRadius, 5)
        XCTAssertEqual(PaddrStyle.Metrics.zoneMapWidth, 190)
        XCTAssertEqual(PaddrStyle.Metrics.zoneMapHeight, 182)
    }

    func testStatusStripUsesReadinessOrder() {
        XCTAssertEqual(
            PaddrStatusKind.allCases,
            [.access, .puck, .controller, .output, .battery]
        )
    }

    func testTypographyRolesKeepNativeHeadingAndBodyHierarchy() {
        func height(for role: PaddrTextRole) -> CGFloat {
            let hostingView = NSHostingView(
                rootView: Text("Hierarchy").paddrTypography(role)
            )
            hostingView.layoutSubtreeIfNeeded()
            return hostingView.fittingSize.height
        }

        let page = height(for: .pageTitle)
        let card = height(for: .cardTitle)
        let section = height(for: .sectionTitle)
        let band = height(for: .sectionLabel)
        let row = height(for: .rowLabel)

        XCTAssertGreaterThan(page, card)
        XCTAssertGreaterThan(card, section)
        XCTAssertGreaterThan(section, band)
        XCTAssertGreaterThanOrEqual(band, row)
        XCTAssertEqual(row, height(for: .value), accuracy: 0.5)
    }

    func testWorkspacePaletteAdaptsToSystemAppearance() throws {
        func resolved(_ color: Color, under name: NSAppearance.Name) throws -> NSColor {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            var result: NSColor?
            appearance.performAsCurrentDrawingAppearance {
                result = NSColor(color).usingColorSpace(.sRGB)
            }
            return try XCTUnwrap(result)
        }

        let lightCanvas = try resolved(PaddrStyle.night0, under: .aqua)
        let darkCanvas = try resolved(PaddrStyle.night0, under: .darkAqua)
        let lightText = try resolved(PaddrStyle.textPrimary, under: .aqua)
        let darkText = try resolved(PaddrStyle.textPrimary, under: .darkAqua)
        XCTAssertGreaterThan(lightCanvas.redComponent, darkCanvas.redComponent)
        XCTAssertGreaterThan(lightCanvas.greenComponent, darkCanvas.greenComponent)
        XCTAssertGreaterThan(lightCanvas.blueComponent, darkCanvas.blueComponent)
        XCTAssertLessThan(lightText.redComponent, darkText.redComponent)
        XCTAssertLessThan(lightText.greenComponent, darkText.greenComponent)
        XCTAssertLessThan(lightText.blueComponent, darkText.blueComponent)
    }

    func testAccessibilityIdentifiersAreStableAndPaddrNamespaced() {
        XCTAssertEqual(PaddrAccessibility.slug("  Left / Right  "), "left-right")
        XCTAssertEqual(PaddrAccessibility.slug("Profile_42"), "profile-42")
        XCTAssertEqual(
            PaddrAccessibility.identifier("Pad Editor", "Left"),
            "paddr.pad-editor.left"
        )
        XCTAssertEqual(PaddrAccessibility.identifier("", "Status Item"), "paddr.status-item")
    }

    func testReadinessResolverUsesDeterministicGatePriority() {
        let cases: [(PaddrReadinessInput, PaddrReadinessNextAction)] = [
            (input(isInitialized: false), .waitForInitialization),
            (input(puckConnected: false), .refreshPuck),
            (input(inputMonitoringGranted: false), .requestInputMonitoring),
            (input(controllerConnected: false), .connectController),
            (input(accessibilityTrusted: false), .requestAccessibility),
            (input(isReleasingOutput: true), .waitForOutputRelease),
            (
                input(isEnabled: false, isRunning: false, canToggleOutput: false),
                .waitForProfileOperation
            ),
            (input(isEnabled: false), .enableOutput),
            (input(isRunning: false), .releaseTrackpads),
            (input(), .none)
        ]

        for (input, expectedAction) in cases {
            XCTAssertEqual(
                PaddrReadinessResolver.resolve(input).nextAction,
                expectedAction,
                "Unexpected action for \(input)"
            )
        }

        XCTAssertEqual(
            String(localized: PaddrReadinessNextAction.waitForProfileOperation.title),
            "Wait for the profile operation to finish"
        )
    }

    func testReadinessResolverExplainsEveryDisabledOutputState() {
        XCTAssertEqual(
            PaddrReadinessResolver.resolve(
                input(isInitialized: false, canToggleOutput: false)
            ).outputDisabledReason,
            .initializing
        )
        XCTAssertEqual(
            PaddrReadinessResolver.resolve(
                input(isReleasingOutput: true, canToggleOutput: false)
            ).outputDisabledReason,
            .releasingOutputs
        )
        XCTAssertEqual(
            PaddrReadinessResolver.resolve(
                input(canToggleOutput: false)
            ).outputDisabledReason,
            .profileOperation
        )
        XCTAssertNil(PaddrReadinessResolver.resolve(input()).outputDisabledReason)
    }

    func testMenuBarPresentationIncludesRequiredSemantics() {
        let presentation = MenuBarPresentation(
            isEnabled: true,
            isRunning: true,
            isReleasingOutput: false,
            controllerConnected: true,
            puckConnected: true,
            profileName: "Everyday"
        )

        XCTAssertEqual(presentation.outputSummary, "Output: Active")
        XCTAssertEqual(presentation.controllerSummary, "Controller: Connected")
        XCTAssertEqual(presentation.transportSummary, "Transport: Puck connected")
        XCTAssertEqual(presentation.profileSummary, "Profile: Everyday")
        XCTAssertTrue(presentation.accessibilityLabel.contains(presentation.outputSummary))
        XCTAssertTrue(presentation.accessibilityLabel.contains(presentation.controllerSummary))
        XCTAssertTrue(presentation.accessibilityLabel.contains(presentation.transportSummary))
        XCTAssertTrue(presentation.accessibilityLabel.contains(presentation.profileSummary))
        XCTAssertEqual(presentation.tintRole, .active)
        XCTAssertEqual(presentation.symbolName, "hand.point.up.left.fill")

        let waiting = MenuBarPresentation(
            isEnabled: true,
            isRunning: false,
            isReleasingOutput: false,
            controllerConnected: true,
            puckConnected: true,
            profileName: "Everyday"
        )
        XCTAssertEqual(waiting.tintRole, .warning)
        XCTAssertEqual(waiting.symbolName, "hourglass.circle.fill")

        let releasing = MenuBarPresentation(
            isEnabled: false,
            isRunning: false,
            isReleasingOutput: true,
            controllerConnected: true,
            puckConnected: true,
            profileName: "Everyday"
        )
        XCTAssertEqual(releasing.tintRole, .none)
        XCTAssertEqual(releasing.symbolName, "arrow.down.circle.fill")
    }

    private func input(
        isInitialized: Bool = true,
        puckConnected: Bool = true,
        controllerConnected: Bool = true,
        batteryAvailable: Bool = true,
        inputMonitoringGranted: Bool = true,
        accessibilityTrusted: Bool = true,
        isEnabled: Bool = true,
        isRunning: Bool = true,
        isReleasingOutput: Bool = false,
        canToggleOutput: Bool = true
    ) -> PaddrReadinessInput {
        PaddrReadinessInput(
            isInitialized: isInitialized,
            puckConnected: puckConnected,
            controllerConnected: controllerConnected,
            batteryAvailable: batteryAvailable,
            inputMonitoringGranted: inputMonitoringGranted,
            accessibilityTrusted: accessibilityTrusted,
            isEnabled: isEnabled,
            isRunning: isRunning,
            isReleasingOutput: isReleasingOutput,
            canToggleOutput: canToggleOutput
        )
    }

}

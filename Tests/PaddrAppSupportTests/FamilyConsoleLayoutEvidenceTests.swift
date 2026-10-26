import AppKit
import Observation
import ScreenCaptureKit
import SwiftUI
import XCTest

import PaddrAppSupport
import PaddrCore
@testable import PaddrMenu

@MainActor
final class FamilyConsoleLayoutEvidenceTests: XCTestCase {
    /// Opt-in image evidence uses only the existing inert, in-memory model fixture.
    func testExportConfigurationRenderEvidence() async throws {
        guard let path = ProcessInfo.processInfo.environment["PADDR_UI_EVIDENCE_DIR"] else {
            throw XCTSkip("Set PADDR_UI_EVIDENCE_DIR to export configuration PNG evidence")
        }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = try makeEditableMenuModel(hasSystemAccess: true)
        let initialized = await waitUntil { model.isInitialized }
        XCTAssertTrue(initialized)
        model.configuration.rearButtons = .init(l4: "F1", l5: "F2", r4: "F3", r5: "F4")
        for (theme, scheme, appearance) in [
            ("light", ColorScheme.light, NSAppearance.Name.aqua),
            ("dark", ColorScheme.dark, NSAppearance.Name.darkAqua)
        ] {
            for radius in [0.0, 0.6, 1.0] {
                try await exportEvidence(PadModePreview(mode: .mouse, deadzone: radius),
                    size: NSSize(width: 190, height: 182), scheme: scheme, appearance: appearance,
                    to: directory.appendingPathComponent("pointer-radius-\(Int(radius * 100))-\(theme).png"))
            }
            model.configuration.left.mode = .scroll
            model.configuration.right.mode = .mouse
            for (name, size) in [
                ("minimum", PaddrStyle.Metrics.minimumWindowSize),
                ("default", PaddrStyle.Metrics.defaultWindowSize),
                ("narrow-pair", NSSize(width: 940, height: 620)),
                ("wide", NSSize(width: 1600, height: 900))
            ] {
                try await exportEvidence(
                    ConfigurationView(model: model), size: size, scheme: scheme, appearance: appearance,
                    to: directory.appendingPathComponent("\(name)-\(theme)-workspace.png")
                )
                let document = NSHostingView(rootView: ConfigurationContentView(model: model)
                    .foregroundStyle(PaddrStyle.textPrimary)
                    .tint(PaddrStyle.controlTint)
                    .environment(\.colorScheme, scheme)
                    .background(PanelBackgroundView()))
                document.appearance = NSAppearance(named: appearance)
                document.frame = NSRect(x: 0, y: 0, width: size.width, height: 3000)
                await settle(document, passes: 12)
                document.frame.size.height = document.fittingSize.height
                await settle(document, passes: 12)
                try exportPNG(document, to: directory.appendingPathComponent("\(name)-\(theme)-document.png"))
            }
            model.configuration.left.mode = .mouse
            model.configuration.right.mode = .mouse
            for width in [CGFloat(680), 940, 1080] {
                try await exportEvidence(
                    ConfigurationView(model: model, initialTuningExpanded: true),
                    size: NSSize(width: width, height: 900), scheme: scheme, appearance: appearance,
                    to: directory.appendingPathComponent("both-tuning-\(Int(width))-\(theme).png"))
            }
            try await exportEvidence(
                PadConfigurationView(side: .left, configuration: .constant(model.configuration.left),
                    isEditable: false, initialTuningExpanded: true),
                size: NSSize(width: 500, height: 650), scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("disabled-tuning-\(theme).png"))
            try await exportEvidence(
                PadConfigurationView(side: .left, configuration: .constant(model.configuration.left), initialTuningExpanded: true)
                    .environment(\._colorSchemeContrast, .increased)
                    .environment(\._accessibilityReduceTransparency, true)
                    .environment(\._accessibilityReduceMotion, true),
                size: NSSize(width: 500, height: 650), scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("increased-contrast-tuning-\(theme).png"))
            model.configuration.left.mode = .scroll
            model.configuration.right.mode = .disabled
            try await exportEvidence(
                ConfigurationView(model: model), size: NSSize(width: 940, height: 620),
                scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("mixed-off-\(theme).png")
            )
            model.configuration.left.mode = .disabled
            try await exportEvidence(
                ConfigurationView(model: model), size: PaddrStyle.Metrics.defaultWindowSize,
                scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("both-off-\(theme).png")
            )
            let readyModel = try makeEditableMenuModel(hasSystemAccess: true)
            let ready = await waitUntil { readyModel.isInitialized }
            XCTAssertTrue(ready)
            try await exportEvidence(
                ConfigurationView(model: readyModel), size: PaddrStyle.Metrics.defaultWindowSize,
                scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("access-ready-\(theme).png")
            )
            for (name, inputGranted, accessibilityGranted) in [
                ("input-monitoring-needed", false, true), ("accessibility-needed", true, false)
            ] {
                let permissionModel = try makeEditableMenuModel(hasSystemAccess: false,
                    inputMonitoringGranted: inputGranted, accessibilityGranted: accessibilityGranted)
                let initialized = await waitUntil { permissionModel.isInitialized }
                XCTAssertTrue(initialized)
                try await exportEvidence(
                    ConfigurationView(model: permissionModel), size: PaddrStyle.Metrics.defaultWindowSize,
                    scheme: scheme, appearance: appearance,
                    to: directory.appendingPathComponent("\(name)-\(theme).png")
                )
            }
            try await exportEvidence(
                ConfigurationView(model: model).environment(\.dynamicTypeSize, .accessibility5),
                size: PaddrStyle.Metrics.minimumWindowSize, scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("large-text-\(theme).png")
            )
            model.configuration.right.mode = .mouse
            model.configuration.left.mode = .dpad
            for layout in PadZoneLayout.allCases {
                model.configuration.left.zoneLayout = layout
                try await exportEvidence(
                    ConfigurationView(model: model), size: PaddrStyle.Metrics.defaultWindowSize,
                    scheme: scheme, appearance: appearance,
                    to: directory.appendingPathComponent("zones-\(layout.rawValue)-\(theme).png")
                )
            }
            try await exportEvidence(
                OnboardingGuideView(model: model, onSkip: {}, onComplete: {}),
                size: PaddrStyle.Metrics.guideWindowSize, scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("guide-welcome-\(theme).png")
            )
            model.configuration.left.mode = .mouse
            model.configuration.right.mode = .mouse
            try await exportReadmeWindow(
                ConfigurationView(model: model, managesWindowSize: true, initialTuningExpanded: true),
                scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("readme-both-tuning-\(theme).png"))
            let longModel = try makeEditableMenuModel(hasSystemAccess: true,
                profileName: "A deliberately long profile name that remains fully readable in the selector")
            let longReady = await waitUntil { longModel.isInitialized }
            XCTAssertTrue(longReady)
            longModel.configuration.left.mode = .dpad
            longModel.configuration.left.zoneLayout = .gridNine
            for zone in PadZoneLayout.gridNine.zones {
                longModel.configuration.left[bindingFor: zone] = "code:65535"
            }
            longModel.configuration.right.tapKey = "code:65535"
            try await exportReadmeWindow(
                ConfigurationView(model: longModel, managesWindowSize: true), scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("readme-long-labels-\(theme).png"))
            var pager = OnboardingPager()
            pager.advance()
            pager.advance()
            try await exportEvidence(
                OnboardingGuideView(model: model, onSkip: {}, onComplete: {}, initialPager: pager),
                size: PaddrStyle.Metrics.guideWindowSize, scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("guide-permissions-\(theme).png")
            )
            try await exportEvidence(
                PadConfigurationView(side: .right, configuration: .constant(model.configuration.right),
                    initialTuningExpanded: true),
                size: NSSize(width: 640, height: 760), scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("pointer-tuning-\(theme).png")
            )
        }
    }

    /// README captures use production window construction, not the deliberately
    /// fixed viewports above that exercise constrained/responsive layouts.
    func testExportReadmeWindowEvidence() async throws {
        guard let path = ProcessInfo.processInfo.environment["PADDR_UI_EVIDENCE_DIR"] else {
            throw XCTSkip("Set PADDR_UI_EVIDENCE_DIR to export README window evidence")
        }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = try makeEditableMenuModel(hasSystemAccess: true)
        let initialized = await waitUntil { model.isInitialized }
        XCTAssertTrue(initialized)
        model.configuration.rearButtons = .init(l4: "F1", l5: "F2", r4: "F3", r5: "F4")
        let readyModel = try makeEditableMenuModel(hasSystemAccess: true)
        let ready = await waitUntil { readyModel.isInitialized }
        XCTAssertTrue(ready)
        let permissionModel = try makeEditableMenuModel(hasSystemAccess: false)
        let permissionsInitialized = await waitUntil { permissionModel.isInitialized }
        XCTAssertTrue(permissionsInitialized)

        for (theme, scheme, appearance) in [
            ("light", ColorScheme.light, NSAppearance.Name.aqua),
            ("dark", ColorScheme.dark, NSAppearance.Name.darkAqua)
        ] {
            model.configuration.left.mode = .scroll
            model.configuration.right.mode = .mouse
            try await exportReadmeWindow(
                ConfigurationView(model: model, managesWindowSize: true),
                scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("readme-overview-\(theme).png")
            )
            try await exportReadmeWindow(
                ConfigurationView(model: readyModel, managesWindowSize: true),
                scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("readme-access-ready-\(theme).png")
            )
            try await exportReadmeWindow(
                ConfigurationView(model: permissionModel, managesWindowSize: true),
                scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("readme-permission-setup-\(theme).png"))
            model.configuration.left.mode = .dpad
            model.configuration.right.mode = .dpad
            model.configuration.left.zoneLayout = .fourCorners
            model.configuration.right.zoneLayout = .fourCorners
            model.configuration.left.dpadDeadzone = 0
            model.configuration.right.dpadDeadzone = 0
            try await exportReadmeWindow(
                ConfigurationView(model: model, managesWindowSize: true),
                scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("readme-both-zones-\(theme).png"))
            for (state, index) in [("hover-other", 1), ("hover-selected", 3)] {
                try await exportReadmeWindow(
                    ConfigurationView(model: model, managesWindowSize: true),
                    scheme: scheme, appearance: appearance,
                    to: directory.appendingPathComponent("readme-both-zones-\(state)-\(theme).png"),
                    prepare: { view in
                        for mode in self.descendants(of: PaddrModeSegmentedControl.self, in: view) {
                            let rect = mode.segmentRect(index)
                            mode.updateHover(at: CGPoint(x: rect.midX, y: rect.midY))
                        }
                    })
            }
            try await exportReadmeWindow(
                ConfigurationView(model: model, managesWindowSize: true)
                    .environment(\._accessibilityReduceTransparency, true)
                    .environment(\._colorSchemeContrast, .increased)
                    .environment(\._accessibilityReduceMotion, true),
                scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("readme-both-zones-opaque-\(theme).png"))
            try await exportReadmeWindow(
                ConfigurationView(model: model, managesWindowSize: true)
                    .environment(\.layoutDirection, .rightToLeft),
                scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("readme-both-zones-rtl-\(theme).png"))
            model.configuration.right.mode = .mouse
            model.configuration.left.mode = .dpad
            for layout in PadZoneLayout.allCases {
                model.configuration.left.zoneLayout = layout
                try await exportReadmeWindow(
                    ConfigurationView(model: model, managesWindowSize: true),
                    scheme: scheme, appearance: appearance,
                    to: directory.appendingPathComponent("readme-zones-\(layout.rawValue)-\(theme).png")
                )
            }
            model.configuration.left.mode = .mouse
            model.configuration.right.mode = .dpad
            model.configuration.right.zoneLayout = .radialFour
            try await exportReadmeWindow(
                ConfigurationView(model: model, managesWindowSize: true, initialTuningExpanded: true),
                scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("readme-expanded-\(theme).png")
            )
            model.configuration.left.mode = .dpad
            model.configuration.left.zoneLayout = .radialFour
            try await exportReadmeWindow(
                ConfigurationView(model: model, managesWindowSize: true),
                scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("readme-shorter-\(theme).png")
            )
            model.configuration.left.mode = .mouse
            model.configuration.right.mode = .mouse
            try await exportReadmeWindow(
                ConfigurationView(model: model, managesWindowSize: true, initialTuningExpanded: true),
                scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("readme-both-tuning-\(theme).png"))
            try await exportReadmeWindow(
                OnboardingGuideView(model: model, onSkip: {}, onComplete: {}),
                isGuide: true, scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("readme-guide-welcome-\(theme).png")
            )
            var pager = OnboardingPager()
            pager.advance()
            pager.advance()
            try await exportReadmeWindow(
                OnboardingGuideView(model: permissionModel, onSkip: {}, onComplete: {}, initialPager: pager),
                isGuide: true, scheme: scheme, appearance: appearance,
                to: directory.appendingPathComponent("readme-guide-permissions-\(theme).png")
            )
        }
    }

    private func exportReadmeWindow<Content: View>(
        _ content: Content,
        isGuide: Bool = false,
        scheme: ColorScheme,
        appearance: NSAppearance.Name,
        to url: URL,
        prepare: ((NSView) -> Void)? = nil
    ) async throws {
        let size = isGuide ? PaddrStyle.Metrics.guideWindowSize : PaddrStyle.Metrics.defaultWindowSize
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: isGuide ? PaddrFamilyWindowChrome.styleMask : PaddrFamilyWindowChrome.configurationStyleMask,
            backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        defer { window.close() }
        window.title = isGuide ? "Paddr Guide" : "Paddr"
        window.appearance = NSAppearance(named: appearance)
        window.collectionBehavior.insert(.fullScreenNone)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.tabbingMode = .disallowed
        let controller = NSHostingController(rootView: content
            .environment(\.colorScheme, scheme)
            .environment(\.controlActiveState, .key))
        if !isGuide {
            window.toolbarStyle = .unifiedCompact
            controller.sizingOptions = []
        }
        window.contentViewController = controller
        PaddrFamilyWindowChrome.apply(to: window)
        if isGuide {
            PaddrFamilyWindowChrome.setUsableLayoutSize(size, for: window)
            PaddrFamilyWindowChrome.setMinimumUsableLayoutSize(PaddrStyle.Metrics.minimumGuideWindowSize, for: window)
        } else {
            PaddrFamilyWindowChrome.installConfigurationTitle(window.title, in: window)
            PaddrFamilyWindowChrome.setFreshDefaultUsableFrame(for: window)
        }
        if let screen = window.screen?.visibleFrame {
            window.setFrameTopLeftPoint(NSPoint(x: screen.minX + 80, y: screen.maxY - 40))
        }
        await settle(controller.view, passes: 60)
        if !isGuide {
            let scroll = try XCTUnwrap(configurationScrollView(in: controller.view))
            let document = try XCTUnwrap(scroll.documentView)
            XCTAssertEqual(scroll.contentSize.height, document.bounds.height, accuracy: 2,
                "README capture must fit its full document without blank space or screen-limited clipping")
        }
        // Include the actual titlebar instead of leaving its reserved area blank.
        let frameView = try XCTUnwrap(window.contentView?.superview)
        frameView.layoutSubtreeIfNeeded()
        prepare?(controller.view)
        try exportPNG(frameView, to: url)
        // Cached display exports don't include WindowServer's native glass pass.
        // Capture only this inert fixture window when access is already granted.
        // Never request or change Screen Recording/TCC permissions for evidence.
        if CGPreflightScreenCaptureAccess() {
            window.orderFront(nil)
            await settle(controller.view, passes: 12)
            prepare?(controller.view)
            controller.view.displayIfNeeded()
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            let fixture = try XCTUnwrap(content.windows.first { $0.windowID == CGWindowID(window.windowNumber) })
            let filter = SCContentFilter(desktopIndependentWindow: fixture)
            let configuration = SCScreenshotConfiguration()
            configuration.showsCursor = false
            configuration.ignoreShadows = true
            configuration.dynamicRange = .sdr
            let output = try await SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: configuration)
            let image = try XCTUnwrap(output.sdrImage)
            print("Composited fixture \(url.lastPathComponent): \(image.width)x\(image.height), window \(window.frame.size), filter scale \(filter.pointPixelScale)")
            let bitmap = NSBitmapImageRep(cgImage: image)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: url.deletingPathExtension().appendingPathExtension("composited.png"))
        } else {
            print("Composited capture unavailable: Screen Recording is not already granted; no permission requested")
        }
    }

    private func exportEvidence<Content: View>(
        _ content: Content,
        size: NSSize,
        scheme: ColorScheme,
        appearance: NSAppearance.Name,
        to url: URL
    ) async throws {
        let host = NSHostingView(rootView: content
            .environment(\.colorScheme, scheme)
            .background(PanelBackgroundView()))
        host.appearance = NSAppearance(named: appearance)
        host.frame = NSRect(origin: .zero, size: size)
        await settle(host, passes: 12)
        try exportPNG(host, to: url)
    }

    func testManagedWindowFitsExpandedTuningAndShrinksWithShorterContent() async throws {
        let model = try makeEditableMenuModel(hasSystemAccess: false)
        let initialized = await waitUntil { model.isInitialized }
        XCTAssertTrue(initialized)
        model.configuration.left.mode = .dpad
        model.configuration.right.mode = .dpad
        let controller = NSHostingController(rootView: ConfigurationView(model: model, managesWindowSize: true, initialTuningExpanded: true)
            .environment(\.accessibilityEnabled, true)
            .environment(\.colorScheme, .dark)
            .environment(\.controlActiveState, .key))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: PaddrStyle.Metrics.defaultWindowSize),
            styleMask: PaddrFamilyWindowChrome.configurationStyleMask, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.toolbarStyle = .unifiedCompact
        window.appearance = NSAppearance(named: .darkAqua)
        controller.sizingOptions = []
        window.contentViewController = controller
        let host = controller.view
        PaddrFamilyWindowChrome.installConfigurationTitle("Paddr", in: window)
        PaddrFamilyWindowChrome.setFreshDefaultUsableFrame(for: window)
        // Leave room below the top edge for growth without moving to another screen.
        if let screen = window.screen?.visibleFrame {
            window.setFrameTopLeftPoint(NSPoint(x: screen.minX + 80, y: screen.maxY - 40))
        }
        await settle(host, passes: 40)
        let collapsed = window.contentLayoutRect.size
        let top = window.frame.maxY
        XCTAssertFalse(window.styleMask.contains(.resizable))
        // Use the existing initial-disclosure fixture to mount expanded tuning
        // when switching modes, without synthesizing a coordinate-based click.
        model.configuration.left.mode = .mouse
        await settle(host, passes: 40)
        XCTAssertGreaterThan(window.contentLayoutRect.height, collapsed.height + 100)
        XCTAssertEqual(window.contentLayoutRect.width, collapsed.width, accuracy: 0.5)
        XCTAssertEqual(window.frame.maxY, top, accuracy: 0.5)
        let scroll = try XCTUnwrap(configurationScrollView(in: host))
        let document = try XCTUnwrap(scroll.documentView)
        XCTAssertLessThanOrEqual(document.bounds.height, scroll.contentSize.height + 1,
            "Expanded tuning and rear bindings must fit when the screen has room")
        if let path = ProcessInfo.processInfo.environment["PADDR_UI_EVIDENCE_DIR"] {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            try exportPNG(host, to: URL(fileURLWithPath: path).appendingPathComponent("managed-expanded-dark.png"))
        }
        model.configuration.left.mode = .dpad
        await settle(host, passes: 40)
        XCTAssertEqual(window.contentLayoutRect.height, collapsed.height, accuracy: 1)
        XCTAssertEqual(window.frame.maxY, top, accuracy: 0.5)
        if let path = ProcessInfo.processInfo.environment["PADDR_UI_EVIDENCE_DIR"] {
            try exportPNG(host, to: URL(fileURLWithPath: path).appendingPathComponent("managed-collapsed-dark.png"))
        }
    }

    func testMixedPadModesStayCompactAtNarrowTwoPadWidth() async throws {
        let state = DualPadEvidenceState(configuration: .default)
        state.configuration.left.scrollSensitivity = 1.7
        state.configuration.right.mouseAcceleration = 0.25
        state.configuration.right.pointerSmoothingEnabled = true
        state.configuration.right.pointerSmoothingStrength = 1
        state.configuration.right.tapStabilizationThresholdPoints = 10
        let host = dualPadHostingView(state: state)
        // The pad workspace inside the operator's 940-point window, after its insets.
        host.frame.size.width = 940 - (2 * PaddrStyle.Inset.chrome)
        await settle(host, passes: 12)
        let pointerHeight = host.fittingSize.height
        let leftMode = try XCTUnwrap(modeSelector(side: .left, in: host))
        let rightMode = try XCTUnwrap(modeSelector(side: .right, in: host))
        let leftFrame = frame(of: leftMode, in: host)
        XCTAssertEqual(leftFrame.midY, frame(of: rightMode, in: host).midY, accuracy: 1)
        XCTAssertLessThan(pointerHeight, 2 * PaddrStyle.Metrics.zoneMapHeight,
            "Common controls must share the preview band instead of creating a second large band below it")

        state.configuration.right.mode = .disabled
        await settle(host, passes: 12)
        XCTAssertTrue(leftMode === modeSelector(side: .left, in: host))
        XCTAssertEqual(frame(of: leftMode, in: host), leftFrame,
            "The left pad must not shift when the right pad is turned off")
        XCTAssertLessThanOrEqual(abs(host.fittingSize.height - pointerHeight), 2 * PaddrStyle.Spacing.s5,
            "A collapsed tuning summary must not create an oversized blank band on the other pad")
        XCTAssertEqual(state.configuration.left.scrollSensitivity, 1.7)
    }

    func testPadInspectorLeadingTracksModeColumnAcrossModesWidthsDirectionsAndAccessibility() async throws {
        for side in [PadSide.left, .right] {
            for direction in [LayoutDirection.leftToRight, .rightToLeft] {
                func content(_ mode: PadMode, _ size: DynamicTypeSize) -> some View {
                    PadConfigurationView(side: side, configuration: .constant(PadConfiguration(mode: mode)))
                        .environment(\.layoutDirection, direction)
                        .environment(\.dynamicTypeSize, size)
                }
                let host = NSHostingView(rootView: content(.mouse, .large))
                host.frame = CGRect(x: 0, y: 0, width: 488, height: 1600)
                await settle(host, passes: 12)
                let original = try XCTUnwrap(modeSelector(side: side, in: host))
                for size in [DynamicTypeSize.large, .accessibility1] {
                    for width in [CGFloat(488), 478, 472.5, 470, 469.5, 418, 413, 680] {
                        host.frame.size.width = width
                        for mode in PadMode.allCases {
                            host.rootView = content(mode, size)
                            await settle(host, passes: 12)
                            let selector = try XCTUnwrap(modeSelector(side: side, in: host))
                            XCTAssertTrue(selector === original, "Reflow/mode changes must retain the mounted header control")
                            let usesColumns = width >= PaddrStyle.previewInspectorColumnsBreakpoint && !size.isAccessibilitySize
                            let columnLeading = usesColumns ? PaddrPadColumns.inspectorLeading(in: width) : 0
                            let headerInline = width >= PaddrPadColumns.minimumInlineWidth && !size.isAccessibilitySize
                            let headerLeading = headerInline ? columnLeading : 0
                            let selectorFrame = frame(of: selector, in: host)
                            let actualHeaderLeading = direction == .leftToRight ? selectorFrame.minX : width - selectorFrame.maxX
                            XCTAssertEqual(actualHeaderLeading, headerLeading, accuracy: 0.6, "\(side)/\(mode)/\(width)/\(direction)/\(size)")
                            XCTAssertEqual(selectorFrame.width, 272, accuracy: 0.5)
                            for menu in descendants(of: PaddrPopUpButton.self, in: host) {
                                let rect = frame(of: menu, in: host)
                                let leading = direction == .leftToRight ? rect.minX : width - rect.maxX
                                XCTAssertEqual(leading, columnLeading, accuracy: 0.6, "Menu \(mode)/\(width)/\(direction)/\(size)")
                                XCTAssertEqual(rect.width, 192, accuracy: 0.5)
                                if headerInline { XCTAssertEqual(leading, actualHeaderLeading, accuracy: 0.6) }
                            }
                            for slider in descendants(of: NSSlider.self, in: host) where slider.accessibilityLabel() == "Sensitivity" {
                                let aligned = slider.convert(slider.alignmentRect(forFrame: slider.bounds), to: host)
                                let leading = direction == .leftToRight ? aligned.minX : width - aligned.maxX
                                XCTAssertEqual(leading, columnLeading, accuracy: 0.6, "Slider \(mode)/\(width)/\(direction)/\(size)")
                            }
                        }
                    }
                }
            }
        }
    }

    func testCompactSliderPreservesUsableTrackWidth() async throws {
        let row = ValueSliderRow(
            title: "Pointer acceleration", systemImage: "speedometer",
            value: .constant(0.5), range: 0...1, step: 0.01, valueText: "100%"
        )
        .environment(\.paddrStacksSettingLabels, true)
        .environment(\.accessibilityEnabled, true)
        .frame(width: PaddrStyle.minimumPadSectionWidth)
        let host = NSHostingView(rootView: row)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0,
            width: PaddrStyle.minimumPadSectionWidth, height: 120),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        host.frame = NSRect(x: 0, y: 0, width: PaddrStyle.minimumPadSectionWidth, height: 120)
        await settle(host, passes: 12)
        let slider = try XCTUnwrap(accessibilityElements(in: host).first {
            $0.accessibilityRole?() == .slider
        })
        let rect = try XCTUnwrap(slider.accessibilityFrame?())
        XCTAssertGreaterThanOrEqual(rect.width, 120)
        XCTAssertTrue(window.frame.contains(rect))
        XCTAssertLessThanOrEqual(host.fittingSize.width, PaddrStyle.minimumPadSectionWidth + 0.5)
    }

    private func exportPNG(_ view: NSView, to url: URL) throws {
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: url)
    }

    func testTopControlsReflowAt680PointsAndFitAvailableWidth() async {
        let model = makeMenuModel()
        let didInitialize = await waitUntil { model.isInitialized && model.hasSystemAccess }
        XCTAssertTrue(didInitialize)

        let hostingView = NSHostingView(rootView: TopControlsView(model: model))
        hostingView.frame = NSRect(x: 0, y: 0, width: 680, height: 240)
        await settle(hostingView)

        let compactSize = hostingView.fittingSize
        XCTAssertLessThanOrEqual(compactSize.width, 680.5)
        XCTAssertGreaterThan(compactSize.height, 0)

        hostingView.frame.size.width = PaddrStyle.Metrics.defaultContentWidth
        await settle(hostingView)

        let inlineSize = hostingView.fittingSize
        XCTAssertLessThanOrEqual(inlineSize.width, PaddrStyle.Metrics.defaultContentWidth + 0.5)
        XCTAssertGreaterThan(
            compactSize.height,
            inlineSize.height + (PaddrStyle.Metrics.row / 2),
            "The controls should use two rows at 680 points and one row above the breakpoint"
        )
    }

    func testSharedPermissionSetupKeepsBothRecoveryPathsAtCompactAndAccessibilitySizes() async throws {
        let model = try makeEditableMenuModel(hasSystemAccess: false)
        let initialized = await waitUntil { model.isInitialized && !model.hasSystemAccess }
        XCTAssertTrue(initialized)
        XCTAssertTrue(model.canEditActiveProfile, "Missing permissions must not prevent offline editing")

        for textSize in [DynamicTypeSize.medium, .accessibility5] {
            let host = NSHostingView(rootView: PermissionSetupContent(model: model, identifierPrefix: "test-setup")
                .environment(\.dynamicTypeSize, textSize)
                // XCTest has no assistive client to activate SwiftUI's semantic tree.
                .environment(\.accessibilityEnabled, true))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 592, height: 600),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            window.contentView = host
            host.frame = NSRect(x: 0, y: 0, width: 592, height: 600)
            await settle(host, passes: 12)
            XCTAssertLessThanOrEqual(host.fittingSize.width, 592.5)
            let elements = accessibilityElements(in: host)
            for (identifier, label) in [
                ("input-monitoring.request", "Request Input Monitoring"),
                ("input-monitoring.settings", "Open Input Monitoring Settings"),
                ("accessibility.request", "Request Accessibility"),
                ("accessibility.settings", "Open Accessibility Settings")
            ] {
                let button = try XCTUnwrap(elements.first {
                    $0.accessibilityIdentifier?() == "paddr.test-setup." + identifier
                }, "Missing permission action: " + identifier)
                XCTAssertEqual(button.accessibilityLabel?(), label)
                XCTAssertEqual(button.accessibilityRole?(), .button)
                let rect = try XCTUnwrap(button.accessibilityFrame?())
                XCTAssertGreaterThan(rect.width, 0)
                XCTAssertGreaterThan(rect.height, 0)
                XCTAssertTrue(window.frame.contains(rect), "Permission actions must remain visible")
            }
            for control in descendants(of: NSControl.self, in: host) {
                let rect = frame(of: control, in: host)
                XCTAssertGreaterThanOrEqual(rect.minX, -0.5)
                XCTAssertLessThanOrEqual(rect.maxX, host.bounds.maxX + 0.5)
            }
        }
    }

    func testAllDefaultModeCombinationsKeepControlsContainedAndBothPadsMounted() async throws {
        let model = try makeEditableMenuModel(hasSystemAccess: false)
        let initialized = await waitUntil { model.isInitialized && !model.hasSystemAccess }
        XCTAssertTrue(initialized)
        for left in PadMode.allCases {
            for right in PadMode.allCases {
                model.configuration.left.mode = left
                model.configuration.right.mode = right
                let host = NSHostingView(rootView: ConfigurationView(model: model))
                host.frame = NSRect(origin: .zero, size: PaddrStyle.Metrics.defaultWindowSize)
                await settle(host, passes: 12)
                let scrollView = try XCTUnwrap(configurationScrollView(in: host))
                XCTAssertGreaterThan(scrollView.contentSize.height, 0)
                XCTAssertLessThan(scrollView.contentSize.height, host.bounds.height,
                    "The fixed profile header and output footer must retain their own space")
                XCTAssertEqual(modeSelectors(in: host).count, 2)
                let documentHeight = await configurationContentHeight(
                    model: model, width: scrollView.contentSize.width)
                XCTAssertLessThanOrEqual(documentHeight, scrollView.contentSize.height + 0.5,
                    "The opening size must include both editors, rear buttons, and the bottom workspace inset: \(left)/\(right)")
                for control in descendants(of: NSControl.self, in: host) {
                    let rect = frame(of: control, in: host)
                    XCTAssertGreaterThanOrEqual(rect.minX, -0.5, "\(left)/\(right)")
                    XCTAssertLessThanOrEqual(rect.maxX, host.bounds.maxX + 0.5, "\(left)/\(right)")
                }
            }
        }
    }

    func testMinimumAndAccessibilityLayoutsScrollWithoutHorizontalClipping() async throws {
        let model = try makeEditableMenuModel(hasSystemAccess: false)
        let didInitialize = await waitUntil { model.isInitialized && !model.hasSystemAccess }
        XCTAssertTrue(didInitialize)
        model.configuration.left.mode = .dpad
        model.configuration.right.mode = .mouse

        for dynamicTypeSize in [DynamicTypeSize.medium, .accessibility5] {
            let hostingView = NSHostingView(
                rootView: ConfigurationView(model: model)
                    .environment(\.dynamicTypeSize, dynamicTypeSize)
                    .environment(\.layoutDirection, .rightToLeft)
            )
            hostingView.frame = NSRect(origin: .zero, size: PaddrStyle.Metrics.minimumWindowSize)
            await settle(hostingView, passes: 12)

            let scrollView = try XCTUnwrap(configurationScrollView(in: hostingView))
            let contentHeight = await configurationContentHeight(
                model: model,
                width: scrollView.contentSize.width,
                dynamicTypeSize: dynamicTypeSize,
                layoutDirection: .rightToLeft
            )
            XCTAssertGreaterThan(contentHeight, scrollView.contentSize.height)
            XCTAssertTrue(scrollView.hasVerticalScroller)
            for control in descendants(of: NSControl.self, in: hostingView) {
                let controlFrame = frame(of: control, in: hostingView)
                XCTAssertGreaterThanOrEqual(controlFrame.minX, hostingView.bounds.minX - 0.5)
                XCTAssertLessThanOrEqual(controlFrame.maxX, hostingView.bounds.maxX + 0.5)
            }
        }
    }

    func testApplyBarKeepsOutputAndGuidanceContainedAcrossWidthsAndTextSizes() async {
        let model = makeMenuModel(receiver: "Test puck")
        let initialized = await waitUntil { model.isInitialized && model.hasSystemAccess }
        XCTAssertTrue(initialized)
        XCTAssertEqual(model.readiness.nextAction, .connectController)
        for width in [CGFloat(680), 800, PaddrStyle.Metrics.defaultWindowSize.width] {
            for textSize in [DynamicTypeSize.medium, .accessibility5] {
                let host = NSHostingView(rootView: ApplyBarView(model: model)
                    .environment(\.dynamicTypeSize, textSize))
                host.frame = NSRect(x: 0, y: 0, width: width, height: 500)
                await settle(host)
                host.frame.size.height = host.fittingSize.height
                await settle(host)
                XCTAssertLessThanOrEqual(host.fittingSize.width, width + 0.5)
                XCTAssertGreaterThan(host.fittingSize.height, 0)
                XCTAssertEqual(descendants(of: NSSwitch.self, in: host).count, 1)
                for control in descendants(of: NSControl.self, in: host) {
                    let rect = frame(of: control, in: host)
                    XCTAssertGreaterThanOrEqual(rect.minX, -0.5)
                    XCTAssertLessThanOrEqual(rect.maxX, width + 0.5)
                    XCTAssertGreaterThanOrEqual(rect.minY, -0.5)
                    XCTAssertLessThanOrEqual(rect.maxY, host.bounds.maxY + 0.5)
                }
            }
        }
    }

    func testPermissionRecoveryStaysWithOutputAndSuppressesCompetingConnectionAdvice() async throws {
        for granted in [false, true] {
            let model = try makeEditableMenuModel(hasSystemAccess: granted)
            let initialized = await waitUntil { model.isInitialized }
            XCTAssertTrue(initialized)
            XCTAssertEqual(ApplyBarView(model: model).showsStatusMessage, granted)
            for textSize in [DynamicTypeSize.medium, .accessibility5] {
                let host = NSHostingView(rootView: ApplyBarView(model: model)
                    .environment(\.dynamicTypeSize, textSize)
                    .environment(\.accessibilityEnabled, true))
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 400),
                    styleMask: [.titled, .closable], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                defer { window.close() }
                window.contentView = host
                host.frame = NSRect(x: 0, y: 0, width: 680, height: 400)
                await settle(host, passes: 12)
                let elements = accessibilityElements(in: host)
                let setup = elements.filter { $0.accessibilityIdentifier?() == "paddr.permissions.open-setup" }
                XCTAssertEqual(setup.count, granted ? 0 : 1)
                for button in setup {
                    XCTAssertEqual(button.accessibilityRole?(), .button)
                    XCTAssertTrue(window.frame.contains(try XCTUnwrap(button.accessibilityFrame?())))
                }
                XCTAssertFalse(elements.contains { $0.accessibilityIdentifier?() == "paddr.status.battery" },
                    "Unavailable battery data belongs in connection details, not the footer")
                XCTAssertEqual(descendants(of: NSSwitch.self, in: host).count, 1)
                XCTAssertLessThanOrEqual(host.fittingSize.width, 680.5)
            }
        }
    }

    func testEnableOutputRemainsANativeSwitchWhenDraftHasPendingChanges() async throws {
        let model = try makeEditableMenuModel(hasSystemAccess: true)
        let initialized = await waitUntil { model.isInitialized }
        XCTAssertTrue(initialized)
        model.configuration.rearButtons.l4 = "F1"
        XCTAssertTrue(model.hasUnsavedChanges)
        XCTAssertFalse(model.isEnabled)

        let bar = ApplyBarView(model: model)
        XCTAssertTrue(bar.showsPendingSaveHint)
        XCTAssertEqual(String(localized: bar.outputToggleAccessibilityLabel), "Enable output")
        XCTAssertTrue(String(localized: bar.outputToggleHelp).contains("Turning on saves your pending changes."))
        let host = NSHostingView(rootView: bar)
        host.frame = NSRect(x: 0, y: 0, width: 680, height: 350)
        await settle(host)
        let toggle = try XCTUnwrap(descendants(of: NSSwitch.self, in: host).first)
        XCTAssertEqual(descendants(of: NSSwitch.self, in: host).count, 1)
        XCTAssertEqual(toggle.isEnabled, model.canToggleOutput)
        XCTAssertEqual(toggle.state, .off)
        toggle.performClick(nil)
        let enabled = await waitUntil { model.isEnabled && !model.hasUnsavedChanges }
        XCTAssertTrue(enabled, "The existing dirty-enable path must save before activation")
        await settle(host)
        XCTAssertTrue(toggle === descendants(of: NSSwitch.self, in: host).first)
        XCTAssertEqual(toggle.state, .on)
        XCTAssertFalse(ApplyBarView(model: model).showsPendingSaveHint)
        XCTAssertNotEqual(String(localized: ApplyBarView(model: model).outputValue), "Active",
            "Enabling without a connected receiver must not claim active output")
    }

    func testSaveAndOutputControlsRemainVisibleWhileMappingDocumentScrolls() async throws {
        let model = try makeEditableMenuModel(hasSystemAccess: false)
        let initialized = await waitUntil { model.isInitialized }
        XCTAssertTrue(initialized)
        model.configuration.left.mode = .dpad
        model.configuration.right.mode = .dpad
        let host = NSHostingView(rootView: ConfigurationView(model: model)
            // XCTest has no assistive client to activate SwiftUI's semantic tree.
            .environment(\.accessibilityEnabled, true))
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: PaddrStyle.Metrics.minimumWindowSize),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        defer { window.close() }
        host.sizingOptions = []
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: PaddrStyle.Metrics.minimumWindowSize)
        await settle(host, passes: 12)
        let scroll = try XCTUnwrap(configurationScrollView(in: host))
        let document = try XCTUnwrap(scroll.documentView)
        XCTAssertGreaterThan(document.bounds.height, scroll.contentSize.height)
        let initialScrollOrigin = scroll.contentView.bounds.origin.y
        let save = try XCTUnwrap(accessibilityElements(in: host).first {
            $0.accessibilityIdentifier?() == "paddr.profile.save-apply"
        })
        XCTAssertEqual(save.accessibilityRole?(), .button)
        let output = try XCTUnwrap(descendants(of: NSSwitch.self, in: host).first)
        XCTAssertFalse(output.isDescendant(of: document))
        let saveFrame = try XCTUnwrap(save.accessibilityFrame?())
        let outputFrame = output.accessibilityFrame()
        XCTAssertGreaterThan(saveFrame.width, 0)
        XCTAssertGreaterThan(saveFrame.height, 0)
        XCTAssertFalse(saveFrame.intersects(scroll.accessibilityFrame()),
            "The save action belongs above the scrolling mapping workspace")
        scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, document.bounds.height - scroll.contentSize.height)))
        scroll.reflectScrolledClipView(scroll.contentView)
        await settle(host)
        XCTAssertGreaterThan(scroll.contentView.bounds.origin.y, initialScrollOrigin)
        let scrolledSave = try XCTUnwrap(accessibilityElements(in: host).first {
            $0.accessibilityIdentifier?() == "paddr.profile.save-apply"
        })
        XCTAssertEqual(scrolledSave.accessibilityFrame?(), saveFrame)
        XCTAssertTrue(output === descendants(of: NSSwitch.self, in: host).first)
        XCTAssertEqual(output.accessibilityFrame(), outputFrame)
        for rect in [saveFrame, outputFrame] {
            XCTAssertTrue(window.frame.contains(rect), "Persistent actions must stay inside the window")
        }
    }

    func testConfigurationControlsStayHorizontallyContainedAtMinimumWindowWidth() async {
        let model = makeMenuModel()
        let didInitialize = await waitUntil { model.isInitialized && model.hasSystemAccess }
        XCTAssertTrue(didInitialize)
        model.configuration.left.mode = .dpad

        let hostingView = NSHostingView(rootView: ConfigurationView(model: model))
        hostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(width: PaddrStyle.Metrics.minimumWindowSize.width, height: 900)
        )
        await settle(hostingView)

        let controls = descendants(of: NSControl.self, in: hostingView)
        XCTAssertGreaterThanOrEqual(controls.count, 2)
        for control in controls {
            let controlFrame = frame(of: control, in: hostingView)
            XCTAssertGreaterThanOrEqual(controlFrame.minX, hostingView.bounds.minX - 0.5)
            XCTAssertLessThanOrEqual(controlFrame.maxX, hostingView.bounds.maxX + 0.5)
        }
    }

    func testNativePadModeControlIdentifiersRemainDistinctInHostedConfiguration() async {
        let model = makeMenuModel()
        let didInitialize = await waitUntil { model.isInitialized && model.hasSystemAccess }
        XCTAssertTrue(didInitialize)

        let hostingView = NSHostingView(rootView: ConfigurationView(model: model))
        hostingView.frame = NSRect(origin: .zero, size: PaddrStyle.Metrics.defaultWindowSize)
        await settle(hostingView)

        let identifiers = modeSelectors(in: hostingView).compactMap { $0.identifier?.rawValue }
        XCTAssertEqual(
            Set(identifiers),
            ["paddr.pad-mode.left", "paddr.pad-mode.right"],
            "The two simultaneously hosted native mode controls need distinct stable IDs"
        )
        XCTAssertEqual(identifiers.count, 2)
    }

    func testRestoredWideConfigurationUsesAvailableWidthWithoutDeadGutters() async throws {
        let model = makeMenuModel()
        let didInitialize = await waitUntil { model.isInitialized && model.hasSystemAccess }
        XCTAssertTrue(didInitialize)
        let restoredWidth: CGFloat = 1_440
        let hostingView = NSHostingView(rootView: ConfigurationView(model: model))
        hostingView.frame = NSRect(x: 0, y: 0, width: restoredWidth, height: 900)
        await settle(hostingView)

        let left = try XCTUnwrap(modeSelector(side: .left, in: hostingView))
        let right = try XCTUnwrap(modeSelector(side: .right, in: hostingView))
        let availableContentWidth = restoredWidth - (2 * PaddrStyle.Metrics.outerSpacing)
            - (2 * PaddrStyle.Inset.card)
        let expectedColumnWidth = (
            availableContentWidth - PaddrStyle.Spacing.s5
        ) / 2

        XCTAssertEqual(
            abs(frame(of: left, in: hostingView).midX - frame(of: right, in: hostingView).midX),
            expectedColumnWidth + PaddrStyle.Spacing.s5,
            accuracy: 1,
            "A restored wide window must expand both pad columns instead of centering a default-width island"
        )
    }

    func testDualPadEditorsMountSideBySideAtTheDefaultContentWidth() async throws {
        let state = DualPadEvidenceState(configuration: .default)
        let hostingView = dualPadHostingView(state: state)
        await settle(hostingView)

        XCTAssertEqual(modeSelectors(in: hostingView).count, 2)
        let left = try XCTUnwrap(modeSelector(side: .left, in: hostingView))
        let right = try XCTUnwrap(modeSelector(side: .right, in: hostingView))
        XCTAssertEqual(
            frame(of: left, in: hostingView).midY,
            frame(of: right, in: hostingView).midY,
            accuracy: 1
        )
        XCTAssertGreaterThan(
            abs(frame(of: left, in: hostingView).midX - frame(of: right, in: hostingView).midX),
            PaddrStyle.Metrics.row
        )
        XCTAssertEqual(
            abs(frame(of: left, in: hostingView).midX - frame(of: right, in: hostingView).midX),
            (PaddrStyle.Metrics.defaultContentWidth + PaddrStyle.Spacing.s5) / 2,
            accuracy: 1,
            "The two rendered editors should occupy equal columns at the default width"
        )
        XCTAssertEqual(
            PaddrStyle.padColumnWidth,
            (PaddrStyle.Metrics.defaultContentWidth - PaddrStyle.cardSpacing) / 2
        )
        XCTAssertLessThan(hostingView.fittingSize.height, hostingView.bounds.height / 2,
            "Pad editors must use intrinsic content height, not stretch to the host proposal")
    }

    func testDualPadBreakpointContainsControlsImmediatelyBelowAtAndAboveIt() async throws {
        let state = DualPadEvidenceState(configuration: .default)
        let hostingView = dualPadHostingView(state: state)

        for width in [
            PaddrStyle.Metrics.padEditorColumnsBreakpoint - 1,
            PaddrStyle.Metrics.padEditorColumnsBreakpoint,
            PaddrStyle.Metrics.padEditorColumnsBreakpoint + 1
        ] {
            hostingView.frame.size.width = width
            await settle(hostingView)

            let left = try XCTUnwrap(modeSelector(side: .left, in: hostingView))
            let right = try XCTUnwrap(modeSelector(side: .right, in: hostingView))
            if width < PaddrStyle.Metrics.padEditorColumnsBreakpoint {
                XCTAssertGreaterThan(
                    abs(frame(of: left, in: hostingView).midY
                        - frame(of: right, in: hostingView).midY),
                    PaddrStyle.Metrics.row
                )
            } else {
                XCTAssertEqual(
                    frame(of: left, in: hostingView).midY,
                    frame(of: right, in: hostingView).midY,
                    accuracy: 1
                )
            }

            for control in descendants(of: NSControl.self, in: hostingView) {
                let controlFrame = frame(of: control, in: hostingView)
                XCTAssertGreaterThanOrEqual(
                    controlFrame.minX,
                    hostingView.bounds.minX - 0.5,
                    "\(type(of: control)) escapes the leading edge at \(width)pt"
                )
                XCTAssertLessThanOrEqual(
                    controlFrame.maxX,
                    hostingView.bounds.maxX + 0.5,
                    "\(type(of: control)) escapes the trailing edge at \(width)pt"
                )
            }
        }
    }

    func testDualPadEditorsMutateLeftAndRightIndependently() async throws {
        var initialConfiguration = PaddrConfiguration.default
        initialConfiguration.left.mode = .scroll
        initialConfiguration.right.mode = .mouse
        let state = DualPadEvidenceState(configuration: initialConfiguration)
        let hostingView = dualPadHostingView(state: state)
        await settle(hostingView)

        let originalRight = state.configuration.right
        let leftModeSelector = try XCTUnwrap(modeSelector(side: .left, in: hostingView))
        leftModeSelector.selectedSegment = 3
        _ = leftModeSelector.sendAction(leftModeSelector.action, to: leftModeSelector.target)
        await settle(hostingView)

        XCTAssertEqual(state.configuration.left.mode, .dpad)
        XCTAssertEqual(state.configuration.right, originalRight)

        let originalLeft = state.configuration.left
        let rightModeSelector = try XCTUnwrap(modeSelector(side: .right, in: hostingView))
        rightModeSelector.selectedSegment = 0
        _ = rightModeSelector.sendAction(rightModeSelector.action, to: rightModeSelector.target)
        await settle(hostingView)

        XCTAssertEqual(state.configuration.left, originalLeft)
        XCTAssertEqual(state.configuration.right.mode, .disabled)
        XCTAssertEqual(modeSelectors(in: hostingView).count, 2)
    }

    func testDualPadEditorsStackAtNarrowWidthWithoutRemountingEitherEditor() async throws {
        let state = DualPadEvidenceState(configuration: .default)
        let hostingView = dualPadHostingView(state: state)
        await settle(hostingView)

        let initialLeft = try XCTUnwrap(modeSelector(side: .left, in: hostingView))
        let initialRight = try XCTUnwrap(modeSelector(side: .right, in: hostingView))
        XCTAssertEqual(
            frame(of: initialLeft, in: hostingView).midY,
            frame(of: initialRight, in: hostingView).midY,
            accuracy: 1
        )

        hostingView.frame.size.width = PaddrStyle.Metrics.padEditorColumnsBreakpoint - 1
        await settle(hostingView)

        let reflowedLeft = try XCTUnwrap(modeSelector(side: .left, in: hostingView))
        let reflowedRight = try XCTUnwrap(modeSelector(side: .right, in: hostingView))
        XCTAssertGreaterThan(
            abs(frame(of: reflowedLeft, in: hostingView).midY
                - frame(of: reflowedRight, in: hostingView).midY),
            PaddrStyle.Metrics.row
        )
        XCTAssertTrue(initialLeft === reflowedLeft)
        XCTAssertTrue(initialRight === reflowedRight)
        XCTAssertEqual(modeSelectors(in: hostingView).count, 2)

        XCTAssertLessThan(hostingView.fittingSize.height, hostingView.bounds.height,
            "Stacked editors must retain natural content heights")
    }

    func testAccessibilityTextStacksWidePadEditorsAndContainsEveryControl() async throws {
        let state = DualPadEvidenceState(configuration: .default)
        let hostingView = NSHostingView(
            rootView: DualPadEvidenceHarness(state: state)
                .environment(\.dynamicTypeSize, .accessibility1)
        )
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: PaddrStyle.Metrics.defaultContentWidth,
            height: 2_000
        )
        await settle(hostingView)

        let left = try XCTUnwrap(modeSelector(side: .left, in: hostingView))
        let right = try XCTUnwrap(modeSelector(side: .right, in: hostingView))
        XCTAssertGreaterThan(
            abs(frame(of: left, in: hostingView).midY - frame(of: right, in: hostingView).midY),
            PaddrStyle.Metrics.row,
            "Accessibility text must stack editors even when regular-size text uses columns"
        )
        for control in descendants(of: NSControl.self, in: hostingView) {
            let controlFrame = frame(of: control, in: hostingView)
            XCTAssertGreaterThanOrEqual(controlFrame.minX, hostingView.bounds.minX - 0.5)
            XCTAssertLessThanOrEqual(controlFrame.maxX, hostingView.bounds.maxX + 0.5)
        }
    }

    func testEqualHeightColumnsReturnToNaturalIndependentStackedHeights() async throws {
        let recorder = AdaptiveSplitSentinelRecorder()
        let hostingView = NSHostingView(
            rootView: EqualHeightSplitEvidenceHarness(recorder: recorder)
        )
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: PaddrStyle.Metrics.defaultContentWidth,
            height: 1_400
        )
        await settle(hostingView)

        let initialShort = try XCTUnwrap(boundsProbe("short", in: hostingView))
        let initialTall = try XCTUnwrap(boundsProbe("tall", in: hostingView))
        XCTAssertEqual(
            frame(of: initialShort, in: hostingView).height,
            frame(of: initialTall, in: hostingView).height,
            accuracy: 0.5
        )
        XCTAssertEqual(
            frame(of: initialTall, in: hostingView).height,
            420 + (2 * PaddrStyle.Inset.card),
            accuracy: 0.5
        )
        XCTAssertLessThan(
            frame(of: initialTall, in: hostingView).height,
            hostingView.bounds.height / 2,
            "The equal-height layout must ignore the arbitrary host-height proposal"
        )

        hostingView.frame.size.width = PaddrStyle.Metrics.padEditorColumnsBreakpoint - 1
        await settle(hostingView)

        let stackedShort = try XCTUnwrap(boundsProbe("short", in: hostingView))
        let stackedTall = try XCTUnwrap(boundsProbe("tall", in: hostingView))
        XCTAssertTrue(initialShort === stackedShort)
        XCTAssertTrue(initialTall === stackedTall)
        XCTAssertEqual(
            frame(of: stackedShort, in: hostingView).height,
            260 + (2 * PaddrStyle.Inset.card),
            accuracy: 0.5
        )
        XCTAssertEqual(
            frame(of: stackedTall, in: hostingView).height,
            420 + (2 * PaddrStyle.Inset.card),
            accuracy: 0.5
        )
        XCTAssertGreaterThan(
            abs(
                frame(of: stackedShort, in: hostingView).midY
                    - frame(of: stackedTall, in: hostingView).midY
            ),
            PaddrStyle.Metrics.row
        )
        XCTAssertEqual(recorder.mountCount(for: "short"), 1)
        XCTAssertEqual(recorder.mountCount(for: "tall"), 1)
    }

    func testAdaptiveSplitRetainsOneStatefulIdentityPerChildAcrossReflowAndAccessibilityChange() async throws {
        let recorder = AdaptiveSplitSentinelRecorder()
        let environment = AdaptiveSplitEvidenceEnvironment()
        let hostingView = NSHostingView(
            rootView: AdaptiveSplitEvidenceHarness(
                environment: environment,
                recorder: recorder
            )
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 820, height: 180)
        await settle(hostingView)

        let initialLeading = try XCTUnwrap(sentinelButton("leading", in: hostingView))
        let initialTrailing = try XCTUnwrap(sentinelButton("trailing", in: hostingView))
        XCTAssertEqual(
            frame(of: initialLeading, in: hostingView).width,
            PaddrStyle.Metrics.zoneMapWidth,
            accuracy: 0.5,
            "The rendered leading pad/map column must retain its protected 190-point width"
        )
        XCTAssertEqual(
            frame(of: initialLeading, in: hostingView).midY,
            frame(of: initialTrailing, in: hostingView).midY,
            accuracy: 1
        )
        XCTAssertEqual(
            frame(of: initialTrailing, in: hostingView).minX
                - frame(of: initialLeading, in: hostingView).maxX,
            PaddrStyle.previewInspectorSpacing,
            accuracy: 0.5,
            "Dividerless preview and settings columns must retain their 16-point gutter"
        )
        initialLeading.performClick(nil)
        initialTrailing.performClick(nil)
        await settle(hostingView)
        XCTAssertEqual(recorder.value(for: "leading"), 1)
        XCTAssertEqual(recorder.value(for: "trailing"), 1)

        environment.dynamicTypeSize = .accessibility1
        await settle(hostingView)

        let accessibilityLeading = try XCTUnwrap(sentinelButton("leading", in: hostingView))
        let accessibilityTrailing = try XCTUnwrap(sentinelButton("trailing", in: hostingView))
        XCTAssertGreaterThan(
            abs(frame(of: accessibilityLeading, in: hostingView).midY
                - frame(of: accessibilityTrailing, in: hostingView).midY),
            PaddrStyle.Metrics.row / 2
        )
        XCTAssertTrue(initialLeading === accessibilityLeading)
        XCTAssertTrue(initialTrailing === accessibilityTrailing)

        hostingView.frame.size.width = 640
        await settle(hostingView)

        let reflowedLeading = try XCTUnwrap(sentinelButton("leading", in: hostingView))
        let reflowedTrailing = try XCTUnwrap(sentinelButton("trailing", in: hostingView))
        XCTAssertTrue(initialLeading === reflowedLeading)
        XCTAssertTrue(initialTrailing === reflowedTrailing)
        XCTAssertEqual(recorder.mountCount(for: "leading"), 1)
        XCTAssertEqual(recorder.mountCount(for: "trailing"), 1)
        XCTAssertEqual(recorder.value(for: "leading"), 1)
        XCTAssertEqual(recorder.value(for: "trailing"), 1)

        reflowedLeading.performClick(nil)
        reflowedTrailing.performClick(nil)
        await settle(hostingView)
        XCTAssertEqual(recorder.value(for: "leading"), 2)
        XCTAssertEqual(recorder.value(for: "trailing"), 2)
        XCTAssertEqual(recorder.mountCount(for: "leading"), 1)
        XCTAssertEqual(recorder.mountCount(for: "trailing"), 1)
    }

    private func dualPadHostingView(state: DualPadEvidenceState) -> NSHostingView<DualPadEvidenceHarness> {
        let hostingView = NSHostingView(rootView: DualPadEvidenceHarness(state: state))
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: PaddrStyle.Metrics.defaultContentWidth,
            height: 1_400
        )
        return hostingView
    }

    private func makeMenuModel(receiver: String? = nil) -> PaddrMenuModel {
        PaddrMenuModel(
            dependencies: MenuDependencies(
                session: LayoutEvidenceSession(),
                loadProfiles: { ConfigurationProfileLoadResult(document: .default) },
                saveProfiles: { _ in },
                probeReceiver: { receiver },
                accessibilityTrusted: { _ in true },
                inputMonitoringAccess: { _ in .granted },
                openPrivacySettings: { _ in },
                sleep: { _ in throw CancellationError() },
                reconnectDelay: { _ in throw CancellationError() }
            )
        )
    }

    private func makeEditableMenuModel(
        hasSystemAccess: Bool, inputMonitoringGranted: Bool? = nil, accessibilityGranted: Bool? = nil,
        profileName: String = "Editable"
    ) throws -> PaddrMenuModel {
        var document = ConfigurationProfileDocument.default
        let profile = try document.createProfile(named: profileName)
        try document.activateProfile(id: profile.id)
        let loadedDocument = document
        return PaddrMenuModel(
            dependencies: MenuDependencies(
                session: LayoutEvidenceSession(),
                loadProfiles: { ConfigurationProfileLoadResult(document: loadedDocument) },
                saveProfiles: { _ in },
                probeReceiver: { nil },
                accessibilityTrusted: { _ in accessibilityGranted ?? hasSystemAccess },
                inputMonitoringAccess: { _ in (inputMonitoringGranted ?? hasSystemAccess) ? .granted : .denied },
                openPrivacySettings: { _ in },
                sleep: { _ in throw CancellationError() },
                reconnectDelay: { _ in throw CancellationError() }
            )
        )
    }

    private func configurationScrollView(in view: NSView) -> NSScrollView? {
        descendants(of: NSScrollView.self, in: view).max {
            ($0.contentSize.width * $0.contentSize.height)
                < ($1.contentSize.width * $1.contentSize.height)
        }
    }

    private func configurationContentHeight(
        model: PaddrMenuModel,
        width: CGFloat,
        dynamicTypeSize: DynamicTypeSize = .medium,
        layoutDirection: LayoutDirection = .leftToRight
    ) async -> CGFloat {
        let hostingView = NSHostingView(
            rootView: ConfigurationContentView(model: model)
                .environment(\.dynamicTypeSize, dynamicTypeSize)
                .environment(\.layoutDirection, layoutDirection)
        )
        hostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(width: width, height: 2_000)
        )
        await settle(hostingView, passes: 12)
        return hostingView.fittingSize.height
    }

    private func modeSelectors(in view: NSView) -> [NSSegmentedControl] {
        descendants(of: NSSegmentedControl.self, in: view).filter { $0.segmentCount == 4 }
    }

    private func modeSelector(side: PadSide, in view: NSView) -> NSSegmentedControl? {
        modeSelectors(in: view).first {
            $0.identifier?.rawValue == PaddrAccessibility.identifier("pad-mode", side.rawValue)
        }
    }

    private func sentinelButton(_ identifier: String, in view: NSView) -> NSButton? {
        descendants(of: NSButton.self, in: view).first {
            $0.identifier?.rawValue == identifier
        }
    }

    private func boundsProbe(_ identifier: String, in view: NSView) -> AdaptiveSplitBoundsNSView? {
        descendants(of: AdaptiveSplitBoundsNSView.self, in: view).first {
            $0.identifier?.rawValue == identifier
        }
    }

    private func frame(of view: NSView, in ancestor: NSView) -> NSRect {
        view.convert(view.bounds, to: ancestor)
    }

    /// SwiftUI exposes AccessibilityNode objects that implement the public Objective-C
    /// accessibility selectors without declaring NSAccessibilityProtocol conformance.
    private func accessibilityElements(in view: NSView) -> [AnyObject] {
        var visited = Set<ObjectIdentifier>()
        func walk(_ object: AnyObject) -> [AnyObject] {
            guard visited.insert(ObjectIdentifier(object)).inserted else { return [] }
            let children = object.accessibilityChildren?() as? [Any] ?? []
            return [object] + children.flatMap { walk($0 as AnyObject) }
        }
        return walk(view)
    }

    private func descendants<ViewType: NSView>(
        of type: ViewType.Type,
        in view: NSView
    ) -> [ViewType] {
        let current = (view as? ViewType).map { [$0] } ?? []
        return current + view.subviews.flatMap { descendants(of: type, in: $0) }
    }

    private func settle(_ hostingView: NSView, passes: Int = 6) async {
        for _ in 0..<passes {
            hostingView.layoutSubtreeIfNeeded()
            await Task.yield()
        }
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () async -> Bool
    ) async -> Bool {
        for _ in 0..<200 {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
}

@MainActor
@Observable
private final class DualPadEvidenceState {
    var configuration: PaddrConfiguration

    init(configuration: PaddrConfiguration) {
        self.configuration = configuration
    }
}

private struct DualPadEvidenceHarness: View {
    @Bindable var state: DualPadEvidenceState

    var body: some View {
        DualPadConfigurationView(
            configuration: $state.configuration,
            appearsEnabled: true,
            isEditable: true
        )
    }
}

private struct LayoutEvidenceSession: TrackpadSessionControlling {
    func start(
        configuration: PaddrConfiguration,
        observeOnly: Bool,
        outputGate: OutputGate?
    ) async -> AsyncStream<TrackpadSessionEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    @discardableResult
    func stop() async -> TrackpadSessionStopOutcome { .clean }
}

@MainActor
@Observable
private final class AdaptiveSplitEvidenceEnvironment {
    var dynamicTypeSize: DynamicTypeSize = .medium
}

@MainActor
private final class AdaptiveSplitSentinelRecorder {
    private var mountCounts: [String: Int] = [:]
    private var values: [String: Int] = [:]

    func recordMount(identifier: String) {
        mountCounts[identifier, default: 0] += 1
    }

    func recordValue(_ value: Int, identifier: String) {
        values[identifier] = value
    }

    func mountCount(for identifier: String) -> Int {
        mountCounts[identifier, default: 0]
    }

    func value(for identifier: String) -> Int? {
        values[identifier]
    }
}

private struct AdaptiveSplitEvidenceHarness: View {
    @Bindable var environment: AdaptiveSplitEvidenceEnvironment
    let recorder: AdaptiveSplitSentinelRecorder

    var body: some View {
        PaddrAdaptiveSplitView(
            breakpoint: 680,
            leadingWidth: PaddrStyle.Metrics.zoneMapWidth,
            showsDivider: false,
            leading: {
                AdaptiveSplitStateSentinel(identifier: "leading", recorder: recorder)
            },
            trailing: {
                AdaptiveSplitStateSentinel(identifier: "trailing", recorder: recorder)
            }
        )
        .environment(\.dynamicTypeSize, environment.dynamicTypeSize)
    }
}

private struct EqualHeightSplitEvidenceHarness: View {
    let recorder: AdaptiveSplitSentinelRecorder

    var body: some View {
        PaddrAdaptiveSplitView(
            equalHeightColumnsBreakpoint: PaddrStyle.Metrics.padEditorColumnsBreakpoint,
            leading: {
                EqualHeightEvidenceCard(
                    identifier: "short",
                    naturalHeight: 260,
                    recorder: recorder
                )
            },
            trailing: {
                EqualHeightEvidenceCard(
                    identifier: "tall",
                    naturalHeight: 420,
                    recorder: recorder
                )
            }
        )
    }
}

private struct EqualHeightEvidenceCard: View {
    @Environment(\.paddrFillsEqualHeightColumn) private var fillsEqualHeightColumn

    let identifier: String
    let naturalHeight: CGFloat
    let recorder: AdaptiveSplitSentinelRecorder

    var body: some View {
        Color.clear
            .frame(height: naturalHeight)
            .frame(
                maxWidth: .infinity,
                maxHeight: fillsEqualHeightColumn ? .infinity : nil,
                alignment: .topLeading
            )
            .paddrCard()
            .background {
                AdaptiveSplitBoundsProbe(identifier: identifier, recorder: recorder)
            }
    }
}

private final class AdaptiveSplitBoundsNSView: NSView {}

private struct AdaptiveSplitBoundsProbe: NSViewRepresentable {
    let identifier: String
    let recorder: AdaptiveSplitSentinelRecorder

    func makeNSView(context: Context) -> AdaptiveSplitBoundsNSView {
        let view = AdaptiveSplitBoundsNSView()
        view.identifier = NSUserInterfaceItemIdentifier(identifier)
        recorder.recordMount(identifier: identifier)
        return view
    }

    func updateNSView(_ view: AdaptiveSplitBoundsNSView, context: Context) {}
}

private struct AdaptiveSplitStateSentinel: View {
    let identifier: String
    let recorder: AdaptiveSplitSentinelRecorder
    @State private var value = 0

    var body: some View {
        AdaptiveSplitSentinelButton(
            identifier: identifier,
            value: $value,
            recorder: recorder
        )
    }
}

private struct AdaptiveSplitSentinelButton: NSViewRepresentable {
    let identifier: String
    @Binding var value: Int
    let recorder: AdaptiveSplitSentinelRecorder

    @MainActor
    final class Coordinator: NSObject {
        var value: Binding<Int>

        init(value: Binding<Int>) {
            self.value = value
        }

        @objc func incrementValue() {
            value.wrappedValue += 1
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    func makeNSView(context: Context) -> NSButton {
        recorder.recordMount(identifier: identifier)
        let button = NSButton(
            title: identifier,
            target: context.coordinator,
            action: #selector(Coordinator.incrementValue)
        )
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.value = $value
        button.title = "\(identifier):\(value)"
        recorder.recordValue(value, identifier: identifier)
    }
}

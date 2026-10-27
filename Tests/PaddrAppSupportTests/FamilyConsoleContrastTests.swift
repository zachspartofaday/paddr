import AppKit
import SwiftUI
import XCTest

import PaddrAppSupport
@testable import PaddrMenu

@MainActor
final class FamilyConsoleContrastTests: XCTestCase {
    func testProminentControlPairMeetsTextContrastInBothAppearances() throws {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            let tint = try resolved(PaddrStyle.controlTint, appearance: appearance)
            let foreground = try resolved(PaddrStyle.controlForeground, appearance: appearance)
            XCTAssertGreaterThanOrEqual(foreground.contrastRatio(with: tint), 4.5, name.rawValue)
        }
    }

    func testAccentRolesAndForegroundAreOneAdaptivePair() throws {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            let accent = try resolved(PaddrStyle.action, appearance: appearance)
            let expected = name == .darkAqua
                ? SRGBColor(red: 120 / 255, green: 199 / 255, blue: 189 / 255, alpha: 1)
                : SRGBColor(red: 40 / 255, green: 89 / 255, blue: 207 / 255, alpha: 1)
            assertEqual(accent, expected)
            for role in [PaddrStyle.controlTint, PaddrStyle.selectionBoundary, PaddrStyle.selectedZoneCaptionFill] {
                assertEqual(try resolved(role, appearance: appearance), accent)
            }
            assertEqual(try resolved(PaddrStyle.controlForeground, appearance: appearance),
                try resolved(PaddrStyle.selectedZoneCaptionForeground, appearance: appearance))
            // Hover and press preserve readable selected text as well as the fill.
            for overlay in [PaddrStyle.controlHover, PaddrStyle.controlPressed] {
                let fill = try resolved(overlay, appearance: appearance).composited(over: accent)
                let foreground = try resolved(PaddrStyle.controlForeground, appearance: appearance)
                XCTAssertGreaterThanOrEqual(foreground.contrastRatio(with: fill), 4.5)
            }
        }
    }

    func testWorkspaceTextMeetsContrastInBothAppearances() throws {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            for backgroundColor in [PaddrStyle.night0, PaddrStyle.night1] {
                let background = try resolved(backgroundColor, appearance: appearance)
                for textColor in [PaddrStyle.textPrimary, PaddrStyle.textSecondary, PaddrStyle.textTertiary] {
                    let foreground = try resolved(textColor, appearance: appearance)
                    XCTAssertGreaterThanOrEqual(foreground.contrastRatio(with: background), 4.5, name.rawValue)
                }
            }
        }
    }

    func testMenuBarSemanticTintsMeetLightAndDarkNonTextContrast() throws {
        let lightAppearance = try XCTUnwrap(NSAppearance(named: .aqua))
        let darkAppearance = try XCTUnwrap(NSAppearance(named: .darkAqua))
        let lightBackground = SRGBColor(red: 1, green: 1, blue: 1, alpha: 1)
        let darkBackground = try resolved(PaddrStyle.night1, appearance: darkAppearance)

        for role in [MenuBarTintRole.active, .warning] {
            let dynamicColor = try XCTUnwrap(PaddrMenuBarPalette.color(for: role))
            let lightColor = try resolved(dynamicColor, appearance: lightAppearance)
            let darkColor = try resolved(dynamicColor, appearance: darkAppearance)
            XCTAssertGreaterThanOrEqual(lightColor.contrastRatio(with: lightBackground), 3)
            XCTAssertGreaterThanOrEqual(darkColor.contrastRatio(with: darkBackground), 3)
        }
    }

    func testSelectedZoneBoundaryAndCaptionMeetRenderedContrastInBothAppearances() throws {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let drawingAppearance = try XCTUnwrap(NSAppearance(named: name))
            let background = try resolved(PaddrStyle.night1, appearance: drawingAppearance)
            let boundary = try resolved(PaddrStyle.selectionBoundary, appearance: drawingAppearance)
            for contrast in [ColorSchemeContrast.standard, .increased] {
                let appearance = PaddrAppearance(colorSchemeContrast: contrast)
                for elevated in [false, true] {
                    let surface = try resolved(appearance.surface(elevated: elevated), appearance: drawingAppearance)
                        .composited(over: background)
                    for fill in [PaddrStyle.selectedZoneFillTop, PaddrStyle.selectedZoneFillBottom] {
                        let selected = try resolved(fill, appearance: drawingAppearance).composited(over: surface)
                        XCTAssertGreaterThanOrEqual(boundary.contrastRatio(with: selected), 3,
                            "Selected zone boundary: \(name.rawValue), \(contrast), elevated=\(elevated)")
                    }
                }
            }
            let captionFill = try resolved(PaddrStyle.selectedZoneCaptionFill, appearance: drawingAppearance)
            let captionForeground = try resolved(PaddrStyle.selectedZoneCaptionForeground, appearance: drawingAppearance)
            XCTAssertGreaterThanOrEqual(captionForeground.contrastRatio(with: captionFill), 4.5, name.rawValue)
        }
    }

    func testPointerTapBoundaryMeetsRenderedContrastInBothAppearances() throws {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let drawingAppearance = try XCTUnwrap(NSAppearance(named: name))
            let background = try resolved(PaddrStyle.night1, appearance: drawingAppearance)
            let boundary = try resolved(PaddrStyle.selectionBoundary, appearance: drawingAppearance)
            let tapFill = try resolved(PaddrStyle.selectedTapFill, appearance: drawingAppearance)
            for contrast in [ColorSchemeContrast.standard, .increased] {
                let appearance = PaddrAppearance(colorSchemeContrast: contrast)
                for elevated in [false, true] {
                    let pad = try resolved(appearance.surface(elevated: elevated), appearance: drawingAppearance)
                        .composited(over: background)
                    XCTAssertGreaterThanOrEqual(boundary.contrastRatio(with: tapFill.composited(over: pad)), 3,
                        "Pointer boundary: \(name.rawValue), \(contrast), elevated=\(elevated)")
                }
            }
        }
    }

    func testPermissionStatusAndDetailTextMeetContrastInBothAppearances() throws {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            for surface in [PaddrStyle.canvas, PaddrStyle.workspace] {
                let background = try resolved(surface, appearance: appearance)
                for text in [PaddrStyle.successText, PaddrStyle.warningText, PaddrStyle.textSecondary] {
                    let foreground = try resolved(text, appearance: appearance)
                    XCTAssertGreaterThanOrEqual(foreground.contrastRatio(with: background), 4.5, name.rawValue)
                }
            }
        }
    }

    func testIncreasedContrastStrengthensBoundariesWithoutReintroducingTransparency() throws {
        let standard = PaddrAppearance(colorSchemeContrast: .standard)
        let increased = PaddrAppearance(colorSchemeContrast: .increased)
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let drawingAppearance = try XCTUnwrap(NSAppearance(named: name))
            for elevated in [false, true] {
                let surface = try resolved(standard.surface(elevated: elevated), appearance: drawingAppearance)
                let increasedSurface = try resolved(increased.surface(elevated: elevated), appearance: drawingAppearance)
                XCTAssertEqual(surface.alpha, 1, accuracy: 0.001)
                XCTAssertEqual(increasedSurface.alpha, 1, accuracy: 0.001)
                let standardBoundary = try resolved(standard.surfaceStroke, appearance: drawingAppearance)
                let increasedBoundary = try resolved(increased.surfaceStroke, appearance: drawingAppearance)
                XCTAssertGreaterThan(increasedBoundary.contrastRatio(with: increasedSurface),
                    standardBoundary.contrastRatio(with: surface), name.rawValue)
            }
        }
        XCTAssertGreaterThan(increased.strokeWidth, standard.strokeWidth)
    }

    func testStatusSemanticsRemainReadableInBothAppearances() throws {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            let background = try resolved(PaddrStyle.night1, appearance: appearance)
            for (state, tone, text) in [
                (StatusBadgeState.ready, PaddrStyle.successGreen, PaddrStyle.successText),
                (StatusBadgeState.critical, PaddrStyle.errorText, PaddrStyle.errorText)
            ] {
                let foreground = try resolved(state.textColor, appearance: appearance)
                assertEqual(try resolved(state.color, appearance: appearance), try resolved(tone, appearance: appearance))
                assertEqual(foreground, try resolved(text, appearance: appearance))
                XCTAssertGreaterThanOrEqual(foreground.contrastRatio(with: background), 4.5, name.rawValue)
            }
        }
    }

    private func resolved(
        _ color: Color,
        appearance: NSAppearance? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> SRGBColor {
        try resolved(NSColor(color), appearance: appearance, file: file, line: line)
    }

    private func resolved(
        _ color: NSColor,
        appearance: NSAppearance? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> SRGBColor {
        var resolvedColor: NSColor?
        if let appearance {
            appearance.performAsCurrentDrawingAppearance {
                resolvedColor = color.usingColorSpace(.sRGB)
            }
        } else {
            resolvedColor = color.usingColorSpace(.sRGB)
        }
        let color = try XCTUnwrap(resolvedColor, file: file, line: line)
        return SRGBColor(
            red: color.redComponent,
            green: color.greenComponent,
            blue: color.blueComponent,
            alpha: color.alphaComponent
        )
    }

    private func assertEqual(
        _ lhs: SRGBColor,
        _ rhs: SRGBColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(lhs.red, rhs.red, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(lhs.green, rhs.green, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(lhs.blue, rhs.blue, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(lhs.alpha, rhs.alpha, accuracy: 0.001, file: file, line: line)
    }
}

private struct SRGBColor {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    func withAlpha(_ alpha: Double) -> Self {
        Self(red: red, green: green, blue: blue, alpha: CGFloat(alpha))
    }

    func composited(over background: Self) -> Self {
        let outputAlpha = alpha + background.alpha * (1 - alpha)
        guard outputAlpha > 0 else {
            return Self(red: 0, green: 0, blue: 0, alpha: 0)
        }
        return Self(
            red: (red * alpha + background.red * background.alpha * (1 - alpha)) / outputAlpha,
            green: (green * alpha + background.green * background.alpha * (1 - alpha)) / outputAlpha,
            blue: (blue * alpha + background.blue * background.alpha * (1 - alpha)) / outputAlpha,
            alpha: outputAlpha
        )
    }

    func contrastRatio(with other: Self) -> CGFloat {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private var relativeLuminance: CGFloat {
        0.2126 * Self.linearized(red)
            + 0.7152 * Self.linearized(green)
            + 0.0722 * Self.linearized(blue)
    }

    private static func linearized(_ component: CGFloat) -> CGFloat {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}

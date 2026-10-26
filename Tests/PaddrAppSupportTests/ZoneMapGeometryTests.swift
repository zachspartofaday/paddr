import CoreGraphics
import SwiftUI
@testable import PaddrMenu
import XCTest
@testable import PaddrAppSupport
import PaddrCore

final class ZoneMapGeometryTests: XCTestCase {
    @MainActor
    func testBespokePadShellAndSelectedOutlineShareThe14PointCorner() {
        let bounds = CGRect(x: 0, y: 0, width: 190, height: 182)
        XCTAssertEqual(PaddrStyle.Radius.pad, 14)
        let shell = PaddrPadShape().path(in: bounds)
        XCTAssertFalse(shell.contains(.zero))
        XCTAssertTrue(shell.contains(CGPoint(x: 6, y: 6)),
            "The approved tighter corner must include this point that the old 30-point shell excluded")
        let outline = ZoneMapGeometry.selectedOutlineRegion(
            for: CGPath(rect: CGRect(x: 0, y: 0, width: 95, height: 91), transform: nil),
            in: bounds, cornerRadius: PaddrStyle.Radius.pad, lineWidth: 2)
        XCTAssertFalse(outline.contains(CGPoint(x: 1, y: 1)))
        XCTAssertTrue(outline.contains(CGPoint(x: 6, y: 6)))
        XCTAssertEqual(outline.boundingBoxOfPath.maxX, 95, accuracy: 0.001,
            "Changing the shell must preserve the contiguous internal divider")
    }

    func testSelectedOutlineInsetsEveryOuterEdgeAndPreservesInternalDividers() {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 180)
        let lineWidth: CGFloat = 2
        let inset = lineWidth / 2
        let quadrants = [
            CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width / 2, height: bounds.height / 2),
            CGRect(x: bounds.midX, y: bounds.minY, width: bounds.width / 2, height: bounds.height / 2),
            CGRect(x: bounds.midX, y: bounds.midY, width: bounds.width / 2, height: bounds.height / 2),
            CGRect(x: bounds.minX, y: bounds.midY, width: bounds.width / 2, height: bounds.height / 2)
        ]
        let expectedBounds = [
            CGRect(x: inset, y: inset, width: bounds.width / 2 - inset, height: bounds.height / 2 - inset),
            CGRect(
                x: bounds.midX,
                y: inset,
                width: bounds.width / 2 - inset,
                height: bounds.height / 2 - inset
            ),
            CGRect(
                x: bounds.midX,
                y: bounds.midY,
                width: bounds.width / 2 - inset,
                height: bounds.height / 2 - inset
            ),
            CGRect(
                x: inset,
                y: bounds.midY,
                width: bounds.width / 2 - inset,
                height: bounds.height / 2 - inset
            )
        ]

        for (quadrant, expected) in zip(quadrants, expectedBounds) {
            let outline = ZoneMapGeometry.selectedOutlineRegion(
                for: CGPath(rect: quadrant, transform: nil),
                in: bounds,
                cornerRadius: 30,
                lineWidth: lineWidth
            )

            XCTAssertEqual(outline.boundingBoxOfPath.origin.x, expected.origin.x, accuracy: 0.001)
            XCTAssertEqual(outline.boundingBoxOfPath.origin.y, expected.origin.y, accuracy: 0.001)
            XCTAssertEqual(outline.boundingBoxOfPath.width, expected.width, accuracy: 0.001)
            XCTAssertEqual(outline.boundingBoxOfPath.height, expected.height, accuracy: 0.001)
        }
    }

    func testSelectedOutlineFollowsTheInsetRoundedPadInsteadOfAClippedSquareCorner() {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 180)
        let topLeft = CGPath(
            rect: CGRect(x: 0, y: 0, width: bounds.width / 2, height: bounds.height / 2),
            transform: nil
        )
        let outline = ZoneMapGeometry.selectedOutlineRegion(
            for: topLeft,
            in: bounds,
            cornerRadius: 30,
            lineWidth: 2
        )

        XCTAssertFalse(outline.contains(CGPoint(x: 5, y: 5)))
        XCTAssertTrue(outline.contains(CGPoint(x: 30, y: 2)))
        XCTAssertTrue(outline.contains(CGPoint(x: 2, y: 30)))
        XCTAssertTrue(outline.contains(CGPoint(x: bounds.midX - 1, y: bounds.midY - 1)))
    }

    func testRadialNeutralPreviewPreservesRuntimeNormalizedRadius() throws {
        let bounds = CGRect(x: 0, y: 0, width: 230, height: 190)
        let rect = try XCTUnwrap(
            ZoneMapGeometry.neutralRect(in: bounds, deadzone: 0.5, layout: .radialFour)
        )

        XCTAssertEqual(rect.width, 115)
        XCTAssertEqual(rect.height, 95)
        XCTAssertEqual(rect.midX, bounds.midX)
        XCTAssertEqual(rect.midY, bounds.midY)
    }

    func testLinearAndGridNeutralPreviewGeometry() throws {
        let bounds = CGRect(x: 10, y: 20, width: 200, height: 100)
        XCTAssertEqual(
            ZoneMapGeometry.neutralRect(in: bounds, deadzone: 0.2, layout: .horizontalTwo),
            CGRect(x: 90, y: 20, width: 40, height: 100)
        )
        XCTAssertEqual(
            ZoneMapGeometry.neutralRect(in: bounds, deadzone: 0.2, layout: .verticalTwo),
            CGRect(x: 10, y: 60, width: 200, height: 20)
        )
        XCTAssertNil(ZoneMapGeometry.neutralRect(in: bounds, deadzone: 0.2, layout: .gridNine))
    }
}

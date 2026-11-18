import CoreGraphics
@testable import PaddrAppSupport
import PaddrCore
@testable import PaddrMenu
import SwiftUI
import XCTest

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

    @MainActor
    func testOutwardPadFocusKeepsCornerCentersAndControlRimsStayContained() {
        let bounds = CGRect(x: 0, y: 0, width: 190, height: 182)
        let focus = PaddrPadShape(insetAmount: -PaddrPadFocusRing.outset).path(in: bounds)
        XCTAssertEqual(focus.boundingRect, bounds.insetBy(dx: -4, dy: -4))
        XCTAssertFalse(focus.contains(CGPoint(x: 0.5, y: 0.5)),
                       "Growing bounds while retaining radius 14 incorrectly cuts inside the concentric corner")
        XCTAssertTrue(focus.contains(CGPoint(x: 2, y: 2)))
        let focusStroke = focus.cgPath.copy(strokingWithWidth: 2, lineCap: .round, lineJoin: .round, miterLimit: 1)
        XCTAssertEqual(focusStroke.boundingBoxOfPath.minX, -5, accuracy: 0.01)
        XCTAssertEqual(focusStroke.boundingBoxOfPath.maxY, 187, accuracy: 0.01)
        for size in [CGSize(width: 32, height: 32), CGSize(width: 104, height: 32), CGSize(width: 192, height: 48)] {
            let rect = CGRect(origin: .zero, size: size)
            let width = PaddrStyle.Control.outlineWidth
            let path = PaddrControlDrawing.strokePath(rect, radius: PaddrStyle.Control.radius, width: width)
            let rim = path.copy(strokingWithWidth: width, lineCap: .butt, lineJoin: .round, miterLimit: 1)
            XCTAssertEqual(rim.boundingBoxOfPath.minX, 0, accuracy: 0.01)
            XCTAssertEqual(rim.boundingBoxOfPath.minY, 0, accuracy: 0.01)
            XCTAssertEqual(rim.boundingBoxOfPath.maxX, rect.maxX, accuracy: 0.01)
            XCTAssertEqual(rim.boundingBoxOfPath.maxY, rect.maxY, accuracy: 0.01)
            XCTAssertFalse(rim.contains(.zero), "The rim must follow the rounded silhouette, not add a square seam")
        }
    }

    func testSelectedOutlineInsetsEveryOuterEdgeAndPreservesInternalDividers() {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 180)
        let lineWidth: CGFloat = 2
        let inset = lineWidth / 2
        let quadrants = [
            CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width / 2, height: bounds.height / 2),
            CGRect(x: bounds.midX, y: bounds.minY, width: bounds.width / 2, height: bounds.height / 2),
            CGRect(x: bounds.midX, y: bounds.midY, width: bounds.width / 2, height: bounds.height / 2),
            CGRect(x: bounds.minX, y: bounds.midY, width: bounds.width / 2, height: bounds.height / 2),
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
            ),
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

    // MARK: Key plates

    private static let padBounds = CGRect(
        x: 0, y: 0, width: PaddrStyle.Metrics.zoneMapWidth, height: PaddrStyle.Metrics.zoneMapHeight
    )

    @MainActor
    private func plateRect(for zone: ButtonZone, layout: PadZoneLayout, in bounds: CGRect) -> CGRect {
        let clearance = PaddrStyle.Control.bindingPlateClearance
        let height = PaddrStyle.Control.bindingPlateHeight
        let width = ZoneMapGeometry.plateWidth(
            preferred: layout == .gridNine
                ? PaddrStyle.Control.bindingPlateCompactWidth
                : PaddrStyle.Control.bindingPlateWidth,
            plateHeight: height, layout: layout, in: bounds, clearance: clearance
        )
        let center = ZoneMapGeometry.plateCenter(
            for: zone, plateSize: CGSize(width: width, height: height), layout: layout, in: bounds,
            clearance: clearance
        )
        return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }

    /// The distance from a point to the pad's nearer diagonal.
    private func distanceToDiagonals(_ point: CGPoint, in bounds: CGRect) -> CGFloat {
        let length = hypot(bounds.width, bounds.height)
        let falling = abs(bounds.height * (point.x - bounds.minX) - bounds.width * (point.y - bounds.minY)) / length
        let rising = abs(bounds.height * (point.x - bounds.minX) + bounds.width * (point.y - bounds.maxY)) / length
        return min(falling, rising)
    }

    @MainActor
    func testFourWayKeyPlatesStayClearOfTheDividersAndThePadEdge() {
        let bounds = Self.padBounds
        let clearance = PaddrStyle.Control.bindingPlateClearance
        var widths = Set<CGFloat>()
        for zone in PadZoneLayout.radialFour.zones {
            let plate = plateRect(for: zone, layout: .radialFour, in: bounds)
            widths.insert(plate.width)
            let corners = [
                CGPoint(x: plate.minX, y: plate.minY), CGPoint(x: plate.maxX, y: plate.minY),
                CGPoint(x: plate.minX, y: plate.maxY), CGPoint(x: plate.maxX, y: plate.maxY),
            ]
            for corner in corners {
                XCTAssertGreaterThanOrEqual(distanceToDiagonals(corner, in: bounds), clearance - 0.01,
                                            "\(zone) plate corner \(corner) crowds a divider")
            }
            XCTAssertTrue(bounds.insetBy(dx: clearance - 0.01, dy: clearance - 0.01).contains(plate),
                          "\(zone) plate \(plate) crowds the pad's edge")
            // The plate belongs to its own zone: its centre is on that zone's side of both dividers.
            let fromCenter = CGPoint(x: plate.midX - bounds.midX, y: plate.midY - bounds.midY)
            let horizontal = abs(fromCenter.x) / bounds.width > abs(fromCenter.y) / bounds.height
            switch zone {
            case .up: XCTAssertTrue(!horizontal && fromCenter.y < 0)
            case .down: XCTAssertTrue(!horizontal && fromCenter.y > 0)
            case .right: XCTAssertTrue(horizontal && fromCenter.x > 0)
            default: XCTAssertTrue(horizontal && fromCenter.x < 0)
            }
        }
        XCTAssertEqual(widths.count, 1, "The four plates share one width")

        // Control: the fixed plates this replaced reached the dividers.
        let old = CGRect(x: bounds.width * 0.23 - 39, y: bounds.midY - 12, width: 78, height: 24)
        XCTAssertLessThan(distanceToDiagonals(CGPoint(x: old.maxX, y: old.minY), in: bounds), 1)
    }

    @MainActor
    func testKeyPlatesInRectangularZonesAreCentredWithClearance() {
        let bounds = Self.padBounds
        let clearance = PaddrStyle.Control.bindingPlateClearance
        let grids: [(PadZoneLayout, columns: Int, rows: Int)] = [
            (.fourCorners, 2, 2), (.horizontalTwo, 2, 1), (.verticalTwo, 1, 2), (.gridNine, 3, 3),
        ]
        for (layout, columns, rows) in grids {
            let cell = CGSize(width: bounds.width / CGFloat(columns), height: bounds.height / CGFloat(rows))
            var cells = Set<String>()
            for zone in layout.zones {
                let plate = plateRect(for: zone, layout: layout, in: bounds)
                let column = Int(plate.midX / cell.width), row = Int(plate.midY / cell.height)
                cells.insert("\(column),\(row)")
                let zoneRect = CGRect(x: CGFloat(column) * cell.width, y: CGFloat(row) * cell.height,
                                      width: cell.width, height: cell.height)
                XCTAssertEqual(plate.midX, zoneRect.midX, accuracy: 0.01, "\(layout) \(zone)")
                XCTAssertEqual(plate.midY, zoneRect.midY, accuracy: 0.01, "\(layout) \(zone)")
                XCTAssertTrue(zoneRect.insetBy(dx: clearance - 0.01, dy: clearance - 0.01).contains(plate),
                              "\(layout) \(zone) plate \(plate) crowds its zone \(zoneRect)")
            }
            XCTAssertEqual(cells.count, layout.zones.count, "\(layout): every zone has its own plate position")
        }
        XCTAssertEqual(plateRect(for: .topLeft, layout: .fourCorners, in: bounds).width,
                       PaddrStyle.Control.bindingPlateWidth, "Where there is room the plate keeps its full width")
    }

    @MainActor
    func testTheLongestBindingNamesFitOnOneLineOfTheNarrowestPlate() throws {
        let width = plateRect(for: .left, layout: .radialFour, in: Self.padBounds).width
        // The map draws its labels in the bold caption style, inset 2 points at each end.
        let font = NSFont.boldSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .caption1).pointSize)
        for name in ["Right arrow", "Right click", "Left arrow", "Down arrow"] {
            let textWidth = (name as NSString).size(withAttributes: [.font: font]).width
            XCTAssertLessThanOrEqual(ceil(textWidth), width - 4, "\(name) would wrap inside a \(width)-point plate")
        }
    }
}

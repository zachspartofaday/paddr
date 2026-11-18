import CoreGraphics
import PaddrCore

public enum ZoneMapGeometry {
    /// Returns the region whose boundary can be stroked entirely inside the pad.
    ///
    /// Zone paths intentionally reach the pad's physical bounds so their fills tile without
    /// seams. A centered stroke on those same paths would be clipped at the outer edge. The
    /// intersection with this inset pad preserves every internal divider while moving only the
    /// rounded exterior contour far enough inward for the complete selection stroke to render.
    public static func selectedOutlineRegion(
        for zoneRegion: CGPath,
        in bounds: CGRect,
        cornerRadius: CGFloat,
        lineWidth: CGFloat
    ) -> CGPath {
        let maximumInset = max(0, min(bounds.width, bounds.height) / 2)
        let inset = min(max(0, lineWidth / 2), maximumInset)
        let insetBounds = bounds.insetBy(dx: inset, dy: inset)
        let insetCornerRadius = min(
            max(0, cornerRadius - inset),
            max(0, min(insetBounds.width, insetBounds.height) / 2)
        )
        let insetPad = CGPath(
            roundedRect: insetBounds,
            cornerWidth: insetCornerRadius,
            cornerHeight: insetCornerRadius,
            transform: nil
        )
        return zoneRegion.intersection(insetPad)
    }

    /// The width of every key plate in a layout. All plates share one width so
    /// the map reads as a set of keys, and it is the widest that still leaves
    /// `clearance` between a plate and its zone's dividers and the pad's edge.
    ///
    /// Only the four-way layout narrows the plates: its zones are triangles, and
    /// a plate lying along the axis of a side zone runs into both dividers.
    public static func plateWidth(
        preferred: CGFloat,
        plateHeight: CGFloat,
        layout: PadZoneLayout,
        in bounds: CGRect,
        clearance: CGFloat
    ) -> CGFloat {
        let available: CGFloat
        switch layout {
        case .radialFour:
            available = sidePlateDepths(plateHeight: plateHeight, in: bounds, clearance: clearance).length
        case .fourCorners, .horizontalTwo:
            available = bounds.width / 2 - 2 * clearance
        case .verticalTwo:
            available = bounds.width - 2 * clearance
        case .gridNine:
            available = bounds.width / 3 - 2 * clearance
        }
        return max(0, min(preferred, available))
    }

    /// The centre of a zone's key plate.
    ///
    /// Rectangular zones centre their plate. In the four-way layout each plate
    /// sits as near the middle of the pad as it can while its corners keep
    /// `clearance` from the two dividers that meet there.
    public static func plateCenter(
        for zone: ButtonZone,
        plateSize: CGSize,
        layout: PadZoneLayout,
        in bounds: CGRect,
        clearance: CGFloat
    ) -> CGPoint {
        let position: CGPoint
        switch layout {
        case .radialFour:
            return radialPlateCenter(for: zone, plateSize: plateSize, in: bounds, clearance: clearance)
        case .fourCorners:
            position = switch zone {
            case .topLeft: CGPoint(x: 0.25, y: 0.25)
            case .topRight: CGPoint(x: 0.75, y: 0.25)
            case .bottomRight: CGPoint(x: 0.75, y: 0.75)
            default: CGPoint(x: 0.25, y: 0.75)
            }
        case .horizontalTwo:
            position = CGPoint(x: zone == .left ? 0.25 : 0.75, y: 0.5)
        case .verticalTwo:
            position = CGPoint(x: 0.5, y: zone == .up ? 0.25 : 0.75)
        case .gridNine:
            let columns: [ButtonZone: CGFloat] = [
                .topLeft: 1.0 / 6.0, .left: 1.0 / 6.0, .bottomLeft: 1.0 / 6.0,
                .up: 0.5, .center: 0.5, .down: 0.5,
                .topRight: 5.0 / 6.0, .right: 5.0 / 6.0, .bottomRight: 5.0 / 6.0,
            ]
            let rows: [ButtonZone: CGFloat] = [
                .topLeft: 1.0 / 6.0, .up: 1.0 / 6.0, .topRight: 1.0 / 6.0,
                .left: 0.5, .center: 0.5, .right: 0.5,
                .bottomLeft: 5.0 / 6.0, .down: 5.0 / 6.0, .bottomRight: 5.0 / 6.0,
            ]
            position = CGPoint(x: columns[zone] ?? 0.5, y: rows[zone] ?? 0.5)
        }
        return CGPoint(
            x: bounds.minX + bounds.width * position.x,
            y: bounds.minY + bounds.height * position.y
        )
    }

    private static func radialPlateCenter(
        for zone: ButtonZone,
        plateSize: CGSize,
        in bounds: CGRect,
        clearance: CGFloat
    ) -> CGPoint {
        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2
        guard halfWidth > 0, halfHeight > 0 else { return CGPoint(x: bounds.midX, y: bounds.midY) }
        switch zone {
        case .up, .down:
            // The zone narrows towards the middle of the pad. Measured from the
            // pad's edge, this is the deepest the plate can go before its inner
            // corners come within `clearance` of the dividers.
            let diagonal = hypot(halfWidth, halfHeight)
            let narrowing = (plateSize.width / 2 + clearance * diagonal / halfHeight) / halfWidth
            let deepest = halfHeight * (1 - narrowing) - plateSize.height / 2
            let depth = max(deepest, clearance + plateSize.height / 2)
            return CGPoint(x: bounds.midX, y: zone == .up ? bounds.minY + depth : bounds.maxY - depth)
        default:
            let depths = sidePlateDepths(plateHeight: plateSize.height, in: bounds, clearance: clearance)
            // Against the inner limit, so all four plates keep the same distance
            // from the dividers; any spare room goes to the pad's edge.
            let depth = max(depths.inner - plateSize.width / 2, clearance + plateSize.width / 2)
            return CGPoint(x: zone == .right ? bounds.maxX - depth : bounds.minX + depth, y: bounds.midY)
        }
    }

    /// For a plate lying along the axis of a side zone in the four-way layout:
    /// how far from the pad's edge it may start and end.
    private static func sidePlateDepths(
        plateHeight: CGFloat,
        in bounds: CGRect,
        clearance: CGFloat
    ) -> (inner: CGFloat, length: CGFloat) {
        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2
        guard halfWidth > 0, halfHeight > 0 else { return (0, 0) }
        let diagonal = hypot(halfWidth, halfHeight)
        let narrowing = (plateHeight / 2 + clearance * diagonal / halfWidth) / halfHeight
        let inner = halfWidth * (1 - narrowing)
        return (inner, max(0, inner - clearance))
    }

    public static func neutralRect(
        in bounds: CGRect,
        deadzone: Double,
        layout: PadZoneLayout
    ) -> CGRect? {
        guard deadzone > 0, layout != .gridNine else { return nil }
        switch layout {
        case .horizontalTwo:
            let width = bounds.width * deadzone
            return CGRect(
                x: bounds.midX - width / 2,
                y: bounds.minY,
                width: width,
                height: bounds.height
            )
        case .verticalTwo:
            let height = bounds.height * deadzone
            return CGRect(
                x: bounds.minX,
                y: bounds.midY - height / 2,
                width: bounds.width,
                height: height
            )
        case .radialFour, .fourCorners:
            let width = bounds.width * deadzone
            let height = bounds.height * deadzone
            return CGRect(
                x: bounds.midX - width / 2,
                y: bounds.midY - height / 2,
                width: width,
                height: height
            )
        case .gridNine:
            return nil
        }
    }
}

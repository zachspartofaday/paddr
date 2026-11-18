import PaddrAppSupport
import PaddrCore
import SwiftUI

struct ZonePadMap: View {
    let layout: PadZoneLayout
    let deadzone: Double
    let configuration: PadConfiguration
    @Binding var selection: ButtonZone
    @FocusState private var isFocused: Bool

    var body: some View {
        PaddrAppearanceReader { appearance in
            GeometryReader { proxy in
                Canvas { context, size in
                    let bounds = CGRect(origin: .zero, size: size)
                    context.fill(Path(bounds), with: .color(appearance.surface(elevated: false)))

                    for zone in layout.zones {
                        let path = path(for: zone, in: bounds)
                        let isSelected = zone == selection
                        context.fill(
                            path,
                            with: .color(isSelected ? PaddrStyle.selectedZoneFillTop : appearance.surface(elevated: false))
                        )
                        context.stroke(
                            path,
                            with: .color(appearance.surfaceStroke),
                            lineWidth: appearance.strokeWidth
                        )
                        drawLabel(
                            for: zone,
                            selected: isSelected,
                            in: bounds,
                            appearance: appearance,
                            context: &context
                        )
                    }
                }
                .modifier(PaddrPadSurface(appearance: appearance))
                .overlay {
                    ZStack {
                        Canvas { context, size in
                            let bounds = CGRect(origin: .zero, size: size)
                            if layout.zones.contains(selection) {
                                let lineWidth: CGFloat = 2
                                let zoneRegion = path(for: selection, in: bounds)
                                let outlineRegion = ZoneMapGeometry.selectedOutlineRegion(
                                    for: zoneRegion.cgPath,
                                    in: bounds,
                                    cornerRadius: PaddrStyle.Radius.pad,
                                    lineWidth: lineWidth
                                )
                                context.stroke(
                                    Path(outlineRegion),
                                    with: .color(PaddrStyle.selectionBoundary),
                                    lineWidth: lineWidth
                                )
                            }
                            if let neutral = neutralPath(in: bounds) {
                                context.fill(neutral, with: .color(PaddrStyle.textPrimary.opacity(0.10)))
                                context.stroke(
                                    neutral,
                                    with: .color(PaddrStyle.textSecondary.opacity(0.62)),
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                                )
                                context.draw(
                                    Text(verbatim: "○")
                                        .font(PaddrTextRole.bindingPlate.font)
                                        .foregroundStyle(PaddrStyle.textSecondary),
                                    at: center(in: bounds)
                                )
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
                .contentShape(.interaction, PaddrPadShape())
                .contentShape(.focusEffect, PaddrPadShape())
                .gesture(
                    SpatialTapGesture().onEnded { value in
                        if let zone = hitZone(at: value.location, size: proxy.size) {
                            selection = zone
                        }
                    }
                )
            }
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .overlay {
            if isFocused {
                PaddrPadFocusRing()
            }
        }
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
            let direction: ZoneNavigationDirection
            switch press.key {
            case .leftArrow: direction = .left
            case .rightArrow: direction = .right
            case .upArrow: direction = .up
            case .downArrow: direction = .down
            default: return .ignored
            }
            selection = ZoneSelectionPolicy.moved(from: selection, direction: direction, in: layout)
            return .handled
        }
        .accessibilityHidden(true)
        .help("Select a zone on the pad, then choose its keyboard or mouse action.")
    }

    private func hitZone(at point: CGPoint, size: CGSize) -> ButtonZone? {
        guard size.width > 0, size.height > 0 else { return nil }
        let x = ((point.x / size.width) * 2 - 1).clamped(to: -1 ... 1)
        let y = (1 - (point.y / size.height) * 2).clamped(to: -1 ... 1)
        let rawX = Int16((x * Double(Int16.max)).rounded())
        let rawY = Int16((y * Double(Int16.max)).rounded())
        return PadMapper.activeButtonZones(x: rawX, y: rawY, deadzone: deadzone, layout: layout).first
    }

    private func path(for zone: ButtonZone, in bounds: CGRect) -> Path {
        let midX = bounds.midX
        let midY = bounds.midY
        switch layout {
        case .radialFour:
            switch zone {
            case .up: return polygon([CGPoint(x: midX, y: midY), bounds.origin, CGPoint(x: bounds.maxX, y: bounds.minY)])
            case .right: return polygon([CGPoint(x: midX, y: midY), CGPoint(x: bounds.maxX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.maxY)])
            case .down: return polygon([CGPoint(x: midX, y: midY), CGPoint(x: bounds.maxX, y: bounds.maxY), CGPoint(x: bounds.minX, y: bounds.maxY)])
            default: return polygon([CGPoint(x: midX, y: midY), CGPoint(x: bounds.minX, y: bounds.maxY), bounds.origin])
            }
        case .fourCorners:
            switch zone {
            case .topLeft: return Path(CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width / 2, height: bounds.height / 2))
            case .topRight: return Path(CGRect(x: midX, y: bounds.minY, width: bounds.width / 2, height: bounds.height / 2))
            case .bottomRight: return Path(CGRect(x: midX, y: midY, width: bounds.width / 2, height: bounds.height / 2))
            default: return Path(CGRect(x: bounds.minX, y: midY, width: bounds.width / 2, height: bounds.height / 2))
            }
        case .horizontalTwo:
            return Path(CGRect(x: zone == .left ? bounds.minX : midX, y: bounds.minY, width: bounds.width / 2, height: bounds.height))
        case .verticalTwo:
            return Path(CGRect(x: bounds.minX, y: zone == .up ? bounds.minY : midY, width: bounds.width, height: bounds.height / 2))
        case .gridNine:
            let index = layout.zones.firstIndex(of: zone) ?? 0
            let column = index % 3
            let row = index / 3
            return Path(CGRect(
                x: bounds.minX + CGFloat(column) * bounds.width / 3,
                y: bounds.minY + CGFloat(row) * bounds.height / 3,
                width: bounds.width / 3,
                height: bounds.height / 3
            ))
        }
    }

    private func neutralPath(in bounds: CGRect) -> Path? {
        guard let rect = ZoneMapGeometry.neutralRect(
            in: bounds,
            deadzone: deadzone,
            layout: layout
        ) else { return nil }
        switch layout {
        case .horizontalTwo:
            return Path(rect)
        case .verticalTwo:
            return Path(rect)
        case .radialFour, .fourCorners:
            return Path(ellipseIn: rect)
        case .gridNine:
            return nil
        }
    }

    private func drawLabel(
        for zone: ButtonZone,
        selected: Bool,
        in bounds: CGRect,
        appearance: PaddrAppearance,
        context: inout GraphicsContext
    ) {
        let clearance = PaddrStyle.Control.bindingPlateClearance
        let plateWidth = ZoneMapGeometry.plateWidth(
            preferred: layout == .gridNine
                ? PaddrStyle.Control.bindingPlateCompactWidth
                : PaddrStyle.Control.bindingPlateWidth,
            plateHeight: PaddrStyle.Control.bindingPlateHeight,
            layout: layout, in: bounds, clearance: clearance
        )
        let label = OutputBindingText.text(for: configuration[bindingFor: zone])
            .font(PaddrTextRole.bindingPlate.font)
            .foregroundStyle(selected ? PaddrStyle.selectedZoneCaptionForeground : PaddrStyle.textSecondary)
        let resolved = context.resolve(label)
        let labelSize = resolved.measure(in: CGSize(width: plateWidth - 4, height: .greatestFiniteMagnitude))
        let plateSize = CGSize(width: plateWidth, height: max(PaddrStyle.Control.bindingPlateHeight, ceil(labelSize.height) + 4))
        let point = ZoneMapGeometry.plateCenter(
            for: zone, plateSize: plateSize, layout: layout, in: bounds, clearance: clearance
        )
        let plateRect = CGRect(
            x: point.x - plateSize.width / 2,
            y: point.y - plateSize.height / 2,
            width: plateSize.width,
            height: plateSize.height
        )
        let plate = Path(roundedRect: plateRect, cornerRadius: PaddrStyle.Control.bindingPlateRadius)
        if selected {
            context.fill(plate, with: .color(PaddrStyle.selectedZoneCaptionFill))
            // The filled key plate already carries selection; avoid a fractional bright rim.
        } else {
            context.fill(plate, with: .color(appearance.surface(elevated: true)))
            context.stroke(
                plate,
                with: .color(appearance.surfaceStroke),
                lineWidth: appearance.strokeWidth
            )
        }
        context.draw(resolved, in: CGRect(x: point.x - labelSize.width / 2,
                                          y: point.y - labelSize.height / 2, width: labelSize.width, height: labelSize.height))
    }

    private func center(in bounds: CGRect) -> CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }

    private func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}

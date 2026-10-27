import AppKit
import SwiftUI

/// Paddr-owned chrome and small input adapters. Native menu tracking/cancellation
/// and cell state/dispatch remain intact. No Quilter/CoreKit source is copied here.
@MainActor
enum PaddrControlDrawing {
    static func shape(_ rect: CGRect, radius: CGFloat) -> CGPath {
        PaddrControlShape(radius: radius).path(in: rect).cgPath
    }

    static func fill(_ rect: CGRect, radius: CGFloat, color: Color) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.addPath(shape(rect, radius: radius))
        context.setFillColor(NSColor(color).cgColor)
        context.fillPath()
    }

    static func strokePath(_ rect: CGRect, radius: CGFloat, width: CGFloat) -> CGPath {
        PaddrControlShape(radius: radius, insetAmount: width / 2).path(in: rect).cgPath
    }

    static func stroke(_ rect: CGRect, radius: CGFloat, color: Color, width: CGFloat = 1) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        context.addPath(strokePath(rect, radius: radius, width: width))
        context.setStrokeColor(NSColor(color).cgColor)
        context.setLineWidth(width)
        context.strokePath()
    }

    static func text(_ text: String, rect: CGRect, font: NSFont, color: Color,
                     alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: NSColor(color), .paragraphStyle: paragraph
        ]
        let height = (text as NSString).boundingRect(with: rect.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes).height
        (text as NSString).draw(in: CGRect(x: rect.minX, y: rect.midY - ceil(height) / 2,
            width: rect.width, height: ceil(height)), withAttributes: attributes)
    }

    static func height(_ text: String, width: CGFloat, font: NSFont) -> CGFloat {
        ceil((text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font]).height)
    }

    static func focus(_ view: NSView, rect: CGRect, radius: CGFloat) {
        if view.window?.firstResponder === view {
            stroke(rect, radius: radius, color: PaddrStyle.action, width: PaddrStyle.Control.focusWidth)
        }
    }
}

struct PaddrMenuOption<Value: Equatable>: Equatable {
    let value: Value?
    let title: String
    var systemImage: String?

    static var separator: Self { Self(value: nil, title: "") }
}

/// A native pop-up button with bespoke closed chrome. Its NSMenu and selected item
/// remain native (including checkmarks, raw values, Escape and responder restoration).
struct PaddrNativeMenuPicker<Value: Equatable>: NSViewRepresentable {
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
    let title: LocalizedStringResource
    @Binding var selection: Value
    let options: [PaddrMenuOption<Value>]
    var width: CGFloat = PaddrStyle.Width.control
    var accessibilityIdentifier: String?
    var accessibilityValue: String?

    @MainActor
    final class Coordinator: NSObject {
        var parent: PaddrNativeMenuPicker
        init(_ parent: PaddrNativeMenuPicker) { self.parent = parent }
        @objc func changed(_ sender: NSPopUpButton) {
            guard sender.isEnabled, parent.options.indices.contains(sender.indexOfSelectedItem),
                  let value = parent.options[sender.indexOfSelectedItem].value else { return }
            parent.selection = value
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> PaddrPopUpButton {
        let control = PaddrPopUpButton(frame: .zero, pullsDown: false)
        control.target = context.coordinator
        control.action = #selector(Coordinator.changed(_:))
        control.isBordered = false
        control.focusRingType = .none
        control.font = .preferredFont(forTextStyle: .body)
        updateNSView(control, context: context)
        return control
    }

    func updateNSView(_ control: PaddrPopUpButton, context: Context) {
        context.coordinator.parent = self
        let bodyFont = NSFont.preferredFont(forTextStyle: .body)
        control.font = NSFont(descriptor: bodyFont.fontDescriptor, size: bodyFont.pointSize * textScale) ?? bodyFont
        // Avoid replacing the menu during a tracking session or equal-value redraw.
        if control.optionTitles != options.map(\.title) {
            control.removeAllItems()
            let menu = NSMenu()
            menu.autoenablesItems = false
            for option in options {
                guard option.value != nil else { menu.addItem(.separator()); continue }
                let item = NSMenuItem(title: option.title, action: nil, keyEquivalent: "")
                if let symbol = option.systemImage {
                    item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
                }
                menu.addItem(item)
            }
            control.menu = menu
            control.optionTitles = options.map(\.title)
        }
        let selected = options.firstIndex { $0.value == selection }
        if let selected { control.selectItem(at: selected) }
        for (index, item) in control.itemArray.enumerated() {
            item.state = index == selected ? .on : .off
        }
        control.isEnabled = context.environment.isEnabled
        control.controlAppearance = PaddrAppearance(environment: context.environment)
        control.userInterfaceLayoutDirection = context.environment.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
        control.setAccessibilityLabel(String(localized: title))
        control.cell?.setAccessibilityLabel(String(localized: title))
        control.setAccessibilityValue(accessibilityValue ?? control.titleOfSelectedItem)
        control.setAccessibilityIdentifier(accessibilityIdentifier)
        control.cell?.setAccessibilityIdentifier(accessibilityIdentifier)
        control.identifier = accessibilityIdentifier.map { NSUserInterfaceItemIdentifier($0) }
        control.needsDisplay = true
        control.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: PaddrPopUpButton, context: Context) -> CGSize? {
        CGSize(width: width, height: nsView.height(for: width))
    }
}

final class PaddrPopUpButton: NSPopUpButton {
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsetsZero }
    var iconName: String?
    var optionTitles: [String] = []
    var actionSignature: [String] = []
    var isHovered = false
    var controlAppearance = PaddrAppearance() { didSet { needsDisplay = true } }
    var increasedContrast: Bool { controlAppearance.hasIncreasedContrast }

    override func updateTrackingAreas() { super.updateTrackingAreas(); paddrUpdateHoverTracking() }
    override func mouseEntered(with event: NSEvent) { isHovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { isHovered = false; needsDisplay = true }
    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: PaddrStyle.Width.control, height: height(for: PaddrStyle.Width.control)) }
    func height(for width: CGFloat) -> CGFloat {
        if iconName != nil { return PaddrStyle.Control.height }
        return max(PaddrStyle.Control.height, PaddrControlDrawing.height(titleOfSelectedItem ?? "",
            width: width - 2 * PaddrStyle.Control.sideInset - 20,
            font: font ?? .preferredFont(forTextStyle: .body)) + 12)
    }
    override func becomeFirstResponder() -> Bool { needsDisplay = true; return super.becomeFirstResponder() }
    override func resignFirstResponder() -> Bool { needsDisplay = true; return super.resignFirstResponder() }
    var valueRect: CGRect {
        CGRect(x: userInterfaceLayoutDirection == .rightToLeft ? 32 : 12, y: 4,
               width: max(0, bounds.width - 44), height: bounds.height - 8)
    }
    var chevronRect: CGRect {
        CGRect(x: userInterfaceLayoutDirection == .rightToLeft ? 12 : bounds.maxX - 24,
               y: bounds.midY - 7, width: 12, height: 14)
    }
    var valueAlignment: NSTextAlignment {
        userInterfaceLayoutDirection == .rightToLeft ? .right : .left
    }
    override func draw(_ dirtyRect: NSRect) {
        drawChrome()
    }
    private func drawChrome() {
        if !controlAppearance.usesControlGlass {
            PaddrControlDrawing.fill(bounds, radius: PaddrStyle.Control.radius, color: PaddrStyle.workspace)
        }
        if (isHovered || isHighlighted) && isEnabled {
            PaddrControlDrawing.fill(bounds, radius: PaddrStyle.Control.radius,
                color: isHighlighted ? PaddrStyle.controlPressed : PaddrStyle.controlHover)
        }
        PaddrControlDrawing.stroke(bounds, radius: PaddrStyle.Control.radius,
            color: controlAppearance.controlStroke(enabled: isEnabled),
            width: PaddrStyle.Control.outlineWidth)
        if let iconName {
            drawSymbol(iconName, in: CGRect(x: bounds.midX - 7, y: bounds.midY - 7, width: 14, height: 14))
        } else {
            PaddrControlDrawing.text(titleOfSelectedItem ?? "", rect: valueRect,
                font: font ?? .preferredFont(forTextStyle: .body),
                color: isEnabled ? PaddrStyle.textPrimary : PaddrStyle.textSecondary,
                alignment: valueAlignment)
            drawSymbol("chevron.up.chevron.down", in: chevronRect)
        }
        PaddrControlDrawing.focus(self, rect: bounds, radius: PaddrStyle.Control.radius)
    }
    private func drawSymbol(_ name: String, in rect: CGRect) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(PaddrStyle.textSecondary)]))
        NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)?.draw(in: rect, from: .zero,
                operation: .sourceOver, fraction: isEnabled ? 1 : 0.5,
                respectFlipped: true, hints: nil)
    }

}

/// NSButton's switch cell supplies a real binary AXCheckBox, integer state,
/// Space/press activation and disabled handling; only its drawing is replaced.
struct PaddrNativeTuningSwitch: NSViewRepresentable {
    let title: LocalizedStringResource
    @Binding var isOn: Bool
    let accessibilityIdentifier: String

    @MainActor
    final class Coordinator: NSObject {
        var binding: Binding<Bool>
        init(_ binding: Binding<Bool>) { self.binding = binding }
        @objc func changed(_ sender: PaddrTuningSwitchButton) {
            guard sender.isEnabled else { return }
            binding.wrappedValue = sender.state == .on
            NSAccessibility.post(element: sender, notification: .valueChanged)
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator($isOn) }
    func makeNSView(context: Context) -> PaddrTuningSwitchButton {
        let control = PaddrTuningSwitchButton(frame: .zero)
        control.setButtonType(.switch)
        control.setAccessibilityElement(true)
        control.setAccessibilityRole(.checkBox)
        control.title = ""
        control.isBordered = false
        control.focusRingType = .none
        control.target = context.coordinator
        control.action = #selector(Coordinator.changed(_:))
        updateNSView(control, context: context)
        return control
    }
    func updateNSView(_ control: PaddrTuningSwitchButton, context: Context) {
        context.coordinator.binding = $isOn
        control.state = isOn ? .on : .off
        control.isEnabled = context.environment.isEnabled
        control.controlAppearance = PaddrAppearance(environment: context.environment)
        control.userInterfaceLayoutDirection = context.environment.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
        control.setAccessibilityLabel(String(localized: title))
        control.cell?.setAccessibilityLabel(String(localized: title))
        control.setAccessibilityIdentifier(accessibilityIdentifier)
        control.identifier = NSUserInterfaceItemIdentifier(accessibilityIdentifier)
        control.needsDisplay = true
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: PaddrTuningSwitchButton, context: Context) -> CGSize? {
        CGSize(width: PaddrStyle.Width.toggle, height: PaddrStyle.Control.height)
    }
}

final class PaddrTuningSwitchButton: NSButton {
    var isHovered = false
    var controlAppearance = PaddrAppearance() { didSet { needsDisplay = true } }
    var increasedContrast: Bool { controlAppearance.hasIncreasedContrast }

    override func updateTrackingAreas() { super.updateTrackingAreas(); paddrUpdateHoverTracking() }
    override func mouseEntered(with event: NSEvent) { isHovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { isHovered = false; needsDisplay = true }
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsetsZero }
    override func accessibilityRole() -> NSAccessibility.Role? { .checkBox }
    override func accessibilitySubrole() -> NSAccessibility.Subrole? { .switch }
    override func accessibilityRoleDescription() -> String? { NSAccessibility.Role.checkBox.description(with: .switch) }
    override func accessibilityChildren() -> [Any]? { nil }
    override func accessibilityValueDescription() -> String? { String(localized: state == .on ? LocalizedStringResource("On") : LocalizedStringResource("Off")) }
    override func accessibilityValue() -> Any? { NSNumber(value: state == .on) }
    override func isAccessibilityEnabled() -> Bool { isEnabled }
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        performClick(nil)
        return true
    }
    override func keyDown(with event: NSEvent) {
        guard isEnabled else { return }
        if event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
           event.charactersIgnoringModifiers == " " {
            if !event.isARepeat { performClick(nil) }
        } else { super.keyDown(with: event) }
    }
    override var intrinsicContentSize: NSSize { NSSize(width: PaddrStyle.Width.toggle, height: PaddrStyle.Control.height) }
    override func becomeFirstResponder() -> Bool { needsDisplay = true; return super.becomeFirstResponder() }
    override func resignFirstResponder() -> Bool { needsDisplay = true; return super.resignFirstResponder() }
    var trackRect: CGRect {
        let size = PaddrStyle.Control.TuningSwitch.track
        return CGRect(x: (bounds.width - size.width) / 2,
                      y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
    }
    var thumbRect: CGRect {
        let metrics = PaddrStyle.Control.TuningSwitch.self
        let thumbAtRight = (state == .on) != (userInterfaceLayoutDirection == .rightToLeft)
        return CGRect(origin: CGPoint(x: trackRect.minX + metrics.inset + (thumbAtRight ? metrics.travel : 0),
                                      y: trackRect.minY + metrics.inset), size: metrics.thumb)
    }
    override func draw(_ dirtyRect: NSRect) {
        drawChrome()
        // Focus belongs outside the material/track and must not be clipped by it.
        PaddrControlDrawing.focus(self, rect: trackRect.insetBy(dx: -3, dy: -3), radius: PaddrStyle.Control.radius + 3)
    }
    private func drawChrome() {
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        defer { context?.restoreGState() }
        context?.setAlpha(isEnabled ? 1 : 0.5)
        if state == .on || !controlAppearance.usesControlGlass {
            PaddrControlDrawing.fill(trackRect.insetBy(dx: 1, dy: 1), radius: 6,
                color: state == .on ? PaddrStyle.controlTint : PaddrStyle.workspace)
        }
        PaddrControlDrawing.stroke(trackRect, radius: PaddrStyle.Control.radius,
            color: controlAppearance.controlStroke(enabled: isEnabled),
            width: PaddrStyle.Control.outlineWidth)
        if (isHovered || isHighlighted) && isEnabled {
            PaddrControlDrawing.fill(trackRect, radius: PaddrStyle.Control.radius, color: isHighlighted ? PaddrStyle.controlPressed : PaddrStyle.controlHover)
        }
        PaddrControlDrawing.fill(thumbRect, radius: PaddrStyle.Control.TuningSwitch.thumbRadius,
            color: state == .on ? PaddrStyle.selectedZoneCaptionForeground : PaddrStyle.textSecondary)
        if !isEnabled {
            PaddrControlDrawing.stroke(thumbRect, radius: PaddrStyle.Control.TuningSwitch.thumbRadius, color: controlAppearance.controlStroke(enabled: false))
        }
    }
}

extension NSControl {
    /// Tracking changes drawing only and never adds an accessibility/focus stop.
    func paddrUpdateHoverTracking() {
        for area in trackingAreas where area.owner === self { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self))
    }
}

struct PaddrMenuAction {
    let title: LocalizedStringResource?
    var systemImage: String? = nil
    var isEnabled = true
    var isDestructive = false
    var action: () -> Void = {}
    static var separator: Self { Self(title: nil) }
}

/// A pull-down system action menu uses the same chrome as selection menus.
struct PaddrNativeActionMenu: NSViewRepresentable {
    let title: LocalizedStringResource
    let systemImage: String
    let actions: [PaddrMenuAction]
    let accessibilityIdentifier: String
    let accessibilityValue: String

    @MainActor
    final class Coordinator: NSObject {
        var parent: PaddrNativeActionMenu
        init(_ parent: PaddrNativeActionMenu) { self.parent = parent }
        @objc func invoke(_ sender: NSMenuItem) {
            guard sender.isEnabled, parent.actions.indices.contains(sender.tag), parent.actions[sender.tag].isEnabled else { return }
            parent.actions[sender.tag].action()
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> PaddrPopUpButton {
        let control = PaddrPopUpButton(frame: .zero, pullsDown: true)
        control.iconName = systemImage
        control.isBordered = false
        control.focusRingType = .none
        updateNSView(control, context: context)
        return control
    }
    func updateNSView(_ control: PaddrPopUpButton, context: Context) {
        context.coordinator.parent = self
        let signature = actions.map { action in
            (action.title.map { String(localized: $0) } ?? "<separator>")
                + "|\(action.systemImage ?? "")|\(action.isEnabled && context.environment.isEnabled)|\(action.isDestructive)"
        }
        if control.actionSignature != signature {
            let menu = NSMenu()
            menu.autoenablesItems = false
            menu.addItem(NSMenuItem(title: "", action: nil, keyEquivalent: ""))
            for (index, action) in actions.enumerated() {
                guard let title = action.title else { menu.addItem(.separator()); continue }
                let item = NSMenuItem(title: String(localized: title),
                    action: #selector(Coordinator.invoke(_:)), keyEquivalent: "")
                if action.isDestructive && action.isEnabled && context.environment.isEnabled {
                    item.attributedTitle = NSAttributedString(string: String(localized: title),
                        attributes: [.foregroundColor: NSColor(PaddrStyle.errorText)])
                }
                item.target = context.coordinator
                item.tag = index
                item.isEnabled = action.isEnabled && context.environment.isEnabled
                if let image = action.systemImage {
                    item.image = NSImage(systemSymbolName: image, accessibilityDescription: nil)
                }
                menu.addItem(item)
            }
            control.menu = menu
            control.actionSignature = signature
        }
        control.isEnabled = context.environment.isEnabled
        control.controlAppearance = PaddrAppearance(environment: context.environment)
        control.userInterfaceLayoutDirection = context.environment.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
        control.setAccessibilityLabel(String(localized: title))
        control.cell?.setAccessibilityLabel(String(localized: title))
        control.setAccessibilityValue(accessibilityValue)
        control.cell?.setAccessibilityValueDescription(accessibilityValue)
        control.setAccessibilityIdentifier(accessibilityIdentifier)
        control.cell?.setAccessibilityIdentifier(accessibilityIdentifier)
        control.identifier = NSUserInterfaceItemIdentifier(accessibilityIdentifier)
        control.needsDisplay = true
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: PaddrPopUpButton, context: Context) -> CGSize? {
        CGSize(width: PaddrStyle.Control.height, height: PaddrStyle.Control.height)
    }
}

// Glass is composed behind the existing native hit/AX owners. SwiftUI owns the
// material's layout; no decorative NSView is inserted into an NSControl's internals.
struct PaddrMenuPicker<Value: Equatable>: View {
    let title: LocalizedStringResource
    @Binding var selection: Value
    let options: [PaddrMenuOption<Value>]
    var width: CGFloat = PaddrStyle.Width.control
    var accessibilityIdentifier: String?
    var accessibilityValue: String?
    var body: some View {
        PaddrNativeMenuPicker(title: title, selection: $selection, options: options, width: width,
            accessibilityIdentifier: accessibilityIdentifier, accessibilityValue: accessibilityValue)
            .paddrControlMaterial()
    }
}

struct PaddrTuningSwitch: View {
    let title: LocalizedStringResource
    @Binding var isOn: Bool
    let accessibilityIdentifier: String
    var body: some View {
        PaddrNativeTuningSwitch(title: title, isOn: $isOn, accessibilityIdentifier: accessibilityIdentifier)
            .paddrControlMaterial(isSwitch: true)
    }
}

struct PaddrActionMenu: View {
    let title: LocalizedStringResource
    let systemImage: String
    let actions: [PaddrMenuAction]
    let accessibilityIdentifier: String
    let accessibilityValue: String
    var body: some View {
        PaddrNativeActionMenu(title: title, systemImage: systemImage, actions: actions,
            accessibilityIdentifier: accessibilityIdentifier, accessibilityValue: accessibilityValue)
            .paddrControlMaterial()
    }
}

import SwiftUI

/// One read-only line in Connection details: a name and its current value.
/// It has no container of its own, so it cannot be mistaken for a control.
struct StatusDetailRow: View {
    private enum Value {
        case localized(LocalizedStringResource)
        case verbatim(String)
    }

    let title: LocalizedStringResource
    let systemImage: String
    let state: StatusBadgeState
    private let identifier: String
    private let value: Value
    private let explicitAccessibilityValue: String?

    init(
        title: LocalizedStringResource,
        value: LocalizedStringResource,
        systemImage: String,
        state: StatusBadgeState,
        identifier: String = "status"
    ) {
        self.title = title
        self.value = .localized(value)
        self.systemImage = systemImage
        self.state = state
        self.identifier = identifier
        explicitAccessibilityValue = nil
    }

    init(
        title: LocalizedStringResource,
        value: String,
        systemImage: String,
        state: StatusBadgeState,
        accessibilityValue: String? = nil,
        identifier: String = "status"
    ) {
        self.title = title
        self.value = .verbatim(value)
        self.systemImage = systemImage
        self.state = state
        self.identifier = identifier
        explicitAccessibilityValue = accessibilityValue
    }

    var body: some View {
        HStack(spacing: PaddrStyle.Spacing.s2) {
            Image(systemName: systemImage)
                .foregroundStyle(state.color)
                .symbolRenderingMode(.hierarchical)
                .frame(width: PaddrStyle.Metrics.statusIconColumn)
                .accessibilityHidden(true)
            Text(title)
                .paddrTypography(.rowLabel)
                .foregroundStyle(PaddrStyle.textSecondary)
                .lineLimit(1)
            Spacer(minLength: PaddrStyle.Spacing.s4)
            valueText
                .paddrTypography(.value)
                .foregroundStyle(state.textColor)
                .lineLimit(1)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
        .help(helpText)
        .paddrAccessibilityID("status", identifier)
    }

    @ViewBuilder private var valueText: some View {
        switch value {
        case let .localized(resource): Text(resource)
        case let .verbatim(string): Text(verbatim: string)
        }
    }

    private var accessibilityValue: Text {
        Text(verbatim: accessibilityValueText)
    }

    private var helpText: Text {
        Text("\(accessibilityLabelText): \(accessibilityValueText)")
    }

    var accessibilityLabelText: String { String(localized: title) }

    var accessibilityValueText: String {
        if let explicitAccessibilityValue {
            explicitAccessibilityValue
        } else {
            switch self.value {
            case let .localized(resource): String(localized: resource)
            case let .verbatim(string): string
            }
        }
    }
}

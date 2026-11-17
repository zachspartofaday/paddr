import SwiftUI

/// A real button keeps explanatory copy available to keyboard and assistive
/// input as well as hover, without leaving a permanent paragraph in the editor.
struct PaddrInfoButton<Content: View>: View {
    let title: LocalizedStringResource
    /// The tooltip and accessibility help: the explanation itself when it is
    /// short, or one sentence naming what the popover explains.
    let help: String
    let identifier: String
    @ViewBuilder let content: () -> Content
    @State private var isPresented = false

    var body: some View {
        Button { isPresented.toggle() } label: {
            Label(title, systemImage: "info.circle")
                .labelStyle(.iconOnly)
                .paddrTypography(.caption)
                .foregroundStyle(PaddrStyle.textSecondary)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .accessibilityLabel(title)
        .help(Text(verbatim: help))
        .accessibilityIdentifier(identifier)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
                content()
                Button("Done") { isPresented = false }
                    .paddrActionButton(.secondary)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(PaddrStyle.Inset.section)
            .frame(idealWidth: 320, maxWidth: 360, alignment: .leading)
            .foregroundStyle(PaddrStyle.textPrimary)
        }
    }
}

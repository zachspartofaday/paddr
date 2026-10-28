import PaddrAppSupport
import SwiftUI

struct OnboardingGuideView: View {
    @Bindable var model: PaddrMenuModel
    let onSkip: @MainActor () -> Void
    let onComplete: @MainActor () -> Void

    @State private var pager: OnboardingPager

    init(
        model: PaddrMenuModel,
        onSkip: @escaping @MainActor () -> Void,
        onComplete: @escaping @MainActor () -> Void,
        initialPager: OnboardingPager = OnboardingPager()
    ) {
        self.model = model
        self.onSkip = onSkip
        self.onComplete = onComplete
        _pager = State(initialValue: initialPager)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView { page.frame(maxWidth: .infinity, alignment: .leading) }
            Divider()
            footer
        }
        .frame(
            minWidth: PaddrStyle.Metrics.minimumGuideWindowSize.width,
            idealWidth: PaddrStyle.Metrics.guideWindowSize.width,
            minHeight: PaddrStyle.Metrics.minimumGuideWindowSize.height,
            idealHeight: PaddrStyle.Metrics.guideWindowSize.height
        )
        .background { PanelBackgroundView() }
        .foregroundStyle(PaddrStyle.textPrimary)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Paddr Guide")
                .paddrTypography(.pageTitle)
            Spacer()
            Text("Step \(pager.pageNumber) of \(OnboardingPager.pageCount)")
                .paddrTypography(.rowLabel)
                .foregroundStyle(PaddrStyle.textSecondary)
        }
        .padding(.horizontal, PaddrStyle.Spacing.s5)
        .padding(.vertical, PaddrStyle.Spacing.s4)
        .accessibilityElement(children: .combine)
        .paddrAccessibilityID("guide", "header")
    }

    private var page: some View {
        VStack(spacing: PaddrStyle.Spacing.s5) {
            switch pager.pageIndex {
            case 0:
                guidePage(
                    symbol: "hand.point.up.left.fill",
                    title: LocalizedStringResource("Welcome to Paddr"),
                    detail: LocalizedStringResource(
                        "Use Steam Controller trackpads without Steam Input. Paddr maps trackpad gestures to normal macOS mouse, scrolling, and keyboard input; it does not inject into games."
                    )
                )
            case 1:
                guidePage(
                    symbol: "person.crop.rectangle.stack",
                    title: LocalizedStringResource("Profiles and Duplicate Default"),
                    detail: LocalizedStringResource(
                        "Default is a safe, read-only reference. Duplicate Default to create an editable profile, then set each pad to Pointer, Scroll, Off, or Zones."
                    )
                )
            case 2:
                guidePage(
                    symbol: "accessibility",
                    title: LocalizedStringResource("Allow Access"),
                    detail: LocalizedStringResource(
                        "Input Monitoring lets Paddr receive controller reports from the puck, and Accessibility lets it send your mapped mouse and keyboard input. Paddr asks for Input Monitoring at first launch; otherwise it only requests permission or opens Settings when you choose an action below."
                    )
                ) {
                    permissionControls
                }
            default:
                guidePage(
                    symbol: "play.circle.fill",
                    title: LocalizedStringResource("Start Output Safely"),
                    detail: LocalizedStringResource(
                        "The Paddr menu shows receiver and controller status with the Enable output switch. When output starts, release both trackpads and any assigned rear buttons or grips to return to neutral before mapped input activates."
                    )
                )
            }

            pageIndicator
        }
        .padding(PaddrStyle.Spacing.s5)
    }

    private func guidePage(
        symbol: String,
        title: LocalizedStringResource,
        detail: LocalizedStringResource
    ) -> some View {
        guidePage(symbol: symbol, title: title, detail: detail) { EmptyView() }
    }

    private func guidePage<Actions: View>(
        symbol: String,
        title: LocalizedStringResource,
        detail: LocalizedStringResource,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .top, spacing: PaddrStyle.Spacing.s5) {
            Image(systemName: symbol)
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(PaddrStyle.accentText)
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
                Text(title)
                    .paddrTypography(.cardTitle)
                Text(detail)
                    .paddrTypography(.rowLabel)
                    .foregroundStyle(PaddrStyle.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                actions()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .paddrCard()
        .accessibilityElement(children: .contain)
    }

    private var permissionControls: some View {
        PermissionSetupContent(model: model, identifierPrefix: "guide")
    }

    private var pageIndicator: some View {
        HStack(spacing: PaddrStyle.Spacing.s2) {
            ForEach(0..<OnboardingPager.pageCount, id: \.self) { index in
                Image(systemName: index == pager.pageIndex ? "circle.fill" : "circle")
                    .foregroundStyle(
                        index == pager.pageIndex
                            ? PaddrStyle.accentText
                            : PaddrStyle.textTertiary
                    )
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Guide progress")
        .accessibilityValue("Step \(pager.pageNumber) of \(OnboardingPager.pageCount)")
    }

    private var currentPageTitle: String {
        switch pager.pageIndex {
        case 0: String(localized: "Welcome to Paddr")
        case 1: String(localized: "Profiles and Duplicate Default")
        case 2: String(localized: "Allow Access")
        default: String(localized: "Start Output Safely")
        }
    }

    private func goBack() {
        pager.goBack()
        announcePageChange()
    }

    private func goNext() {
        pager.advance()
        announcePageChange()
    }

    private func announcePageChange() {
        AccessibilityNotification.Announcement(
            String(
                localized: "Step \(pager.pageNumber) of \(OnboardingPager.pageCount): \(currentPageTitle)"
            )
        ).post()
    }

    private var footer: some View {
        HStack(spacing: PaddrStyle.Spacing.s2) {
            Button("Skip", action: onSkip)
                .keyboardShortcut(.cancelAction)
                .paddrActionButton(.secondary)
                .paddrAccessibilityID("guide", "skip")

            Spacer()

            if pager.canGoBack {
                Button("Back", action: goBack)
                    .paddrActionButton(.secondary)
                    .paddrAccessibilityID("guide", "back")
            }

            if pager.isLastPage {
                Button("Get Started", action: onComplete)
                    .keyboardShortcut(.defaultAction)
                    .paddrActionButton(.primary)
                    .paddrAccessibilityID("guide", "complete")
            } else {
                Button("Next", action: goNext)
                    .keyboardShortcut(.defaultAction)
                    .paddrActionButton(.primary)
                    .paddrAccessibilityID("guide", "next")
            }
        }
        .padding(.horizontal, PaddrStyle.Spacing.s5)
        .padding(.vertical, PaddrStyle.Spacing.s4)
    }
}

import Foundation
import Observation

package enum OnboardingPresentationTrigger: Sendable {
    case automatic
    case help
}

package enum OnboardingDismissal: String, CaseIterable, Sendable {
    case skipped
    case completed
}

package enum OnboardingEligibility {
    package static func shouldPresent(
        trigger: OnboardingPresentationTrigger,
        hasRecordedDismissal: Bool
    ) -> Bool {
        switch trigger {
        case .automatic:
            !hasRecordedDismissal
        case .help:
            true
        }
    }
}

package final class OnboardingPreferences {
    package static let dismissalKey = "com.partofaday.Paddr.onboarding.v1.dismissal"

    private let defaults: UserDefaults

    package init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    package var dismissal: OnboardingDismissal? {
        guard let rawValue = defaults.string(forKey: Self.dismissalKey) else { return nil }
        return OnboardingDismissal(rawValue: rawValue)
    }

    package var hasRecordedDismissal: Bool { dismissal != nil }

    package func record(_ dismissal: OnboardingDismissal) {
        guard self.dismissal != .completed else { return }
        defaults.set(dismissal.rawValue, forKey: Self.dismissalKey)
    }
}

/// Whether the setup checklist is showing in the configuration window. Automatic
/// presentation happens once; Help can always reopen it.
@MainActor
@Observable
package final class SetupGuidePresentation {
    package private(set) var isPresented = false
    /// Counts presentations, so the window can bring the checklist into view
    /// each time it is asked for, including while it is already showing.
    package private(set) var presentationCount = 0
    @ObservationIgnored private let preferences: OnboardingPreferences

    package init(preferences: OnboardingPreferences = OnboardingPreferences()) {
        self.preferences = preferences
    }

    package func present(trigger: OnboardingPresentationTrigger) {
        guard OnboardingEligibility.shouldPresent(
            trigger: trigger,
            hasRecordedDismissal: preferences.hasRecordedDismissal
        ) else { return }
        isPresented = true
        presentationCount += 1
    }

    /// Setup finished, so it is not offered automatically again. The checklist
    /// stays up for the person still reading it.
    package func recordCompletion() {
        preferences.record(.completed)
    }

    /// Closing the window ends an unfinished presentation, as closing the
    /// separate guide window once did.
    package func windowDidClose() {
        guard isPresented else { return }
        dismiss(as: .skipped)
    }

    package func dismiss(as dismissal: OnboardingDismissal) {
        preferences.record(dismissal)
        isPresented = false
    }
}

package struct CompanionWindowState: Equatable, Sendable {
    package let isVisible: Bool
    package let isMiniaturized: Bool

    package init(isVisible: Bool, isMiniaturized: Bool) {
        self.isVisible = isVisible
        self.isMiniaturized = isMiniaturized
    }

    package var requiresRegularActivation: Bool {
        isVisible || isMiniaturized
    }
}

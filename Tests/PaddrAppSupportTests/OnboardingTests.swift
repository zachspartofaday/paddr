@testable import PaddrAppSupport
import XCTest

final class OnboardingTests: XCTestCase {
    func testAbsentMarkerPresentsAutomatically() {
        XCTAssertTrue(
            OnboardingEligibility.shouldPresent(
                trigger: .automatic,
                hasRecordedDismissal: false
            )
        )
    }

    func testCompletedAndSkippedGuidesDoNotPresentAutomatically() {
        for dismissal in OnboardingDismissal.allCases {
            let defaults = isolatedDefaults()
            defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
            let preferences = OnboardingPreferences(defaults: defaults)

            preferences.record(dismissal)

            XCTAssertEqual(preferences.dismissal, dismissal)
            XCTAssertFalse(
                OnboardingEligibility.shouldPresent(
                    trigger: .automatic,
                    hasRecordedDismissal: preferences.hasRecordedDismissal
                )
            )
        }
    }

    func testHelpPresentationAlwaysOpens() {
        for hasRecordedDismissal in [false, true] {
            XCTAssertTrue(
                OnboardingEligibility.shouldPresent(
                    trigger: .help,
                    hasRecordedDismissal: hasRecordedDismissal
                )
            )
        }
    }

    func testCompletedThenExplicitSkipRemainsCompleted() {
        assertDismissalTransition([.completed, .skipped], expected: .completed)
    }

    func testSkippedThenGetStartedUpgradesToCompleted() {
        assertDismissalTransition([.skipped, .completed], expected: .completed)
    }

    func testAbsentThenSkipRecordsSkipped() {
        assertDismissalTransition([.skipped], expected: .skipped)
    }

    func testAbsentThenGetStartedRecordsCompleted() {
        assertDismissalTransition([.completed], expected: .completed)
    }

    @MainActor
    func testSetupPresentsAutomaticallyOnceAndHelpAlwaysReopensIt() {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        let preferences = OnboardingPreferences(defaults: defaults)
        let setup = SetupGuidePresentation(preferences: preferences)
        XCTAssertFalse(setup.isPresented, "Setup waits for the application to ask for it")

        setup.present(trigger: .automatic)
        XCTAssertTrue(setup.isPresented, "A first launch shows setup inside the configuration window")
        setup.present(trigger: .automatic)
        XCTAssertTrue(setup.isPresented, "Asking again keeps the one checklist")

        setup.dismiss(as: .skipped)
        XCTAssertFalse(setup.isPresented)
        XCTAssertEqual(preferences.dismissal, .skipped)

        let nextLaunch = SetupGuidePresentation(preferences: preferences)
        nextLaunch.present(trigger: .automatic)
        XCTAssertFalse(nextLaunch.isPresented, "A recorded dismissal ends automatic presentation at the next launch")
        setup.present(trigger: .automatic)
        XCTAssertFalse(setup.isPresented, "A recorded dismissal ends automatic presentation")

        setup.present(trigger: .help)
        XCTAssertTrue(setup.isPresented, "Help > Paddr Guide always reopens setup")
        setup.dismiss(as: .completed)
        XCTAssertEqual(preferences.dismissal, .completed)

        setup.present(trigger: .help)
        setup.dismiss(as: .skipped)
        XCTAssertEqual(preferences.dismissal, .completed, "Skipping a reopened guide keeps completion")
    }

    @MainActor
    func testClosingTheWindowEndsAutomaticSetupAsClosingTheGuideDid() {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        let preferences = OnboardingPreferences(defaults: defaults)
        let setup = SetupGuidePresentation(preferences: preferences)

        setup.windowDidClose()
        XCTAssertNil(preferences.dismissal, "Closing a window that never showed setup records nothing")

        setup.present(trigger: .automatic)
        setup.windowDidClose()
        XCTAssertFalse(setup.isPresented, "Reopening the window in the same session does not bring setup back")
        XCTAssertEqual(preferences.dismissal, .skipped)

        let nextLaunch = SetupGuidePresentation(preferences: preferences)
        nextLaunch.present(trigger: .automatic)
        XCTAssertFalse(nextLaunch.isPresented, "Setup is offered automatically once")
        nextLaunch.present(trigger: .help)
        XCTAssertTrue(nextLaunch.isPresented)
    }

    @MainActor
    func testReachingActiveOutputEndsAutomaticSetupWithoutHidingTheChecklist() {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        let preferences = OnboardingPreferences(defaults: defaults)
        let setup = SetupGuidePresentation(preferences: preferences)
        setup.present(trigger: .automatic)

        setup.recordCompletion()
        XCTAssertTrue(setup.isPresented, "The person still reading the checklist keeps it")
        XCTAssertEqual(preferences.dismissal, .completed)

        setup.windowDidClose()
        XCTAssertEqual(preferences.dismissal, .completed, "Closing afterwards never downgrades completion")
        let nextLaunch = SetupGuidePresentation(preferences: preferences)
        nextLaunch.present(trigger: .automatic)
        XCTAssertFalse(nextLaunch.isPresented)
    }

    @MainActor
    func testEveryRequestForSetupIsCountedSoTheWindowCanBringItIntoView() {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        let setup = SetupGuidePresentation(preferences: OnboardingPreferences(defaults: defaults))
        XCTAssertEqual(setup.presentationCount, 0)
        setup.present(trigger: .automatic)
        XCTAssertEqual(setup.presentationCount, 1)
        setup.present(trigger: .help)
        XCTAssertEqual(setup.presentationCount, 2, "Asking again while it shows is still a request")
        setup.dismiss(as: .skipped)
        setup.present(trigger: .automatic)
        XCTAssertEqual(setup.presentationCount, 2, "A refused automatic presentation is not a request")
    }

    func testConnectionGuidanceNamesThePuckFirstAndMatchesTheNextAction() {
        let cases: [(PaddrReadinessInput, PaddrReadinessNextAction?)] = [
            (readiness(puck: false, controller: false), .refreshPuck),
            (readiness(puck: false, controller: false, searchingForPuck: true), .connectPuck),
            (readiness(controller: false), .connectController),
            (readiness(controller: false, searchingForPuck: true), .connectController),
            (readiness(), nil),
            // Access comes first as the next action, yet the connection step
            // still says what is missing.
            (readiness(controller: false, inputMonitoring: false), .connectController),
        ]
        for (input, expected) in cases {
            let resolution = PaddrReadinessResolver.resolve(input)
            XCTAssertEqual(resolution.connectionAction, expected, "\(input)")
            if resolution.nextAction.setupStep == .connection {
                XCTAssertEqual(resolution.connectionAction, resolution.nextAction, "\(input)")
            }
        }
        let initializing = PaddrReadinessResolver.resolve(PaddrReadinessInput(
            isInitialized: false, puckConnected: false, controllerConnected: false,
            batteryAvailable: false, inputMonitoringGranted: true, accessibilityTrusted: true,
            isEnabled: false, isRunning: false, isReleasingOutput: false, canToggleOutput: false))
        XCTAssertEqual(initializing.nextAction, .waitForInitialization)
        XCTAssertEqual(initializing.connectionAction, .connectPuck,
                       "Initialization probes for the puck itself, so it never asks for a refresh")
    }

    func testSetupChecklistMarksTheStepThatOwnsTheNextAction() {
        let cases: [(PaddrReadinessInput, PaddrSetupStep?, [PaddrSetupStep])] = [
            // (readiness, current step, done steps)
            (readiness(puck: false, controller: false, inputMonitoring: false, accessibility: false,
                       enabled: false, running: false), .connection, []),
            (readiness(controller: false, inputMonitoring: false, accessibility: false,
                       enabled: false, running: false), .access, []),
            (readiness(controller: false, accessibility: false, enabled: false, running: false),
             .connection, []),
            (readiness(accessibility: false, enabled: false, running: false), .access, [.connection]),
            (readiness(enabled: false, running: false), .output, [.access, .connection]),
            (readiness(running: false), .output, [.access, .connection]),
            (readiness(), nil, [.access, .connection, .output]),
        ]
        for (input, expectedCurrent, expectedDone) in cases {
            let checklist = PaddrSetupChecklist(
                readiness: PaddrReadinessResolver.resolve(input), editsOwnProfile: false)
            XCTAssertEqual(checklist.items.map(\.step), PaddrSetupStep.allCases)
            XCTAssertEqual(checklist.items.filter { $0.state == .current }.map(\.step),
                           expectedCurrent.map { [$0] } ?? [], "\(input)")
            XCTAssertEqual(checklist.items.filter { $0.state == .done }.map(\.step), expectedDone, "\(input)")
            XCTAssertEqual(checklist.nextAction.setupStep, expectedCurrent, "\(input)")
        }
    }

    func testSetupCompletesWhenOutputIsActiveWithoutRequiringAnOwnProfile() {
        let active = PaddrReadinessResolver.resolve(readiness())
        let onDefault = PaddrSetupChecklist(readiness: active, editsOwnProfile: false)
        XCTAssertTrue(onDefault.isComplete, "Default is a working profile; editing one is optional")
        XCTAssertEqual(onDefault.state(of: .profile), .pending)
        XCTAssertEqual(PaddrSetupChecklist(readiness: active, editsOwnProfile: true).state(of: .profile), .done)

        let waiting = PaddrReadinessResolver.resolve(readiness(running: false))
        XCTAssertFalse(PaddrSetupChecklist(readiness: waiting, editsOwnProfile: true).isComplete,
                       "Setup is not complete until mapped output is active")
    }

    func testEveryNextActionBelongsToItsSetupStepAndWaitingStatesToNone() {
        XCTAssertNil(PaddrReadinessNextAction.waitForInitialization.setupStep)
        XCTAssertNil(PaddrReadinessNextAction.waitForProfileOperation.setupStep)
        XCTAssertNil(PaddrReadinessNextAction.none.setupStep)
        XCTAssertEqual(PaddrReadinessNextAction.connectPuck.setupStep, .connection)
        XCTAssertEqual(PaddrReadinessNextAction.refreshPuck.setupStep, .connection)
        XCTAssertEqual(PaddrReadinessNextAction.connectController.setupStep, .connection)
        XCTAssertEqual(PaddrReadinessNextAction.requestInputMonitoring.setupStep, .access)
        XCTAssertEqual(PaddrReadinessNextAction.requestAccessibility.setupStep, .access)
        XCTAssertEqual(PaddrReadinessNextAction.releaseTrackpads.setupStep, .output)
        XCTAssertEqual(PaddrReadinessNextAction.enableOutput.setupStep, .output)
        XCTAssertEqual(PaddrReadinessNextAction.waitForOutputRelease.setupStep, .output,
                       "Releasing held input is the output step finishing, not a separate wait")
    }

    func testMissingPuckAsksForRefreshOnlyWhenNothingIsSearchingForIt() {
        let manual = PaddrReadinessResolver.resolve(readiness(puck: false))
        XCTAssertEqual(manual.nextAction, .refreshPuck)
        XCTAssertEqual(String(localized: manual.nextAction.title), "Connect the puck, then refresh")

        let searching = PaddrReadinessResolver.resolve(readiness(puck: false, searchingForPuck: true))
        XCTAssertEqual(searching.nextAction, .connectPuck)
        XCTAssertEqual(String(localized: searching.nextAction.title), "Connect the puck",
                       "The reconnect probe finds the puck, so the instruction must not ask for a refresh")

        XCTAssertEqual(
            PaddrReadinessResolver.resolve(readiness(searchingForPuck: true)).nextAction, .none,
            "A connected puck is never reported as missing"
        )
    }

    func testMinimizedCompanionWindowRetainsRegularActivation() {
        let state = CompanionWindowState(isVisible: false, isMiniaturized: true)

        XCTAssertTrue(state.requiresRegularActivation)
    }

    func testCompanionWindowReleasesRegularActivationOnlyAfterClosing() {
        XCTAssertTrue(
            CompanionWindowState(isVisible: true, isMiniaturized: false).requiresRegularActivation
        )
        XCTAssertFalse(
            CompanionWindowState(isVisible: false, isMiniaturized: false).requiresRegularActivation
        )
    }

    private func readiness(
        puck: Bool = true, controller: Bool = true, inputMonitoring: Bool = true,
        accessibility: Bool = true, enabled: Bool = true, running: Bool = true,
        searchingForPuck: Bool = false
    ) -> PaddrReadinessInput {
        PaddrReadinessInput(
            isInitialized: true, puckConnected: puck, controllerConnected: controller,
            batteryAvailable: controller, inputMonitoringGranted: inputMonitoring,
            accessibilityTrusted: accessibility, isEnabled: enabled, isRunning: running,
            isReleasingOutput: false, canToggleOutput: true,
            isSearchingForPuck: searchingForPuck
        )
    }

    private func assertDismissalTransition(
        _ transitions: [OnboardingDismissal],
        expected: OnboardingDismissal,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        let preferences = OnboardingPreferences(defaults: defaults)

        for transition in transitions { preferences.record(transition) }

        XCTAssertEqual(preferences.dismissal, expected, file: file, line: line)
        XCTAssertFalse(
            OnboardingEligibility.shouldPresent(
                trigger: .automatic,
                hasRecordedDismissal: preferences.hasRecordedDismissal
            ),
            file: file,
            line: line
        )
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "OnboardingTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated defaults suite")
            return .standard
        }
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(suiteName, forKey: Self.suiteMarkerKey)
        return defaults
    }

    private func defaultsSuiteName(_ defaults: UserDefaults) -> String {
        guard let suiteName = defaults.string(forKey: Self.suiteMarkerKey) else {
            XCTFail("Isolated defaults suite marker is missing")
            return ""
        }
        return suiteName
    }

    private static let suiteMarkerKey = "OnboardingTests.suiteName"
}

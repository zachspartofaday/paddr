import Foundation

/// The things a new user does, in order, before mapped output works.
public enum PaddrSetupStep: CaseIterable, Sendable {
    case access
    case connection
    case profile
    case output
}

public enum PaddrSetupStepState: Equatable, Sendable {
    case done
    /// The step that owns the readiness resolver's next action.
    case current
    case pending
}

extension PaddrReadinessNextAction {
    /// The setup step this action belongs to. Waiting states belong to none.
    public var setupStep: PaddrSetupStep? {
        switch self {
        case .requestInputMonitoring, .requestAccessibility: .access
        case .connectPuck, .refreshPuck, .connectController: .connection
        case .enableOutput, .releaseTrackpads, .waitForOutputRelease: .output
        case .waitForInitialization, .waitForProfileOperation, .none: nil
        }
    }
}

/// Setup progress derived from the same readiness resolution that drives the
/// status bar, so the checklist and the bar can never disagree about what is next.
public struct PaddrSetupChecklist: Equatable, Sendable {
    public struct Item: Equatable, Identifiable, Sendable {
        public let step: PaddrSetupStep
        public let state: PaddrSetupStepState
        public var id: PaddrSetupStep { step }
    }

    public let items: [Item]
    public let nextAction: PaddrReadinessNextAction

    public init(readiness: PaddrReadinessResolution, editsOwnProfile: Bool) {
        nextAction = readiness.nextAction
        let currentStep = readiness.nextAction.setupStep
        items = PaddrSetupStep.allCases.map { step in
            let isDone = switch step {
            case .access: readiness.access == .ready
            case .connection: readiness.puck == .connected && readiness.controller == .connected
            case .profile: editsOwnProfile
            case .output: readiness.output == .active
            }
            return Item(step: step, state: isDone ? .done : step == currentStep ? .current : .pending)
        }
    }

    public func state(of step: PaddrSetupStep) -> PaddrSetupStepState {
        items.first { $0.step == step }?.state ?? .pending
    }

    /// Mapped output is active. Editing a profile of one's own is optional, so
    /// it does not hold completion back.
    public var isComplete: Bool {
        items.allSatisfy { $0.step == .profile || $0.state == .done }
    }
}

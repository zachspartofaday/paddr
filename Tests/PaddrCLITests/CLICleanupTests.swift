import Foundation
import Synchronization
import XCTest
import PaddrCLIKit
@testable import PaddrCore

final class CLICleanupTests: XCTestCase {
    func testShutdownRetainsKeysAndMouseUntilRecoveryAfterReturnOrThrow() throws {
        let key = try KeyCatalog.resolve("space")
        for failsRuntime in [false, true] {
            for requestedStop in [false, true] {
                let sink = RecoveringOutput()
                let token = TrackpadStopToken()
                let result = Result {
                    try CLIExecution.run(
                        configuration: .default,
                        observeOnly: false,
                        stopToken: token,
                        duration: try CLIDuration(argument: "0.25"),
                        onAction: { _ in },
                        runtime: { _, _, stop, _, _ in
                            let ledger = HeldOutputLedger(output: sink)
                            try stop.beginRun(retaining: ledger)
                            defer { stop.finishRun() }
                            try ledger.dispatch([.key(key, isPressed: true), .mouseButton(.left, isPressed: true)])
                            if requestedStop { stop.requestStop(); _ = stop.shouldContinue }
                            XCTAssertFalse(ledger.releasePending(maxPasses: 2).isDrained)
                            if failsRuntime { throw PaddrError.output("original runtime failure") }
                            return .init(summary: .init(reportCount: 2, actionCount: 2), termination: .stopped)
                        },
                        onCleanupDiagnostic: { sink.recordDiagnostic($0) },
                        waitBeforeCleanupRetry: {
                            // Recovery happens only after the coordinator has retained the token
                            // through two separate retry intervals. No live events or wall-clock wait.
                            XCTAssertTrue(token.hasPendingOutputs)
                            sink.recoverAfterTwoWaits()
                        }
                    )
                }
                XCTAssertFalse(token.hasPendingOutputs)
                XCTAssertEqual(sink.actions, [
                    .key(key, isPressed: true), .mouseButton(.left, isPressed: true),
                    .key(key, isPressed: false), .mouseButton(.left, isPressed: false)
                ])
                XCTAssertEqual(sink.waits, 2)
                XCTAssertEqual(sink.diagnostics.count, 2)
                XCTAssertTrue(sink.diagnostics.first?.contains("Waiting to release") == true)
                if failsRuntime {
                    XCTAssertThrowsError(try result.get()) {
                        XCTAssertTrue(String(describing: $0).contains("original runtime failure"))
                    }
                } else { XCTAssertEqual(try result.get().summary.actionCount, 2) }
            }
        }
    }

    func testPartialTapFailureReleasesOnlyItsSuccessfullyPostedDown() throws {
        let sink = RecoveringOutput()
        let token = TrackpadStopToken()
        XCTAssertThrowsError(try CLIExecution.run(
            configuration: .default, observeOnly: false, stopToken: token,
            duration: nil, onAction: { _ in },
            runtime: { _, _, stop, _, _ in
                let ledger = HeldOutputLedger(output: sink)
                try stop.beginRun(retaining: ledger)
                defer { stop.finishRun() }
                // A batch fails after the first down. The second button was never pressed.
                try ledger.dispatch([
                    .mouseButton(.left, isPressed: true), .mouseButton(.left, isPressed: false),
                    .mouseButton(.right, isPressed: true)
                ])
                XCTFail("Expected the partial tap to fail")
                return .init(summary: .init(reportCount: 0, actionCount: 0), termination: .stopped)
            },
            waitBeforeCleanupRetry: { sink.recoverAfterTwoWaits() }
        ))
        XCTAssertEqual(sink.actions, [.mouseButton(.left, isPressed: true), .mouseButton(.left, isPressed: false)])
        XCTAssertFalse(token.hasPendingOutputs)
    }
}

private final class RecoveringOutput: TrackpadOutputDispatching, Sendable {
    private struct State {
        var actions: [TrackpadOutputAction] = []
        var waits = 0
        var diagnostics: [String] = []
    }
    private let state = Mutex(State())
    var actions: [TrackpadOutputAction] { state.withLock { $0.actions } }
    var waits: Int { state.withLock { $0.waits } }
    var diagnostics: [String] { state.withLock { $0.diagnostics } }
    func recordDiagnostic(_ text: String) { state.withLock { $0.diagnostics.append(text) } }
    func recoverAfterTwoWaits() { state.withLock { $0.waits += 1 } }
    func dispatch(_ actions: [TrackpadOutputAction]) throws {
        try state.withLock { state in
            for action in actions {
                switch action {
                case .key(_, isPressed: false), .mouseButton(_, isPressed: false):
                    guard state.waits >= 2 else { throw PaddrError.output("release unavailable") }
                default: break
                }
                state.actions.append(action)
            }
        }
    }
}

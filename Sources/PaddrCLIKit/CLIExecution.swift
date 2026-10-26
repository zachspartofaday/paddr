import Foundation
import PaddrCore

package enum CLIExecution {
    package typealias Runtime = @Sendable (
        PaddrConfiguration,
        Bool,
        TrackpadStopToken,
        Duration?,
        @escaping @Sendable (String) -> Void
    ) throws -> TrackpadRunResult

    package static func run(
        configuration: PaddrConfiguration,
        observeOnly: Bool,
        stopToken: TrackpadStopToken,
        duration: CLIDuration?,
        onAction: @escaping @Sendable (String) -> Void,
        runtime: Runtime = liveRuntime,
        onCleanupDiagnostic: @Sendable (String) -> Void = { _ in },
        waitBeforeCleanupRetry: @Sendable () -> Void = { Thread.sleep(forTimeInterval: 0.25) }
    ) throws -> TrackpadRunResult {
        let result = Result {
            try runtime(configuration, observeOnly, stopToken, duration?.runtimeValue, onAction)
        }
        // Signals request runtime shutdown, not abandonment of successfully posted downs.
        // Keep the token (and its output sink) alive through permission/allocation recovery.
        var reportedPendingRelease = false
        while let diagnostic = stopToken.retryPendingOutputRelease() {
            if !reportedPendingRelease {
                onCleanupDiagnostic(
                    "Waiting to release held input: \(diagnostic). "
                        + "Keep PaddrCLI running; restore Accessibility access if needed. "
                        + "Cleanup will retry automatically."
                )
                reportedPendingRelease = true
            }
            waitBeforeCleanupRetry()
        }
        if reportedPendingRelease { onCleanupDiagnostic("Held input released; shutdown can finish.") }
        return try result.get()
    }

    private static func liveRuntime(
        configuration: PaddrConfiguration,
        observeOnly: Bool,
        stopToken: TrackpadStopToken,
        duration: Duration?,
        onAction: @escaping @Sendable (String) -> Void
    ) throws -> TrackpadRunResult {
        try TrackpadRuntime.run(
            configuration: configuration,
            observeOnly: observeOnly,
            stopToken: stopToken,
            duration: duration,
            onAction: onAction
        )
    }
}

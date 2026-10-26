import AppKit
import PaddrCore

@main
@MainActor
struct PaddrMain {
    static func main() {
        do {
            try run(
                arguments: CommandLine.arguments,
                launch: {
                    let application = NSApplication.shared
                    let delegate = AppDelegate()
                    application.delegate = delegate
                    withExtendedLifetime(delegate) { application.run() }
                },
                diagnosticSmoke: {
                    let configuration = (try? ConfigurationStore.load()) ?? .default
                    print("Paddr smoke test")
                    print("left=\(configuration.left.mode.rawValue), right=\(configuration.right.mode.rawValue)")
                    print("device=\(TritonHIDDevice.probe()?.description ?? "not found")")
                },
                report: { print($0) }
            )
        } catch {
            FileHandle.standardError.write(Data("Paddr artifact check failed: \(error)\n".utf8))
            exit(2)
        }
    }

    /// The packaging path only loads the executable and validates built-in data. Keep
    /// production dependencies lazy: no application, delegate, user store, TCC or HID.
    static func run(
        arguments: [String],
        launch: () -> Void,
        diagnosticSmoke: () -> Void,
        report: (String) -> Void
    ) throws {
        if arguments.contains("--artifact-smoke-test") {
            _ = try ConfigurationProfileStore.encoded(.default)
            report("Paddr artifact smoke test passed")
        } else if arguments.contains("--smoke-test") {
            diagnosticSmoke()
        } else {
            launch()
        }
    }
}

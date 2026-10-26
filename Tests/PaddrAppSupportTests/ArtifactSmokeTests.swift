import XCTest
@testable import PaddrMenu

@MainActor
final class ArtifactSmokeTests: XCTestCase {
    func testPackagingStartupNeverCreatesLiveDependencies() throws {
        var messages: [String] = []
        // Even a diagnostic flag alongside the packaging flag must not probe hardware.
        try PaddrMain.run(
            arguments: ["Paddr", "--artifact-smoke-test", "--smoke-test"],
            launch: { XCTFail("Packaging must not create NSApplication/AppDelegate or their store, permissions and HID dependencies") },
            diagnosticSmoke: { XCTFail("Packaging must not run the live diagnostic store/HID probe") },
            report: { messages.append($0) }
        )
        XCTAssertEqual(messages, ["Paddr artifact smoke test passed"])
    }
}

import Foundation
import Synchronization
import XCTest
@testable import PaddrCore

final class ProfileTransactionTests: XCTestCase {
    func testStaleClientCannotEraseAnotherClientsProfileAndCanReload() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.json")
        let gui = ConfigurationProfileStoreClient(url: url)
        let cli = ConfigurationProfileStoreClient(url: url)
        var stale = try gui.load().document
        var current = try cli.load().document
        _ = try current.createProfile(named: "CLI addition")
        try cli.save(current)
        let committedBytes = try Data(contentsOf: url)
        _ = try stale.createProfile(named: "GUI draft")
        XCTAssertThrowsError(try gui.save(stale)) {
            XCTAssertTrue(String(describing: $0).contains("changed in another"))
        }
        XCTAssertEqual(try Data(contentsOf: url), committedBytes)
        XCTAssertNotNil(stale.profile(matching: "GUI draft"))
        var reloaded = try gui.load().document
        _ = try reloaded.createProfile(named: "Recovered draft")
        try gui.save(reloaded)
        XCTAssertNotNil(try cli.load().document.profile(matching: "CLI addition"))
        XCTAssertNotNil(try cli.load().document.profile(matching: "Recovered draft"))
    }

    func testSimultaneousClientsCommitExactlyOneVersion() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.json")
        let clients = (0..<2).map { _ in ConfigurationProfileStoreClient(url: url) }
        let documents = try clients.enumerated().map { index, client in
            var document = try client.load().document
            _ = try document.createProfile(named: "Writer \(index)")
            return document
        }
        let outcomes = Mutex<[Bool]>([])
        let ready = DispatchSemaphore(value: 0)
        let start = DispatchSemaphore(value: 0)
        let group = DispatchGroup()
        for index in 0..<2 {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                ready.signal()
                guard start.wait(timeout: .now() + 5) == .success else { return }
                do { try clients[index].save(documents[index]); outcomes.withLock { $0.append(true) } }
                catch { outcomes.withLock { $0.append(false) } }
            }
        }
        for _ in 0..<2 { XCTAssertEqual(ready.wait(timeout: .now() + 5), .success) }
        for _ in 0..<2 { start.signal() }
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(outcomes.withLock { $0.sorted { !$0 && $1 } }, [false, true])
        XCTAssertEqual(try ConfigurationProfileStore.load(from: url).document.userProfiles.count, 1)
    }

    func testMigrationAndAliasUseTheSameCommitBoundary() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let real = directory.appendingPathComponent("real", isDirectory: true)
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let alias = directory.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: real)
        let url = real.appendingPathComponent("config.json")
        try ConfigurationStore.encoded(.formerCoupledDefault).write(to: url)
        let first = ConfigurationProfileStoreClient(url: url)
        let second = ConfigurationProfileStoreClient(url: alias.appendingPathComponent("config.json"))
        let migrated = try first.load().document
        var secondDocument = try second.load().document
        XCTAssertEqual(migrated, secondDocument)
        XCTAssertEqual(migrated.builtInDefaultCenterTapTrackingMode, .coupled)
        _ = try secondDocument.createProfile(named: "After migration")
        try second.save(secondDocument)
        XCTAssertThrowsError(try first.save(migrated))
        XCTAssertNotNil(try first.load().document.profile(matching: "After migration"))
    }

    func testExplicitExportChecksItsSourceButReplacesDestination() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.json")
        let destination = directory.appendingPathComponent("export.json")
        try ConfigurationProfileStore.save(.default, to: source)
        let client = ConfigurationProfileStoreClient(url: source)
        var document = try client.loadInput().profileDocument!
        _ = try document.createProfile(named: "Exported")
        try Data("deliberately replaced".utf8).write(to: destination)
        try client.save(document, to: destination)
        XCTAssertEqual(try ConfigurationProfileStore.load(from: source).document, .default)
        XCTAssertNotNil(try ConfigurationProfileStore.load(from: destination).document.profile(matching: "Exported"))
        // Export consumes the prior snapshot; load again so this failure exercises
        // a changed source, rather than merely the load-before-save precondition.
        _ = try client.loadInput()
        try ConfigurationProfileStore.save(document, to: source)
        let exportedBytes = try Data(contentsOf: destination)
        XCTAssertThrowsError(try client.save(.default, to: destination)) {
            XCTAssertTrue(String(describing: $0).contains("changed in another"))
        }
        XCTAssertEqual(try Data(contentsOf: destination), exportedBytes)
    }

    func testCompatibilityReadAndExportDoNotWriteIntoSourceDirectory() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceDirectory = directory.appendingPathComponent("input", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        let source = sourceDirectory.appendingPathComponent("legacy.json")
        try ConfigurationStore.encoded(.default).write(to: source)
        let client = ConfigurationProfileStoreClient(url: source)
        _ = try client.loadInput()
        try client.save(.default, to: directory.appendingPathComponent("export.json"))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: sourceDirectory.path), ["legacy.json"])
    }

    func testStorageLockExcludesAnotherProcessAndReleasesAfterThrowing() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.json")
        func probeLock() throws -> Int32 {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = ["-c", """
                import fcntl, os, sys
                fd = os.open(sys.argv[1], os.O_RDWR)
                try:
                    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    sys.exit(73)
                os.close(fd)
                """, directory.appendingPathComponent(".paddr-profiles.lock").path]
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        }
        enum Witness: Error { case expected }
        XCTAssertThrowsError(try ConfigurationProfileStore.withStorageLock(for: url) {
            XCTAssertEqual(try probeLock(), 73)
            throw Witness.expected
        })
        XCTAssertEqual(try probeLock(), 0)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

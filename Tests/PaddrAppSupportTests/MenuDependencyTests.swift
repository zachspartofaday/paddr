import Foundation
import Synchronization
import XCTest
@testable import PaddrAppSupport
import PaddrCore

@MainActor
final class MenuDependencyTests: XCTestCase {
    func testStaleModelSavePreservesExternalProfileAndUnsavedDraft() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.json")
        var document = ConfigurationProfileDocument.default
        let editable = try document.createProfile(named: "Editable")
        document.activeProfileID = editable.id
        try ConfigurationProfileStore.save(document, to: url)
        let guiStore = ConfigurationProfileStoreClient(url: url)
        let model = PaddrMenuModel(dependencies: MenuDependencies(
            session: InertSession(),
            loadProfiles: { try guiStore.load() },
            saveProfiles: { try guiStore.save($0) },
            probeReceiver: { nil }, accessibilityTrusted: { _ in true },
            openPrivacySettings: { _ in }, sleep: { try await Task.sleep(for: $0) }
        ))
        await waitUntil(model: model) { model.isInitialized }
        let cliStore = ConfigurationProfileStoreClient(url: url)
        var external = try cliStore.load().document
        _ = try external.createProfile(named: "CLI addition")
        try cliStore.save(external)
        let externalBytes = try Data(contentsOf: url)
        model.configuration.left.sensitivity = 7
        model.saveAndApply()
        await waitUntil(model: model) {
            if case .failure(.configurationSave) = model.status { return true }
            return false
        }
        XCTAssertTrue(model.hasUnsavedChanges)
        XCTAssertEqual(model.configuration.left.sensitivity, 7)
        XCTAssertEqual(model.savedConfiguration, editable.configuration)
        XCTAssertEqual(try Data(contentsOf: url), externalBytes)
        XCTAssertTrue(model.renameActiveProfile(to: "Renamed draft"))
        await waitUntil(model: model) {
            if case .failure(.profileSave) = model.status { return true }
            return false
        }
        XCTAssertEqual(model.profiles.first(where: { $0.id == editable.id })?.name, "Editable")
        XCTAssertEqual(model.configuration.left.sensitivity, 7)
        XCTAssertEqual(try Data(contentsOf: url), externalBytes)
    }

    func testConfigurationAndReceiverDependenciesRunOffMainActor() async throws {
        let state = DependencyExecutionState()
        let storedConfiguration: PaddrConfiguration = {
            var configuration = PaddrConfiguration.default
            configuration.left.sensitivity = 4
            return configuration
        }()
        var mutableDocument = ConfigurationProfileDocument.default
        let profile = try mutableDocument.createProfile(named: "Stored", configuration: storedConfiguration)
        mutableDocument.activeProfileID = profile.id
        let storedDocument = mutableDocument
        let dependencies = MenuDependencies(
            session: InertSession(),
            loadProfiles: {
                state.loadRanOnMainThread = Thread.isMainThread
                return ConfigurationProfileLoadResult(document: storedDocument)
            },
            saveProfiles: { document in
                state.saveRanOnMainThread = Thread.isMainThread
                state.savedConfiguration = document.activeProfile?.configuration
            },
            probeReceiver: {
                state.probeRanOnMainThread = Thread.isMainThread
                return "Fake puck"
            },
            accessibilityTrusted: { _ in true },
            openPrivacySettings: { _ in },
            sleep: { _ in }
        )

        let loadedDocument = try await dependencies.loadProfiles().document
        try await dependencies.saveProfiles(loadedDocument)
        let receiverDescription = await dependencies.probeReceiver()

        XCTAssertEqual(loadedDocument.activeProfile?.configuration.left.sensitivity, 4)
        XCTAssertEqual(state.savedConfiguration, loadedDocument.activeProfile?.configuration)
        XCTAssertEqual(receiverDescription, "Fake puck")
        XCTAssertEqual(state.loadRanOnMainThread, false)
        XCTAssertEqual(state.saveRanOnMainThread, false)
        XCTAssertEqual(state.probeRanOnMainThread, false)
    }
}

private actor InertSession: TrackpadSessionControlling {
    func start(
        configuration: PaddrConfiguration,
        observeOnly: Bool,
        outputGate: OutputGate?
    ) async -> AsyncStream<TrackpadSessionEvent> {
        AsyncStream { $0.finish() }
    }

    @discardableResult
    func stop() async -> TrackpadSessionStopOutcome { .clean }
}

private final class DependencyExecutionState: Sendable {
    private struct State: ~Copyable {
        var savedConfiguration: PaddrConfiguration?
        var loadRanOnMainThread: Bool?
        var saveRanOnMainThread: Bool?
        var probeRanOnMainThread: Bool?
    }

    private let state = Mutex(State())

    var savedConfiguration: PaddrConfiguration? {
        get { state.withLock { $0.savedConfiguration } }
        set { state.withLock { $0.savedConfiguration = newValue } }
    }

    var loadRanOnMainThread: Bool? {
        get { state.withLock { $0.loadRanOnMainThread } }
        set { state.withLock { $0.loadRanOnMainThread = newValue } }
    }

    var saveRanOnMainThread: Bool? {
        get { state.withLock { $0.saveRanOnMainThread } }
        set { state.withLock { $0.saveRanOnMainThread = newValue } }
    }

    var probeRanOnMainThread: Bool? {
        get { state.withLock { $0.probeRanOnMainThread } }
        set { state.withLock { $0.probeRanOnMainThread = newValue } }
    }
}

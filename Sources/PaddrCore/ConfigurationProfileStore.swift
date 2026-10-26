import Darwin
import Foundation
import Synchronization

public enum ConfigurationProfileStore {
    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/Paddr/config.json")
    }

    public static func load(from url: URL? = nil) throws -> ConfigurationProfileLoadResult {
        try withStorageLock(for: url ?? defaultURL) {
            try loadUnlocked(from: url)
        }
    }

    public static func save(
        _ document: ConfigurationProfileDocument,
        to url: URL? = nil
    ) throws {
        // Explicit full-document replacement (for new stores and deliberate exports).
        // Read-modify-write clients must use ConfigurationProfileStoreClient instead.
        try withStorageLock(for: url ?? defaultURL) {
            try saveUnlocked(document, to: url ?? defaultURL)
        }
    }

    fileprivate static func loadUnlocked(from url: URL?) throws -> ConfigurationProfileLoadResult {
        try load(from: url, fileManager: .default,
                 homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
                 writeAtomically: atomicWrite)
    }

    fileprivate static func saveUnlocked(_ document: ConfigurationProfileDocument, to url: URL) throws {
        try save(document, to: url, fileManager: .default, writeAtomically: atomicWrite)
    }

    fileprivate static func bytes(at url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw PaddrError.configuration("Profile storage path is not a regular file: \(url.path).")
        }
        return try Data(contentsOf: url)
    }

    /// A persistent, directory-scoped advisory lock survives atomic file replacement
    /// and filename aliases (including case/Unicode variants). Do not unlink this lock.
    static func withStorageLock<T>(for url: URL, _ operation: () throws -> T) throws -> T {
        let directory = url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lockPath = directory.appendingPathComponent(".paddr-profiles.lock").path
        let descriptor = Darwin.open(lockPath, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else {
            throw PaddrError.configuration("Could not open profile storage lock: \(String(cString: strerror(errno))).")
        }
        defer { Darwin.close(descriptor) }
        while flock(descriptor, LOCK_EX) != 0 {
            if errno == EINTR { continue }
            throw PaddrError.configuration("Could not lock profile storage: \(String(cString: strerror(errno))).")
        }
        defer { _ = flock(descriptor, LOCK_UN) }
        return try operation()
    }

    public static func encoded(_ document: ConfigurationProfileDocument) throws -> Data {
        let validated = try document.validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(validated) + Data("\n".utf8)
    }

    static func load(
        from url: URL?,
        fileManager: FileManager,
        homeDirectory: URL,
        writeAtomically: (_ data: Data, _ destination: URL) throws -> Void
    ) throws -> ConfigurationProfileLoadResult {
        let destination = url ?? homeDirectory.appendingPathComponent(".config/Paddr/config.json")
        let candidate = url ?? ConfigurationStore.defaultCandidateURL(
            fileManager: fileManager,
            homeDirectory: homeDirectory
        )
        guard fileManager.fileExists(atPath: candidate.path) else {
            return ConfigurationProfileLoadResult(document: .default)
        }

        let data: Data
        do {
            let values = try candidate.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else {
                throw PaddrError.configuration(
                    "Profile storage path is not a regular file: \(candidate.path)."
                )
            }
            data = try Data(contentsOf: candidate)
        } catch let error as PaddrError {
            throw error
        } catch {
            throw PaddrError.configuration(
                "Could not read profile storage at \(candidate.path): \(error)"
            )
        }

        do {
            if try isProfileDocument(data) {
                let decoded = try JSONDecoder().decode(ConfigurationProfileDocument.self, from: data)
                let repaired = try decoded.validated(repairingMissingActiveProfile: true)
                let diagnostic: String? = repaired.activeProfileID == decoded.activeProfileID
                    ? nil
                    : "The saved active profile ID \(decoded.activeProfileID.rawValue) was missing. Default is active; user profiles were preserved."
                return ConfigurationProfileLoadResult(document: repaired, diagnostic: diagnostic)
            }

            let legacy = try decodeLegacyConfiguration(data)
            var migrated = ConfigurationProfileDocument.default
            if legacy == PaddrConfiguration.formerCoupledDefault {
                migrated.builtInDefaultCenterTapTrackingMode = .coupled
            } else if legacy != .default {
                let previous = try migrated.createProfile(
                    named: "Previous configuration",
                    configuration: legacy
                )
                migrated.activeProfileID = previous.id
            }
            do {
                try fileManager.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try writeAtomically(try encoded(migrated), destination)
            } catch {
                throw PaddrError.configuration(
                    "Could not migrate configuration to profiles at \(destination.path). The original file at \(candidate.path) was preserved: \(error)"
                )
            }
            return ConfigurationProfileLoadResult(document: migrated)
        } catch let error as PaddrError {
            throw error
        } catch {
            throw PaddrError.configuration(
                "Could not load profile storage at \(candidate.path): \(error)"
            )
        }
    }

    static func save(
        _ document: ConfigurationProfileDocument,
        to destination: URL,
        fileManager: FileManager,
        writeAtomically: (_ data: Data, _ destination: URL) throws -> Void
    ) throws {
        do {
            let data = try encoded(document)
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try writeAtomically(data, destination)
        } catch let error as PaddrError {
            throw error
        } catch {
            throw PaddrError.configuration(
                "Could not save profiles at \(destination.path): \(error)"
            )
        }
    }

    static func decodeConfiguration(from data: Data) throws -> PaddrConfiguration {
        try decodeConfigurationInput(from: data).configuration
    }

    static func decodeConfigurationInput(
        from data: Data
    ) throws -> (
        configuration: PaddrConfiguration,
        profileDocument: ConfigurationProfileDocument?
    ) {
        if try isProfileDocument(data) {
            let document = try JSONDecoder().decode(ConfigurationProfileDocument.self, from: data)
            let validated = try document.validated()
            guard let active = validated.activeProfile else {
                throw PaddrError.configuration("The active profile does not exist.")
            }
            return (active.configuration, validated)
        }
        return (try decodeLegacyConfiguration(data), nil)
    }

    static func isProfileDocument(_ data: Data) throws -> Bool {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PaddrError.configuration("Configuration JSON must contain an object.")
        }
        return object["schemaVersion"] != nil
            || object["activeProfileID"] != nil
            || object["userProfiles"] != nil
    }

    private static func decodeLegacyConfiguration(_ data: Data) throws -> PaddrConfiguration {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["left"] != nil || object["right"] != nil || object["rearButtons"] != nil else {
            throw PaddrError.configuration(
                "Configuration JSON is neither a profile document nor a raw left/right/rearButtons configuration."
            )
        }
        return try JSONDecoder().decode(PaddrConfiguration.self, from: data).validated()
    }

    private static func atomicWrite(_ data: Data, _ destination: URL) throws {
        try data.write(to: destination, options: .atomic)
    }
}

/// Retains the exact storage version read by one GUI/CLI client. A commit compares and
/// replaces while holding the same interprocess lock; failed commits keep its baseline.
/// This is intentionally not an automatic merge: drafts and external profiles stay intact.
public final class ConfigurationProfileStoreClient: Sendable {
    private enum Version: Sendable {
        case notLoaded
        case loaded(Data?)
    }
    private let version = Mutex<Version>(.notLoaded)
    private let explicitURL: URL?
    public let url: URL

    public init(url: URL? = nil) {
        explicitURL = url
        self.url = url ?? ConfigurationProfileStore.defaultURL
    }

    public func load() throws -> ConfigurationProfileLoadResult {
        try version.withLock { version in
            version = .notLoaded
            return try ConfigurationProfileStore.withStorageLock(for: url) {
                let result = try ConfigurationProfileStore.loadUnlocked(from: explicitURL)
                version = .loaded(try ConfigurationProfileStore.bytes(at: url))
                return result
            }
        }
    }

    /// Compatibility input is read once, without migration or rewriting its source.
    package func loadInput() throws -> (configuration: PaddrConfiguration, profileDocument: ConfigurationProfileDocument?) {
        try version.withLock { version in
            version = .notLoaded
            // A compatibility read must also work in a read-only directory. One atomic
            // file read supplies both the decoded document and its comparison baseline.
            guard let bytes = try ConfigurationProfileStore.bytes(at: url) else {
                throw PaddrError.configuration("Configuration file does not exist at \(url.path).")
            }
            let result = try ConfigurationProfileStore.decodeConfigurationInput(from: bytes)
            version = .loaded(bytes)
            return result
        }
    }

    /// An explicit destination is a deliberate export/replacement. The source baseline
    /// is checked under the destination lock. In-place writes and directory/name aliases
    /// share that lock. Distinct exports deliberately replace only their destination.
    public func save(_ document: ConfigurationProfileDocument, to exportDestination: URL? = nil) throws {
        try version.withLock { version in
            guard case let .loaded(expected) = version else {
                throw PaddrError.configuration("Load profile storage before saving changes.")
            }
            let destination = exportDestination ?? url
            try ConfigurationProfileStore.withStorageLock(for: destination) {
                guard try ConfigurationProfileStore.bytes(at: url) == expected else {
                    throw PaddrError.configuration(
                        "Profile storage changed in another app or CLI process. Your changes have not been saved. "
                            + "Keep a copy of your edits, then reopen Paddr or rerun the CLI to load the current profiles."
                    )
                }
                try ConfigurationProfileStore.saveUnlocked(document, to: destination)
                // An explicit export consumes its snapshot. Never adopt a later source
                // version without also loading that version's document.
                version = exportDestination == nil
                    ? .loaded(try ConfigurationProfileStore.encoded(document))
                    : .notLoaded
            }
        }
    }
}

import Foundation
import SwiftKey

/// An in-memory auth session store.
public actor SwiftRestMemorySessionStore: SwiftRestSessionStore {
    private var session: SwiftRestAuthSession?

    public init(session: SwiftRestAuthSession? = nil) {
        self.session = session
    }

    public func load() async throws -> SwiftRestAuthSession? {
        session
    }

    public func save(_ session: SwiftRestAuthSession) async throws {
        self.session = session.isEmpty ? nil : session
    }

    public func clear() async throws {
        session = nil
    }
}

/// A `UserDefaults` backed auth session store.
public final class SwiftRestDefaultsSessionStore: SwiftRestSessionStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "SwiftRestDefaultsSessionStore")

    public init(defaults: UserDefaults = .standard, key: String = "SwiftRest.auth.session") {
        self.defaults = defaults
        self.key = key
    }

    public func load() async throws -> SwiftRestAuthSession? {
        return try queue.sync {
            guard let data = defaults.data(forKey: key) else {
                return nil
            }
            return try decoder.decode(SwiftRestAuthSession.self, from: data)
        }
    }

    public func save(_ session: SwiftRestAuthSession) async throws {
        try queue.sync {
            if session.isEmpty {
                defaults.removeObject(forKey: key)
                return
            }

            let data = try encoder.encode(session)
            defaults.set(data, forKey: key)
        }
    }

    public func clear() async throws {
        queue.sync {
            defaults.removeObject(forKey: key)
        }
    }
}

/// A no-op auth session store.
public actor SwiftRestNullSessionStore: SwiftRestSessionStore {
    public init() {}

    public func load() async throws -> SwiftRestAuthSession? {
        nil
    }

    public func save(_ session: SwiftRestAuthSession) async throws {
        _ = session
    }

    public func clear() async throws {}
}

/// A Keychain-backed auth session store using SwiftKey.
public actor SwiftRestKeychainSessionStore: SwiftRestSessionStore {
    private let keychain: SwiftKey.Beginner
    private let key: String

    public init(
        service: String? = nil,
        key: String = "SwiftRest.auth.session"
    ) {
        let configuration = SwiftKeyConfiguration(service: service ?? SwiftKey.defaultService)
        self.keychain = SwiftKey.Beginner(store: SwiftKey(configuration: configuration))
        self.key = key
    }

    public func load() async throws -> SwiftRestAuthSession? {
        let session = keychain.getModel(key, as: SwiftRestAuthSession.self)
        if session == nil, let message = keychain.lastErrorMessage {
            throw SwiftRestClientError.authSessionStoreFailed(
                underlying: ErrorContext(description: message)
            )
        }
        return session
    }

    public func save(_ session: SwiftRestAuthSession) async throws {
        if session.isEmpty {
            _ = keychain.remove(key)
            return
        }

        guard keychain.setModel(key, session) else {
            throw SwiftRestClientError.authSessionStoreFailed(
                underlying: ErrorContext(
                    description: keychain.lastErrorMessage ?? "Unable to save auth session."
                )
            )
        }
    }

    public func clear() async throws {
        guard keychain.remove(key) || keychain.lastErrorMessage == nil else {
            throw SwiftRestClientError.authSessionStoreFailed(
                underlying: ErrorContext(
                    description: keychain.lastErrorMessage ?? "Unable to clear auth session."
                )
            )
        }
    }
}

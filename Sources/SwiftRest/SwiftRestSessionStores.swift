import Foundation
import Security

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

/// A Keychain-backed auth session store.
public actor SwiftRestKeychainSessionStore: SwiftRestSessionStore {
    private let service: String
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        service: String? = nil,
        key: String = "SwiftRest.auth.session"
    ) {
        self.service = service ?? Bundle.main.bundleIdentifier ?? "SwiftRest"
        self.key = key
    }

    public func load() async throws -> SwiftRestAuthSession? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw storeFailure(
                    error: NSError(
                        domain: "SwiftRestKeychainSessionStore",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Keychain returned data in an unexpected format."]
                    )
                )
            }

            do {
                return try decoder.decode(SwiftRestAuthSession.self, from: data)
            } catch {
                throw storeFailure(error: error)
            }

        case errSecItemNotFound:
            return nil

        default:
            throw storeFailure(status: status, operation: "load")
        }
    }

    public func save(_ session: SwiftRestAuthSession) async throws {
        if session.isEmpty {
            try await clear()
            return
        }

        let data = try encoder.encode(session)
        var addQuery = baseQuery()
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }

        guard addStatus == errSecDuplicateItem else {
            throw storeFailure(status: addStatus, operation: "save")
        }

        let updateStatus = SecItemUpdate(
            baseQuery() as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        guard updateStatus == errSecSuccess else {
            throw storeFailure(status: updateStatus, operation: "update")
        }
    }

    public func clear() async throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw storeFailure(status: status, operation: "clear")
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }

    private func storeFailure(status: OSStatus, operation: String) -> SwiftRestClientError {
        let description = keychainMessage(for: status, operation: operation)
        return .authSessionStoreFailed(underlying: ErrorContext(description: description))
    }

    private func storeFailure(error: Error) -> SwiftRestClientError {
        .authSessionStoreFailed(underlying: ErrorContext(error))
    }

    private func keychainMessage(for status: OSStatus, operation: String) -> String {
        let message = SecCopyErrorMessageString(status, nil) as String?
        let statusText = message ?? "OSStatus \(status)"
        return "Keychain \(operation) failed: \(statusText)"
    }
}

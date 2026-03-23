import Foundation

/// Defines how SwiftRest auth responses should expose token values.
public enum SwiftRestAuthValueSource: Sendable, Equatable {
    /// Read the token from a top-level JSON field.
    case bodyField(String)
    /// Read the token from a response header.
    case header(String)
    /// Do not read a token for this value.
    case none
}

struct SwiftRestAuthSettings: Sendable {
    var tokenSource: SwiftRestAuthValueSource = .bodyField("accessToken")
    var refreshTokenSource: SwiftRestAuthValueSource = .none
    var refreshEndpoint: String? = nil
    var refreshMethod: HTTPMethod = .post
    var refreshRequestField: String = "refreshToken"
    var refreshHeaders: [String: String] = [:]
    var triggerStatusCodes: Set<Int> = [401]
}

/// Entry point for beginner-friendly auth/session setup.
public extension SwiftRest {
    /// Creates a plain client from a `URL` without throwing.
    static func client(
        baseURL: URL,
        config: SwiftRestConfig = .standard,
        session: URLSession = .shared
    ) -> SwiftRestClient {
        SwiftRestClient(baseURL: baseURL, config: config, session: session)
    }

    /// Creates an auth/session builder from a `URL` without throwing.
    static func auth(
        baseURL: URL,
        config: SwiftRestConfig = .standard,
        session: URLSession = .shared
    ) -> SwiftRestAuthBuilder {
        SwiftRestAuthBuilder(baseURL: baseURL, config: config, session: session)
    }
}

/// Builder for the beginner-friendly auth/session wrapper.
public struct SwiftRestAuthBuilder: Sendable {
    private var baseURL: URL
    private var config: SwiftRestConfig
    private var session: URLSession
    private var sessionStore: any SwiftRestSessionStore
    private var settings: SwiftRestAuthSettings

    init(
        baseURL: URL,
        config: SwiftRestConfig = .standard,
        session: URLSession = .shared,
        sessionStore: any SwiftRestSessionStore = SwiftRestKeychainSessionStore()
    ) {
        self.baseURL = baseURL
        self.config = config
        self.session = session
        self.sessionStore = sessionStore
        self.settings = SwiftRestAuthSettings()
    }

    /// Sets a default header for every request.
    public func header(_ name: String, _ value: String) -> Self {
        var copy = self
        var headers = copy.config.baseHeaders
        headers.set(value, for: name)
        copy.config.baseHeaders = headers
        return copy
    }

    /// Sets default headers for every request.
    public func headers(_ values: [String: String]) -> Self {
        var copy = self
        var headers = copy.config.baseHeaders
        for (key, value) in values {
            headers.set(value, for: key)
        }
        copy.config.baseHeaders = headers
        return copy
    }

    /// Sets the JSON coding strategy used by the auth client.
    public func json(_ coding: SwiftRestJSONCoding) -> Self {
        var copy = self
        copy.config = copy.config.jsonCoding(coding)
        return copy
    }

    /// Sets the date coding preset used by the auth client.
    public func jsonDates(_ dates: SwiftRestJSONDates) -> Self {
        var copy = self
        copy.config = copy.config
            .dateDecodingStrategy(dates.decodingStrategy)
            .dateEncodingStrategy(dates.encodingStrategy)
        return copy
    }

    /// Sets the key coding preset used by the auth client.
    public func jsonKeys(_ keys: SwiftRestJSONKeys) -> Self {
        var copy = self
        copy.config = copy.config
            .keyDecodingStrategy(keys.decodingStrategy)
            .keyEncodingStrategy(keys.encodingStrategy)
        return copy
    }

    /// Sets the retry policy used by the auth client.
    public func retry(_ policy: RetryPolicy) -> Self {
        var copy = self
        copy.config.retryPolicy = policy
        return copy
    }

    /// Sets the request timeout in seconds.
    public func timeout(_ seconds: TimeInterval) -> Self {
        var copy = self
        copy.config.timeout = max(0.1, seconds)
        return copy
    }

    /// Sets the debug logging mode.
    public func logging(_ logging: SwiftRestDebugLogging) -> Self {
        var copy = self
        copy.config = copy.config.debugLogging(logging)
        return copy
    }

    /// Enables/disables basic debug logging.
    public func logging(_ enabled: Bool) -> Self {
        logging(enabled ? .basic : .disabled)
    }

    /// Overrides the `URLSession` used by the auth client.
    ///
    /// Useful for tests and custom networking configuration.
    public func session(_ session: URLSession) -> Self {
        var copy = self
        copy.session = session
        return copy
    }

    /// Uses the Keychain store backed by SwiftKey.
    public func keychain(
        service: String? = nil,
        key: String = "SwiftRest.auth.session"
    ) -> Self {
        var copy = self
        copy.sessionStore = SwiftRestKeychainSessionStore(service: service, key: key)
        return copy
    }

    /// Uses `UserDefaults` for storage.
    public func defaults(
        _ userDefaults: UserDefaults = .standard,
        key: String = "SwiftRest.auth.session"
    ) -> Self {
        var copy = self
        copy.sessionStore = SwiftRestDefaultsSessionStore(defaults: userDefaults, key: key)
        return copy
    }

    /// Uses in-memory storage.
    public func memory(session: SwiftRestAuthSession? = nil) -> Self {
        var copy = self
        copy.sessionStore = SwiftRestMemorySessionStore(session: session)
        return copy
    }

    /// Disables persistence entirely.
    public func none() -> Self {
        var copy = self
        copy.sessionStore = SwiftRestNullSessionStore()
        return copy
    }

    /// Uses a custom session store.
    public func store(_ store: some SwiftRestSessionStore) -> Self {
        var copy = self
        copy.sessionStore = store
        return copy
    }

    /// Reads the primary token from a top-level JSON field.
    public func tokenField(_ field: String) -> Self {
        tokenSource(.bodyField(field))
    }

    /// Reads the primary token from a response header.
    public func tokenHeader(_ header: String) -> Self {
        tokenSource(.header(header))
    }

    /// Uses a custom source for the primary token.
    public func tokenSource(_ source: SwiftRestAuthValueSource) -> Self {
        var copy = self
        copy.settings.tokenSource = source
        return copy
    }

    /// Reads the refresh token from a top-level JSON field.
    public func refreshTokenField(_ field: String) -> Self {
        refreshTokenSource(.bodyField(field))
    }

    /// Reads the refresh token from a response header.
    public func refreshTokenHeader(_ header: String) -> Self {
        refreshTokenSource(.header(header))
    }

    /// Uses a custom source for the refresh token.
    public func refreshTokenSource(_ source: SwiftRestAuthValueSource) -> Self {
        var copy = self
        copy.settings.refreshTokenSource = source
        return copy
    }

    /// Enables `401 -> refresh -> retry once` auth recovery.
    public func refresh(
        endpoint: String,
        method: HTTPMethod = .post,
        requestRefreshField: String = "refreshToken",
        triggerStatusCodes: Set<Int> = [401],
        headers: [String: String] = [:]
    ) -> Self {
        var copy = self
        copy.settings.refreshEndpoint = endpoint
        copy.settings.refreshMethod = method
        copy.settings.refreshRequestField = requestRefreshField
        copy.settings.triggerStatusCodes = Self.normalizedTriggerStatusCodes(triggerStatusCodes)
        copy.settings.refreshHeaders = headers
        return copy
    }

    /// Final auth/session client.
    public var client: SwiftRestAuthClient {
        SwiftRestAuthClient(
            baseClient: SwiftRestClient(baseURL: baseURL, config: config, session: session),
            config: config,
            sessionStore: sessionStore,
            settings: settings
        )
    }

    private static func normalizedTriggerStatusCodes(_ statusCodes: Set<Int>) -> Set<Int> {
        let valid = statusCodes.filter { (100...599).contains($0) }
        return valid.isEmpty ? [401] : valid
    }
}

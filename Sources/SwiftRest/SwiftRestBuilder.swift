import Foundation

/// Entry point for chain-based SwiftRest client setup.
public enum SwiftRest {
    /// Starts a chain-based client configuration for the provided base URL.
    public static func `for`(_ baseURL: String) -> SwiftRestBuilder {
        SwiftRestBuilder(baseURL: baseURL)
    }
}

/// Chainable builder for creating `SwiftRestClient`.
public struct SwiftRestBuilder: Sendable {
    private var baseURL: String
    private var config: SwiftRestConfig
    private var session: URLSession

    init(
        baseURL: String,
        config: SwiftRestConfig = .standard,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.config = config
        self.session = session
    }

    /// Sets a static bearer token used by default requests.
    ///
    /// Use `accessTokenProvider` when tokens change over time.
    public func accessToken(_ token: String?) -> Self {
        var copy = self
        copy.config = copy.config.accessToken(token)
        return copy
    }

    /// Sets an async token provider resolved per request.
    ///
    /// Common for actor-backed session stores and Keychain reads.
    public func accessTokenProvider(
        _ provider: SwiftRestAccessTokenProvider?
    ) -> Self {
        var copy = self
        copy.config = copy.config.accessTokenProvider(provider)
        return copy
    }

    /// Enables auth refresh using a pre-built refresh configuration.
    public func autoRefresh(_ refresh: SwiftRestAuthRefresh) -> Self {
        var copy = self
        copy.config = copy.config.authRefresh(refresh)
        return copy
    }

    /// Enables endpoint-based auth refresh.
    ///
    /// Use this for the beginner-friendly `401 -> refresh -> retry once` flow.
    public func autoRefresh(
        endpoint: String,
        method: HTTPMethod = .post,
        refreshTokenProvider: @escaping SwiftRestRefreshTokenProvider,
        refreshTokenField: String = "refreshToken",
        tokenField: String = "accessToken",
        refreshTokenResponseField: String? = nil,
        onTokensRefreshed: SwiftRestTokensRefreshedHandler? = nil,
        triggerStatusCodes: Set<Int> = [401],
        headers: [String: String] = [:]
    ) -> Self {
        autoRefresh(
            .endpoint(
                endpoint,
                method: method,
                refreshTokenProvider: refreshTokenProvider,
                refreshTokenField: refreshTokenField,
                tokenField: tokenField,
                refreshTokenResponseField: refreshTokenResponseField,
                onTokensRefreshed: onTokensRefreshed,
                triggerStatusCodes: triggerStatusCodes,
                headers: headers
            )
        )
    }

    /// Enables custom refresh logic with a bypass refresh context.
    public func autoRefreshCustom(
        _ handler: @escaping SwiftRestCustomRefreshHandler
    ) -> Self {
        autoRefresh(.custom(handler))
    }

    /// Sets the full JSON coding strategy for all requests.
    public func json(_ coding: SwiftRestJSONCoding) -> Self {
        var copy = self
        copy.config = copy.config.jsonCoding(coding)
        return copy
    }

    /// Sets simplified date coding behavior for all requests.
    public func jsonDates(_ dates: SwiftRestJSONDates) -> Self {
        var copy = self
        copy.config = copy.config
            .dateDecodingStrategy(dates.decodingStrategy)
            .dateEncodingStrategy(dates.encodingStrategy)
        return copy
    }

    /// Sets simplified key coding behavior for all requests.
    public func jsonKeys(_ keys: SwiftRestJSONKeys) -> Self {
        var copy = self
        copy.config = copy.config
            .keyDecodingStrategy(keys.decodingStrategy)
            .keyEncodingStrategy(keys.encodingStrategy)
        return copy
    }

    /// Sets the default retry policy for requests without a per-request override.
    public func retry(_ policy: RetryPolicy) -> Self {
        var copy = self
        copy.config.retryPolicy = policy
        return copy
    }

    /// Sets the request timeout (seconds). Minimum applied timeout is `0.1`.
    public func timeout(_ seconds: TimeInterval) -> Self {
        var copy = self
        copy.config.timeout = max(0.1, seconds)
        return copy
    }

    /// Adds/overwrites a default header for every request.
    public func header(_ name: String, _ value: String) -> Self {
        var copy = self
        var headers = copy.config.baseHeaders
        headers.set(value, for: name)
        copy.config.baseHeaders = headers
        return copy
    }

    /// Adds/overwrites multiple default headers for every request.
    public func headers(_ values: [String: String]) -> Self {
        var copy = self
        var headers = copy.config.baseHeaders
        for (key, value) in values {
            headers.set(value, for: key)
        }
        copy.config.baseHeaders = headers
        return copy
    }

    /// Sets debug logging mode.
    public func logging(_ logging: SwiftRestDebugLogging) -> Self {
        var copy = self
        copy.config = copy.config.debugLogging(logging)
        return copy
    }

    /// Enables/disables basic debug logging.
    public func logging(_ enabled: Bool) -> Self {
        logging(enabled ? .basic : .disabled)
    }

    /// Overrides the `URLSession` used by the client.
    ///
    /// Useful for tests and custom networking configuration.
    public func session(_ session: URLSession) -> Self {
        var copy = self
        copy.session = session
        return copy
    }

    /// Final built client.
    public var client: SwiftRestClient {
        get throws {
            try SwiftRestClient(baseURL, config: config, session: session)
        }
    }
}

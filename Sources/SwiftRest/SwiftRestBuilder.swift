import Foundation

/// Entry point for chain-based SwiftRest client setup.
public enum SwiftRest {
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

    public func accessToken(_ token: String?) -> Self {
        var copy = self
        copy.config = copy.config.accessToken(token)
        return copy
    }

    public func accessTokenProvider(
        _ provider: SwiftRestAccessTokenProvider?
    ) -> Self {
        var copy = self
        copy.config = copy.config.accessTokenProvider(provider)
        return copy
    }

    public func autoRefresh(_ refresh: SwiftRestAuthRefresh) -> Self {
        var copy = self
        copy.config = copy.config.authRefresh(refresh)
        return copy
    }

    public func autoRefresh(
        endpoint: String,
        method: HTTPMethod = .post,
        refreshTokenProvider: @escaping SwiftRestRefreshTokenProvider,
        refreshTokenField: String = "refreshToken",
        tokenField: String = "accessToken",
        refreshTokenResponseField: String? = nil,
        onTokensRefreshed: SwiftRestTokensRefreshedHandler? = nil,
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
                headers: headers
            )
        )
    }

    public func autoRefreshCustom(
        _ handler: @escaping SwiftRestCustomRefreshHandler
    ) -> Self {
        autoRefresh(.custom(handler))
    }

    public func json(_ coding: SwiftRestJSONCoding) -> Self {
        var copy = self
        copy.config = copy.config.jsonCoding(coding)
        return copy
    }

    public func jsonDates(_ dates: SwiftRestJSONDates) -> Self {
        var copy = self
        copy.config = copy.config
            .dateDecodingStrategy(dates.decodingStrategy)
            .dateEncodingStrategy(dates.encodingStrategy)
        return copy
    }

    public func jsonKeys(_ keys: SwiftRestJSONKeys) -> Self {
        var copy = self
        copy.config = copy.config
            .keyDecodingStrategy(keys.decodingStrategy)
            .keyEncodingStrategy(keys.encodingStrategy)
        return copy
    }

    public func retry(_ policy: RetryPolicy) -> Self {
        var copy = self
        copy.config.retryPolicy = policy
        return copy
    }

    public func timeout(_ seconds: TimeInterval) -> Self {
        var copy = self
        copy.config.timeout = max(0.1, seconds)
        return copy
    }

    public func header(_ name: String, _ value: String) -> Self {
        var copy = self
        var headers = copy.config.baseHeaders
        headers.set(value, for: name)
        copy.config.baseHeaders = headers
        return copy
    }

    public func headers(_ values: [String: String]) -> Self {
        var copy = self
        var headers = copy.config.baseHeaders
        for (key, value) in values {
            headers.set(value, for: key)
        }
        copy.config.baseHeaders = headers
        return copy
    }

    public func logging(_ logging: SwiftRestDebugLogging) -> Self {
        var copy = self
        copy.config = copy.config.debugLogging(logging)
        return copy
    }

    public func logging(_ enabled: Bool) -> Self {
        logging(enabled ? .basic : .disabled)
    }

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

import Foundation

/// Async provider used to resolve an access token at request time.
public typealias SwiftRestAccessTokenProvider = @Sendable () async throws -> String?

/// Defines retry behavior for transient failures.
public struct RetryPolicy: Sendable {
    /// Maximum number of total attempts, including the first request.
    public var maxAttempts: Int

    /// Base delay in seconds used before the first retry.
    public var baseDelay: TimeInterval

    /// Exponential factor applied after each retry.
    public var backoffMultiplier: Double

    /// Maximum delay cap in seconds.
    public var maxDelay: TimeInterval

    /// HTTP status codes considered retryable.
    public var retryableStatusCodes: Set<Int>

    /// If `true`, network transport errors are retryable.
    public var retryOnNetworkErrors: Bool

    public init(
        maxAttempts: Int = 1,
        baseDelay: TimeInterval = 0,
        backoffMultiplier: Double = 2,
        maxDelay: TimeInterval = 30,
        retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504],
        retryOnNetworkErrors: Bool = true
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelay = max(0, baseDelay)
        self.backoffMultiplier = max(1, backoffMultiplier)
        self.maxDelay = max(0, maxDelay)
        self.retryableStatusCodes = retryableStatusCodes
        self.retryOnNetworkErrors = retryOnNetworkErrors
    }

    /// No retries.
    public static let none = RetryPolicy(maxAttempts: 1, baseDelay: 0)

    /// Recommended default retries for common transient failures.
    public static let standard = RetryPolicy(maxAttempts: 3, baseDelay: 0.5)
}

/// Shared client configuration.
public struct SwiftRestConfig: Sendable {
    /// Headers added to every request.
    public var baseHeaders: HTTPHeaders

    /// Request timeout interval in seconds.
    public var timeout: TimeInterval

    /// Default retry policy when a request does not override retries.
    public var retryPolicy: RetryPolicy

    /// Default JSON encoding/decoding behavior.
    public var jsonCoding: SwiftRestJSONCoding

    /// Optional global bearer token used when a request does not provide one.
    public var accessToken: String?

    /// Optional provider to resolve bearer token dynamically per request.
    public var accessTokenProvider: SwiftRestAccessTokenProvider?

    /// Optional request/response debug logging.
    public var debugLogging: SwiftRestDebugLogging

    /// Optional auth refresh behavior on unauthorized responses.
    public var authRefresh: SwiftRestAuthRefresh

    public init(
        baseHeaders: HTTPHeaders = HTTPHeaders(),
        timeout: TimeInterval = 30,
        retryPolicy: RetryPolicy = .none,
        jsonCoding: SwiftRestJSONCoding = .foundationDefault,
        accessToken: String? = nil,
        accessTokenProvider: SwiftRestAccessTokenProvider? = nil,
        debugLogging: SwiftRestDebugLogging = .disabled,
        authRefresh: SwiftRestAuthRefresh = .disabled
    ) {
        self.baseHeaders = baseHeaders
        self.timeout = max(0.1, timeout)
        self.retryPolicy = retryPolicy
        self.jsonCoding = jsonCoding
        self.accessToken = accessToken
        self.accessTokenProvider = accessTokenProvider
        self.debugLogging = debugLogging
        self.authRefresh = authRefresh
    }

    /// Recommended default profile for most apps.
    ///
    /// Includes:
    /// - `Accept: application/json`
    /// - `timeout = 30` seconds
    /// - `RetryPolicy.standard`
    public static let standard = SwiftRestConfig(
        baseHeaders: ["accept": "application/json"],
        timeout: 30,
        retryPolicy: .standard,
        jsonCoding: .foundationDefault
    )

    /// Alias for `standard`.
    public static let `default` = standard

    /// Convenient preset for APIs that use snake_case keys and ISO8601 dates.
    public static let webAPI = SwiftRestConfig(
        baseHeaders: ["accept": "application/json"],
        timeout: 30,
        retryPolicy: .standard,
        jsonCoding: .webAPI
    )

    public func jsonCoding(_ coding: SwiftRestJSONCoding) -> Self {
        var copy = self
        copy.jsonCoding = coding
        return copy
    }

    public func dateDecodingStrategy(
        _ strategy: SwiftRestJSONCoding.DateDecodingStrategy
    ) -> Self {
        var copy = self
        copy.jsonCoding = copy.jsonCoding.dateDecodingStrategy(strategy)
        return copy
    }

    public func dateEncodingStrategy(
        _ strategy: SwiftRestJSONCoding.DateEncodingStrategy
    ) -> Self {
        var copy = self
        copy.jsonCoding = copy.jsonCoding.dateEncodingStrategy(strategy)
        return copy
    }

    public func keyDecodingStrategy(
        _ strategy: SwiftRestJSONCoding.KeyDecodingStrategy
    ) -> Self {
        var copy = self
        copy.jsonCoding = copy.jsonCoding.keyDecodingStrategy(strategy)
        return copy
    }

    public func keyEncodingStrategy(
        _ strategy: SwiftRestJSONCoding.KeyEncodingStrategy
    ) -> Self {
        var copy = self
        copy.jsonCoding = copy.jsonCoding.keyEncodingStrategy(strategy)
        return copy
    }

    public func accessToken(_ token: String?) -> Self {
        var copy = self
        copy.accessToken = token
        return copy
    }

    public func accessTokenProvider(_ provider: SwiftRestAccessTokenProvider?) -> Self {
        var copy = self
        copy.accessTokenProvider = provider
        return copy
    }

    public func debugLogging(_ logging: SwiftRestDebugLogging) -> Self {
        var copy = self
        copy.debugLogging = logging
        return copy
    }

    public func debugLogging(_ enabled: Bool) -> Self {
        var copy = self
        copy.debugLogging = enabled ? .basic : .disabled
        return copy
    }

    public func authRefresh(_ refresh: SwiftRestAuthRefresh) -> Self {
        var copy = self
        copy.authRefresh = refresh
        return copy
    }
}

/// Source-level version marker for this release line.
public enum SwiftRestVersion {
    public static let current = "4.2.0"
}

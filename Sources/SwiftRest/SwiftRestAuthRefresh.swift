import Foundation

/// Async provider used to return the current refresh token.
public typealias SwiftRestRefreshTokenProvider = @Sendable () async throws -> String?

/// Advanced refresh callback for power users.
///
/// Receives a bypass context that does not use normal auth middleware.
public typealias SwiftRestCustomRefreshHandler = @Sendable (SwiftRestRefreshContext) async throws -> String?

/// Endpoint-driven refresh settings for beginner-friendly setup.
public struct SwiftRestAuthRefreshEndpoint: Sendable {
    public var endpoint: String
    public var method: HTTPMethod
    public var refreshTokenProvider: SwiftRestRefreshTokenProvider
    public var refreshTokenField: String
    public var tokenField: String
    public var headers: [String: String]

    public init(
        endpoint: String,
        method: HTTPMethod = .post,
        refreshTokenProvider: @escaping SwiftRestRefreshTokenProvider,
        refreshTokenField: String = "refreshToken",
        tokenField: String = "accessToken",
        headers: [String: String] = [:]
    ) {
        self.endpoint = endpoint
        self.method = method
        self.refreshTokenProvider = refreshTokenProvider
        self.refreshTokenField = refreshTokenField
        self.tokenField = tokenField
        self.headers = headers
    }
}

/// Defines how auth refresh should resolve a new access token.
public enum SwiftRestAuthRefreshMode: Sendable {
    case disabled
    case endpoint(SwiftRestAuthRefreshEndpoint)
    case custom(SwiftRestCustomRefreshHandler)
}

/// Configuration for automatic auth refresh (`401` -> refresh token -> retry once).
public struct SwiftRestAuthRefresh: Sendable {
    /// Refresh strategy.
    public var mode: SwiftRestAuthRefreshMode

    /// If `true`, requests with explicit per-request `authToken` can also trigger refresh.
    ///
    /// Default is `false` so one-off request tokens stay isolated.
    public var appliesToPerRequestToken: Bool

    public init(
        mode: SwiftRestAuthRefreshMode,
        appliesToPerRequestToken: Bool = false
    ) {
        self.mode = mode
        self.appliesToPerRequestToken = appliesToPerRequestToken
    }

    /// Disabled refresh behavior.
    public static let disabled = SwiftRestAuthRefresh(
        mode: .disabled,
        appliesToPerRequestToken: false
    )

    /// Beginner-friendly endpoint mode.
    public static func endpoint(
        _ endpoint: String,
        method: HTTPMethod = .post,
        refreshTokenProvider: @escaping SwiftRestRefreshTokenProvider,
        refreshTokenField: String = "refreshToken",
        tokenField: String = "accessToken",
        headers: [String: String] = [:]
    ) -> Self {
        SwiftRestAuthRefresh(
            mode: .endpoint(
                SwiftRestAuthRefreshEndpoint(
                    endpoint: endpoint,
                    method: method,
                    refreshTokenProvider: refreshTokenProvider,
                    refreshTokenField: refreshTokenField,
                    tokenField: tokenField,
                    headers: headers
                )
            )
        )
    }

    /// Advanced custom mode.
    public static func custom(
        _ handler: @escaping SwiftRestCustomRefreshHandler
    ) -> Self {
        SwiftRestAuthRefresh(
            mode: .custom(handler)
        )
    }

    public func appliesToPerRequestToken(_ applies: Bool) -> Self {
        var copy = self
        copy.appliesToPerRequestToken = applies
        return copy
    }

    public var isEnabled: Bool {
        switch mode {
        case .disabled:
            return false
        case .endpoint, .custom:
            return true
        }
    }
}

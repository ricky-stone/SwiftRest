import Foundation

/// Async provider used to return the current refresh token.
public typealias SwiftRestRefreshTokenProvider = @Sendable () async throws -> String?

/// Optional callback invoked after endpoint refresh resolves new token values.
public typealias SwiftRestTokensRefreshedHandler = @Sendable (
    _ accessToken: String,
    _ refreshToken: String?
) async throws -> Void

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
    public var refreshTokenResponseField: String?
    public var onTokensRefreshed: SwiftRestTokensRefreshedHandler?
    public var headers: [String: String]

    public init(
        endpoint: String,
        method: HTTPMethod = .post,
        refreshTokenProvider: @escaping SwiftRestRefreshTokenProvider,
        refreshTokenField: String = "refreshToken",
        tokenField: String = "accessToken",
        refreshTokenResponseField: String? = nil,
        onTokensRefreshed: SwiftRestTokensRefreshedHandler? = nil,
        headers: [String: String] = [:]
    ) {
        self.endpoint = endpoint
        self.method = method
        self.refreshTokenProvider = refreshTokenProvider
        self.refreshTokenField = refreshTokenField
        self.tokenField = tokenField
        self.refreshTokenResponseField = refreshTokenResponseField
        self.onTokensRefreshed = onTokensRefreshed
        self.headers = headers
    }
}

/// Defines how auth refresh should resolve a new access token.
public enum SwiftRestAuthRefreshMode: Sendable {
    case disabled
    case endpoint(SwiftRestAuthRefreshEndpoint)
    case custom(SwiftRestCustomRefreshHandler)
}

/// Configuration for automatic auth refresh
/// (default `401` -> refresh token -> retry once).
public struct SwiftRestAuthRefresh: Sendable {
    /// Refresh strategy.
    public var mode: SwiftRestAuthRefreshMode

    /// If `true`, requests with explicit per-request `authToken` can also trigger refresh.
    ///
    /// Default is `false` so one-off request tokens stay isolated.
    public var appliesToPerRequestToken: Bool

    /// HTTP status codes that trigger auth refresh.
    ///
    /// Default: `[401]`.
    public var triggerStatusCodes: Set<Int>

    public init(
        mode: SwiftRestAuthRefreshMode,
        appliesToPerRequestToken: Bool = false,
        triggerStatusCodes: Set<Int> = [401]
    ) {
        self.mode = mode
        self.appliesToPerRequestToken = appliesToPerRequestToken
        self.triggerStatusCodes = Self.normalizedTriggerStatusCodes(triggerStatusCodes)
    }

    /// Disabled refresh behavior.
    public static let disabled = SwiftRestAuthRefresh(
        mode: .disabled,
        appliesToPerRequestToken: false,
        triggerStatusCodes: [401]
    )

    /// Beginner-friendly endpoint mode.
    public static func endpoint(
        _ endpoint: String,
        method: HTTPMethod = .post,
        refreshTokenProvider: @escaping SwiftRestRefreshTokenProvider,
        refreshTokenField: String = "refreshToken",
        tokenField: String = "accessToken",
        refreshTokenResponseField: String? = nil,
        onTokensRefreshed: SwiftRestTokensRefreshedHandler? = nil,
        triggerStatusCodes: Set<Int> = [401],
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
                    refreshTokenResponseField: refreshTokenResponseField,
                    onTokensRefreshed: onTokensRefreshed,
                    headers: headers
                )
            ),
            triggerStatusCodes: triggerStatusCodes
        )
    }

    /// Advanced custom mode.
    public static func custom(
        _ handler: @escaping SwiftRestCustomRefreshHandler,
        triggerStatusCodes: Set<Int> = [401]
    ) -> Self {
        SwiftRestAuthRefresh(
            mode: .custom(handler),
            triggerStatusCodes: triggerStatusCodes
        )
    }

    public func appliesToPerRequestToken(_ applies: Bool) -> Self {
        var copy = self
        copy.appliesToPerRequestToken = applies
        return copy
    }

    public func triggerStatusCodes(_ statusCodes: Set<Int>) -> Self {
        var copy = self
        copy.triggerStatusCodes = Self.normalizedTriggerStatusCodes(statusCodes)
        return copy
    }

    public func triggerStatusCodes(_ statusCodes: [Int]) -> Self {
        triggerStatusCodes(Set(statusCodes))
    }

    public var isEnabled: Bool {
        switch mode {
        case .disabled:
            return false
        case .endpoint, .custom:
            return true
        }
    }

    private static func normalizedTriggerStatusCodes(_ statusCodes: Set<Int>) -> Set<Int> {
        let valid = statusCodes.filter { (100...599).contains($0) }
        return valid.isEmpty ? [401] : valid
    }
}

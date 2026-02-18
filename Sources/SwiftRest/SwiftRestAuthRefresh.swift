import Foundation

/// Async callback used to refresh an access token after an unauthorized response.
public typealias SwiftRestRefreshTokenProvider = @Sendable () async throws -> String?

/// Configuration for automatic auth refresh (`401` -> refresh token -> retry once).
public struct SwiftRestAuthRefresh: Sendable {
    /// Enables automatic refresh logic.
    public var isEnabled: Bool

    /// If `true`, requests with explicit per-request `authToken` can also trigger refresh.
    ///
    /// Default is `false` so one-off request tokens stay isolated.
    public var appliesToPerRequestToken: Bool

    /// Callback that returns the refreshed token.
    ///
    /// Return `nil` to indicate refresh did not produce a token.
    public var refreshToken: SwiftRestRefreshTokenProvider

    public init(
        isEnabled: Bool = true,
        appliesToPerRequestToken: Bool = false,
        refreshToken: @escaping SwiftRestRefreshTokenProvider
    ) {
        self.isEnabled = isEnabled
        self.appliesToPerRequestToken = appliesToPerRequestToken
        self.refreshToken = refreshToken
    }

    /// Disabled refresh behavior.
    public static let disabled = SwiftRestAuthRefresh(
        isEnabled: false,
        appliesToPerRequestToken: false,
        refreshToken: { nil }
    )

    public func appliesToPerRequestToken(_ applies: Bool) -> Self {
        var copy = self
        copy.appliesToPerRequestToken = applies
        return copy
    }
}

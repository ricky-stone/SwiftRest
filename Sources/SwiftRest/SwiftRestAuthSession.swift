import Foundation

/// The auth session stored by SwiftRest auth wrappers.
///
/// Keep this simple: one primary token and an optional refresh token.
public struct SwiftRestAuthSession: Codable, Sendable, Equatable {
    /// The token attached to authenticated requests.
    public var token: String?

    /// The optional refresh token used to recover the session after a `401`.
    public var refreshToken: String?

    public init(token: String? = nil, refreshToken: String? = nil) {
        self.token = token
        self.refreshToken = refreshToken
    }

    /// Returns `true` when there is nothing to persist.
    public var isEmpty: Bool {
        token == nil && refreshToken == nil
    }
}

import Foundation

/// Callback used for debug logging output.
public typealias SwiftRestLogHandler = @Sendable (String) -> Void

/// Debug logging settings for `SwiftRestClient`.
public struct SwiftRestDebugLogging: Sendable {
    public var isEnabled: Bool
    public var includeHeaders: Bool
    public var redactedHeaderNames: Set<String>
    public var handler: SwiftRestLogHandler

    public static let defaultRedactedHeaderNames: Set<String> = [
        "authorization",
        "proxy-authorization",
        "cookie",
        "set-cookie",
        "x-api-key",
        "api-key",
        "x-auth-token",
        "x-access-token"
    ]

    public init(
        isEnabled: Bool = false,
        includeHeaders: Bool = false,
        redactedHeaderNames: Set<String> = SwiftRestDebugLogging.defaultRedactedHeaderNames,
        handler: @escaping SwiftRestLogHandler = { print($0) }
    ) {
        self.isEnabled = isEnabled
        self.includeHeaders = includeHeaders
        self.redactedHeaderNames = Set(redactedHeaderNames.map { $0.lowercased() })
        self.handler = handler
    }

    /// Logging disabled.
    public static let disabled = SwiftRestDebugLogging()

    /// Logs request/response line summaries.
    public static let basic = SwiftRestDebugLogging(isEnabled: true, includeHeaders: false)

    /// Logs request/response summaries and headers (with redaction).
    public static let headers = SwiftRestDebugLogging(isEnabled: true, includeHeaders: true)

    public func includeHeaders(_ includeHeaders: Bool) -> Self {
        var copy = self
        copy.includeHeaders = includeHeaders
        return copy
    }
}

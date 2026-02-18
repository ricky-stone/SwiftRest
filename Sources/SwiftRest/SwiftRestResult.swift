import Foundation

/// Result style API for beginner-friendly success/error handling.
public enum SwiftRestResult<Success: Decodable & Sendable, APIError: Decodable & Sendable>: Sendable {
    /// HTTP 2xx with optional decoded payload.
    case success(SwiftRestResponse<Success>)

    /// HTTP non-2xx with optional decoded API error payload and raw response metadata.
    case apiError(decoded: APIError?, response: SwiftRestRawResponse)

    /// Transport/client failures such as network issues, decoding failures, URL errors, etc.
    case failure(SwiftRestClientError)
}

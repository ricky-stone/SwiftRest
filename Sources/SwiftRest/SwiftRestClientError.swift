//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

/// Errors that can occur when using the Swift REST client.
///
/// Conforms to `Error` and `Sendable` for safe propagation in concurrent contexts.
public enum SwiftRestClientError: Error, Sendable {
    /// The provided base URL string was invalid.
    case invalidBaseURL(String)
    /// Failed to construct URL components (path or query).
    case invalidURLComponents
    /// The final URL after appending path or query items was invalid.
    case invalidFinalURL
    /// A network-level error occurred (e.g., timeout, unreachable host).
    case networkError(underlying: Error)
    /// A decoding error occurred while parsing the JSON response.
    case decodingError(underlying: Error)
    /// The HTTP response returned a non-2xx status code.
    case httpError(ErrorResponse)
    /// Exceeded the maximum number of retry attempts.
    case retryLimitReached
}

extension SwiftRestClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let url):
            return NSLocalizedString(
                "The base URL provided (\(url)) is invalid. Please check the URL format.",
                comment: "Invalid Base URL"
            )
        case .invalidURLComponents:
            return NSLocalizedString(
                "Unable to construct URL components.",
                comment: "Invalid URL Components"
            )
        case .invalidFinalURL:
            return NSLocalizedString(
                "The final URL is invalid after appending path components or query items.",
                comment: "Invalid Final URL"
            )
        case .networkError(let error):
            return String(format:
                NSLocalizedString(
                    "A network error occurred: %@",
                    comment: "Network Error"
                ),
                error.localizedDescription
            )
        case .decodingError(let error):
            return String(format:
                NSLocalizedString(
                    "Failed to decode response: %@",
                    comment: "Decoding Error"
                ),
                error.localizedDescription
            )
        case .httpError(let response):
            let body = (response.rawPayload ?? response.message) ?? ""
            let reason = HTTPURLResponse
                .localizedString(forStatusCode: response.statusCode)
                .capitalized
            if body.isEmpty {
                return String(format:
                    NSLocalizedString(
                        "HTTP %d: %@",
                        comment: "HTTP Error"
                    ),
                    response.statusCode,
                    reason
                )
            } else {
                return String(format:
                    NSLocalizedString(
                        "HTTP %d: %@ - %@",
                        comment: "HTTP Error"
                    ),
                    response.statusCode,
                    reason,
                    body
                )
            }
        case .retryLimitReached:
            return NSLocalizedString(
                "The maximum number of retry attempts has been reached. Please try again later.",
                comment: "Retry Limit Reached"
            )
        }
    }
}

/// Provides a plain-text, user-friendly summary of the error.
///
/// Extracts JSON `reason` or `title` fields for HTTP errors when available,
/// otherwise falls back to the standard HTTP reason phrase.
public extension SwiftRestClientError {
    var userMessage: String {
        switch self {
        case .invalidBaseURL(let url):
            return "Invalid URL: \"\(url)\""
        case .invalidURLComponents:
            return "Unable to construct URL."
        case .invalidFinalURL:
            return "Invalid final URL after appending path or query."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Response decoding error: \(error.localizedDescription)"
        case .httpError(let response):
            let code = response.statusCode
            if let raw = response.rawPayload ?? response.message,
               let data = raw.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let reason = json["reason"] as? String {
                    return "\(code): \(reason)"
                }
                if let title = json["title"] as? String {
                    return "\(code): \(title)"
                }
            }
            let phrase = HTTPURLResponse
                .localizedString(forStatusCode: code)
                .capitalized
            return "\(code): \(phrase)"
        case .retryLimitReached:
            return "Too many attempts. Please try again later."
        }
    }
}

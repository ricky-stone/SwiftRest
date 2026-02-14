import Foundation

/// A sendable wrapper for underlying error descriptions.
public struct ErrorContext: Error, Sendable {
    public let description: String

    public init(_ error: any Error) {
        self.description = error.localizedDescription
    }

    public init(description: String) {
        self.description = description
    }
}

/// Errors that can occur when using the Swift REST client.
public enum SwiftRestClientError: Error, Sendable {
    case invalidBaseURL(String)
    case invalidURLComponents
    case invalidFinalURL
    case networkError(underlying: ErrorContext)
    case decodingError(underlying: ErrorContext)
    case httpError(ErrorResponse)
    case emptyResponseBody(expectedType: String)
    case retryLimitReached
}

extension SwiftRestClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let url):
            return "The base URL (\(url)) is invalid."
        case .invalidURLComponents:
            return "Unable to construct URL components."
        case .invalidFinalURL:
            return "The final URL is invalid after appending path components or query items."
        case .networkError(let context):
            return "A network error occurred: \(context.description)"
        case .decodingError(let context):
            return "Failed to decode response: \(context.description)"
        case .httpError(let response):
            let body = (response.rawPayload ?? response.message) ?? ""
            let reason = HTTPURLResponse.localizedString(forStatusCode: response.statusCode).capitalized
            return body.isEmpty ? "HTTP \(response.statusCode): \(reason)" : "HTTP \(response.statusCode): \(reason) - \(body)"
        case .emptyResponseBody(let expectedType):
            return "Response body was empty but \(expectedType) was expected."
        case .retryLimitReached:
            return "The maximum number of retry attempts has been reached."
        }
    }
}

public extension SwiftRestClientError {
    /// A plain-text, user-friendly summary.
    var userMessage: String {
        switch self {
        case .invalidBaseURL(let url):
            return "Invalid URL: \"\(url)\""
        case .invalidURLComponents:
            return "Unable to construct URL."
        case .invalidFinalURL:
            return "Invalid final URL after appending path or query."
        case .networkError(let context):
            return "Network error: \(context.description)"
        case .decodingError(let context):
            return "Response decoding error: \(context.description)"
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
                if let error = json["error"] as? String {
                    return "\(code): \(error)"
                }
            }
            let phrase = HTTPURLResponse.localizedString(forStatusCode: code).capitalized
            return "\(code): \(phrase)"
        case .emptyResponseBody(let expectedType):
            return "Response was empty. Expected: \(expectedType)."
        case .retryLimitReached:
            return "Too many attempts. Please try again later."
        }
    }
}

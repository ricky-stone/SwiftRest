//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

/// An enumeration of errors that can occur when using the Swift REST client.
///
/// Conforms to `Error` and `Sendable` to allow safe propagation across concurrent contexts.
public enum SwiftRestClientError: Error, Sendable {
    /// Indicates that the provided base URL is invalid.
    case invalidBaseURL(String)
    /// Indicates that URL components could not be constructed properly.
    case invalidURLComponents
    /// Indicates that the final URL (after appending path components or query items) is invalid.
    case invalidFinalURL
    /// Indicates that the HTTP response is invalid or malformed.
    case invalidHTTPResponse
    /// Indicates that the expected "Content-Type" header is missing.
    case missingContentType
    /// Indicates that the maximum number of retry attempts has been reached without success.
    case retryLimitReached
}

extension SwiftRestClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let url):
            return NSLocalizedString("The base URL provided (\(url)) is invalid. Please check the URL format.", comment: "Invalid Base URL")
        case .invalidURLComponents:
            return NSLocalizedString("Unable to construct URL components.", comment: "Invalid URL Components")
        case .invalidFinalURL:
            return NSLocalizedString("The final URL is invalid after appending path components or query items.", comment: "Invalid Final URL")
        case .invalidHTTPResponse:
            return NSLocalizedString("Received an invalid or malformed HTTP response.", comment: "Invalid HTTP Response")
        case .missingContentType:
            return NSLocalizedString("The 'Content-Type' header is missing from the response.", comment: "Missing Content-Type")
        case .retryLimitReached:
            return NSLocalizedString("The maximum number of retry attempts has been reached. Please try again later.", comment: "Retry Limit Reached")
        }
    }
}

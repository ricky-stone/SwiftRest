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

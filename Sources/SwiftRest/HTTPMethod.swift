//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

/// An enumeration representing the HTTP methods used in REST requests.
///
/// Conforms to `Sendable` to ensure safe usage in concurrent contexts.
public enum HTTPMethod: String, Sendable {
    /// The GET method.
    case get = "GET"
    /// The POST method.
    case post = "POST"
    /// The PUT method.
    case put = "PUT"
    /// The DELETE method.
    case delete = "DELETE"
    /// The PATCH method.
    case patch = "PATCH"
    /// The HEAD method.
    case head = "HEAD"
    /// The OPTIONS method.
    case options = "OPTIONS"
}

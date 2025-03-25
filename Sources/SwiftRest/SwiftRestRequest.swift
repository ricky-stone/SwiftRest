//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

/// A structure representing a REST request.
///
/// This encapsulates the endpoint path, HTTP method, headers, URL parameters, JSON body, and retry configuration.
/// It also provides an optional authorization token that, when provided, is automatically added as a Bearer token.
public struct SwiftRestRequest: Sendable {
    
    /// The endpoint path relative to the base URL.
    public private(set) var path: String
    
    /// The HTTP method for the request.
    public private(set) var method: HTTPMethod
    
    /// Optional headers to include in the request.
    public private(set) var headers: [String: String]?
    
    /// Optional URL parameters appended as query items.
    public private(set) var parameters: [String: String]?
    
    /// Optional JSON body of the request as a string.
    public private(set) var jsonBody: String?
    
    /// The maximum number of retry attempts for the request.
    ///
    /// Defaults to `0`, meaning no retries will be performed unless explicitly configured.
    public private(set) var maxRetries: Int = 0
    
    /// The delay between retry attempts (in seconds).
    ///
    /// Defaults to `0`, meaning no delay (and effectively no retries) unless explicitly configured.
    public private(set) var retryDelay: TimeInterval = 0
    
    /// Optional authorization token.
    ///
    /// If provided, it will be added as a Bearer token in the `Authorization` header.
    public private(set) var authToken: String?
    
    /// Initializes a new REST request with the specified endpoint path and HTTP method.
    ///
    /// - Parameters:
    ///   - path: The endpoint path relative to the base URL.
    ///   - method: The HTTP method (e.g. `.get`, `.post`).
    public init(path: String, method: HTTPMethod) {
        self.path = path
        self.method = method
    }
    
    /// Adds an HTTP header to the request.
    ///
    /// - Parameters:
    ///   - key: The header field name.
    ///   - value: The header field value.
    public mutating func addHeader(_ key: String, _ value: String) {
        if headers == nil { headers = [:] }
        headers?[key] = value
    }
    
    /// Adds a URL parameter to the request.
    ///
    /// - Parameters:
    ///   - key: The parameter name.
    ///   - value: The parameter value.
    public mutating func addParameter(_ key: String, _ value: String) {
        if parameters == nil { parameters = [:] }
        parameters?[key] = value
    }
    
    /// Sets the JSON body of the request by encoding an Encodable object.
    ///
    /// - Parameter object: The object to be encoded as JSON.
    /// - Throws: An error if encoding fails.
    public mutating func addJsonBody<T: Encodable>(_ object: T) throws {
        self.jsonBody = try Json.toString(object: object)
    }
    
    /// Configures the retry behavior for the request.
    ///
    /// - Parameters:
    ///   - maxRetries: The maximum number of retry attempts.
    ///   - retryDelay: The delay between retry attempts, in seconds.
    public mutating func configureRetries(maxRetries: Int, retryDelay: TimeInterval) {
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
    }
    
    /// Adds an authorization token to the request.
    ///
    /// The token will be automatically added as a Bearer token in the `Authorization` header.
    ///
    /// - Parameter token: The authorization token.
    public mutating func addAuthToken(_ token: String) {
        self.authToken = token
    }
}

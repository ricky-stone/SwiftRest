//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

/// A generic structure representing a REST response that can be decoded into a model of type `T`.
///
/// This structure encapsulates key elements of an HTTP response, including the status code,
/// optional decoded data, raw response string, headers, response time, the final URL after redirection,
/// and the MIME type of the response content.
///
/// - Note: The generic type `T` must conform to both `Decodable` and `Sendable`.
public struct SwiftRestResponse<T: Decodable & Sendable>: Sendable {
    
    /// The HTTP status code of the response.
    public private(set) var statusCode: Int
    
    /// The decoded response data of type `T`, if available.
    public private(set) var data: T?
    
    /// The raw response string received from the server.
    public private(set) var rawValue: String?
    
    /// A dictionary containing the HTTP headers from the response.
    public private(set) var headers: [String: String]?
    
    /// The time interval (in seconds) it took to receive the response.
    public private(set) var responseTime: TimeInterval?
    
    /// The final URL after any redirections.
    public private(set) var finalURL: URL?
    
    /// The MIME type of the response content.
    public private(set) var mimeType: String?
    
    /// A computed property indicating whether the response is considered successful.
    ///
    /// A response is considered successful if the HTTP status code is within the range 200 to 299.
    public var isSuccess: Bool {
        return (200...299).contains(statusCode)
    }
    
    /// Initializes a new instance of `SwiftRestResponse` with the provided values.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code from the response.
    ///   - data: The decoded response data of type `T`. Defaults to `nil`.
    ///   - rawValue: The raw response string. Defaults to `nil`.
    ///   - headers: The HTTP headers from the response. Defaults to `nil`.
    ///   - responseTime: The duration (in seconds) it took to get the response. Defaults to `nil`.
    ///   - finalURL: The final URL after following any redirects. Defaults to `nil`.
    ///   - mimeType: The MIME type of the response content. Defaults to `nil`.
    init(
        statusCode: Int,
        data: T? = nil,
        rawValue: String? = nil,
        headers: [String: String]? = nil,
        responseTime: TimeInterval? = nil,
        finalURL: URL? = nil,
        mimeType: String? = nil
    ) {
        self.statusCode = statusCode
        self.data = data
        self.rawValue = rawValue
        self.headers = headers
        self.responseTime = responseTime
        self.finalURL = finalURL
        self.mimeType = mimeType
    }
}

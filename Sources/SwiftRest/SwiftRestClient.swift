//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

/// A client for executing asynchronous REST requests.
///
/// Supports:
/// - Automatic retry on failure
/// - Base URL and path/query construction
/// - Request-specific headers and JSON body
/// - Bearer token authorization
/// - JSON decoding into `Decodable` types
public actor SwiftRestClient {
    
    /// The base URL string used for all requests.
    private let url: String
        
    /// Initializes a new REST client with the specified base URL.
    ///
    /// - Parameter url: The base URL to which all request paths will be appended.
    public init(_ url: String) {
        self.url = url
    }
    
    // MARK: - Public API
    
    /// Executes an HTTP request and decodes the JSON response to the specified type.
    ///
    /// - Parameter httpRequest: A `SwiftRestRequest` defining method, path, headers,
    ///   query parameters, JSON body, retry policy, and auth token.
    /// - Returns: A `SwiftRestResponse<T>` containing status, headers, decoded payload,
    ///   raw JSON, timing, and final URL.
    /// - Throws:
    ///   - `SwiftRestClientError.invalidBaseURL` if the base URL cannot be parsed.
    ///   - `SwiftRestClientError.httpError` for any non-2xx HTTP response, with full
    ///     status code and payload.
    ///   - `SwiftRestClientError.networkError` or `SwiftRestClientError.decodingError` if
    ///     a network or decoding issue occurs.
    @discardableResult
    public func executeAsyncWithResponse<T: Decodable>(
        _ httpRequest: SwiftRestRequest
    ) async throws -> SwiftRestResponse<T> {
        let maxRetries = httpRequest.maxRetries
        let retryDelay = httpRequest.retryDelay
        var attempt = 0
        var lastError: Error?
        
        // Ensure base URL is valid before starting retries
        guard let baseURL = URL(string: url) else {
            throw SwiftRestClientError.invalidBaseURL(url)
        }
        
        // Retry loop: attempt up to `maxRetries` on transient failures
        while attempt <= maxRetries {
            do {
                // Build URL with path and query parameters
                let requestURL = try buildRequestURL(for: httpRequest, baseURL: baseURL)
                // Construct URLRequest (method, headers, token, body)
                let request = buildURLRequest(for: httpRequest, requestURL: requestURL)
                // Record start time for performance metrics
                let startTime = Date()
                // Perform network call
                let (data, urlResponse) = try await URLSession.shared.data(for: request)
                // Process status code, headers, JSON decode if 2xx
                let response = try processResponse(
                    data,
                    urlResponse,
                    startTime,
                    type: T.self
                )
                return response
            } catch {
                // Capture last error for throwing if all retries fail
                lastError = error
            }
            
            attempt += 1
            // Delay before next retry if attempts remain
            if attempt <= maxRetries {
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }
        
        // If retries exhausted, rethrow the last encountered error
        if let error = lastError {
            throw error
        }
        // Fallback if no error was captured
        throw SwiftRestClientError.retryLimitReached
    }
    
    /// Executes an HTTP request when no response payload is expected.
    ///
    /// Wraps `executeAsyncWithResponse` with `T = NoContent` and discards the result.
    ///
    /// - Parameter request: A `SwiftRestRequest` defining the call.
    /// - Throws: Any error from `executeAsyncWithResponse`.
    public func executeAsyncWithoutResponse(_ request: SwiftRestRequest) async throws {
        // Explicitly bind generic to `NoContent` to satisfy type inference
        let _: SwiftRestResponse<NoContent> = try await executeAsyncWithResponse(request)
    }
    
    // MARK: - Private Helpers
    
    /// Builds the full request URL by appending path and encoding query parameters.
    ///
    /// - Parameters:
    ///   - httpRequest: The request definition containing `path` and `parameters`.
    ///   - baseURL: The validated base URL.
    /// - Returns: A `URL` with path and query items.
    /// - Throws:
    ///   - `SwiftRestClientError.invalidURLComponents` if URLComponents cannot be created.
    ///   - `SwiftRestClientError.invalidFinalURL` if the resulting URL is invalid.
    private func buildRequestURL(
        for httpRequest: SwiftRestRequest,
        baseURL: URL
    ) throws -> URL {
        var requestURL = baseURL.appendingPathComponent(httpRequest.path)
        
        guard
            let parameters = httpRequest.parameters,
            !parameters.isEmpty
        else {
            return requestURL
        }
        
        guard var components = URLComponents(
            url: requestURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw SwiftRestClientError.invalidURLComponents
        }
        components.queryItems = parameters.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        guard let finalURL = components.url else {
            throw SwiftRestClientError.invalidFinalURL
        }
        return finalURL
    }
    
    /// Constructs a URLRequest by configuring HTTP method, headers, auth, and JSON body.
    ///
    /// - Parameters:
    ///   - httpRequest: The request definition containing method, headers, authToken, and body.
    ///   - requestURL: The fully built URL for the request.
    /// - Returns: A configured `URLRequest`.
    private func buildURLRequest(
        for httpRequest: SwiftRestRequest,
        requestURL: URL
    ) -> URLRequest {
        var request = URLRequest(url: requestURL)
        request.httpMethod = httpRequest.method.rawValue
                
        // Add any custom headers
        if let headers = httpRequest.headers {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Append Bearer token if provided
        if let token = httpRequest.authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Attach JSON payload for POST/PUT
        if (httpRequest.method == .post || httpRequest.method == .put),
           let jsonBody = httpRequest.jsonBody {
            request.httpBody = jsonBody.data(using: .utf8)
            // Ensure Content-Type header is set
            if httpRequest.headers?[
                "Content-Type"
            ] == nil {
                request.addValue(
                    "application/json",
                    forHTTPHeaderField: "Content-Type"
                )
            }
        }
        return request
    }
    
    /// Processes the HTTPURLResponse and data, decoding JSON for 2xx status codes.
    ///
    /// - Parameters:
    ///   - data: Raw response data.
    ///   - urlResponse: The URLResponse returned by URLSession.
    ///   - startTime: Timestamp when the request started (for timing).
    ///   - type: The `Decodable` type to decode the JSON into.
    /// - Returns: A `SwiftRestResponse<T>` on success.
    /// - Throws:
    ///   - `SwiftRestClientError.httpError` with full details for non-2xx status codes.
    ///   - Any underlying JSON or network errors.
    private func processResponse<T: Decodable>(
        _ data: Data,
        _ urlResponse: URLResponse,
        _ startTime: Date,
        type: T.Type
    ) throws -> SwiftRestResponse<T> {
        let responseTime = Date().timeIntervalSince(startTime)
        
        // Ensure we have an HTTP response
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            let errorResponse = ErrorResponse(
                statusCode: 0,
                message: "Received an invalid or malformed HTTP response.",
                url: nil,
                headers: nil,
                rawPayload: nil,
                responseTime: responseTime
            )
            throw SwiftRestClientError.httpError(errorResponse)
        }
        
        let statusCode = httpResponse.statusCode
        let responseHeaders = httpResponse.allHeaderFields as? [String: String]
        let mimeType = httpResponse.mimeType
        
        // Build the base SwiftRestResponse without payload
        var response = SwiftRestResponse<T>(
            statusCode: statusCode,
            headers: responseHeaders,
            responseTime: responseTime,
            finalURL: httpResponse.url,
            mimeType: mimeType
        )
        
        // Decode JSON payload if applicable
        if !data.isEmpty,
           let contentType = httpResponse.value(
               forHTTPHeaderField: "Content-Type"
           ),
           contentType.contains("application/json") {
            if let bodyString = String(data: data, encoding: .utf8),
               !bodyString.isEmpty {
                let parsedPayload = try Json.parse(data: bodyString) as T
                response = SwiftRestResponse(
                    statusCode: statusCode,
                    data: parsedPayload,
                    rawValue: bodyString,
                    headers: responseHeaders,
                    responseTime: responseTime,
                    finalURL: httpResponse.url,
                    mimeType: mimeType
                )
            }
        }
        
        // Throw for non-2xx status codes, including full payload
        guard (200...299).contains(statusCode) else {
            let errorResponse = ErrorResponse(
                statusCode: statusCode,
                message: response.rawValue,
                url: httpResponse.url,
                headers: responseHeaders,
                rawPayload: response.rawValue,
                responseTime: responseTime
            )
            throw SwiftRestClientError.httpError(errorResponse)
        }
        
        return response
    }
    
    /// A placeholder type for requests expecting no response payload.
    private struct NoContent: Decodable, Sendable {}
}

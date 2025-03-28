//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

/// A client for executing REST requests with support for retries, base headers, and authorization tokens.
public actor SwiftRestClient {
    
    /// The base URL for all requests.
    private let url: String
    
    /// Base headers that are applied to every request.
    ///
    /// These headers are merged with the request-specific headers; in case of conflicts, the request's headers take precedence.
    public var baseHeaders: [String: String]
    
    /// Initializes a new REST client with the specified base URL and optional base headers.
    ///
    /// The provided base headers will be applied to every request made by this client, merging with any request-specific headers.
    /// In case of a conflict, the request-specific header values will override the base headers.
    ///
    /// - Parameters:
    ///   - url: The base URL as a string.
    ///   - baseHeaders: A dictionary of header keys and values to be applied to each request.
    public init(_ url: String, baseHeaders: [String: String] = [:]) {
        self.url = url
        self.baseHeaders = baseHeaders
    }
    
    /// Executes a REST request and decodes the response to the specified type.
    ///
    /// This method uses the retry configuration provided in the request. It automatically applies the client-level
    /// base headers, request-specific headers, and (if provided) the authorization token.
    ///
    /// - Parameter httpRequest: The REST request containing all relevant information.
    /// - Returns: A `SwiftRestResponse` containing the decoded response.
    public func executeAsyncWithResponse<T: Decodable>(_ httpRequest: SwiftRestRequest) async throws -> SwiftRestResponse<T> {
        let maxRetries = httpRequest.maxRetries
        let retryDelay = httpRequest.retryDelay
        var attempt = 0
        var lastError: Error?
        
        guard let baseURL = URL(string: url) else {
            throw SwiftRestClientError.invalidBaseURL(url)
        }
        
        // Nested helper that captures the generic type T.
        func performRequest() async throws -> SwiftRestResponse<T> {
            var requestURL = baseURL.appendingPathComponent(httpRequest.path)
            
            // Append query parameters if available.
            if let parameters = httpRequest.parameters, !parameters.isEmpty {
                guard var components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false) else {
                    throw SwiftRestClientError.invalidURLComponents
                }
                components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
                guard let finalURL = components.url else {
                    throw SwiftRestClientError.invalidFinalURL
                }
                requestURL = finalURL
            }
            
            // Build the URLRequest.
            var request = URLRequest(url: requestURL)
            request.httpMethod = httpRequest.method.rawValue
            
            // Add client-level base headers.
            for (key, value) in baseHeaders {
                request.addValue(value, forHTTPHeaderField: key)
            }
            
            // Add request-specific headers.
            if let headers = httpRequest.headers {
                for (key, value) in headers {
                    request.addValue(value, forHTTPHeaderField: key)
                }
            }
            
            // If an authorization token is provided, add it as a Bearer token.
            if let token = httpRequest.authToken {
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            // Set the JSON body for POST/PUT requests.
            if (httpRequest.method == .post || httpRequest.method == .put),
               let jsonBody = httpRequest.jsonBody {
                request.httpBody = jsonBody.data(using: .utf8)
                // Set default content type if not provided.
                if httpRequest.headers?["Content-Type"] == nil {
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            }
            
            let startTime = Date()
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw SwiftRestClientError.invalidHTTPResponse
            }
            
            let responseHeaders = httpResponse.allHeaderFields as? [String: String]
            let statusCode = httpResponse.statusCode
            let mimeType = httpResponse.mimeType
            
            var response = SwiftRestResponse<T>(
                statusCode: statusCode,
                headers: responseHeaders,
                responseTime: responseTime,
                finalURL: httpResponse.url,
                mimeType: mimeType
            )
            
            // If the response status code is not successful, return early.
            guard (200...299).contains(statusCode) else {
                return response
            }
            
            // Process and decode the response body if available.
            guard !data.isEmpty else {
                return response
            }
            
            if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
               contentType.contains("application/json") {
                // Use the default JSON decoding via the Json helper.
                guard let bodyString = String(data: data, encoding: .utf8), !bodyString.isEmpty else {
                    return response
                }
                let parsedPayload = try Json.parse(data: bodyString) as T
                response = SwiftRestResponse(
                    statusCode: statusCode,
                    data: parsedPayload,
                    rawValue: String(data: data, encoding: .utf8),
                    headers: responseHeaders,
                    responseTime: responseTime,
                    finalURL: httpResponse.url,
                    mimeType: mimeType
                )
            }
            
            return response
        }
        
        // Retry loop.
        while attempt <= maxRetries {
            do {
                let response = try await performRequest()
                if (200...299).contains(response.statusCode) {
                    return response
                } else {
                    lastError = SwiftRestClientError.invalidHTTPResponse
                }
            } catch {
                lastError = error
            }
            
            attempt += 1
            if attempt <= maxRetries {
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }
        
        if let error = lastError {
            throw error
        }
        throw SwiftRestClientError.retryLimitReached
    }
    
    /// Executes a REST request that does not expect a response payload.
    ///
    /// - Parameter request: The REST request.
    public func executeAsyncWithoutResponse(_ request: SwiftRestRequest) async throws {
        let response: SwiftRestResponse<NoContent> = try await executeAsyncWithResponse(request)
        guard (200...299).contains(response.statusCode) else {
            throw SwiftRestClientError.invalidHTTPResponse
        }
    }
    
    /// A helper type representing an empty response.
    private struct NoContent: Decodable, Sendable {}
}



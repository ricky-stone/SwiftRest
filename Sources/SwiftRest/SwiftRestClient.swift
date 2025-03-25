import Foundation

public actor SwiftRestClient {
    
    private let url: String
    public var maxRetries: Int = 3
    public var retryDelay: TimeInterval = 0.5
    
    public init(url: String) {
        self.url = url
    }
    
    public func executeAsyncWithResponse<T: Decodable>(_ httpRequest: SwiftRestRequest) async throws -> SwiftRestResponse<T> {
        
        guard let baseURL = URL(string: url) else {
            throw SwiftRestClientError.invalidBaseURL(url)
        }
        
        var requestURL = baseURL.appendingPathComponent(httpRequest.path)
        
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
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = httpRequest.method.rawValue
        
        if let headers = httpRequest.headers {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        if (httpRequest.method == .post || httpRequest.method == .put),
           let jsonBody = httpRequest.jsonBody {
            request.httpBody = jsonBody.data(using: .utf8)
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
        let finalURL = httpResponse.url
        let mimeType = httpResponse.mimeType
        
        var response = SwiftRestResponse<T>(
            statusCode: statusCode,
            headers: responseHeaders,
            responseTime: responseTime,
            finalURL: finalURL,
            mimeType: mimeType
        )
        
        guard (200...299).contains(statusCode) else {
            return response
        }
        
        guard let bodyString = String(data: data, encoding: .utf8), !bodyString.isEmpty else {
            return response
        }
        
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           contentType.contains("application/json") {
            let parsedPayload = try Json.parse(data: bodyString) as T
            response = SwiftRestResponse(
                statusCode: statusCode,
                data: parsedPayload,
                rawValue: bodyString,
                headers: responseHeaders,
                responseTime: responseTime,
                finalURL: finalURL,
                mimeType: mimeType
            )
        }
        
        return response
    }
    
    public func executeAsyncWithoutResponse(_ request: SwiftRestRequest) async throws {
        let response: SwiftRestResponse<NoContent> = try await executeAsyncWithResponse(request)
        guard (200...299).contains(response.statusCode) else {
            throw SwiftRestClientError.invalidHTTPResponse
        }
    }
    
    public func executeAsyncWithResponse<T: Decodable>(_ httpRequest: SwiftRestRequest, retries: Int? = nil) async throws -> SwiftRestResponse<T> {
        
        let attempts = retries ?? maxRetries
        var lastError: Error?

        for attempt in 0..<attempts {
            
            do {
                let response: SwiftRestResponse<T> = try await executeAsyncWithResponse(httpRequest)
                
                if response.isSuccess {
                    return response
                }
                
                lastError = SwiftRestClientError.invalidHTTPResponse
            } catch {
                lastError = error
            }
            
            if attempt < attempts - 1 {
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }
        throw lastError ?? SwiftRestClientError.invalidHTTPResponse
    }

    public func executeAsyncWithoutResponse(_ request: SwiftRestRequest, retries: Int? = nil) async throws {
        let response: SwiftRestResponse<NoContent> = try await executeAsyncWithResponse(request, retries: retries)
        guard (200...299).contains(response.statusCode) else {
            throw SwiftRestClientError.invalidHTTPResponse
        }
    }
    
    private struct NoContent: Decodable, Sendable {}
}



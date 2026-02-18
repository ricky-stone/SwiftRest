import Foundation

/// A concurrency-safe client for executing async REST requests.
public actor SwiftRestClient: RestClientType {
    private let baseURL: URL
    private let config: SwiftRestConfig
    private let session: URLSession
    private var accessToken: String?
    private var accessTokenProvider: SwiftRestAccessTokenProvider?

    public init(
        _ url: String,
        config: SwiftRestConfig = .standard,
        session: URLSession = .shared
    ) throws {
        guard
            let parsed = URL(string: url),
            let scheme = parsed.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            parsed.host != nil
        else {
            throw SwiftRestClientError.invalidBaseURL(url)
        }

        self.baseURL = parsed
        self.config = config
        self.session = session
        self.accessToken = config.accessToken
        self.accessTokenProvider = config.accessTokenProvider
    }

    // MARK: - Low-level API

    /// Executes a request and returns a raw response.
    ///
    /// If `allowHTTPError` is `false`, non-2xx responses throw `SwiftRestClientError.httpError`.
    public func executeRaw(
        _ request: SwiftRestRequest,
        allowHTTPError: Bool = false
    ) async throws -> SwiftRestRawResponse {
        let policy = effectiveRetryPolicy(for: request)

        var attempt = 1
        var lastError: SwiftRestClientError?

        while attempt <= policy.maxAttempts {
            do {
                let requestURL = try buildRequestURL(for: request)
                let resolvedAuthToken = try await effectiveAuthToken(for: request)
                let urlRequest = buildURLRequest(
                    for: request,
                    requestURL: requestURL,
                    resolvedAuthToken: resolvedAuthToken
                )

                let startTime = Date()
                let (data, urlResponse) = try await session.data(for: urlRequest)
                let raw = try processRawResponse(data, urlResponse, startTime)

                if !allowHTTPError, !raw.isSuccess {
                    throw SwiftRestClientError.httpError(makeErrorResponse(from: raw))
                }

                return raw
            } catch let cancellation as CancellationError {
                throw cancellation
            } catch {
                let normalized = normalize(error)
                lastError = normalized

                if attempt >= policy.maxAttempts || !shouldRetry(normalized, policy: policy) {
                    throw normalized
                }

                let delay = retryDelay(for: attempt, policy: policy, error: normalized)
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }

                attempt += 1
            }
        }

        if let lastError {
            throw lastError
        }

        throw SwiftRestClientError.retryLimitReached
    }

    /// Executes a request and decodes the response body into `T`.
    @discardableResult
    public func executeAsyncWithResponse<T: Decodable & Sendable>(
        _ request: SwiftRestRequest
    ) async throws -> SwiftRestResponse<T> {
        let raw = try await executeRaw(request)
        let decoder = effectiveJSONCoding(for: request).makeDecoder()

        guard !raw.rawData.isEmpty else {
            return SwiftRestResponse(
                statusCode: raw.statusCode,
                data: nil,
                rawData: raw.rawData,
                headers: raw.headers,
                responseTime: raw.responseTime,
                finalURL: raw.finalURL,
                mimeType: raw.mimeType
            )
        }

        let decoded: T
        do {
            if T.self == Data.self, let value = raw.rawData as? T {
                decoded = value
            } else if T.self == String.self,
                      let text = raw.text(),
                      let value = text as? T {
                decoded = value
            } else {
                decoded = try Json.parse(data: raw.rawData, using: decoder)
            }
        } catch {
            throw SwiftRestClientError.decodingError(underlying: ErrorContext(error))
        }

        return SwiftRestResponse(
            statusCode: raw.statusCode,
            data: decoded,
            rawData: raw.rawData,
            headers: raw.headers,
            responseTime: raw.responseTime,
            finalURL: raw.finalURL,
            mimeType: raw.mimeType
        )
    }

    /// Executes a request where response payload is not required.
    public func executeAsyncWithoutResponse(_ request: SwiftRestRequest) async throws {
        _ = try await executeRaw(request)
    }

    /// Executes a request and returns a decoded value directly.
    @discardableResult
    public func execute<T: Decodable & Sendable>(
        _ request: SwiftRestRequest,
        as type: T.Type = T.self
    ) async throws -> T {
        let response: SwiftRestResponse<T> = try await executeAsyncWithResponse(request)

        if let value = response.data {
            return value
        }

        if T.self == NoContent.self, let noContent = NoContent() as? T {
            return noContent
        }

        throw SwiftRestClientError.emptyResponseBody(expectedType: String(describing: type))
    }

    // MARK: - Auth Management

    /// Sets the global access token used when a request does not provide one.
    public func setAccessToken(_ token: String) {
        accessToken = normalizedToken(token)
    }

    /// Clears the global access token.
    public func clearAccessToken() {
        accessToken = nil
    }

    /// Sets an async provider used to resolve an access token per request.
    public func setAccessTokenProvider(_ provider: @escaping SwiftRestAccessTokenProvider) {
        accessTokenProvider = provider
    }

    /// Clears the async access token provider.
    public func clearAccessTokenProvider() {
        accessTokenProvider = nil
    }

    // MARK: - Beginner-friendly HTTP verbs

    public func getRaw(
        _ path: String,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil,
        allowHTTPError: Bool = false
    ) async throws -> SwiftRestRawResponse {
        let request = makeRequest(
            path: path,
            method: .get,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return try await executeRaw(request, allowHTTPError: allowHTTPError)
    }

    @discardableResult
    public func get<T: Decodable & Sendable>(
        _ path: String,
        as type: T.Type = T.self,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async throws -> T {
        let request = makeRequest(
            path: path,
            method: .get,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return try await execute(request, as: type)
    }

    /// Executes `GET` and returns both metadata and decoded payload.
    public func getResponse<T: Decodable & Sendable>(
        _ path: String,
        as type: T.Type = T.self,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async throws -> SwiftRestResponse<T> {
        _ = type
        let request = makeRequest(
            path: path,
            method: .get,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return try await executeAsyncWithResponse(request)
    }

    public func deleteRaw(
        _ path: String,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil,
        allowHTTPError: Bool = false
    ) async throws -> SwiftRestRawResponse {
        let request = makeRequest(
            path: path,
            method: .delete,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return try await executeRaw(request, allowHTTPError: allowHTTPError)
    }

    @discardableResult
    public func delete<T: Decodable & Sendable>(
        _ path: String,
        as type: T.Type = T.self,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async throws -> T {
        let request = makeRequest(
            path: path,
            method: .delete,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return try await execute(request, as: type)
    }

    /// Executes `DELETE` and returns both metadata and decoded payload.
    public func deleteResponse<T: Decodable & Sendable>(
        _ path: String,
        as type: T.Type = T.self,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async throws -> SwiftRestResponse<T> {
        _ = type
        let request = makeRequest(
            path: path,
            method: .delete,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return try await executeAsyncWithResponse(request)
    }

    public func postRaw<Body: Encodable & Sendable>(
        _ path: String,
        body: Body,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil,
        allowHTTPError: Bool = false
    ) async throws -> SwiftRestRawResponse {
        let request = try makeRequest(
            path: path,
            method: .post,
            body: body,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return try await executeRaw(request, allowHTTPError: allowHTTPError)
    }

    @discardableResult
    public func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: Body,
        as type: Response.Type = Response.self,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async throws -> Response {
        let request = try makeRequest(
            path: path,
            method: .post,
            body: body,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return try await execute(request, as: type)
    }

    /// Executes `POST` and returns both metadata and decoded payload.
    public func postResponse<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: Body,
        as type: Response.Type = Response.self,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async throws -> SwiftRestResponse<Response> {
        _ = type
        let request = try makeRequest(
            path: path,
            method: .post,
            body: body,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return try await executeAsyncWithResponse(request)
    }

    public func putRaw<Body: Encodable & Sendable>(
        _ path: String,
        body: Body,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil,
        allowHTTPError: Bool = false
    ) async throws -> SwiftRestRawResponse {
        let request = try makeRequest(
            path: path,
            method: .put,
            body: body,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return try await executeRaw(request, allowHTTPError: allowHTTPError)
    }

    @discardableResult
    public func put<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: Body,
        as type: Response.Type = Response.self,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async throws -> Response {
        let request = try makeRequest(
            path: path,
            method: .put,
            body: body,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return try await execute(request, as: type)
    }

    /// Executes `PUT` and returns both metadata and decoded payload.
    public func putResponse<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: Body,
        as type: Response.Type = Response.self,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async throws -> SwiftRestResponse<Response> {
        _ = type
        let request = try makeRequest(
            path: path,
            method: .put,
            body: body,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return try await executeAsyncWithResponse(request)
    }

    public func patchRaw<Body: Encodable & Sendable>(
        _ path: String,
        body: Body,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil,
        allowHTTPError: Bool = false
    ) async throws -> SwiftRestRawResponse {
        let request = try makeRequest(
            path: path,
            method: .patch,
            body: body,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return try await executeRaw(request, allowHTTPError: allowHTTPError)
    }

    @discardableResult
    public func patch<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: Body,
        as type: Response.Type = Response.self,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async throws -> Response {
        let request = try makeRequest(
            path: path,
            method: .patch,
            body: body,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return try await execute(request, as: type)
    }

    /// Executes `PATCH` and returns both metadata and decoded payload.
    public func patchResponse<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: Body,
        as type: Response.Type = Response.self,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async throws -> SwiftRestResponse<Response> {
        _ = type
        let request = try makeRequest(
            path: path,
            method: .patch,
            body: body,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return try await executeAsyncWithResponse(request)
    }

    // MARK: - Request Builders

    private func makeRequest(
        path: String,
        method: HTTPMethod,
        parameters: [String: String],
        headers: [String: String],
        authToken: String?,
        retryPolicy: RetryPolicy?
    ) -> SwiftRestRequest {
        var request = SwiftRestRequest(path: path, method: method)
        request.addParameters(parameters)
        request.addHeaders(headers)

        if let authToken {
            request.addAuthToken(authToken)
        }

        if let retryPolicy {
            request.configureRetryPolicy(retryPolicy)
        }

        return request
    }

    private func makeRequest<Body: Encodable & Sendable>(
        path: String,
        method: HTTPMethod,
        body: Body,
        parameters: [String: String],
        headers: [String: String],
        authToken: String?,
        retryPolicy: RetryPolicy?
    ) throws -> SwiftRestRequest {
        var request = makeRequest(
            path: path,
            method: method,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: retryPolicy
        )

        try request.addJsonBody(body, using: config.jsonCoding.makeEncoder())
        return request
    }

    // MARK: - Internal Helpers

    private func effectiveRetryPolicy(for request: SwiftRestRequest) -> RetryPolicy {
        request.retryPolicy ?? config.retryPolicy
    }

    private func effectiveJSONCoding(for request: SwiftRestRequest) -> SwiftRestJSONCoding {
        request.jsonCoding ?? config.jsonCoding
    }

    private func buildRequestURL(for request: SwiftRestRequest) throws -> URL {
        let requestURL = baseURL.appendingPathComponent(request.path)

        guard !request.parameters.isEmpty else {
            return requestURL
        }

        guard var components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false) else {
            throw SwiftRestClientError.invalidURLComponents
        }

        components.queryItems = request.parameters.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }

        guard let finalURL = components.url else {
            throw SwiftRestClientError.invalidFinalURL
        }

        return finalURL
    }

    private func buildURLRequest(
        for request: SwiftRestRequest,
        requestURL: URL,
        resolvedAuthToken: String?
    ) -> URLRequest {
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = config.timeout

        var mergedHeaders = config.baseHeaders
        for (key, value) in request.headers.dictionary {
            mergedHeaders.set(value, for: key)
        }

        if let token = resolvedAuthToken {
            mergedHeaders.set("Bearer \(token)", for: "Authorization")
        }

        for (key, value) in mergedHeaders.dictionary {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let body = request.body {
            urlRequest.httpBody = body
        }

        return urlRequest
    }

    private func processRawResponse(
        _ data: Data,
        _ urlResponse: URLResponse,
        _ startTime: Date
    ) throws -> SwiftRestRawResponse {
        let responseTime = Date().timeIntervalSince(startTime)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            let errorResponse = ErrorResponse(
                statusCode: 0,
                message: "Invalid HTTP response",
                url: nil,
                headers: HTTPHeaders(),
                rawPayload: nil,
                responseTime: responseTime
            )
            throw SwiftRestClientError.httpError(errorResponse)
        }

        let headers = HTTPHeaders(httpResponseHeaders: httpResponse.allHeaderFields)

        return SwiftRestResponse(
            statusCode: httpResponse.statusCode,
            data: nil,
            rawData: data,
            headers: headers,
            responseTime: responseTime,
            finalURL: httpResponse.url,
            mimeType: httpResponse.mimeType
        )
    }

    private func makeErrorResponse(from response: SwiftRestRawResponse) -> ErrorResponse {
        ErrorResponse(
            statusCode: response.statusCode,
            message: response.rawValue,
            url: response.finalURL,
            headers: response.headers,
            rawPayload: response.rawValue,
            responseTime: response.responseTime
        )
    }

    private func normalize(_ error: Error) -> SwiftRestClientError {
        if let swiftRestError = error as? SwiftRestClientError {
            return swiftRestError
        }

        if error is DecodingError {
            return .decodingError(underlying: ErrorContext(error))
        }

        if error is URLError {
            return .networkError(underlying: ErrorContext(error))
        }

        return .networkError(underlying: ErrorContext(error))
    }

    private func effectiveAuthToken(for request: SwiftRestRequest) async throws -> String? {
        if let token = normalizedToken(request.authToken) {
            return token
        }

        if let provider = accessTokenProvider,
           let token = normalizedToken(try await provider()) {
            return token
        }

        return normalizedToken(accessToken)
    }

    private func normalizedToken(_ token: String?) -> String? {
        guard let token else {
            return nil
        }
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func shouldRetry(_ error: SwiftRestClientError, policy: RetryPolicy) -> Bool {
        switch error {
        case .networkError:
            return policy.retryOnNetworkErrors
        case .httpError(let response):
            return policy.retryableStatusCodes.contains(response.statusCode)
        default:
            return false
        }
    }

    private func retryDelay(
        for attempt: Int,
        policy: RetryPolicy,
        error: SwiftRestClientError
    ) -> TimeInterval {
        if case .httpError(let response) = error,
           let retryAfter = response.headers["retry-after"],
           let value = TimeInterval(retryAfter),
           value >= 0 {
            return value
        }

        let exponent = Double(max(0, attempt - 1))
        let computed = policy.baseDelay * pow(policy.backoffMultiplier, exponent)
        return min(computed, policy.maxDelay)
    }
}

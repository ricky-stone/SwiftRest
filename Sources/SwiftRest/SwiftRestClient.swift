import Foundation

/// A concurrency-safe client for executing async REST requests.
public actor SwiftRestClient: RestClientType {
    private enum ExecutionMode: Equatable {
        case standard
        case bypassAuthPipeline
    }

    private let baseURL: URL
    private let config: SwiftRestConfig
    private let session: URLSession
    private var accessToken: String?
    private var accessTokenProvider: SwiftRestAccessTokenProvider?
    private var authRefresh: SwiftRestAuthRefresh
    private var authRefreshTask: Task<String?, Error>?

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
        self.authRefresh = config.authRefresh
    }

    // MARK: - Low-level API

    /// Executes a request and returns a raw response.
    ///
    /// If `allowHTTPError` is `false`, non-2xx responses throw `SwiftRestClientError.httpError`.
    public func executeRaw(
        _ request: SwiftRestRequest,
        allowHTTPError: Bool = false
    ) async throws -> SwiftRestRawResponse {
        try await executeRaw(
            request,
            allowHTTPError: allowHTTPError,
            executionMode: .standard
        )
    }

    /// Executes a request and decodes the response body into `T`.
    @discardableResult
    public func executeAsyncWithResponse<T: Decodable & Sendable>(
        _ request: SwiftRestRequest
    ) async throws -> SwiftRestResponse<T> {
        let raw = try await executeRaw(request)
        let decoded: T? = try decodeResponseData(
            raw,
            as: T.self,
            coding: effectiveJSONCoding(for: request)
        )

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

    /// Executes a request and returns result-style success/API-error/failure output.
    public func executeResult<Success: Decodable & Sendable, APIError: Decodable & Sendable>(
        _ request: SwiftRestRequest,
        as successType: Success.Type = Success.self,
        error apiErrorType: APIError.Type = APIError.self
    ) async -> SwiftRestResult<Success, APIError> {
        _ = successType
        _ = apiErrorType

        let coding = effectiveJSONCoding(for: request)

        do {
            let raw = try await executeRaw(request, allowHTTPError: true)

            if raw.isSuccess {
                do {
                    let decoded: Success? = try decodeResponseData(raw, as: Success.self, coding: coding)
                    return .success(
                        SwiftRestResponse(
                            statusCode: raw.statusCode,
                            data: decoded,
                            rawData: raw.rawData,
                            headers: raw.headers,
                            responseTime: raw.responseTime,
                            finalURL: raw.finalURL,
                            mimeType: raw.mimeType
                        )
                    )
                } catch let error as SwiftRestClientError {
                    return .failure(error)
                } catch {
                    return .failure(normalize(error))
                }
            }

            do {
                let decodedAPIError: APIError? = try decodeResponseData(raw, as: APIError.self, coding: coding)
                return .apiError(decoded: decodedAPIError, response: raw)
            } catch {
                return .apiError(decoded: nil, response: raw)
            }
        } catch let error as SwiftRestClientError {
            return .failure(error)
        } catch {
            return .failure(normalize(error))
        }
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

    /// Sets auth refresh behavior for unauthorized responses.
    public func setAuthRefresh(_ refresh: SwiftRestAuthRefresh) {
        authRefresh = refresh
    }

    /// Disables auth refresh behavior.
    public func clearAuthRefresh() {
        authRefresh = .disabled
        authRefreshTask?.cancel()
        authRefreshTask = nil
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

    public func getRaw<Query: Encodable & Sendable>(
        _ path: String,
        query: Query,
        headers: [String: String] = [:],
        authToken: String? = nil,
        allowHTTPError: Bool = false
    ) async throws -> SwiftRestRawResponse {
        let request = try makeRequest(
            path: path,
            method: .get,
            query: query,
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

    @discardableResult
    public func get<T: Decodable & Sendable, Query: Encodable & Sendable>(
        _ path: String,
        as type: T.Type = T.self,
        query: Query,
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async throws -> T {
        let request = try makeRequest(
            path: path,
            method: .get,
            query: query,
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

    /// Executes `GET` and returns both metadata and decoded payload.
    public func getResponse<T: Decodable & Sendable, Query: Encodable & Sendable>(
        _ path: String,
        as type: T.Type = T.self,
        query: Query,
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async throws -> SwiftRestResponse<T> {
        _ = type
        let request = try makeRequest(
            path: path,
            method: .get,
            query: query,
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

    public func deleteRaw<Query: Encodable & Sendable>(
        _ path: String,
        query: Query,
        headers: [String: String] = [:],
        authToken: String? = nil,
        allowHTTPError: Bool = false
    ) async throws -> SwiftRestRawResponse {
        let request = try makeRequest(
            path: path,
            method: .delete,
            query: query,
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

    @discardableResult
    public func delete<T: Decodable & Sendable, Query: Encodable & Sendable>(
        _ path: String,
        as type: T.Type = T.self,
        query: Query,
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async throws -> T {
        let request = try makeRequest(
            path: path,
            method: .delete,
            query: query,
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

    /// Executes `DELETE` and returns both metadata and decoded payload.
    public func deleteResponse<T: Decodable & Sendable, Query: Encodable & Sendable>(
        _ path: String,
        as type: T.Type = T.self,
        query: Query,
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async throws -> SwiftRestResponse<T> {
        _ = type
        let request = try makeRequest(
            path: path,
            method: .delete,
            query: query,
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

    // MARK: - Result-style HTTP verbs

    public func getResult<Success: Decodable & Sendable, APIError: Decodable & Sendable>(
        _ path: String,
        as type: Success.Type = Success.self,
        error errorType: APIError.Type = APIError.self,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async -> SwiftRestResult<Success, APIError> {
        _ = type
        _ = errorType
        let request = makeRequest(
            path: path,
            method: .get,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return await executeResult(request, as: Success.self, error: APIError.self)
    }

    public func getResult<Success: Decodable & Sendable, APIError: Decodable & Sendable, Query: Encodable & Sendable>(
        _ path: String,
        as type: Success.Type = Success.self,
        error errorType: APIError.Type = APIError.self,
        query: Query,
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async -> SwiftRestResult<Success, APIError> {
        _ = type
        _ = errorType
        do {
            let request = try makeRequest(
                path: path,
                method: .get,
                query: query,
                headers: headers,
                authToken: authToken,
                retryPolicy: nil
            )
            return await executeResult(request, as: Success.self, error: APIError.self)
        } catch let error as SwiftRestClientError {
            return .failure(error)
        } catch {
            return .failure(normalize(error))
        }
    }

    public func deleteResult<Success: Decodable & Sendable, APIError: Decodable & Sendable>(
        _ path: String,
        as type: Success.Type = Success.self,
        error errorType: APIError.Type = APIError.self,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async -> SwiftRestResult<Success, APIError> {
        _ = type
        _ = errorType
        let request = makeRequest(
            path: path,
            method: .delete,
            parameters: parameters,
            headers: headers,
            authToken: authToken,
            retryPolicy: nil
        )
        return await executeResult(request, as: Success.self, error: APIError.self)
    }

    public func deleteResult<Success: Decodable & Sendable, APIError: Decodable & Sendable, Query: Encodable & Sendable>(
        _ path: String,
        as type: Success.Type = Success.self,
        error errorType: APIError.Type = APIError.self,
        query: Query,
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async -> SwiftRestResult<Success, APIError> {
        _ = type
        _ = errorType
        do {
            let request = try makeRequest(
                path: path,
                method: .delete,
                query: query,
                headers: headers,
                authToken: authToken,
                retryPolicy: nil
            )
            return await executeResult(request, as: Success.self, error: APIError.self)
        } catch let error as SwiftRestClientError {
            return .failure(error)
        } catch {
            return .failure(normalize(error))
        }
    }

    public func postResult<Body: Encodable & Sendable, Success: Decodable & Sendable, APIError: Decodable & Sendable>(
        _ path: String,
        body: Body,
        as type: Success.Type = Success.self,
        error errorType: APIError.Type = APIError.self,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async -> SwiftRestResult<Success, APIError> {
        _ = type
        _ = errorType
        do {
            let request = try makeRequest(
                path: path,
                method: .post,
                body: body,
                parameters: parameters,
                headers: headers,
                authToken: authToken,
                retryPolicy: nil
            )
            return await executeResult(request, as: Success.self, error: APIError.self)
        } catch let error as SwiftRestClientError {
            return .failure(error)
        } catch {
            return .failure(normalize(error))
        }
    }

    public func putResult<Body: Encodable & Sendable, Success: Decodable & Sendable, APIError: Decodable & Sendable>(
        _ path: String,
        body: Body,
        as type: Success.Type = Success.self,
        error errorType: APIError.Type = APIError.self,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async -> SwiftRestResult<Success, APIError> {
        _ = type
        _ = errorType
        do {
            let request = try makeRequest(
                path: path,
                method: .put,
                body: body,
                parameters: parameters,
                headers: headers,
                authToken: authToken,
                retryPolicy: nil
            )
            return await executeResult(request, as: Success.self, error: APIError.self)
        } catch let error as SwiftRestClientError {
            return .failure(error)
        } catch {
            return .failure(normalize(error))
        }
    }

    public func patchResult<Body: Encodable & Sendable, Success: Decodable & Sendable, APIError: Decodable & Sendable>(
        _ path: String,
        body: Body,
        as type: Success.Type = Success.self,
        error errorType: APIError.Type = APIError.self,
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        authToken: String? = nil
    ) async -> SwiftRestResult<Success, APIError> {
        _ = type
        _ = errorType
        do {
            let request = try makeRequest(
                path: path,
                method: .patch,
                body: body,
                parameters: parameters,
                headers: headers,
                authToken: authToken,
                retryPolicy: nil
            )
            return await executeResult(request, as: Success.self, error: APIError.self)
        } catch let error as SwiftRestClientError {
            return .failure(error)
        } catch {
            return .failure(normalize(error))
        }
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

    private func makeRequest<Query: Encodable & Sendable>(
        path: String,
        method: HTTPMethod,
        query: Query,
        headers: [String: String],
        authToken: String?,
        retryPolicy: RetryPolicy?
    ) throws -> SwiftRestRequest {
        let encoded = try SwiftRestQuery.encode(query, using: config.jsonCoding.makeEncoder())
        return makeRequest(
            path: path,
            method: method,
            parameters: encoded,
            headers: headers,
            authToken: authToken,
            retryPolicy: retryPolicy
        )
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

    func materialize(
        baseRequest: SwiftRestRequest,
        bodyApplier: @Sendable (inout SwiftRestRequest, SwiftRestJSONCoding) throws -> Void
    ) throws -> SwiftRestRequest {
        var request = baseRequest
        let coding = effectiveJSONCoding(for: request)
        try bodyApplier(&request, coding)
        return request
    }

    private func executeRaw(
        _ request: SwiftRestRequest,
        allowHTTPError: Bool,
        executionMode: ExecutionMode
    ) async throws -> SwiftRestRawResponse {
        let policy: RetryPolicy = {
            switch executionMode {
            case .standard:
                return effectiveRetryPolicy(for: request)
            case .bypassAuthPipeline:
                return .none
            }
        }()

        var attempt = 1
        var lastError: SwiftRestClientError?
        var didAttemptAuthRefresh = false
        var authOverrideToken: String?

        while attempt <= policy.maxAttempts {
            do {
                let requestURL = try buildRequestURL(for: request)
                let resolvedAuthToken = try await resolvedAuthToken(
                    for: request,
                    executionMode: executionMode,
                    authOverrideToken: authOverrideToken
                )
                let urlRequest = buildURLRequest(
                    for: request,
                    requestURL: requestURL,
                    resolvedAuthToken: resolvedAuthToken
                )
                logOutgoingRequest(urlRequest, attempt: attempt, maxAttempts: policy.maxAttempts)

                let startTime = Date()
                let (data, urlResponse) = try await session.data(for: urlRequest)
                let raw = try processRawResponse(data, urlResponse, startTime)
                logIncomingResponse(
                    raw,
                    method: request.method.rawValue,
                    requestURL: requestURL,
                    attempt: attempt,
                    maxAttempts: policy.maxAttempts
                )

                if executionMode == .standard,
                   raw.statusCode == 401,
                   shouldAttemptAuthRefresh(
                       for: request,
                       didAttemptAuthRefresh: didAttemptAuthRefresh
                   ) {
                    didAttemptAuthRefresh = true
                    let refreshedToken = try await refreshAccessToken(triggeringRequest: request)

                    if let refreshedToken,
                       refreshedToken != resolvedAuthToken {
                        authOverrideToken = refreshedToken
                        logAuthRefresh("Token refreshed after 401. Retrying request once.")
                        continue
                    }

                    if let currentToken = try await effectiveAuthToken(for: request),
                       currentToken != resolvedAuthToken {
                        authOverrideToken = currentToken
                        logAuthRefresh("Auth token changed after refresh. Retrying request once.")
                        continue
                    }

                    logAuthRefresh("Auth refresh did not produce a new token.")
                }

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

    private func resolvedAuthToken(
        for request: SwiftRestRequest,
        executionMode: ExecutionMode,
        authOverrideToken: String?
    ) async throws -> String? {
        if let authOverrideToken {
            return authOverrideToken
        }

        switch executionMode {
        case .standard:
            return try await effectiveAuthToken(for: request)
        case .bypassAuthPipeline:
            return normalizedToken(request.authToken)
        }
    }

    private func effectiveRetryPolicy(for request: SwiftRestRequest) -> RetryPolicy {
        request.retryPolicy ?? config.retryPolicy
    }

    private func effectiveJSONCoding(for request: SwiftRestRequest) -> SwiftRestJSONCoding {
        request.jsonCoding ?? config.jsonCoding
    }

    private func decodeResponseData<T: Decodable & Sendable>(
        _ raw: SwiftRestRawResponse,
        as type: T.Type,
        coding: SwiftRestJSONCoding
    ) throws -> T? {
        _ = type

        guard !raw.rawData.isEmpty else {
            return nil
        }

        let decoder = coding.makeDecoder()
        do {
            if T.self == Data.self, let value = raw.rawData as? T {
                return value
            }
            if T.self == String.self,
               let text = raw.text(),
               let value = text as? T {
                return value
            }
            return try Json.parse(data: raw.rawData, using: decoder)
        } catch {
            throw SwiftRestClientError.decodingError(underlying: ErrorContext(error))
        }
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
        if request.noAuth {
            return nil
        }

        if let token = normalizedToken(request.authToken) {
            return token
        }

        if let provider = accessTokenProvider,
           let token = normalizedToken(try await provider()) {
            return token
        }

        return normalizedToken(accessToken)
    }

    private func shouldAttemptAuthRefresh(
        for request: SwiftRestRequest,
        didAttemptAuthRefresh: Bool
    ) -> Bool {
        if request.noAuth {
            return false
        }

        if request.autoRefreshEnabled == false {
            return false
        }

        guard authRefresh.isEnabled, !didAttemptAuthRefresh else {
            return false
        }

        let hasPerRequestToken = normalizedToken(request.authToken) != nil
        if hasPerRequestToken && !authRefresh.appliesToPerRequestToken {
            return false
        }

        if hasPerRequestToken {
            return true
        }

        return normalizedToken(accessToken) != nil || accessTokenProvider != nil
    }

    private func refreshAccessToken(triggeringRequest: SwiftRestRequest) async throws -> String? {
        guard authRefresh.isEnabled else {
            return nil
        }

        if let task = authRefreshTask {
            return try await consumeRefreshTask(task)
        }

        let refresh = authRefresh
        let task = Task<String?, Error> {
            try await self.resolveRefreshedToken(
                refresh,
                triggeringRequest: triggeringRequest
            )
        }

        authRefreshTask = task
        defer { authRefreshTask = nil }
        return try await consumeRefreshTask(task)
    }

    private func consumeRefreshTask(_ task: Task<String?, Error>) async throws -> String? {
        do {
            let refreshedToken = normalizedToken(try await task.value)
            accessToken = refreshedToken
            return refreshedToken
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            throw SwiftRestClientError.authRefreshFailed(underlying: ErrorContext(error))
        }
    }

    private func resolveRefreshedToken(
        _ refresh: SwiftRestAuthRefresh,
        triggeringRequest: SwiftRestRequest
    ) async throws -> String? {
        switch refresh.mode {
        case .disabled:
            return nil
        case .endpoint(let endpointConfig):
            return try await refreshViaEndpoint(
                endpointConfig,
                triggeringRequest: triggeringRequest
            )
        case .custom(let handler):
            let context = makeRefreshContext(for: triggeringRequest)
            return try await handler(context)
        }
    }

    private func refreshViaEndpoint(
        _ endpointConfig: SwiftRestAuthRefreshEndpoint,
        triggeringRequest: SwiftRestRequest
    ) async throws -> String? {
        let refreshTokenProvider = triggeringRequest.refreshTokenProvider ?? endpointConfig.refreshTokenProvider
        guard let refreshToken = normalizedToken(try await refreshTokenProvider()) else {
            throw SwiftRestClientError.authRefreshFailed(
                underlying: ErrorContext(description: "Refresh token provider returned no value.")
            )
        }

        var request = SwiftRestRequest(
            path: endpointConfig.endpoint,
            method: endpointConfig.method
        )
        request.addHeaders(endpointConfig.headers)

        let payload = [endpointConfig.refreshTokenField: refreshToken]
        try request.addJsonBody(payload, using: config.jsonCoding.makeEncoder())

        let raw = try await executeRaw(
            request,
            allowHTTPError: true,
            executionMode: .bypassAuthPipeline
        )

        guard raw.isSuccess else {
            throw SwiftRestClientError.httpError(makeErrorResponse(from: raw))
        }

        do {
            guard
                let object = try raw.jsonObject() as? [String: Any],
                let token = object[endpointConfig.tokenField] as? String
            else {
                throw SwiftRestClientError.authRefreshFailed(
                    underlying: ErrorContext(
                        description: "Refresh response missing token field \"\(endpointConfig.tokenField)\"."
                    )
                )
            }

            guard let accessToken = normalizedToken(token) else {
                throw SwiftRestClientError.authRefreshFailed(
                    underlying: ErrorContext(
                        description: "Refresh token field \"\(endpointConfig.tokenField)\" was empty."
                    )
                )
            }

            let refreshedRefreshToken: String?
            if let refreshTokenResponseField = endpointConfig.refreshTokenResponseField {
                guard let rawRefreshToken = object[refreshTokenResponseField] as? String else {
                    throw SwiftRestClientError.authRefreshFailed(
                        underlying: ErrorContext(
                            description:
                                "Refresh response missing token field \"\(refreshTokenResponseField)\"."
                        )
                    )
                }
                refreshedRefreshToken = normalizedToken(rawRefreshToken)
            } else {
                refreshedRefreshToken = nil
            }

            if let onTokensRefreshed = endpointConfig.onTokensRefreshed {
                try await onTokensRefreshed(accessToken, refreshedRefreshToken)
            }

            return accessToken
        } catch let error as SwiftRestClientError {
            throw error
        } catch {
            throw SwiftRestClientError.authRefreshFailed(underlying: ErrorContext(error))
        }
    }

    private func makeRefreshContext(
        for triggeringRequest: SwiftRestRequest
    ) -> SwiftRestRefreshContext {
        let baseJSONCoding = effectiveJSONCoding(for: triggeringRequest)
        return SwiftRestRefreshContext(
            jsonCoding: baseJSONCoding,
            performRaw: { [weak self] request in
                guard let self else {
                    throw SwiftRestClientError.authRefreshFailed(
                        underlying: ErrorContext(description: "Refresh context was released.")
                    )
                }
                return try await self.executeRaw(
                    request,
                    allowHTTPError: true,
                    executionMode: .bypassAuthPipeline
                )
            }
        )
    }

    private func normalizedToken(_ token: String?) -> String? {
        guard let token else {
            return nil
        }
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func logOutgoingRequest(
        _ request: URLRequest,
        attempt: Int,
        maxAttempts: Int
    ) {
        let logging = config.debugLogging
        guard logging.isEnabled else {
            return
        }

        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown-url"
        logging.handler("[SwiftRest] -> \(method) \(url) [attempt \(attempt)/\(maxAttempts)]")

        guard logging.includeHeaders,
              let headers = request.allHTTPHeaderFields,
              !headers.isEmpty
        else {
            return
        }

        logging.handler("[SwiftRest] request headers: \(redactedHeadersString(from: headers, using: logging))")
    }

    private func logIncomingResponse(
        _ response: SwiftRestRawResponse,
        method: String,
        requestURL: URL,
        attempt: Int,
        maxAttempts: Int
    ) {
        let logging = config.debugLogging
        guard logging.isEnabled else {
            return
        }

        let elapsedMs = Int((response.responseTime ?? 0) * 1_000)
        let finalURL = response.finalURL?.absoluteString ?? requestURL.absoluteString
        logging.handler(
            "[SwiftRest] <- \(response.statusCode) \(method) \(finalURL) (\(elapsedMs) ms) [attempt \(attempt)/\(maxAttempts)]"
        )

        guard logging.includeHeaders, !response.headers.dictionary.isEmpty else {
            return
        }

        logging.handler(
            "[SwiftRest] response headers: \(redactedHeadersString(from: response.headers.dictionary, using: logging))"
        )
    }

    private func redactedHeadersString(
        from headers: [String: String],
        using logging: SwiftRestDebugLogging
    ) -> String {
        headers
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { key, value in
                let isSensitive = logging.redactedHeaderNames.contains(key.lowercased())
                    || key.lowercased().contains("authorization")
                    || key.lowercased().contains("token")
                    || key.lowercased().contains("secret")
                let sanitized = isSensitive ? "<redacted>" : value
                return "\(key): \(sanitized)"
            }
            .joined(separator: ", ")
    }

    private func logAuthRefresh(_ message: String) {
        let logging = config.debugLogging
        guard logging.isEnabled else {
            return
        }
        logging.handler("[SwiftRest] auth refresh: \(message)")
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

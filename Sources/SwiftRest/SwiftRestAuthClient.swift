import Foundation

/// A beginner-friendly auth/session wrapper built on top of `SwiftRestClient`.
public actor SwiftRestAuthClient {
    private let baseClient: SwiftRestClient
    private let config: SwiftRestConfig
    private let sessionStore: any SwiftRestSessionStore
    private let settings: SwiftRestAuthSettings
    private var refreshTask: Task<SwiftRestAuthSession?, Error>?

    init(
        baseClient: SwiftRestClient,
        config: SwiftRestConfig,
        sessionStore: any SwiftRestSessionStore,
        settings: SwiftRestAuthSettings
    ) {
        self.baseClient = baseClient
        self.config = config
        self.sessionStore = sessionStore
        self.settings = settings
    }

    /// Returns the current saved auth session.
    public func currentSession() async throws -> SwiftRestAuthSession? {
        try await sessionStore.load()
    }

    /// Convenience alias for `currentSession()`.
    public func session() async throws -> SwiftRestAuthSession? {
        try await currentSession()
    }

    /// Saves a session directly.
    public func save(_ session: SwiftRestAuthSession) async throws {
        let normalized = SwiftRestAuthSession(
            token: normalizedToken(session.token),
            refreshToken: normalizedToken(session.refreshToken)
        )
        try await sessionStore.save(normalized)
    }

    /// Saves a token pair directly.
    public func save(token: String, refreshToken: String? = nil) async throws {
        try await save(
            SwiftRestAuthSession(
                token: normalizedToken(token),
                refreshToken: normalizedToken(refreshToken)
            )
        )
    }

    /// Clears the stored session.
    public func logout() async throws {
        refreshTask?.cancel()
        refreshTask = nil
        try await sessionStore.clear()
    }

    public func executeRaw(
        _ request: SwiftRestRequest,
        allowHTTPError: Bool = false
    ) async throws -> SwiftRestRawResponse {
        try await executePreparedRaw(request, allowHTTPError: allowHTTPError)
    }

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

    public func executeAsyncWithoutResponse(_ request: SwiftRestRequest) async throws {
        _ = try await executeRaw(request)
    }

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

    func materialize(
        baseRequest: SwiftRestRequest,
        bodyApplier: @Sendable (inout SwiftRestRequest, SwiftRestJSONCoding) throws -> Void
    ) async throws -> SwiftRestRequest {
        var request = baseRequest
        let coding = effectiveJSONCoding(for: request)
        try bodyApplier(&request, coding)
        return request
    }

    private func executePreparedRaw(
        _ request: SwiftRestRequest,
        allowHTTPError: Bool
    ) async throws -> SwiftRestRawResponse {
        let preparedRequest = try await prepareRequest(request)
        let raw = try await baseClient.executeRaw(preparedRequest, allowHTTPError: true)

        if shouldAttemptRefresh(
               for: request,
               statusCode: raw.statusCode
           ) {
            let refreshedSession = try await refreshSession(triggeringRequest: request)
            if let refreshedSession,
               let refreshedToken = refreshedSession.token,
               refreshedToken != preparedRequest.authToken {
                let retriedRequest = preparedRequest.authToken(refreshedToken)
                let retried = try await baseClient.executeRaw(retriedRequest, allowHTTPError: true)
                try await autoSaveSession(from: retried, existingRefreshToken: refreshedSession.refreshToken)

                if !allowHTTPError, !retried.isSuccess {
                    throw SwiftRestClientError.httpError(makeErrorResponse(from: retried))
                }

                return retried
            }

            if !allowHTTPError {
                throw SwiftRestClientError.authRefreshFailed(
                    underlying: ErrorContext(
                        description: "Refresh completed but did not produce a new token."
                    )
                )
            }
        }

        try await autoSaveSession(from: raw)

        if !allowHTTPError, !raw.isSuccess {
            throw SwiftRestClientError.httpError(makeErrorResponse(from: raw))
        }

        return raw
    }

    private func prepareRequest(_ request: SwiftRestRequest) async throws -> SwiftRestRequest {
        guard !request.noAuth else {
            return request
        }

        if request.authToken != nil {
            return request
        }

        let session = try await currentSession()
        guard let token = normalizedToken(session?.token) else {
            return request
        }

        return request.authToken(token)
    }

    private func shouldAttemptRefresh(
        for request: SwiftRestRequest,
        statusCode: Int
    ) -> Bool {
        guard request.noAuth == false else {
            return false
        }

        guard request.autoRefreshEnabled != false else {
            return false
        }

        guard request.authToken == nil else {
            return false
        }

        guard settings.refreshEndpoint != nil else {
            return false
        }

        guard settings.triggerStatusCodes.contains(statusCode) else {
            return false
        }

        return true
    }

    private func refreshSession(triggeringRequest: SwiftRestRequest) async throws -> SwiftRestAuthSession? {
        if let task = refreshTask {
            return try await consumeRefreshTask(task)
        }

        let task = Task<SwiftRestAuthSession?, Error> {
            try await self.performRefresh(triggeringRequest: triggeringRequest)
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await consumeRefreshTask(task)
    }

    private func consumeRefreshTask(_ task: Task<SwiftRestAuthSession?, Error>) async throws -> SwiftRestAuthSession? {
        do {
            return try await task.value
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch let clientError as SwiftRestClientError {
            throw clientError
        } catch {
            throw SwiftRestClientError.authRefreshFailed(underlying: ErrorContext(error))
        }
    }

    private func performRefresh(triggeringRequest: SwiftRestRequest) async throws -> SwiftRestAuthSession? {
        guard let refreshEndpoint = settings.refreshEndpoint else {
            return nil
        }

        let currentSession = try await sessionStore.load()
        let refreshToken = try await resolveRefreshToken(
            for: triggeringRequest,
            currentSession: currentSession
        )

        guard let refreshToken else {
            throw SwiftRestClientError.authRefreshFailed(
                underlying: ErrorContext(description: "Refresh token provider returned no value.")
            )
        }

        var refreshRequest = SwiftRestRequest(path: refreshEndpoint, method: settings.refreshMethod)
        refreshRequest.addHeaders(settings.refreshHeaders)
        try refreshRequest.addJsonBody(
            [settings.refreshRequestField: refreshToken],
            using: config.jsonCoding.makeEncoder()
        )

        let raw = try await baseClient.executeRaw(refreshRequest, allowHTTPError: true)

        guard raw.isSuccess else {
            throw SwiftRestClientError.httpError(makeErrorResponse(from: raw))
        }

        guard let refreshedSession = try buildSession(
            from: raw,
            existingRefreshToken: currentSession?.refreshToken,
            requireToken: true
        ) else {
            return currentSession
        }

        try await sessionStore.save(refreshedSession)
        return refreshedSession
    }

    private func resolveRefreshToken(
        for request: SwiftRestRequest,
        currentSession: SwiftRestAuthSession?
    ) async throws -> String? {
        if let provider = request.refreshTokenProvider,
           let token = normalizedToken(try await provider()) {
            return token
        }

        return normalizedToken(currentSession?.refreshToken)
    }

    private func autoSaveSession(
        from raw: SwiftRestRawResponse,
        existingRefreshToken: String? = nil
    ) async throws {
        guard raw.isSuccess else {
            return
        }

        guard let session = try buildSession(
            from: raw,
            existingRefreshToken: existingRefreshToken,
            requireToken: false
        ) else {
            return
        }

        try await sessionStore.save(session)
    }

    private func buildSession(
        from raw: SwiftRestRawResponse,
        existingRefreshToken: String? = nil,
        requireToken: Bool
    ) throws -> SwiftRestAuthSession? {
        let token = try extractToken(from: raw, source: settings.tokenSource)

        guard token != nil || !requireToken else {
            throw SwiftRestClientError.authRefreshFailed(
                underlying: ErrorContext(
                    description: "Refresh response missing token field."
                )
            )
        }

        let refreshToken = try extractToken(from: raw, source: settings.refreshTokenSource) ?? existingRefreshToken

        guard let token else {
            return nil
        }

        return SwiftRestAuthSession(token: token, refreshToken: refreshToken)
    }

    private func extractToken(
        from raw: SwiftRestRawResponse,
        source: SwiftRestAuthValueSource
    ) throws -> String? {
        switch source {
        case .none:
            return nil
        case .header(let name):
            return normalizedToken(raw.header(name))
        case .bodyField(let field):
            guard !raw.rawData.isEmpty else {
                return nil
            }

            guard let object = try? raw.jsonObject() as? [String: Any],
                  let value = object[field] as? String
            else {
                return nil
            }
            return normalizedToken(value)
        }
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
}

private func normalizedToken(_ token: String?) -> String? {
    guard let token else {
        return nil
    }

    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

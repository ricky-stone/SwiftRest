import Foundation

/// A beginner-friendly auth/session wrapper built on top of `SwiftRestClient`.
public actor SwiftRestAuthClient {
    private let baseClient: SwiftRestClient
    private let baseURL: URL
    private let config: SwiftRestConfig
    private let sessionStore: any SwiftRestSessionStore
    private let settings: SwiftRestAuthSettings
    private let appAttestProvider: any SwiftRestAppAttestProviding
    private let deviceCheckProvider: any SwiftRestDeviceCheckProviding
    private var refreshTask: Task<SwiftRestAuthSession?, Error>?
    private var appAttestRegistrationTask: Task<SwiftRestAuthSession?, Error>?

    init(
        baseClient: SwiftRestClient,
        baseURL: URL,
        config: SwiftRestConfig,
        sessionStore: any SwiftRestSessionStore,
        settings: SwiftRestAuthSettings,
        appAttestProvider: any SwiftRestAppAttestProviding = SwiftRestDefaultAppAttestProvider(),
        deviceCheckProvider: any SwiftRestDeviceCheckProviding = SwiftRestDefaultDeviceCheckProvider()
    ) {
        self.baseClient = baseClient
        self.baseURL = baseURL
        self.config = config
        self.sessionStore = sessionStore
        self.settings = settings
        self.appAttestProvider = appAttestProvider
        self.deviceCheckProvider = deviceCheckProvider
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
            refreshToken: normalizedToken(session.refreshToken),
            appAttestKeyID: normalizedToken(session.appAttestKeyID)
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
        appAttestRegistrationTask?.cancel()
        refreshTask = nil
        appAttestRegistrationTask = nil
        try await sessionStore.clear()
    }

    /// Returns `true` when a usable token is stored.
    public func hasSession() async throws -> Bool {
        let session = try await currentSession()
        return normalizedToken(session?.token) != nil
    }

    /// Returns `true` when a refresh token is stored.
    public func hasRefreshToken() async throws -> Bool {
        let session = try await currentSession()
        return normalizedToken(session?.refreshToken) != nil
    }

    /// Returns `true` when an App Attest key ID is stored.
    public func hasAppAttestKey() async throws -> Bool {
        let session = try await currentSession()
        return normalizedToken(session?.appAttestKeyID) != nil
    }

    /// Registers an App Attest key if App Attest is enabled, supported, and not already registered.
    ///
    /// If App Attest is unsupported and the config uses the default `.skip` behavior, this returns
    /// the current session without changing normal token auth.
    @discardableResult
    public func ensureAppAttestRegistered() async throws -> SwiftRestAuthSession? {
        guard settings.appAttestConfig != nil else {
            return try await currentSession()
        }

        if let task = appAttestRegistrationTask {
            return try await consumeAppAttestRegistrationTask(task)
        }

        let task = Task<SwiftRestAuthSession?, Error> {
            try await self.performAppAttestRegistrationIfNeeded()
        }
        appAttestRegistrationTask = task
        defer { appAttestRegistrationTask = nil }
        return try await consumeAppAttestRegistrationTask(task)
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
        let firstRequest = try await integrityProtectedRequest(preparedRequest)
        let raw = try await baseClient.executeRaw(firstRequest, allowHTTPError: true)

        if shouldAttemptRefresh(
               for: request,
               statusCode: raw.statusCode
           ) {
            let refreshedSession = try await refreshSession(triggeringRequest: request)
            if let refreshedSession,
               let refreshedToken = refreshedSession.token,
               refreshedToken != preparedRequest.authToken {
                let retriedRequest = preparedRequest.authToken(refreshedToken)
                let protectedRetriedRequest = try await integrityProtectedRequest(retriedRequest)
                let retried = try await baseClient.executeRaw(protectedRetriedRequest, allowHTTPError: true)
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

        let protectedRefreshRequest = try await integrityProtectedRequest(refreshRequest)
        let raw = try await baseClient.executeRaw(protectedRefreshRequest, allowHTTPError: true)

        guard raw.isSuccess else {
            throw SwiftRestClientError.httpError(makeErrorResponse(from: raw))
        }

        guard let refreshedSession = try buildSession(
            from: raw,
            existingRefreshToken: currentSession?.refreshToken,
            existingAppAttestKeyID: currentSession?.appAttestKeyID,
            requireToken: true
        ) else {
            return currentSession
        }

        try await sessionStore.save(refreshedSession)
        return try await ensureAppAttestRegistered() ?? refreshedSession
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

        let currentSession = try await sessionStore.load()

        guard let session = try buildSession(
            from: raw,
            existingRefreshToken: existingRefreshToken,
            existingAppAttestKeyID: currentSession?.appAttestKeyID,
            requireToken: false
        ) else {
            return
        }

        try await sessionStore.save(session)
        _ = try await ensureAppAttestRegistered()
    }

    private func buildSession(
        from raw: SwiftRestRawResponse,
        existingRefreshToken: String? = nil,
        existingAppAttestKeyID: String? = nil,
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

        return SwiftRestAuthSession(
            token: token,
            refreshToken: refreshToken,
            appAttestKeyID: normalizedToken(existingAppAttestKeyID)
        )
    }

    private func integrityProtectedRequest(_ request: SwiftRestRequest) async throws -> SwiftRestRequest {
        let shouldUseAppAttest = settings.deviceCheckConfig?.mode != .only
        let appAttestResult = shouldUseAppAttest
            ? try await appAttestedRequest(request)
            : SwiftRestIntegrityRequest(request: request, appAttestApplied: false)

        return try await deviceCheckedRequest(
            appAttestResult.request,
            appAttestApplied: appAttestResult.appAttestApplied
        )
    }

    private func appAttestedRequest(_ request: SwiftRestRequest) async throws -> SwiftRestIntegrityRequest {
        guard shouldAttemptAppAttest(for: request) else {
            return SwiftRestIntegrityRequest(request: request, appAttestApplied: false)
        }

        guard try await isAppAttestAvailable(allowFallbackSkip: canDeviceCheckFallback(for: request)) else {
            return SwiftRestIntegrityRequest(request: request, appAttestApplied: false)
        }

        let session = try await currentSession()
        guard let keyID = normalizedToken(session?.appAttestKeyID) else {
            return SwiftRestIntegrityRequest(request: request, appAttestApplied: false)
        }

        do {
            let challenge = try await fetchAppAttestChallenge(purpose: .assertion)
            let clientData = SwiftRestAppAttestClientData(
                challenge: challenge,
                request: request,
                path: appAttestPath(for: request)
            )
            let clientDataBytes = try SwiftRestAppAttestJSON.encodedData(clientData)
            let clientDataHash = SwiftRestAppAttestSHA256.hash(clientDataBytes)
            let assertion = try await appAttestProvider.generateAssertion(keyID, clientDataHash: clientDataHash)
            guard let appAttestConfig = settings.appAttestConfig else {
                return SwiftRestIntegrityRequest(request: request, appAttestApplied: false)
            }

            var copy = request
            copy.addHeader(appAttestConfig.assertionHeaders.keyID, keyID)
            copy.addHeader(appAttestConfig.assertionHeaders.assertion, assertion.base64EncodedString())
            copy.addHeader(appAttestConfig.assertionHeaders.clientData, clientDataBytes.base64EncodedString())
            return SwiftRestIntegrityRequest(request: copy, appAttestApplied: true)
        } catch let error as SwiftRestClientError {
            throw error
        } catch {
            throw SwiftRestClientError.appAttestFailed(underlying: ErrorContext(error))
        }
    }

    private func shouldAttemptAppAttest(for request: SwiftRestRequest) -> Bool {
        guard settings.appAttestConfig != nil else {
            return false
        }

        guard request.appAttestEnabled != false else {
            return false
        }

        return true
    }

    private func canDeviceCheckFallback(for request: SwiftRestRequest) -> Bool {
        guard let deviceCheckConfig = settings.deviceCheckConfig else {
            return false
        }

        guard request.deviceCheckEnabled != false else {
            return false
        }

        return deviceCheckConfig.mode == .fallbackToAppAttest
    }

    private func appAttestPath(for request: SwiftRestRequest) -> String {
        let path = SwiftRestPathUtilities.joinedPath(baseURL.path, request.path)
        return path.hasPrefix("/") ? path : "/\(path)"
    }

    private func isAppAttestAvailable(allowFallbackSkip: Bool = false) async throws -> Bool {
        guard let appAttestConfig = settings.appAttestConfig else {
            return false
        }

        if await appAttestProvider.isSupported() {
            return true
        }

        switch appAttestConfig.unavailableBehavior {
        case .skip:
            return false
        case .fail:
            if allowFallbackSkip {
                return false
            }
            throw SwiftRestClientError.appAttestUnavailable
        }
    }

    private func deviceCheckedRequest(
        _ request: SwiftRestRequest,
        appAttestApplied: Bool
    ) async throws -> SwiftRestRequest {
        guard shouldAttemptDeviceCheck(for: request, appAttestApplied: appAttestApplied) else {
            return request
        }

        guard try await isDeviceCheckAvailable() else {
            return request
        }

        do {
            guard let deviceCheckConfig = settings.deviceCheckConfig else {
                return request
            }

            let token = try await deviceCheckProvider.generateToken()
            var copy = request
            copy.addHeader(deviceCheckConfig.headers.token, token.base64EncodedString())
            return copy
        } catch let error as SwiftRestClientError {
            throw error
        } catch {
            throw SwiftRestClientError.deviceCheckFailed(underlying: ErrorContext(error))
        }
    }

    private func shouldAttemptDeviceCheck(
        for request: SwiftRestRequest,
        appAttestApplied: Bool
    ) -> Bool {
        guard let deviceCheckConfig = settings.deviceCheckConfig else {
            return false
        }

        guard request.deviceCheckEnabled != false else {
            return false
        }

        switch deviceCheckConfig.mode {
        case .fallbackToAppAttest:
            return !appAttestApplied
        case .always, .only:
            return true
        }
    }

    private func isDeviceCheckAvailable() async throws -> Bool {
        guard let deviceCheckConfig = settings.deviceCheckConfig else {
            return false
        }

        if await deviceCheckProvider.isSupported() {
            return true
        }

        switch deviceCheckConfig.unavailableBehavior {
        case .skip:
            return false
        case .fail:
            throw SwiftRestClientError.deviceCheckUnavailable
        }
    }

    private func consumeAppAttestRegistrationTask(
        _ task: Task<SwiftRestAuthSession?, Error>
    ) async throws -> SwiftRestAuthSession? {
        do {
            return try await task.value
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch let clientError as SwiftRestClientError {
            throw clientError
        } catch {
            throw SwiftRestClientError.appAttestFailed(underlying: ErrorContext(error))
        }
    }

    private func performAppAttestRegistrationIfNeeded() async throws -> SwiftRestAuthSession? {
        guard settings.appAttestConfig != nil else {
            return try await currentSession()
        }

        guard try await isAppAttestAvailable() else {
            return try await currentSession()
        }

        let session = try await currentSession()
        guard let session else {
            return nil
        }

        guard normalizedToken(session.appAttestKeyID) == nil else {
            return session
        }

        guard normalizedToken(session.token) != nil else {
            return session
        }

        do {
            return try await performAppAttestRegistration(with: session)
        } catch let error as SwiftRestClientError {
            throw error
        } catch {
            throw SwiftRestClientError.appAttestFailed(underlying: ErrorContext(error))
        }
    }

    private func performAppAttestRegistration(
        with session: SwiftRestAuthSession
    ) async throws -> SwiftRestAuthSession {
        let challenge = try await fetchAppAttestChallenge(purpose: .registration)
        let clientData = SwiftRestAppAttestRegistrationClientData(challenge: challenge)
        let clientDataBytes = try SwiftRestAppAttestJSON.encodedData(clientData)
        let clientDataHash = SwiftRestAppAttestSHA256.hash(clientDataBytes)
        let keyID = normalizedToken(try await appAttestProvider.generateKey())

        guard let keyID else {
            throw SwiftRestClientError.appAttestFailed(
                underlying: ErrorContext(description: "App Attest generated an empty key ID.")
            )
        }

        let attestation = try await appAttestProvider.attestKey(keyID, clientDataHash: clientDataHash)
        let body = SwiftRestAppAttestRegisterRequest(
            keyId: keyID,
            attestationObject: attestation.base64EncodedString(),
            clientData: clientDataBytes.base64EncodedString()
        )

        guard let appAttestConfig = settings.appAttestConfig else {
            return session
        }

        var request = SwiftRestRequest(
            path: appAttestConfig.registerEndpoint,
            method: appAttestConfig.registerMethod
        )
        request.addHeaders(appAttestConfig.headers)
        try request.addJsonBody(body, using: config.jsonCoding.makeEncoder())

        let raw = try await executeAppAttestInternalRaw(request)
        guard raw.isSuccess else {
            throw SwiftRestClientError.httpError(makeErrorResponse(from: raw))
        }

        let registeredSession = SwiftRestAuthSession(
            token: session.token,
            refreshToken: session.refreshToken,
            appAttestKeyID: keyID
        )
        try await sessionStore.save(registeredSession)
        return registeredSession
    }

    private func fetchAppAttestChallenge(
        purpose: SwiftRestAppAttestPurpose
    ) async throws -> String {
        guard let appAttestConfig = settings.appAttestConfig else {
            throw SwiftRestClientError.appAttestFailed(
                underlying: ErrorContext(description: "App Attest is not configured.")
            )
        }

        var request = SwiftRestRequest(
            path: appAttestConfig.challengeEndpoint,
            method: appAttestConfig.challengeMethod
        )
        request.addHeaders(appAttestConfig.headers)

        if appAttestConfig.challengeMethod == .get {
            request.addParameter("purpose", purpose.rawValue)
        } else {
            try request.addJsonBody(
                SwiftRestAppAttestChallengeRequest(purpose: purpose.rawValue),
                using: config.jsonCoding.makeEncoder()
            )
        }

        let raw = try await executeAppAttestInternalRaw(request)
        guard raw.isSuccess else {
            throw SwiftRestClientError.httpError(makeErrorResponse(from: raw))
        }

        guard let response: SwiftRestAppAttestChallengeResponse = try decodeResponseData(
            raw,
            as: SwiftRestAppAttestChallengeResponse.self,
            coding: config.jsonCoding
        ),
            let challenge = normalizedToken(response.challenge)
        else {
            throw SwiftRestClientError.appAttestFailed(
                underlying: ErrorContext(description: "Challenge response missing \"challenge\".")
            )
        }

        return challenge
    }

    private func executeAppAttestInternalRaw(
        _ request: SwiftRestRequest
    ) async throws -> SwiftRestRawResponse {
        var prepared = request

        if !prepared.noAuth, prepared.authToken == nil {
            let session = try await currentSession()
            if let token = normalizedToken(session?.token) {
                prepared = prepared.authToken(token)
            }
        }

        return try await baseClient.executeRaw(prepared, allowHTTPError: true)
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

private struct SwiftRestIntegrityRequest: Sendable {
    var request: SwiftRestRequest
    var appAttestApplied: Bool
}

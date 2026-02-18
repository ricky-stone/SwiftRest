import Foundation

public extension SwiftRestClient {
    /// Starts a chain-based request for a path.
    nonisolated func path(_ path: String) -> SwiftRestPathBuilder {
        SwiftRestPathBuilder(client: self, path: path)
    }
}

/// Chainable request builder from `client.path(...)`.
public struct SwiftRestPathBuilder: Sendable {
    private let client: SwiftRestClient
    private var request: SwiftRestRequest
    private var deferredApplier: @Sendable (inout SwiftRestRequest, SwiftRestJSONCoding) throws -> Void

    init(client: SwiftRestClient, path: String) {
        self.client = client
        self.request = SwiftRestRequest(path: path, method: .get)
        self.deferredApplier = { _, _ in }
    }

    public func header(_ name: String, _ value: String) -> Self {
        var copy = self
        copy.request.addHeader(name, value)
        return copy
    }

    public func headers(_ values: [String: String]) -> Self {
        var copy = self
        copy.request.addHeaders(values)
        return copy
    }

    public func parameter(_ key: String, _ value: String) -> Self {
        var copy = self
        copy.request.addParameter(key, value)
        return copy
    }

    public func parameters(_ values: [String: String]) -> Self {
        var copy = self
        copy.request.addParameters(values)
        return copy
    }

    public func query<Query: Encodable & Sendable>(
        _ query: Query
    ) throws -> Self {
        var copy = self
        copy.appendDeferredApplier { request, coding in
            try request.addQuery(query, using: coding.makeEncoder())
        }
        return copy
    }

    public func authToken(_ token: String) -> Self {
        var copy = self
        copy.request.addAuthToken(token)
        return copy
    }

    public func retry(_ policy: RetryPolicy) -> Self {
        var copy = self
        copy.request.configureRetryPolicy(policy)
        return copy
    }

    public func json(_ coding: SwiftRestJSONCoding) -> Self {
        var copy = self
        copy.request.configureJSONCoding(coding)
        return copy
    }

    public func jsonDates(_ dates: SwiftRestJSONDates) -> Self {
        var copy = self
        let coding = (copy.request.jsonCoding ?? .foundationDefault)
            .dateDecodingStrategy(dates.decodingStrategy)
            .dateEncodingStrategy(dates.encodingStrategy)
        copy.request.configureJSONCoding(coding)
        return copy
    }

    public func jsonKeys(_ keys: SwiftRestJSONKeys) -> Self {
        var copy = self
        let coding = (copy.request.jsonCoding ?? .foundationDefault)
            .keyDecodingStrategy(keys.decodingStrategy)
            .keyEncodingStrategy(keys.encodingStrategy)
        copy.request.configureJSONCoding(coding)
        return copy
    }

    public func get() -> SwiftRestPreparedRequest {
        prepared(method: .get)
    }

    public func delete() -> SwiftRestPreparedRequest {
        prepared(method: .delete)
    }

    public func post<Body: Encodable & Sendable>(
        body: Body
    ) throws -> SwiftRestPreparedRequest {
        try prepared(method: .post, body: body)
    }

    public func put<Body: Encodable & Sendable>(
        body: Body
    ) throws -> SwiftRestPreparedRequest {
        try prepared(method: .put, body: body)
    }

    public func patch<Body: Encodable & Sendable>(
        body: Body
    ) throws -> SwiftRestPreparedRequest {
        try prepared(method: .patch, body: body)
    }

    private func prepared(method: HTTPMethod) -> SwiftRestPreparedRequest {
        var copy = request
        copy.configureMethod(method)
        return SwiftRestPreparedRequest(
            client: client,
            request: copy,
            requestApplier: deferredApplier
        )
    }

    private func prepared<Body: Encodable & Sendable>(
        method: HTTPMethod,
        body: Body
    ) throws -> SwiftRestPreparedRequest {
        var copy = request
        copy.configureMethod(method)
        let inheritedApplier = deferredApplier
        return SwiftRestPreparedRequest(
            client: client,
            request: copy,
            requestApplier: { request, coding in
                try inheritedApplier(&request, coding)
                try request.addJsonBody(body, using: coding.makeEncoder())
            }
        )
    }

    private mutating func appendDeferredApplier(
        _ applier: @escaping @Sendable (inout SwiftRestRequest, SwiftRestJSONCoding) throws -> Void
    ) {
        let existing = deferredApplier
        deferredApplier = { request, coding in
            try existing(&request, coding)
            try applier(&request, coding)
        }
    }
}

/// Final request stage with terminal output methods.
public struct SwiftRestPreparedRequest: Sendable {
    private let client: SwiftRestClient
    private let baseRequest: SwiftRestRequest
    private let requestApplier: @Sendable (inout SwiftRestRequest, SwiftRestJSONCoding) throws -> Void

    init(
        client: SwiftRestClient,
        request: SwiftRestRequest,
        requestApplier: @escaping @Sendable (inout SwiftRestRequest, SwiftRestJSONCoding) throws -> Void = { _, _ in }
    ) {
        self.client = client
        self.baseRequest = request
        self.requestApplier = requestApplier
    }

    private func materializedRequest() async throws -> SwiftRestRequest {
        try await client.materialize(
            baseRequest: baseRequest,
            bodyApplier: requestApplier
        )
    }

    @discardableResult
    public func value<T: Decodable & Sendable>(
        as type: T.Type = T.self
    ) async throws -> T {
        let request = try await materializedRequest()
        return try await client.execute(request, as: type)
    }

    public func response<T: Decodable & Sendable>(
        as type: T.Type = T.self
    ) async throws -> SwiftRestResponse<T> {
        _ = type
        let request = try await materializedRequest()
        return try await client.executeAsyncWithResponse(request)
    }

    public func raw(
        allowHTTPError: Bool = true
    ) async throws -> SwiftRestRawResponse {
        let request = try await materializedRequest()
        return try await client.executeRaw(request, allowHTTPError: allowHTTPError)
    }

    public func result<Success: Decodable & Sendable, APIError: Decodable & Sendable>(
        as successType: Success.Type = Success.self,
        error errorType: APIError.Type = APIError.self
    ) async -> SwiftRestResult<Success, APIError> {
        let request: SwiftRestRequest
        do {
            request = try await materializedRequest()
        } catch let error as SwiftRestClientError {
            return .failure(error)
        } catch {
            return .failure(.networkError(underlying: ErrorContext(error)))
        }
        return await client.executeResult(request, as: successType, error: errorType)
    }

    public func valueAndHeaders<T: Decodable & Sendable>(
        as type: T.Type = T.self
    ) async throws -> (value: T, headers: HTTPHeaders) {
        let response: SwiftRestResponse<T> = try await self.response(as: type)
        guard let value = response.data else {
            throw SwiftRestClientError.emptyResponseBody(expectedType: String(describing: type))
        }
        return (value, response.headers)
    }
}

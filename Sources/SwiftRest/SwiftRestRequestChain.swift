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
        self.request = SwiftRestRequest(path: Self.normalizedPath(path), method: .get)
        self.deferredApplier = { _, _ in }
    }

    /// Appends one path segment.
    ///
    /// You do not need to manually add `/` between segments.
    /// Supports primitives like `String`, `Int`, `Bool`, `Double`, and `UUID`.
    public func path<Segment: SwiftRestPathSegmentConvertible>(_ segment: Segment) -> Self {
        var copy = self
        copy.request.configurePath(
            Self.joinedPath(copy.request.path, segment.swiftRestPathSegment)
        )
        return copy
    }

    /// Appends path components from a URL.
    ///
    /// Only `url.path` is used. Scheme, host, query, and fragment are ignored.
    public func path(url: URL) -> Self {
        paths(Self.pathSegments(from: url.path))
    }

    /// Appends multiple path segments.
    ///
    /// You do not need to manually add `/` between segments.
    public func paths(_ segments: any SwiftRestPathSegmentConvertible...) -> Self {
        var copy = self
        for segment in segments {
            copy.request.configurePath(
                Self.joinedPath(copy.request.path, segment.swiftRestPathSegment)
            )
        }
        return copy
    }

    /// Appends a sequence of path segments.
    ///
    /// You do not need to manually add `/` between segments.
    public func paths<S: Sequence>(_ segments: S) -> Self where S.Element: SwiftRestPathSegmentConvertible {
        var copy = self
        for segment in segments {
            copy.request.configurePath(
                Self.joinedPath(copy.request.path, segment.swiftRestPathSegment)
            )
        }
        return copy
    }

    /// Appends a sequence of type-erased path segments.
    ///
    /// Useful when your segments are stored as `[any SwiftRestPathSegmentConvertible]`.
    public func paths<S: Sequence>(_ segments: S) -> Self
    where S.Element == any SwiftRestPathSegmentConvertible {
        var copy = self
        for segment in segments {
            copy.request.configurePath(
                Self.joinedPath(copy.request.path, segment.swiftRestPathSegment)
            )
        }
        return copy
    }

    /// Adds/overwrites a header for this request only.
    public func header(_ name: String, _ value: String) -> Self {
        var copy = self
        copy.request.addHeader(name, value)
        return copy
    }

    /// Adds/overwrites multiple headers for this request only.
    public func headers(_ values: [String: String]) -> Self {
        var copy = self
        copy.request.addHeaders(values)
        return copy
    }

    /// Adds/overwrites one query parameter for this request.
    public func parameter(_ key: String, _ value: String) -> Self {
        var copy = self
        copy.request.addParameter(key, value)
        return copy
    }

    /// Adds/overwrites multiple query parameters for this request.
    public func parameters(_ values: [String: String]) -> Self {
        var copy = self
        copy.request.addParameters(values)
        return copy
    }

    /// Encodes an `Encodable` query model into URL query parameters.
    public func query<Query: Encodable & Sendable>(
        _ query: Query
    ) throws -> Self {
        var copy = self
        copy.appendDeferredApplier { request, coding in
            try request.addQuery(query, using: coding.makeEncoder())
        }
        return copy
    }

    /// Sets a per-request bearer token.
    ///
    /// Precedence: per-request token > provider token > static client token.
    public func authToken(_ token: String) -> Self {
        var copy = self
        copy.request.addAuthToken(token)
        return copy
    }

    /// Enables/disables auth header injection for this request.
    public func noAuth(_ disabled: Bool = true) -> Self {
        var copy = self
        copy.request = copy.request.noAuth(disabled)
        return copy
    }

    /// Enables/disables auth refresh handling for this request.
    public func autoRefresh(_ enabled: Bool) -> Self {
        var copy = self
        copy.request.configureAutoRefresh(enabled)
        return copy
    }

    /// Overrides refresh-token lookup for this request if refresh is triggered.
    public func refreshTokenProvider(
        _ provider: @escaping SwiftRestRefreshTokenProvider
    ) -> Self {
        var copy = self
        copy.request.configureRefreshTokenProvider(provider)
        return copy
    }

    /// Overrides retry policy for this request only.
    public func retry(_ policy: RetryPolicy) -> Self {
        var copy = self
        copy.request.configureRetryPolicy(policy)
        return copy
    }

    /// Overrides full JSON coding strategy for this request only.
    public func json(_ coding: SwiftRestJSONCoding) -> Self {
        var copy = self
        copy.request.configureJSONCoding(coding)
        return copy
    }

    /// Overrides simplified date coding behavior for this request only.
    public func jsonDates(_ dates: SwiftRestJSONDates) -> Self {
        var copy = self
        let coding = (copy.request.jsonCoding ?? .foundationDefault)
            .dateDecodingStrategy(dates.decodingStrategy)
            .dateEncodingStrategy(dates.encodingStrategy)
        copy.request.configureJSONCoding(coding)
        return copy
    }

    /// Overrides simplified key coding behavior for this request only.
    public func jsonKeys(_ keys: SwiftRestJSONKeys) -> Self {
        var copy = self
        let coding = (copy.request.jsonCoding ?? .foundationDefault)
            .keyDecodingStrategy(keys.decodingStrategy)
            .keyEncodingStrategy(keys.encodingStrategy)
        copy.request.configureJSONCoding(coding)
        return copy
    }

    /// Prepares a `GET` request.
    public func get() -> SwiftRestPreparedRequest {
        prepared(method: .get)
    }

    /// Prepares a `HEAD` request.
    public func head() -> SwiftRestPreparedRequest {
        prepared(method: .head)
    }

    /// Prepares an `OPTIONS` request.
    public func options() -> SwiftRestPreparedRequest {
        prepared(method: .options)
    }

    /// Prepares a `DELETE` request.
    public func delete() -> SwiftRestPreparedRequest {
        prepared(method: .delete)
    }

    /// Prepares a `POST` request with a JSON-encoded body.
    public func post<Body: Encodable & Sendable>(
        body: Body
    ) throws -> SwiftRestPreparedRequest {
        try prepared(method: .post, body: body)
    }

    /// Prepares a `PUT` request with a JSON-encoded body.
    public func put<Body: Encodable & Sendable>(
        body: Body
    ) throws -> SwiftRestPreparedRequest {
        try prepared(method: .put, body: body)
    }

    /// Prepares a `PATCH` request with a JSON-encoded body.
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

    private static func joinedPath(_ current: String, _ next: String) -> String {
        let segments = pathSegments(from: current) + pathSegments(from: next)
        return segments.joined(separator: "/")
    }

    private static func normalizedPath(_ path: String) -> String {
        pathSegments(from: path).joined(separator: "/")
    }

    private static func pathSegments(from rawPath: String) -> [String] {
        rawPath
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "/")
            .map(String.init)
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

    /// Executes request and returns a decoded value.
    @discardableResult
    public func value<T: Decodable & Sendable>(
        as type: T.Type = T.self
    ) async throws -> T {
        let request = try await materializedRequest()
        return try await client.execute(request, as: type)
    }

    /// Executes request and returns decoded payload plus response metadata.
    public func response<T: Decodable & Sendable>(
        as type: T.Type = T.self
    ) async throws -> SwiftRestResponse<T> {
        _ = type
        let request = try await materializedRequest()
        return try await client.executeAsyncWithResponse(request)
    }

    /// Executes request and returns raw payload + headers.
    ///
    /// Defaults to `allowHTTPError = true` to simplify status-code inspection.
    public func raw(
        allowHTTPError: Bool = true
    ) async throws -> SwiftRestRawResponse {
        let request = try await materializedRequest()
        return try await client.executeRaw(request, allowHTTPError: allowHTTPError)
    }

    /// Executes request when you only care about success/failure.
    ///
    /// Throws for non-2xx responses and transport/decoding errors.
    public func send() async throws {
        let request = try await materializedRequest()
        try await client.executeAsyncWithoutResponse(request)
    }

    /// Executes request and returns result-style success/apiError/failure output.
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

    /// Executes request and returns both decoded value and response headers.
    ///
    /// Throws `emptyResponseBody` when the response has no decodable payload.
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

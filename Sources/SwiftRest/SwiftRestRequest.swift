import Foundation

/// Represents a request to execute against a REST API.
public struct SwiftRestRequest: Sendable {
    public private(set) var path: String
    public private(set) var method: HTTPMethod
    public private(set) var headers: HTTPHeaders
    public private(set) var parameters: [String: String]
    public private(set) var body: Data?
    public private(set) var authToken: String?
    public private(set) var retryPolicy: RetryPolicy?
    public private(set) var jsonCoding: SwiftRestJSONCoding?

    public init(path: String, method: HTTPMethod = .get) {
        self.path = path
        self.method = method
        self.headers = HTTPHeaders()
        self.parameters = [:]
        self.body = nil
        self.authToken = nil
        self.retryPolicy = nil
        self.jsonCoding = nil
    }

    // MARK: - Mutating API

    public mutating func addHeader(_ key: String, _ value: String) {
        headers.set(value, for: key)
    }

    public mutating func addHeaders(_ values: [String: String]) {
        for (key, value) in values {
            headers.set(value, for: key)
        }
    }

    public mutating func addParameter(_ key: String, _ value: String) {
        parameters[key] = value
    }

    public mutating func addParameters(_ values: [String: String]) {
        for (key, value) in values {
            parameters[key] = value
        }
    }

    public mutating func addQuery<Query: Encodable & Sendable>(
        _ query: Query,
        using encoder: JSONEncoder = JSONEncoder()
    ) throws {
        let encoded = try SwiftRestQuery.encode(query, using: encoder)
        addParameters(encoded)
    }

    public mutating func addJsonBody<T: Encodable & Sendable>(
        _ object: T,
        using encoder: JSONEncoder = JSONEncoder()
    ) throws {
        self.body = try encoder.encode(object)
        if headers["content-type"] == nil {
            headers.set("application/json", for: "Content-Type")
        }
    }

    public mutating func addJsonBody<T: Encodable & Sendable>(
        _ object: T,
        using coding: SwiftRestJSONCoding
    ) throws {
        try addJsonBody(object, using: coding.makeEncoder())
    }

    public mutating func addRawBody(_ data: Data, contentType: String? = nil) {
        self.body = data
        if let contentType {
            headers.set(contentType, for: "Content-Type")
        }
    }

    public mutating func addRawBody(_ string: String, contentType: String? = "text/plain") {
        self.body = string.data(using: .utf8)
        if let contentType {
            headers.set(contentType, for: "Content-Type")
        }
    }

    public mutating func addAuthToken(_ token: String) {
        self.authToken = token
    }

    /// Backward-compatible retry configuration.
    ///
    /// `maxRetries` means retries after the first attempt.
    public mutating func configureRetries(maxRetries: Int, retryDelay: TimeInterval) {
        let maxAttempts = max(1, maxRetries + 1)
        self.retryPolicy = RetryPolicy(
            maxAttempts: maxAttempts,
            baseDelay: retryDelay,
            backoffMultiplier: 1,
            maxDelay: retryDelay,
            retryableStatusCodes: [408, 429, 500, 502, 503, 504],
            retryOnNetworkErrors: true
        )
    }

    public mutating func configureRetryPolicy(_ policy: RetryPolicy) {
        self.retryPolicy = policy
    }

    public mutating func configureMethod(_ method: HTTPMethod) {
        self.method = method
    }

    public mutating func configureJSONCoding(_ coding: SwiftRestJSONCoding) {
        self.jsonCoding = coding
    }

    public mutating func configureDateDecodingStrategy(
        _ strategy: SwiftRestJSONCoding.DateDecodingStrategy
    ) {
        if jsonCoding == nil {
            jsonCoding = .foundationDefault
        }
        jsonCoding = jsonCoding?.dateDecodingStrategy(strategy)
    }

    public mutating func configureKeyDecodingStrategy(
        _ strategy: SwiftRestJSONCoding.KeyDecodingStrategy
    ) {
        if jsonCoding == nil {
            jsonCoding = .foundationDefault
        }
        jsonCoding = jsonCoding?.keyDecodingStrategy(strategy)
    }

    // MARK: - Chainable API

    public func header(_ key: String, _ value: String) -> Self {
        var copy = self
        copy.addHeader(key, value)
        return copy
    }

    public func headers(_ values: [String: String]) -> Self {
        var copy = self
        copy.addHeaders(values)
        return copy
    }

    public func parameter(_ key: String, _ value: String) -> Self {
        var copy = self
        copy.addParameter(key, value)
        return copy
    }

    public func parameters(_ values: [String: String]) -> Self {
        var copy = self
        copy.addParameters(values)
        return copy
    }

    public func query<Query: Encodable & Sendable>(
        _ query: Query,
        using encoder: JSONEncoder = JSONEncoder()
    ) throws -> Self {
        var copy = self
        try copy.addQuery(query, using: encoder)
        return copy
    }

    public func jsonBody<T: Encodable & Sendable>(
        _ object: T,
        using encoder: JSONEncoder = JSONEncoder()
    ) throws -> Self {
        var copy = self
        try copy.addJsonBody(object, using: encoder)
        return copy
    }

    public func jsonBody<T: Encodable & Sendable>(
        _ object: T,
        using coding: SwiftRestJSONCoding
    ) throws -> Self {
        var copy = self
        try copy.addJsonBody(object, using: coding)
        return copy
    }

    public func rawBody(_ data: Data, contentType: String? = nil) -> Self {
        var copy = self
        copy.addRawBody(data, contentType: contentType)
        return copy
    }

    public func rawBody(_ text: String, contentType: String? = "text/plain") -> Self {
        var copy = self
        copy.addRawBody(text, contentType: contentType)
        return copy
    }

    public func authToken(_ token: String) -> Self {
        var copy = self
        copy.addAuthToken(token)
        return copy
    }

    public func retries(maxRetries: Int, retryDelay: TimeInterval) -> Self {
        var copy = self
        copy.configureRetries(maxRetries: maxRetries, retryDelay: retryDelay)
        return copy
    }

    public func retryPolicy(_ policy: RetryPolicy) -> Self {
        var copy = self
        copy.configureRetryPolicy(policy)
        return copy
    }

    public func method(_ method: HTTPMethod) -> Self {
        var copy = self
        copy.configureMethod(method)
        return copy
    }

    public func jsonCoding(_ coding: SwiftRestJSONCoding) -> Self {
        var copy = self
        copy.configureJSONCoding(coding)
        return copy
    }

    public func dateDecodingStrategy(
        _ strategy: SwiftRestJSONCoding.DateDecodingStrategy
    ) -> Self {
        var copy = self
        copy.configureDateDecodingStrategy(strategy)
        return copy
    }

    public func keyDecodingStrategy(
        _ strategy: SwiftRestJSONCoding.KeyDecodingStrategy
    ) -> Self {
        var copy = self
        copy.configureKeyDecodingStrategy(strategy)
        return copy
    }
}

public extension SwiftRestRequest {
    static func get(_ path: String) -> SwiftRestRequest {
        SwiftRestRequest(path: path, method: .get)
    }

    static func post(_ path: String) -> SwiftRestRequest {
        SwiftRestRequest(path: path, method: .post)
    }

    static func put(_ path: String) -> SwiftRestRequest {
        SwiftRestRequest(path: path, method: .put)
    }

    static func patch(_ path: String) -> SwiftRestRequest {
        SwiftRestRequest(path: path, method: .patch)
    }

    static func delete(_ path: String) -> SwiftRestRequest {
        SwiftRestRequest(path: path, method: .delete)
    }
}

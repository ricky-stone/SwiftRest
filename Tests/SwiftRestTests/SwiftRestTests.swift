import Foundation
import Testing
@testable import SwiftRest

struct Dummy: Codable, Equatable, Sendable {
    let id: Int
    let name: String
}

struct ConfigFeatureFlags: Codable, Equatable, Sendable {
    let vision: Bool
    let matches: Bool
}

struct CamelConfigResponse: Codable, Equatable, Sendable {
    let maintenanceMode: Bool
    let maintenanceMessage: String
    let featureFlags: ConfigFeatureFlags
    let parameters: [String: String]
    let updatedUtc: Date
}

struct SnakeConfigResponse: Codable, Equatable, Sendable {
    let maintenanceMode: Bool
    let maintenanceMessage: String
    let updatedUtc: Date
}

private struct APIErrorPayload: Codable, Equatable, Sendable {
    let message: String
    let code: String?
}

private struct UserListQuery: Encodable, Sendable {
    let page: Int
    let search: String
    let includeInactive: Bool
}

private struct NestedQueryFlags: Encodable, Sendable {
    let featured: Bool
}

private struct NestedUserQuery: Encodable, Sendable {
    let page: Int
    let flags: NestedQueryFlags
}

private struct RefreshTokenBody: Encodable, Sendable {
    let refreshToken: String
}

private struct RefreshTokenResponse: Decodable, Sendable {
    let accessToken: String
}

private final class EchoAuthURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let observedAuthorization = request.value(forHTTPHeaderField: "Authorization") ?? "none"
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "Content-Type": "application/json",
                "X-Observed-Authorization": observedAuthorization
            ]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class EchoQueryURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let rawQuery = url.query ?? "none"
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "Content-Type": "application/json",
                "X-Observed-Query": rawQuery
            ]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class MethodEchoURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let method = request.httpMethod ?? "UNKNOWN"
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "X-Observed-Method": method
            ]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class SimpleSuccessURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class RefreshAuthURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let authorization = request.value(forHTTPHeaderField: "Authorization") ?? "none"
        let isFresh = authorization == "Bearer fresh-token"
        let statusCode = isFresh ? 200 : 401
        let body = isFresh
            ? #"{"id":1,"name":"Alice"}"#
            : #"{"message":"Unauthorized","code":"unauthorized"}"#

        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: [
                "Content-Type": "application/json",
                "X-Observed-Authorization": authorization
            ]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class RefreshForbiddenAuthURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let authorization = request.value(forHTTPHeaderField: "Authorization") ?? "none"
        let isFresh = authorization == "Bearer fresh-token"
        let statusCode = isFresh ? 200 : 403
        let body = isFresh
            ? #"{"id":1,"name":"Alice"}"#
            : #"{"message":"Forbidden","code":"forbidden"}"#

        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: [
                "Content-Type": "application/json",
                "X-Observed-Authorization": authorization
            ]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class EndpointRefreshState: @unchecked Sendable {
    static let shared = EndpointRefreshState()

    private let lock = NSLock()
    private var refreshCalls: Int = 0
    private var refreshAuthHeaders: [String] = []
    private var refreshBodies: [String] = []

    func reset() {
        lock.lock()
        refreshCalls = 0
        refreshAuthHeaders = []
        refreshBodies = []
        lock.unlock()
    }

    func record(authHeader: String, body: String) {
        lock.lock()
        refreshCalls += 1
        refreshAuthHeaders.append(authHeader)
        refreshBodies.append(body)
        lock.unlock()
    }

    func snapshot() -> (refreshCalls: Int, refreshAuthHeaders: [String], refreshBodies: [String]) {
        lock.lock()
        defer { lock.unlock() }
        return (refreshCalls, refreshAuthHeaders, refreshBodies)
    }
}

private final class EndpointRefreshURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        if url.path == "/auth/refresh" {
            let auth = request.value(forHTTPHeaderField: "Authorization") ?? "none"
            let bodyText = requestBodyText(request)
            EndpointRefreshState.shared.record(authHeader: auth, body: bodyText)
            respond(url: url, statusCode: 200, body: #"{"accessToken":"fresh-token"}"#)
            return
        }

        let authorization = request.value(forHTTPHeaderField: "Authorization") ?? "none"
        if authorization == "Bearer fresh-token" {
            respond(url: url, statusCode: 200, body: #"{"id":1,"name":"Alice"}"#)
        } else {
            respond(url: url, statusCode: 401, body: #"{"message":"Unauthorized"}"#)
        }
    }

    override func stopLoading() {}

    private func respond(url: URL, statusCode: Int, body: String) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

private final class EndpointRefreshForbiddenURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        if url.path == "/auth/refresh" {
            let auth = request.value(forHTTPHeaderField: "Authorization") ?? "none"
            let bodyText = requestBodyText(request)
            EndpointRefreshState.shared.record(authHeader: auth, body: bodyText)
            respond(url: url, statusCode: 200, body: #"{"accessToken":"fresh-token"}"#)
            return
        }

        let authorization = request.value(forHTTPHeaderField: "Authorization") ?? "none"
        if authorization == "Bearer fresh-token" {
            respond(url: url, statusCode: 200, body: #"{"id":1,"name":"Alice"}"#)
        } else {
            respond(url: url, statusCode: 403, body: #"{"message":"Forbidden"}"#)
        }
    }

    override func stopLoading() {}

    private func respond(url: URL, statusCode: Int, body: String) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

private final class EndpointRefreshWithRefreshTokenURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        if url.path == "/auth/refresh" {
            let auth = request.value(forHTTPHeaderField: "Authorization") ?? "none"
            let bodyText = requestBodyText(request)
            EndpointRefreshState.shared.record(authHeader: auth, body: bodyText)
            respond(
                url: url,
                statusCode: 200,
                body: #"{"accessToken":"fresh-token","refreshToken":"fresh-refresh-token"}"#
            )
            return
        }

        let authorization = request.value(forHTTPHeaderField: "Authorization") ?? "none"
        if authorization == "Bearer fresh-token" {
            respond(url: url, statusCode: 200, body: #"{"id":1,"name":"Alice"}"#)
        } else {
            respond(url: url, statusCode: 401, body: #"{"message":"Unauthorized"}"#)
        }
    }

    override func stopLoading() {}

    private func respond(url: URL, statusCode: Int, body: String) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

private func requestBodyText(_ request: URLRequest) -> String {
    if let body = request.httpBody,
       !body.isEmpty {
        return String(data: body, encoding: .utf8) ?? ""
    }

    guard let stream = request.httpBodyStream else {
        return ""
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let readCount = stream.read(buffer, maxLength: bufferSize)
        if readCount <= 0 {
            break
        }
        data.append(buffer, count: readCount)
    }

    return String(data: data, encoding: .utf8) ?? ""
}

private final class ResultScenarioURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        switch url.path {
        case "/result-success":
            respond(
                url: url,
                statusCode: 200,
                body: #"{"id":42,"name":"Result User"}"#
            )
        case "/result-api-error":
            respond(
                url: url,
                statusCode: 422,
                body: #"{"message":"Invalid request","code":"validation_failed"}"#
            )
        case "/result-api-error-plain":
            respond(
                url: url,
                statusCode: 500,
                body: "oops"
            )
        case "/result-network-failure":
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        default:
            respond(url: url, statusCode: 404, body: #"{"message":"Not found","code":"missing"}"#)
        }
    }

    override func stopLoading() {}

    private func respond(url: URL, statusCode: Int, body: String) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

private func makeAuthEchoClient(config: SwiftRestConfig = .standard) throws -> SwiftRestClient {
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [EchoAuthURLProtocol.self]
    let session = URLSession(configuration: sessionConfiguration)
    return try SwiftRestClient("https://api.example.com", config: config, session: session)
}

private func makeQueryEchoClient(config: SwiftRestConfig = .standard) throws -> SwiftRestClient {
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [EchoQueryURLProtocol.self]
    let session = URLSession(configuration: sessionConfiguration)
    return try SwiftRestClient("https://api.example.com", config: config, session: session)
}

private func makeMethodEchoClient(config: SwiftRestConfig = .standard) throws -> SwiftRestClient {
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [MethodEchoURLProtocol.self]
    let session = URLSession(configuration: sessionConfiguration)
    return try SwiftRestClient("https://api.example.com", config: config, session: session)
}

private func makeSimpleSuccessClient(config: SwiftRestConfig = .standard) throws -> SwiftRestClient {
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [SimpleSuccessURLProtocol.self]
    let session = URLSession(configuration: sessionConfiguration)
    return try SwiftRestClient("https://api.example.com", config: config, session: session)
}

private func makeRefreshAuthClient(config: SwiftRestConfig = .standard) throws -> SwiftRestClient {
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [RefreshAuthURLProtocol.self]
    let session = URLSession(configuration: sessionConfiguration)
    return try SwiftRestClient("https://api.example.com", config: config, session: session)
}

private func makeRefreshForbiddenAuthClient(config: SwiftRestConfig = .standard) throws -> SwiftRestClient {
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [RefreshForbiddenAuthURLProtocol.self]
    let session = URLSession(configuration: sessionConfiguration)
    return try SwiftRestClient("https://api.example.com", config: config, session: session)
}

private func makeResultScenarioClient(config: SwiftRestConfig = .standard) throws -> SwiftRestClient {
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [ResultScenarioURLProtocol.self]
    let session = URLSession(configuration: sessionConfiguration)
    return try SwiftRestClient("https://api.example.com", config: config, session: session)
}

private func makeEndpointRefreshSession() -> URLSession {
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [EndpointRefreshURLProtocol.self]
    return URLSession(configuration: sessionConfiguration)
}

private func makeEndpointRefreshForbiddenSession() -> URLSession {
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [EndpointRefreshForbiddenURLProtocol.self]
    return URLSession(configuration: sessionConfiguration)
}

private func makeEndpointRefreshWithRefreshTokenSession() -> URLSession {
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [EndpointRefreshWithRefreshTokenURLProtocol.self]
    return URLSession(configuration: sessionConfiguration)
}

private final class LogCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var messages: [String] = []

    func append(_ message: String) {
        lock.lock()
        messages.append(message)
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return messages
    }
}

private actor AsyncCounter {
    private var value: Int = 0

    func increment() {
        value += 1
    }

    func current() -> Int {
        value
    }
}

private actor RefreshedTokensSink {
    private var accessTokens: [String] = []
    private var refreshTokens: [String?] = []

    func append(accessToken: String, refreshToken: String?) {
        accessTokens.append(accessToken)
        refreshTokens.append(refreshToken)
    }

    func snapshot() -> (accessTokens: [String], refreshTokens: [String?]) {
        (accessTokens, refreshTokens)
    }
}

@Test func testJsonHelperEncodingDecoding() throws {
    let dummy = Dummy(id: 1, name: "Alice")

    let jsonData = try Json.toData(object: dummy)
    let decoded: Dummy = try Json.parse(data: jsonData)

    #expect(decoded == dummy)
}

@Test func testSwiftRestRequestMutatingAndChainableStyles() throws {
    var mutating = SwiftRestRequest(path: "users", method: .post)
    mutating.addHeader("Content-Type", "application/json")
    mutating.addParameter("page", "1")
    try mutating.addJsonBody(["name": "Ricky"])
    mutating.addAuthToken("token")
    mutating.configureRetries(maxRetries: 2, retryDelay: 0.25)

    #expect(mutating.headers["content-type"] == "application/json")
    #expect(mutating.parameters["page"] == "1")
    #expect(mutating.body != nil)
    #expect(mutating.authToken == "token")
    #expect(mutating.retryPolicy?.maxAttempts == 3)

    let chainable = SwiftRestRequest.get("users")
        .header("X-App", "Demo")
        .parameter("page", "2")
        .retries(maxRetries: 1, retryDelay: 0.1)

    #expect(chainable.headers["x-app"] == "Demo")
    #expect(chainable.parameters["page"] == "2")
    #expect(chainable.retryPolicy?.maxAttempts == 2)

    let queryRequest = try SwiftRestRequest.get("users").query(
        UserListQuery(page: 1, search: "ricky", includeInactive: false)
    )
    #expect(queryRequest.parameters["page"] == "1")
    #expect(queryRequest.parameters["search"] == "ricky")
    #expect(queryRequest.parameters["includeInactive"] == "false")
}

@Test func testSwiftRestRequestStaticHelpersIncludeHeadAndOptions() {
    let headRequest = SwiftRestRequest.head("health")
    #expect(headRequest.method == .head)
    #expect(headRequest.path == "health")

    let optionsRequest = SwiftRestRequest.options("users")
    #expect(optionsRequest.method == .options)
    #expect(optionsRequest.path == "users")
}

@Test func testRawResponseHelpers() throws {
    let body = #"{"id":1,"name":"Alice"}"#.data(using: .utf8)!
    let response = SwiftRestRawResponse(
        statusCode: 200,
        data: nil,
        rawData: body,
        headers: ["Content-Type": "application/json"]
    )

    #expect(response.isSuccess)
    #expect(response.header("content-type") == "application/json")
    #expect(response.text() == #"{"id":1,"name":"Alice"}"#)

    let decoded: Dummy = try response.decodeBody(Dummy.self)
    #expect(decoded == Dummy(id: 1, name: "Alice"))

    let object = try response.jsonObject() as? [String: Any]
    #expect(object?["name"] as? String == "Alice")
}

@Test func testMockRestClientDecodingAndHTTPError() async throws {
    let okClient = MockRestClient { _ in
        SwiftRestRawResponse(
            statusCode: 200,
            data: nil,
            rawData: #"{"id":2,"name":"Bob"}"#.data(using: .utf8)!,
            headers: ["Content-Type": "application/json"]
        )
    }

    let okRequest = SwiftRestRequest(path: "users/2")
    let okResponse: SwiftRestResponse<Dummy> = try await okClient.executeAsyncWithResponse(okRequest)
    #expect(okResponse.data == Dummy(id: 2, name: "Bob"))

    let failingClient = MockRestClient { _ in
        SwiftRestRawResponse(
            statusCode: 404,
            data: nil,
            rawData: #"{"reason":"Not found"}"#.data(using: .utf8)!,
            headers: ["Content-Type": "application/json"]
        )
    }

    do {
        _ = try await failingClient.executeRaw(okRequest)
        #expect(Bool(false))
    } catch let error as SwiftRestClientError {
        switch error {
        case .httpError(let details):
            #expect(details.statusCode == 404)
            #expect(details.rawPayload?.contains("Not found") == true)
        default:
            #expect(Bool(false))
        }
    }

    let raw = try await failingClient.executeRaw(okRequest, allowHTTPError: true)
    #expect(raw.statusCode == 404)
}

@Test func testSwiftRestClientInvalidBaseURL() {
    do {
        _ = try SwiftRestClient("not a url")
        #expect(Bool(false))
    } catch let error as SwiftRestClientError {
        switch error {
        case .invalidBaseURL:
            #expect(Bool(true))
        default:
            #expect(Bool(false))
        }
    } catch {
        #expect(Bool(false))
    }
}

@Test func testJSONCodingIso8601ForCamelCasePayload() async throws {
    let payload = #"""
    {
        "maintenanceMode": false,
        "maintenanceMessage": "",
        "featureFlags": {
            "vision": true,
            "matches": true
        },
        "parameters": {},
        "updatedUtc": "2026-02-14T22:46:14.289Z"
    }
    """#.data(using: .utf8)!

    let client = MockRestClient { _ in
        SwiftRestRawResponse(
            statusCode: 200,
            data: nil,
            rawData: payload,
            headers: ["Content-Type": "application/json"]
        )
    }

    var request = SwiftRestRequest(path: "config", method: .get)
    request.configureDateDecodingStrategy(.iso8601)

    let response: SwiftRestResponse<CamelConfigResponse> =
        try await client.executeAsyncWithResponse(request)
    #expect(response.data?.maintenanceMode == false)
    #expect(response.data?.featureFlags.vision == true)
}

@Test func testJSONCodingWebAPISnakeCasePreset() throws {
    let payload = #"""
    {
        "maintenance_mode": true,
        "maintenance_message": "Read-only",
        "updated_utc": "2026-02-14T22:46:14.289Z"
    }
    """#.data(using: .utf8)!

    let response = SwiftRestRawResponse(
        statusCode: 200,
        data: nil,
        rawData: payload,
        headers: ["Content-Type": "application/json"]
    )

    let decoded: SnakeConfigResponse = try response.decodeBody(
        SnakeConfigResponse.self,
        using: SwiftRestJSONCoding.webAPI.makeDecoder()
    )
    #expect(decoded.maintenanceMode == true)
    #expect(decoded.maintenanceMessage == "Read-only")
}

@Test func testJSONCodingAdditionalPresetsAndKeyModes() {
    #expect(SwiftRestJSONCoding.iso8601.dateDecodingStrategy == .iso8601)
    #expect(SwiftRestJSONCoding.iso8601.dateEncodingStrategy == .iso8601)

    #expect(SwiftRestJSONCoding.webAPIFractionalSeconds.dateDecodingStrategy == .iso8601WithFractionalSeconds)
    #expect(SwiftRestJSONCoding.webAPIFractionalSeconds.keyDecodingStrategy == .convertFromSnakeCase)

    #expect(SwiftRestJSONCoding.webAPIUnixSeconds.dateDecodingStrategy == .secondsSince1970)
    #expect(SwiftRestJSONCoding.webAPIUnixMilliseconds.dateDecodingStrategy == .millisecondsSince1970)

    #expect(SwiftRestJSONKeys.snakeCaseDecodingOnly.decodingStrategy == .convertFromSnakeCase)
    #expect(SwiftRestJSONKeys.snakeCaseDecodingOnly.encodingStrategy == .useDefaultKeys)
    #expect(SwiftRestJSONKeys.snakeCaseEncodingOnly.decodingStrategy == .useDefaultKeys)
    #expect(SwiftRestJSONKeys.snakeCaseEncodingOnly.encodingStrategy == .convertToSnakeCase)
}

@Test func testGlobalAccessTokenAndPrecedence() async throws {
    let client = try makeAuthEchoClient(config: .standard.accessToken("global-token"))

    let globalRaw = try await client.getRaw("users/1")
    #expect(globalRaw.header("x-observed-authorization") == "Bearer global-token")

    await client.setAccessToken("updated-global")
    let updatedGlobalRaw = try await client.getRaw("users/1")
    #expect(updatedGlobalRaw.header("x-observed-authorization") == "Bearer updated-global")

    await client.setAccessTokenProvider { "provider-token" }
    let providerRaw = try await client.getRaw("users/1")
    #expect(providerRaw.header("x-observed-authorization") == "Bearer provider-token")

    let requestRaw = try await client.getRaw("users/1", authToken: "request-token")
    #expect(requestRaw.header("x-observed-authorization") == "Bearer request-token")

    await client.clearAccessTokenProvider()
    let fallbackRaw = try await client.getRaw("users/1")
    #expect(fallbackRaw.header("x-observed-authorization") == "Bearer updated-global")

    await client.clearAccessToken()
    let noneRaw = try await client.getRaw("users/1")
    #expect(noneRaw.header("x-observed-authorization") == "none")
}

@Test func testAccessTokenProviderFromConfig() async throws {
    let client = try makeAuthEchoClient(
        config: .standard
            .accessToken("global-token")
            .accessTokenProvider({ "provider-token" })
    )

    let raw = try await client.getRaw("users/1")
    #expect(raw.header("x-observed-authorization") == "Bearer provider-token")
}

@Test func testRequestNoAuthOverridesTokenSources() async throws {
    let client = try makeAuthEchoClient(
        config: .standard
            .accessToken("global-token")
            .accessTokenProvider({ "provider-token" })
    )

    let noAuthRaw = try await client.path("users/1").noAuth().get().raw()
    #expect(noAuthRaw.header("x-observed-authorization") == "none")

    let requestTokenNoAuthRaw = try await client
        .path("users/1")
        .authToken("request-token")
        .noAuth()
        .get()
        .raw()
    #expect(requestTokenNoAuthRaw.header("x-observed-authorization") == "none")
}

@Test func testV4ChainBuilderAndRequestOutputs() async throws {
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [ResultScenarioURLProtocol.self]
    let session = URLSession(configuration: sessionConfiguration)

    let client = try SwiftRest
        .for("https://api.example.com")
        .json(.webAPI)
        .retry(.standard)
        .logging(.off)
        .session(session)
        .client

    let value: Dummy = try await client.path("result-success").get().value()
    #expect(value == Dummy(id: 42, name: "Result User"))

    let response: SwiftRestResponse<Dummy> = try await client.path("result-success").get().response()
    #expect(response.value == Dummy(id: 42, name: "Result User"))
    #expect(response.statusCode == 200)
    #expect(response.headerInt("content-length") == nil)

    let result: SwiftRestResult<Dummy, APIErrorPayload> =
        await client.path("result-api-error").get().result(error: APIErrorPayload.self)
    switch result {
    case .apiError(let decoded, let raw):
        #expect(raw.statusCode == 422)
        #expect(decoded?.code == "validation_failed")
    default:
        #expect(Bool(false))
    }
}

@Test func testV4ChainSendForNoResponseFlows() async throws {
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [ResultScenarioURLProtocol.self]
    let session = URLSession(configuration: sessionConfiguration)

    let client = try SwiftRest
        .for("https://api.example.com")
        .session(session)
        .client

    try await client.path("result-success").get().send()

    do {
        try await client.path("result-api-error").get().send()
        #expect(Bool(false))
    } catch let error as SwiftRestClientError {
        switch error {
        case .httpError(let response):
            #expect(response.statusCode == 422)
        default:
            #expect(Bool(false))
        }
    } catch {
        #expect(Bool(false))
    }
}

@Test func testV4ChainPathSegmentsAppendWithoutManualSlashes() async throws {
    let client = try makeSimpleSuccessClient()

    let chained = try await client
        .path("v1/")
        .path("/sessions/")
        .path("abc123")
        .path("events")
        .get()
        .raw()
    #expect(chained.finalURL?.absoluteString == "https://api.example.com/v1/sessions/abc123/events")

    let variadic = try await client
        .path("/v1//")
        .paths("sessions", "/abc123/", "events")
        .get()
        .raw()
    #expect(variadic.finalURL?.absoluteString == "https://api.example.com/v1/sessions/abc123/events")

    let emptySegments = try await client
        .path("v1")
        .path("")
        .path("/")
        .path("users")
        .get()
        .raw()
    #expect(emptySegments.finalURL?.absoluteString == "https://api.example.com/v1/users")
}

@Test func testV4ChainSupportsHeadAndOptionsMethods() async throws {
    let client = try makeMethodEchoClient()

    let headRaw = try await client.path("health").head().raw()
    #expect(headRaw.header("x-observed-method") == "HEAD")

    let optionsRaw = try await client.path("users").options().raw()
    #expect(optionsRaw.header("x-observed-method") == "OPTIONS")
}

@Test func testV4ChainQueryUsesGlobalJSONCoding() async throws {
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [EchoQueryURLProtocol.self]
    let session = URLSession(configuration: sessionConfiguration)

    let client = try SwiftRest
        .for("https://api.example.com")
        .json(.webAPI)
        .session(session)
        .client

    let query = UserListQuery(page: 1, search: "ricky", includeInactive: true)
    let raw = try await client.path("users").query(query).get().raw()
    let observed = raw.header("x-observed-query") ?? ""
    #expect(observed.contains("include_inactive=true"))
    #expect(!observed.contains("includeInactive=true"))
}

@Test func testV4EndpointAutoRefreshUsesSingleClient() async throws {
    let session = makeEndpointRefreshSession()

    let client = try SwiftRest
        .for("https://api.example.com")
        .accessToken("expired-token")
        .autoRefresh(
            endpoint: "auth/refresh",
            refreshTokenProvider: { "refresh-1" }
        )
        .session(session)
        .client

    let user: Dummy = try await client.path("secure/profile").get().value()
    #expect(user == Dummy(id: 1, name: "Alice"))

    let snapshot = EndpointRefreshState.shared.snapshot()
    #expect(snapshot.refreshCalls >= 1)
    #expect(snapshot.refreshAuthHeaders.allSatisfy { $0 == "none" })
}

@Test func testV4EndpointAutoRefreshCanTriggerOnConfigured403() async throws {
    let session = makeEndpointRefreshForbiddenSession()

    let client = try SwiftRest
        .for("https://api.example.com")
        .accessToken("expired-token")
        .autoRefresh(
            endpoint: "auth/refresh",
            refreshTokenProvider: { "refresh-1" },
            triggerStatusCodes: [403]
        )
        .session(session)
        .client

    let user: Dummy = try await client.path("secure/profile").get().value()
    #expect(user == Dummy(id: 1, name: "Alice"))
}

@Test func testV4EndpointAutoRefreshOnTokensRefreshedCallback() async throws {
    let session = makeEndpointRefreshSession()
    let sink = RefreshedTokensSink()

    let client = try SwiftRest
        .for("https://api.example.com")
        .accessToken("expired-token")
        .autoRefresh(
            endpoint: "auth/refresh",
            refreshTokenProvider: { "refresh-1" },
            onTokensRefreshed: { accessToken, refreshToken in
                await sink.append(accessToken: accessToken, refreshToken: refreshToken)
            }
        )
        .session(session)
        .client

    let user: Dummy = try await client.path("secure/profile").get().value()
    #expect(user == Dummy(id: 1, name: "Alice"))

    let snapshot = await sink.snapshot()
    #expect(snapshot.accessTokens == ["fresh-token"])
    #expect(snapshot.refreshTokens.count == 1)
    #expect(snapshot.refreshTokens[0] == nil)
}

@Test func testV4EndpointAutoRefreshReadsRefreshTokenFieldAndCallback() async throws {
    let session = makeEndpointRefreshWithRefreshTokenSession()
    let sink = RefreshedTokensSink()

    let client = try SwiftRest
        .for("https://api.example.com")
        .accessToken("expired-token")
        .autoRefresh(
            endpoint: "auth/refresh",
            refreshTokenProvider: { "refresh-1" },
            refreshTokenResponseField: "refreshToken",
            onTokensRefreshed: { accessToken, refreshToken in
                await sink.append(accessToken: accessToken, refreshToken: refreshToken)
            }
        )
        .session(session)
        .client

    let user: Dummy = try await client.path("secure/profile").get().value()
    #expect(user == Dummy(id: 1, name: "Alice"))

    let snapshot = await sink.snapshot()
    #expect(snapshot.accessTokens == ["fresh-token"])
    #expect(snapshot.refreshTokens == ["fresh-refresh-token"])
}

@Test func testV4RequestRefreshTokenProviderOverridesEndpointProvider() async throws {
    let session = makeEndpointRefreshSession()
    EndpointRefreshState.shared.reset()

    let client = try SwiftRest
        .for("https://api.example.com")
        .accessToken("expired-token")
        .autoRefresh(
            endpoint: "auth/refresh",
            refreshTokenProvider: { "refresh-global" }
        )
        .session(session)
        .client

    let user: Dummy = try await client
        .path("secure/profile")
        .refreshTokenProvider { "refresh-request" }
        .get()
        .value()
    #expect(user == Dummy(id: 1, name: "Alice"))

    let snapshot = EndpointRefreshState.shared.snapshot()
    #expect(snapshot.refreshCalls >= 1)
    #expect(snapshot.refreshBodies.contains { $0.contains(#""refreshToken":"refresh-request""#) })
}

@Test func testV4CustomAutoRefreshBypassContext() async throws {
    let session = makeEndpointRefreshSession()

    let refresh = SwiftRestAuthRefresh.custom { refresh in
        let response: RefreshTokenResponse = try await refresh.post(
            "auth/refresh",
            body: RefreshTokenBody(refreshToken: "refresh-2")
        )
        return response.accessToken
    }

    let client = try SwiftRest
        .for("https://api.example.com")
        .accessToken("expired-token")
        .autoRefresh(refresh)
        .session(session)
        .client

    let raw = try await client.path("secure/profile").get().raw()
    #expect(raw.statusCode == 200)

    let snapshot = EndpointRefreshState.shared.snapshot()
    #expect(snapshot.refreshCalls >= 1)
    #expect(snapshot.refreshAuthHeaders.allSatisfy { $0 == "none" })
}

@Test func testAuthRefreshRetries401OnceAndSucceeds() async throws {
    let refreshCounter = AsyncCounter()
    let refresh = SwiftRestAuthRefresh.custom { _ in
        await refreshCounter.increment()
        return "fresh-token"
    }

    let client = try makeRefreshAuthClient(
        config: .standard
            .accessToken("expired-token")
            .authRefresh(refresh)
    )

    let raw = try await client.getRaw("secure/profile")
    #expect(raw.statusCode == 200)
    #expect(raw.header("x-observed-authorization") == "Bearer fresh-token")
    #expect(await refreshCounter.current() == 1)
}

@Test func testAuthRefreshCanBeAppliedToPerRequestToken() async throws {
    let refreshCounter = AsyncCounter()
    let refresh = SwiftRestAuthRefresh.custom { _ in
        await refreshCounter.increment()
        return "fresh-token"
    }.appliesToPerRequestToken(true)

    let client = try makeRefreshAuthClient(config: .standard.authRefresh(refresh))

    let raw = try await client.getRaw(
        "secure/profile",
        authToken: "expired-token"
    )
    #expect(raw.statusCode == 200)
    #expect(raw.header("x-observed-authorization") == "Bearer fresh-token")
    #expect(await refreshCounter.current() == 1)
}

@Test func testAuthRefreshSkipsPerRequestTokenByDefault() async throws {
    let refreshCounter = AsyncCounter()
    let refresh = SwiftRestAuthRefresh.custom { _ in
        await refreshCounter.increment()
        return "fresh-token"
    }

    let client = try makeRefreshAuthClient(config: .standard.authRefresh(refresh))

    let raw = try await client.getRaw(
        "secure/profile",
        authToken: "expired-token",
        allowHTTPError: true
    )
    #expect(raw.statusCode == 401)
    #expect(await refreshCounter.current() == 0)
}

@Test func testAuthRefreshCanTriggerOnConfigured403Status() async throws {
    let refreshCounter = AsyncCounter()
    let refresh = SwiftRestAuthRefresh.custom { _ in
        await refreshCounter.increment()
        return "fresh-token"
    }.triggerStatusCodes([403])

    let client = try makeRefreshForbiddenAuthClient(
        config: .standard
            .accessToken("expired-token")
            .authRefresh(refresh)
    )

    let raw = try await client.getRaw("secure/profile")
    #expect(raw.statusCode == 200)
    #expect(raw.header("x-observed-authorization") == "Bearer fresh-token")
    #expect(await refreshCounter.current() == 1)
}

@Test func testAuthRefreshDoesNotTriggerOn403ByDefault() async throws {
    let refreshCounter = AsyncCounter()
    let refresh = SwiftRestAuthRefresh.custom { _ in
        await refreshCounter.increment()
        return "fresh-token"
    }

    let client = try makeRefreshForbiddenAuthClient(
        config: .standard
            .accessToken("expired-token")
            .authRefresh(refresh)
    )

    let raw = try await client.getRaw("secure/profile", allowHTTPError: true)
    #expect(raw.statusCode == 403)
    #expect(await refreshCounter.current() == 0)
}

@Test func testAuthRefreshTriggerStatusCodeNormalization() {
    let refresh = SwiftRestAuthRefresh.custom({ _ in "fresh-token" }, triggerStatusCodes: [0, 700])
    #expect(refresh.triggerStatusCodes == Set([401]))

    let updated = refresh.triggerStatusCodes([401, 403, 700])
    #expect(updated.triggerStatusCodes == Set([401, 403]))
}

@Test func testAuthRefreshCanBeDisabledPerRequest() async throws {
    let refreshCounter = AsyncCounter()
    let refresh = SwiftRestAuthRefresh.custom { _ in
        await refreshCounter.increment()
        return "fresh-token"
    }

    let client = try makeRefreshAuthClient(
        config: .standard
            .accessToken("expired-token")
            .authRefresh(refresh)
    )

    let raw = try await client
        .path("secure/profile")
        .autoRefresh(false)
        .get()
        .raw()
    #expect(raw.statusCode == 401)
    #expect(await refreshCounter.current() == 0)
}

@Test func testAuthRefreshSingleFlightAcrossConcurrentRequests() async throws {
    let refreshCounter = AsyncCounter()
    let refresh = SwiftRestAuthRefresh.custom { _ in
        await refreshCounter.increment()
        try await Task.sleep(nanoseconds: 75_000_000)
        return "fresh-token"
    }

    let client = try makeRefreshAuthClient(
        config: .standard
            .accessToken("expired-token")
            .authRefresh(refresh)
    )

    try await withThrowingTaskGroup(of: Int.self) { group in
        for _ in 0..<6 {
            group.addTask {
                let raw = try await client.getRaw("secure/profile")
                return raw.statusCode
            }
        }

        for try await status in group {
            #expect(status == 200)
        }
    }

    #expect(await refreshCounter.current() == 1)
}

@Test func testAuthRefreshFailureThrowsSpecificError() async throws {
    enum RefreshFailure: Error {
        case failed
    }

    let refresh = SwiftRestAuthRefresh.custom { _ in
        throw RefreshFailure.failed
    }

    let client = try makeRefreshAuthClient(
        config: .standard
            .accessToken("expired-token")
            .authRefresh(refresh)
    )

    do {
        _ = try await client.getRaw("secure/profile")
        #expect(Bool(false))
    } catch let error as SwiftRestClientError {
        switch error {
        case .authRefreshFailed:
            #expect(Bool(true))
        default:
            #expect(Bool(false))
        }
    } catch {
        #expect(Bool(false))
    }
}

@Test func testResultAPIForSuccessAndAPIErrorsAndTransportFailures() async throws {
    let client = try makeResultScenarioClient()

    let success: SwiftRestResult<Dummy, APIErrorPayload> =
        await client.getResult("result-success")
    switch success {
    case .success(let response):
        #expect(response.statusCode == 200)
        #expect(response.data == Dummy(id: 42, name: "Result User"))
    default:
        #expect(Bool(false))
    }

    let apiError: SwiftRestResult<Dummy, APIErrorPayload> =
        await client.getResult("result-api-error")
    switch apiError {
    case .apiError(let decoded, let response):
        #expect(response.statusCode == 422)
        #expect(decoded == APIErrorPayload(message: "Invalid request", code: "validation_failed"))
    default:
        #expect(Bool(false))
    }

    let undecodable: SwiftRestResult<Dummy, APIErrorPayload> =
        await client.getResult("result-api-error-plain")
    switch undecodable {
    case .apiError(let decoded, let response):
        #expect(response.statusCode == 500)
        #expect(decoded == nil)
    default:
        #expect(Bool(false))
    }

    let transport: SwiftRestResult<Dummy, APIErrorPayload> =
        await client.getResult("result-network-failure")
    switch transport {
    case .failure(let error):
        if case .networkError = error {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }
    default:
        #expect(Bool(false))
    }
}

@Test func testQueryModelSupportForGetAndDelete() async throws {
    let client = try makeQueryEchoClient()
    let query = UserListQuery(page: 2, search: "ricky", includeInactive: true)

    let getRaw = try await client.getRaw("users", query: query)
    let getQuery = getRaw.header("x-observed-query") ?? ""
    #expect(getQuery.contains("page=2"))
    #expect(getQuery.contains("search=ricky"))
    #expect(getQuery.contains("includeInactive=true"))

    let deleteRaw = try await client.deleteRaw("users", query: query)
    let deleteQuery = deleteRaw.header("x-observed-query") ?? ""
    #expect(deleteQuery.contains("page=2"))
    #expect(deleteQuery.contains("search=ricky"))
    #expect(deleteQuery.contains("includeInactive=true"))
}

@Test func testNestedQueryEncodingFlattensObjects() throws {
    let encoded = try SwiftRestQuery.encode(
        NestedUserQuery(
            page: 1,
            flags: NestedQueryFlags(featured: true)
        )
    )

    #expect(encoded["page"] == "1")
    #expect(encoded["flags.featured"] == "true")
}

@Test func testQueryModelUsesClientKeyEncodingStrategy() async throws {
    let client = try makeQueryEchoClient(config: .webAPI)
    let query = UserListQuery(page: 1, search: "ricky", includeInactive: true)

    let raw = try await client.getRaw("users", query: query)
    let observed = raw.header("x-observed-query") ?? ""
    #expect(observed.contains("include_inactive=true"))
    #expect(!observed.contains("includeInactive=true"))
}

@Test func testDebugLoggingRedactsSensitiveHeaders() async throws {
    let collector = LogCollector()
    let logging = SwiftRestDebugLogging(
        isEnabled: true,
        includeHeaders: true,
        handler: { collector.append($0) }
    )

    let client = try makeSimpleSuccessClient(
        config: .standard
            .accessToken("super-secret-token")
            .debugLogging(logging)
    )

    _ = try await client.getRaw("users/1")

    let output = collector.snapshot().joined(separator: "\n").lowercased()
    #expect(output.contains("[swiftrest] -> get"))
    #expect(output.contains("[swiftrest] <- 200 get"))
    #expect(output.contains("authorization: <redacted>"))
    #expect(!output.contains("super-secret-token"))
}

@Test func testStandardConfigDefaultsAndVersionMarker() throws {
    #expect(SwiftRestConfig.standard.baseHeaders["accept"] == "application/json")
    #expect(SwiftRestConfig.standard.timeout == 30)
    #expect(SwiftRestConfig.standard.retryPolicy.maxAttempts == 3)
    #expect(SwiftRestConfig.standard.retryPolicy.baseDelay == 0.5)
    #expect(RetryPolicy.standard.retryableStatusCodes.contains(429))
    #expect(SwiftRestConfig.standard.jsonCoding == .foundationDefault)
    #expect(
        SwiftRestConfig.standard.dateDecodingStrategy(.iso8601).jsonCoding.dateDecodingStrategy
            == .iso8601
    )
    #expect(SwiftRestConfig.standard.debugLogging.isEnabled == false)
    #expect(SwiftRestConfig.standard.authRefresh.isEnabled == false)
    #expect(SwiftRestVersion.current == "4.7.0")

    _ = try SwiftRestClient("https://api.example.com")
}

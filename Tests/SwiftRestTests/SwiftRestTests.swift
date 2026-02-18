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

private func makeAuthEchoClient(config: SwiftRestConfig = .standard) throws -> SwiftRestClient {
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [EchoAuthURLProtocol.self]
    let session = URLSession(configuration: sessionConfiguration)
    return try SwiftRestClient("https://api.example.com", config: config, session: session)
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
    #expect(SwiftRestVersion.current == "3.2.0")

    _ = try SwiftRestClient("https://api.example.com")
}

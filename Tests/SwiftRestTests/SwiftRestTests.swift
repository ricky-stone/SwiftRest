import Foundation
import Testing
@testable import SwiftRest

struct Dummy: Codable, Equatable, Sendable {
    let id: Int
    let name: String
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

import Testing
@testable import SwiftRest

import Foundation

// MARK: - JSON Helper Tests

@Test func testJsonHelperEncodingDecoding() async throws {
    // A simple model for testing JSON encoding and decoding.
    struct Dummy: Codable, Equatable, Sendable {
        let id: Int
        let name: String
    }
    
    let dummy = Dummy(id: 1, name: "Alice")
    
    // Encode the dummy model to a JSON string.
    let jsonString = try Json.toString(object: dummy)
    
    // Decode the JSON string back into a Dummy instance.
    let decoded: Dummy = try Json.parse(data: jsonString)
    
    // Assert that the decoded properties match the original values.
    #expect(decoded.id == dummy.id)
    #expect(decoded.name == dummy.name)
}

// MARK: - SwiftRestRequest Tests

@Test func testSwiftRestRequestConfiguration() async throws {
    // Create a request and configure various properties.
    var request = SwiftRestRequest(path: "endpoint", method: .post)
    request.addHeader("Content-Type", "application/json")
    request.addParameter("q", "test")
    try request.addJsonBody(["key": "value"])
    request.addAuthToken("sampleToken")
    request.configureRetries(maxRetries: 3, retryDelay: 1.0)
    
    // Assert that the properties are set correctly.
    #expect(request.headers?["Content-Type"] == "application/json")
    #expect(request.parameters?["q"] == "test")
    #expect(request.jsonBody?.contains("key") == true)
    #expect(request.authToken == "sampleToken")
    #expect(request.maxRetries == 3)
    #expect(request.retryDelay == 1.0)
}

// MARK: - SwiftRestClient Initialization Test

@Test func testSwiftRestClientInvalidBaseURL() async throws {
    do {
        // An empty string is used to guarantee failure in URL initialization.
        _ = try SwiftRestClient(url: "")
        // If no error is thrown, this assertion fails.
        #expect(Bool(false))
    } catch {
        // An error is expected, so we assert true.
        #expect(Bool(true))
    }
}

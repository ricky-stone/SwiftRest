public protocol RestClientType: Sendable {
    func executeRaw(_ request: SwiftRestRequest, allowHTTPError: Bool) async throws -> SwiftRestRawResponse
    func executeAsyncWithResponse<T: Decodable & Sendable>(_ request: SwiftRestRequest) async throws -> SwiftRestResponse<T>
    func executeAsyncWithoutResponse(_ request: SwiftRestRequest) async throws
}

public protocol RestClientType {
    func executeAsyncWithResponse<T: Decodable>(
        _ request: SwiftRestRequest
    ) async throws -> SwiftRestResponse<T>
    
    func executeAsyncWithoutResponse(
        _ request: SwiftRestRequest
    ) async throws
}
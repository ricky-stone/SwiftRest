//
//  MockRestClient.swift
//  SwiftRest
//
//  Created by Ricky Stone on 26/05/2025.
//

import Foundation

/// A mock implementation of `RestClientType` for use in tests.
///
/// Allows callers to inject custom behavior via a handler closure,
/// enabling both successful and failing request simulations.
public struct MockRestClient: RestClientType {
    
    /// A closure that defines the mock’s behavior for each request.
    /// - Parameter request: The `SwiftRestRequest` being executed.
    /// - Returns: An `Any` which must be castable to `SwiftRestResponse<T>`.
    /// - Throws: Any error to simulate request failures.
    public let handler: (SwiftRestRequest) async throws -> Any

    /// Initializes a new `MockRestClient` with the provided handler.
    ///
    /// - Parameter handler: A closure that will be invoked for each
    ///   `executeAsyncWithResponse` or `executeAsyncWithoutResponse` call.
    public init(handler: @escaping (SwiftRestRequest) async throws -> Any) {
        self.handler = handler
    }

    /// Executes a request and returns a decoded response, or throws an error.
    ///
    /// - Parameter request: The `SwiftRestRequest` to execute.
    /// - Returns: A `SwiftRestResponse<T>` containing decoded payload.
    /// - Throws:
    ///   - Any error thrown by the handler closure.
    ///   - A runtime error (`fatalError`) if the handler’s return value
    ///     cannot be cast to `SwiftRestResponse<T>`.
    public func executeAsyncWithResponse<T: Decodable>(
        _ request: SwiftRestRequest
    ) async throws -> SwiftRestResponse<T> {
        let any = try await handler(request)
        guard let typed = any as? SwiftRestResponse<T> else {
            fatalError("MockRestClient: response type mismatch")
        }
        return typed
    }

    /// Executes a request when no response payload is expected.
    ///
    /// - Parameter request: The `SwiftRestRequest` to execute.
    /// - Throws:
    ///   - Any error thrown by the handler closure.
    ///   - A runtime error if the handler’s return value cannot be
    ///     cast to `SwiftRestResponse<NoContent>`.
    public func executeAsyncWithoutResponse(
        _ request: SwiftRestRequest
    ) async throws {
        let _: SwiftRestResponse<NoContent> =
            try await executeAsyncWithResponse(request)
    }
}


//
//  RestClientType.swift
//  SwiftRest
//
//  Created by Ricky Stone on 26/05/2025.
//


public protocol RestClientType {
    func executeAsyncWithResponse<T: Decodable>(_ request: SwiftRestRequest) async throws -> SwiftRestResponse<T>
    func executeAsyncWithoutResponse(_ request: SwiftRestRequest) async throws
}

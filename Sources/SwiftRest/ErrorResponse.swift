//
//  ErrorResponse.swift
//  SwiftRest
//
//  Created by Ricky Stone on 03/04/2025.
//
import Foundation

public struct ErrorResponse: Error {
    public let statusCode: Int
    public let message: String?
    public let url: URL?
    public let headers: [String: String]?
    public let rawPayload: String?
    public let responseTime: TimeInterval?
    
    public init(
        statusCode: Int,
        message: String? = nil,
        url: URL? = nil,
        headers: [String: String]? = nil,
        rawPayload: String? = nil,
        responseTime: TimeInterval? = nil
    ) {
        self.statusCode = statusCode
        self.message = message
        self.url = url
        self.headers = headers
        self.rawPayload = rawPayload
        self.responseTime = responseTime
    }
}

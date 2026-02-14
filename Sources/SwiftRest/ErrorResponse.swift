import Foundation

public struct ErrorResponse: Error, Sendable {
    public let statusCode: Int
    public let message: String?
    public let url: URL?
    public let headers: HTTPHeaders
    public let rawPayload: String?
    public let responseTime: TimeInterval?

    public init(
        statusCode: Int,
        message: String? = nil,
        url: URL? = nil,
        headers: HTTPHeaders = HTTPHeaders(),
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

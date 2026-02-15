import Foundation

/// A mock implementation of `RestClientType` for tests and previews.
public struct MockRestClient: RestClientType {
    public typealias Handler = @Sendable (SwiftRestRequest) async throws -> SwiftRestRawResponse

    public let handler: Handler

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public func executeRaw(
        _ request: SwiftRestRequest,
        allowHTTPError: Bool = false
    ) async throws -> SwiftRestRawResponse {
        let response = try await handler(request)

        if !allowHTTPError, !response.isSuccess {
            throw SwiftRestClientError.httpError(makeErrorResponse(from: response))
        }

        return response
    }

    public func executeAsyncWithResponse<T: Decodable & Sendable>(
        _ request: SwiftRestRequest
    ) async throws -> SwiftRestResponse<T> {
        let raw = try await executeRaw(request)

        guard !raw.rawData.isEmpty else {
            return SwiftRestResponse(
                statusCode: raw.statusCode,
                data: nil,
                rawData: raw.rawData,
                headers: raw.headers,
                responseTime: raw.responseTime,
                finalURL: raw.finalURL,
                mimeType: raw.mimeType
            )
        }

        let decoded: T
        do {
            let decoder = (request.jsonCoding ?? .foundationDefault).makeDecoder()
            decoded = try Json.parse(data: raw.rawData, using: decoder)
        } catch {
            throw SwiftRestClientError.decodingError(underlying: ErrorContext(error))
        }

        return SwiftRestResponse(
            statusCode: raw.statusCode,
            data: decoded,
            rawData: raw.rawData,
            headers: raw.headers,
            responseTime: raw.responseTime,
            finalURL: raw.finalURL,
            mimeType: raw.mimeType
        )
    }

    public func executeAsyncWithoutResponse(_ request: SwiftRestRequest) async throws {
        _ = try await executeRaw(request)
    }

    private func makeErrorResponse(from response: SwiftRestRawResponse) -> ErrorResponse {
        ErrorResponse(
            statusCode: response.statusCode,
            message: response.rawValue,
            url: response.finalURL,
            headers: response.headers,
            rawPayload: response.rawValue,
            responseTime: response.responseTime
        )
    }
}

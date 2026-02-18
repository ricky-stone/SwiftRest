import Foundation

/// Safe context passed to custom auth refresh handlers.
///
/// Requests made from this context bypass normal auth injection and refresh middleware.
public struct SwiftRestRefreshContext: Sendable {
    private let jsonCoding: SwiftRestJSONCoding
    private let performRaw: @Sendable (SwiftRestRequest) async throws -> SwiftRestRawResponse

    init(
        jsonCoding: SwiftRestJSONCoding,
        performRaw: @escaping @Sendable (SwiftRestRequest) async throws -> SwiftRestRawResponse
    ) {
        self.jsonCoding = jsonCoding
        self.performRaw = performRaw
    }

    public func executeRaw(
        _ request: SwiftRestRequest,
        allowHTTPError: Bool = false
    ) async throws -> SwiftRestRawResponse {
        let raw = try await performRaw(request)
        if !allowHTTPError, !raw.isSuccess {
            throw SwiftRestClientError.httpError(
                ErrorResponse(
                    statusCode: raw.statusCode,
                    message: raw.rawValue,
                    url: raw.finalURL,
                    headers: raw.headers,
                    rawPayload: raw.rawValue,
                    responseTime: raw.responseTime
                )
            )
        }
        return raw
    }

    public func postRaw<Body: Encodable & Sendable>(
        _ path: String,
        body: Body,
        headers: [String: String] = [:],
        allowHTTPError: Bool = false
    ) async throws -> SwiftRestRawResponse {
        var request = SwiftRestRequest(path: path, method: .post)
        request.addHeaders(headers)
        try request.addJsonBody(body, using: jsonCoding.makeEncoder())
        return try await executeRaw(request, allowHTTPError: allowHTTPError)
    }

    public func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: Body,
        as type: Response.Type = Response.self,
        headers: [String: String] = [:]
    ) async throws -> Response {
        let response: SwiftRestResponse<Response> = try await postResponse(
            path,
            body: body,
            as: type,
            headers: headers
        )
        if let value = response.data {
            return value
        }
        if Response.self == NoContent.self, let noContent = NoContent() as? Response {
            return noContent
        }
        throw SwiftRestClientError.emptyResponseBody(expectedType: String(describing: type))
    }

    public func postResponse<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: Body,
        as type: Response.Type = Response.self,
        headers: [String: String] = [:]
    ) async throws -> SwiftRestResponse<Response> {
        _ = type
        let raw = try await postRaw(path, body: body, headers: headers)

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

        do {
            let decoded: Response = try Json.parse(
                data: raw.rawData,
                using: jsonCoding.makeDecoder()
            )
            return SwiftRestResponse(
                statusCode: raw.statusCode,
                data: decoded,
                rawData: raw.rawData,
                headers: raw.headers,
                responseTime: raw.responseTime,
                finalURL: raw.finalURL,
                mimeType: raw.mimeType
            )
        } catch {
            throw SwiftRestClientError.decodingError(underlying: ErrorContext(error))
        }
    }
}

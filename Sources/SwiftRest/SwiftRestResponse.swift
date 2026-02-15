import Foundation

/// A convenience alias used when you only need raw headers and payload.
public typealias SwiftRestRawResponse = SwiftRestResponse<NoContent>

/// Represents an HTTP response and optional decoded payload.
public struct SwiftRestResponse<T: Decodable & Sendable>: Sendable {
    public private(set) var statusCode: Int
    public private(set) var data: T?
    public private(set) var rawData: Data
    public private(set) var headers: HTTPHeaders
    public private(set) var responseTime: TimeInterval?
    public private(set) var finalURL: URL?
    public private(set) var mimeType: String?

    public var isSuccess: Bool {
        (200...299).contains(statusCode)
    }

    /// UTF-8 string representation of the raw body, when available.
    public var rawValue: String? {
        String(data: rawData, encoding: .utf8)
    }

    public init(
        statusCode: Int,
        data: T? = nil,
        rawData: Data = Data(),
        headers: HTTPHeaders = HTTPHeaders(),
        responseTime: TimeInterval? = nil,
        finalURL: URL? = nil,
        mimeType: String? = nil
    ) {
        self.statusCode = statusCode
        self.data = data
        self.rawData = rawData
        self.headers = headers
        self.responseTime = responseTime
        self.finalURL = finalURL
        self.mimeType = mimeType
    }

    /// Returns the first value for a header name.
    public func header(_ name: String) -> String? {
        headers[name]
    }

    /// Returns the body as text with a custom encoding.
    public func text(encoding: String.Encoding = .utf8) -> String? {
        String(data: rawData, encoding: encoding)
    }

    /// Decodes the body into the requested type.
    public func decodeBody<U: Decodable & Sendable>(
        _ type: U.Type = U.self,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> U {
        guard !rawData.isEmpty else {
            throw SwiftRestClientError.emptyResponseBody(expectedType: String(describing: U.self))
        }

        do {
            return try decoder.decode(U.self, from: rawData)
        } catch {
            throw SwiftRestClientError.decodingError(underlying: ErrorContext(error))
        }
    }

    /// Decodes the body using a SwiftRest JSON coding preset/options.
    public func decodeBody<U: Decodable & Sendable>(
        _ type: U.Type = U.self,
        using coding: SwiftRestJSONCoding
    ) throws -> U {
        try decodeBody(type, using: coding.makeDecoder())
    }

    /// Parses the body as a JSON object (`Dictionary`, `Array`, etc.).
    public func jsonObject() throws -> Any {
        guard !rawData.isEmpty else {
            throw SwiftRestClientError.emptyResponseBody(expectedType: "JSON")
        }

        do {
            return try JSONSerialization.jsonObject(with: rawData)
        } catch {
            throw SwiftRestClientError.decodingError(underlying: ErrorContext(error))
        }
    }

    /// Returns a pretty-printed JSON string when the body contains valid JSON.
    public func prettyPrintedJSON() throws -> String {
        let object = try jsonObject()

        do {
            let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            guard let text = String(data: data, encoding: .utf8) else {
                throw JsonError.encodingFailed
            }
            return text
        } catch {
            if let clientError = error as? SwiftRestClientError {
                throw clientError
            }
            throw SwiftRestClientError.decodingError(underlying: ErrorContext(error))
        }
    }
}

import Foundation

/// Helper functions for JSON encoding and decoding.
public enum Json {
    public static func parse<T: Decodable & Sendable>(
        data: Data,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw JsonError.decodingFailed
        }
    }

    public static func parse<T: Decodable & Sendable>(
        data: String,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        guard let jsonData = data.data(using: .utf8) else {
            throw JsonError.dataConversionFailed
        }
        return try parse(data: jsonData, using: decoder)
    }

    public static func toData<T: Encodable & Sendable>(
        object: T,
        using encoder: JSONEncoder = JSONEncoder()
    ) throws -> Data {
        do {
            return try encoder.encode(object)
        } catch {
            throw JsonError.encodingFailed
        }
    }

    public static func toString<T: Encodable & Sendable>(
        object: T,
        using encoder: JSONEncoder = JSONEncoder()
    ) throws -> String {
        let data = try toData(object: object, using: encoder)

        guard let result = String(data: data, encoding: .utf8), !result.isEmpty else {
            throw JsonError.emptyResult
        }

        return result
    }
}

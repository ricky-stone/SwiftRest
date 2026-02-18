import CoreFoundation
import Foundation

/// Encodes simple `Encodable` models into URL query parameters.
public enum SwiftRestQuery {
    /// Converts a query model to `[String: String]` using JSON encoding + flattening.
    ///
    /// Nested objects are flattened with dot notation (for example: `filter.active=true`).
    /// Arrays are encoded as comma-separated values.
    public static func encode<Query: Encodable & Sendable>(
        _ query: Query,
        using encoder: JSONEncoder = JSONEncoder()
    ) throws -> [String: String] {
        let data: Data
        do {
            data = try encoder.encode(query)
        } catch {
            throw SwiftRestClientError.invalidQueryParameters(reason: error.localizedDescription)
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw SwiftRestClientError.invalidQueryParameters(reason: error.localizedDescription)
        }

        guard let dictionary = object as? [String: Any] else {
            throw SwiftRestClientError.invalidQueryParameters(
                reason: "Query model must encode to a JSON object."
            )
        }

        var output: [String: String] = [:]
        for (key, value) in dictionary {
            try flatten(value, keyPath: key, into: &output)
        }
        return output
    }

    private static func flatten(
        _ value: Any,
        keyPath: String,
        into output: inout [String: String]
    ) throws {
        if value is NSNull {
            return
        }

        if let dictionary = value as? [String: Any] {
            for (childKey, childValue) in dictionary {
                try flatten(
                    childValue,
                    keyPath: "\(keyPath).\(childKey)",
                    into: &output
                )
            }
            return
        }

        if let array = value as? [Any] {
            let values = try array.compactMap { element -> String? in
                if element is NSNull {
                    return nil
                }
                return try stringify(element)
            }
            output[keyPath] = values.joined(separator: ",")
            return
        }

        output[keyPath] = try stringify(value)
    }

    private static func stringify(_ value: Any) throws -> String {
        if let text = value as? String {
            return text
        }

        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        }

        if JSONSerialization.isValidJSONObject(value) {
            let data = try JSONSerialization.data(withJSONObject: value)
            guard let text = String(data: data, encoding: .utf8) else {
                throw SwiftRestClientError.invalidQueryParameters(
                    reason: "Unable to stringify query value."
                )
            }
            return text
        }

        throw SwiftRestClientError.invalidQueryParameters(
            reason: "Unsupported query value type: \(String(describing: type(of: value)))"
        )
    }
}

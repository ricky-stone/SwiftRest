//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

// A helper class for encoding and decoding JSON data.
///
/// Provides utility methods to parse JSON strings into decodable types and convert encodable types to pretty-printed JSON strings.
public class Json {
    
    /// Decodes a JSON string into an object of type `T`.
    ///
    /// - Parameter data: A `String` containing JSON data.
    /// - Returns: An object of type `T` that was decoded from the JSON string.
    /// - Throws: `JsonError.decodingFailed` if the string cannot be converted to data or decoding fails.
    static func parse<T: Decodable>(data: String) throws -> T {
        guard let jsonData = data.data(using: .utf8) else {
            throw JsonError.decodingFailed
        }
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(T.self, from: jsonData)
        return decoded
    }
    
    /// Encodes an object of type `T` into a pretty-printed JSON string.
    ///
    /// - Parameter object: The encodable object to be converted to JSON.
    /// - Returns: A `String` containing the JSON representation of the object.
    /// - Throws: `JsonError.encodingFailed` if encoding fails or the result is empty.
    static func toString<T: Encodable>(object: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(object)
        
        guard let result = String(data: data, encoding: .utf8), !result.isEmpty else {
            throw JsonError.encodingFailed
        }
        
        return result
    }
}

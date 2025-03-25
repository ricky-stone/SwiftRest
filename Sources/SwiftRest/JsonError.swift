//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

/// An enumeration of errors that can occur during JSON encoding or decoding operations.
///
/// Conforms to `Error` and `Sendable` for safe and descriptive error handling.
public enum JsonError: Error, Sendable {
    /// Indicates that the conversion of a string to data failed.
    case dataConversionFailed
    /// Indicates that JSON decoding has failed.
    case decodingFailed
    /// Indicates that JSON encoding has failed.
    case encodingFailed
    /// Indicates that the result of a JSON operation is empty when data was expected.
    case emptyResult
}

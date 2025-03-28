//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

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

extension JsonError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .dataConversionFailed:
            return NSLocalizedString("Failed to convert the provided string to data.", comment: "Data Conversion Failed")
        case .decodingFailed:
            return NSLocalizedString("Failed to decode JSON. The data may be in an unexpected format.", comment: "Decoding Failed")
        case .encodingFailed:
            return NSLocalizedString("Failed to encode data to JSON. The input might not be valid for encoding.", comment: "Encoding Failed")
        case .emptyResult:
            return NSLocalizedString("Expected JSON data but received an empty result.", comment: "Empty JSON Result")
        }
    }
}

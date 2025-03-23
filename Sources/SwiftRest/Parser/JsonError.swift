//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

public enum JsonError: Error, Sendable {
    case dataConversionFailed
    case decodingFailed
    case encodingFailed
    case emptyResult
}

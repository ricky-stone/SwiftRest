//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

public enum SwiftRestClientError: Error {
    case invalidBaseURL(String)
    case invalidURLComponents
    case invalidFinalURL
    case invalidHTTPResponse
    case missingContentType
}

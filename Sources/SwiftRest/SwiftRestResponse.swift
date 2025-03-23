//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

public struct SwiftRestResponse<T: Decodable & Sendable>: Sendable {
    
    private(set) var statusCode: Int
    private(set) var data: T?
    private(set) var rawValue: String?
    
    init(statusCode: Int, data: T? = nil, rawValue: String? = nil) {
        self.statusCode = statusCode
        self.data = data
        self.rawValue = rawValue
    }
}

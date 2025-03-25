//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

public struct SwiftRestResponse<T: Decodable & Sendable>: Sendable {
    
    public private(set) var statusCode: Int
    public private(set) var data: T?
    public private(set) var rawValue: String?
    public private(set) var headers: [String: String]?
    
    public var isSuccess: Bool {
        return (200...299).contains(statusCode)
    }
    
    init(statusCode: Int, data: T? = nil, rawValue: String? = nil, headers: [String: String]? = nil) {
        self.statusCode = statusCode
        self.data = data
        self.rawValue = rawValue
        self.headers = headers
    }
}

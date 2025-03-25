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
    public private(set) var responseTime: TimeInterval?
    public private(set) var finalURL: URL?
    public private(set) var mimeType: String?
    
    public var isSuccess: Bool {
        return (200...299).contains(statusCode)
    }
    
    init(
        statusCode: Int,
        data: T? = nil,
        rawValue: String? = nil,
        headers: [String: String]? = nil,
        responseTime: TimeInterval? = nil,
        finalURL: URL? = nil,
        mimeType: String? = nil
    ) {
        self.statusCode = statusCode
        self.data = data
        self.rawValue = rawValue
        self.headers = headers
        self.responseTime = responseTime
        self.finalURL = finalURL
        self.mimeType = mimeType
    }
}

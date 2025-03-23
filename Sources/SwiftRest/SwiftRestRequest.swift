//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

public struct SwiftRestRequest: Sendable {
    
    public private(set) var path: String
    public private(set) var method: HTTPMethod
    public private(set) var headers: [String: String]?
    public private(set) var parameters: [String: String]?
    public private(set) var jsonBody: String?
    
    public init(path: String, method: HTTPMethod) {
        self.path = path
        self.method = method
    }
    
    public mutating func addHeader(_ key: String, _ value: String) {
        if headers == nil { headers = [:] }
        headers?[key] = value
    }
    
    public mutating func addParameter(_ key: String, _ value: String) {
        if parameters == nil { parameters = [:] }
        parameters?[key] = value
    }
    
    public mutating func addJsonBody<T: Encodable>(_ object: T) throws {
        self.jsonBody = try Json.toString(object: object)
    }
}

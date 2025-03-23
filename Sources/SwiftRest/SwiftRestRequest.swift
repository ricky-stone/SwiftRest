//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

public struct SwiftRestRequest: Sendable {
    
    private(set) var path: String
    private(set) var method: HTTPMethod
    private(set) var headers: [String: String]?
    private(set) var parameters: [String: String]?
    private(set) var jsonBody: String?
    
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

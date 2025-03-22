//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

public final class SwiftRestRequest {
    
    private(set) var path: String
    private(set) var method: HTTPMethod
    private(set) var headers: [String: String]?
    private(set) var parameters: [String: String]?
    private(set) var jsonBody: String?
    
    init(path: String, method: HTTPMethod) {
        self.path = path
        self.method = method
    }
    
    func addHeader(_ key: String, _ value: String) {
        if headers == nil { headers = [:] }
        headers?[key] = value
    }
    
    func addParameter(_ key: String, _ value: String) {
        if parameters == nil { parameters = [:] }
        parameters?[key] = value
    }
    
    func addJsonBody<T: Encodable>(_ object: T) throws {
        self.jsonBody = try Json.toString(object: object)
    }
}

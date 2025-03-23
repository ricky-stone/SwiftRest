//
//  Swift Rest
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

class Json {
    
    static func parse<T: Decodable>(data: String) throws -> T {
        
        guard let jsonData = data.data(using: .utf8) else {
            throw JsonError.decodingFailed
        }
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(T.self, from: jsonData)
        return decoded
    }
    
    
    static func toString<T: Encodable>(object: T) throws -> String {
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(object)
        
        guard let result = String(data: data, encoding: .utf8), !result.isEmpty else {
            throw JsonError.encodingFailed
        }
        
        return result
    }
}

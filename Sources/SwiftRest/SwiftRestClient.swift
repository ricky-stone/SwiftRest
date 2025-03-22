//
//  SwiftRest.swift
//  Created by Ricky Stone on 22/03/2025.
//

import Foundation

public final class SwiftRestClient {

    private let url: String

    public init(url: String) {
        self.url = url
    }

    public func executeAsync<T: Decodable>(_ httpRequest: HTTPRequest) async throws -> HttpResponse<T> {
        
        guard let baseURL = URL(string: url) else { throw HTTPClientError.invalidBaseURL(url) }
        var url = baseURL.appendingPathComponent(httpRequest.path)

        if let parameters = httpRequest.parameters, !parameters.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw HTTPClientError.invalidURLComponents
            }
            components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            guard let finalURL = components.url else {
                throw HTTPClientError.invalidFinalURL
            }
            url = finalURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = httpRequest.method.rawValue

        if let headers = httpRequest.headers {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }

        if (httpRequest.method == .POST || httpRequest.method == .PUT),
           let jsonBody = httpRequest.jsonBody {
            request.httpBody = jsonBody.data(using: .utf8)
            if httpRequest.headers?["Content-Type"] == nil {
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidHTTPResponse
        }

        let statusCode = httpResponse.statusCode

        guard (200...299).contains(statusCode) else {
            return HttpResponse(statusCode: statusCode)
        }

        let contentType: String? = httpResponse.value(forHTTPHeaderField: "Content-Type")
         
        guard let result = String(data: data, encoding: .utf8), !result.isEmpty else {
            return HttpResponse(statusCode: statusCode)
        }

        if let contentType = contentType, contentType.contains("application/json") {
            let payload = try Json.parse(data: result) as T
            return HttpResponse(statusCode: statusCode, data: payload, rawValue: result)
        }

        return HttpResponse(statusCode: statusCode)
    }
}

import Foundation

/// A lightweight, case-insensitive header container.
///
/// Keys are normalized internally, so lookups like
/// `headers["content-type"]` and `headers["Content-Type"]` behave the same.
public struct HTTPHeaders: Sendable, ExpressibleByDictionaryLiteral {
    private var storage: [String: [String]]

    public init() {
        self.storage = [:]
    }

    public init(_ values: [String: String]) {
        var result: [String: [String]] = [:]
        for (name, value) in values {
            result[Self.normalize(name)] = [value]
        }
        self.storage = result
    }

    public init(dictionaryLiteral elements: (String, String)...) {
        var result: [String: [String]] = [:]
        for (name, value) in elements {
            result[Self.normalize(name)] = [value]
        }
        self.storage = result
    }

    /// Creates headers from `HTTPURLResponse.allHeaderFields`.
    public init(httpResponseHeaders: [AnyHashable: Any]) {
        var result: [String: [String]] = [:]
        for (rawName, rawValue) in httpResponseHeaders {
            guard let name = String(describing: rawName).nilIfEmpty else { continue }
            let value = String(describing: rawValue)
            result[Self.normalize(name), default: []].append(value)
        }
        self.storage = result
    }

    public var isEmpty: Bool {
        storage.isEmpty
    }

    /// Returns the first value for a given header name.
    public subscript(_ name: String) -> String? {
        get { storage[Self.normalize(name)]?.first }
        set {
            let key = Self.normalize(name)
            if let newValue {
                storage[key] = [newValue]
            } else {
                storage.removeValue(forKey: key)
            }
        }
    }

    /// Returns all values for a given header name.
    public func values(for name: String) -> [String] {
        storage[Self.normalize(name)] ?? []
    }

    public mutating func set(_ value: String, for name: String) {
        storage[Self.normalize(name)] = [value]
    }

    public mutating func add(_ value: String, for name: String) {
        storage[Self.normalize(name), default: []].append(value)
    }

    /// Flattens headers into a simple dictionary using comma-joined values.
    public var dictionary: [String: String] {
        storage.mapValues { $0.joined(separator: ", ") }
    }

    private static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

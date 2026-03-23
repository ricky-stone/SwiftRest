import Foundation

enum SwiftRestPathUtilities {
    static func joinedPath(_ current: String, _ next: String) -> String {
        let segments = pathSegments(from: current) + pathSegments(from: next)
        return segments.joined(separator: "/")
    }

    static func normalizedPath(_ path: String) -> String {
        pathSegments(from: path).joined(separator: "/")
    }

    static func pathSegments(from rawPath: String) -> [String] {
        rawPath
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "/")
            .map(String.init)
    }
}

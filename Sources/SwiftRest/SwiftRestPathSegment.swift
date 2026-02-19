import Foundation

/// Converts values into path segments for the V4 request chain.
///
/// Examples:
/// - `String` / `Substring`
/// - integer and floating-point numbers
/// - `Bool`
/// - `UUID`
public protocol SwiftRestPathSegmentConvertible {
    /// String representation used as a single path segment.
    var swiftRestPathSegment: String { get }
}

extension String: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { self }
}

extension Substring: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { String(self) }
}

extension Int: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { String(self) }
}

extension Int8: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { String(self) }
}

extension Int16: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { String(self) }
}

extension Int32: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { String(self) }
}

extension Int64: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { String(self) }
}

extension UInt: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { String(self) }
}

extension UInt8: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { String(self) }
}

extension UInt16: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { String(self) }
}

extension UInt32: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { String(self) }
}

extension UInt64: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { String(self) }
}

extension Double: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { String(self) }
}

extension Float: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { String(self) }
}

extension Decimal: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { NSDecimalNumber(decimal: self).stringValue }
}

extension Bool: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { self ? "true" : "false" }
}

extension UUID: SwiftRestPathSegmentConvertible {
    public var swiftRestPathSegment: String { uuidString }
}

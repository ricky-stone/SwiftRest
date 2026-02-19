import Foundation

/// Simplified date JSON behavior for builder-style configuration.
public enum SwiftRestJSONDates: Sendable, Equatable {
    /// Foundation default date strategy.
    case deferredToDate
    /// Unix seconds timestamp.
    case secondsSince1970
    /// Unix milliseconds timestamp.
    case millisecondsSince1970
    /// ISO8601 string date.
    case iso8601
    /// ISO8601 string date with fractional seconds.
    case iso8601WithFractionalSeconds
    /// Custom `DateFormatter` pattern.
    case formatted(
        format: String,
        timeZoneIdentifier: String? = "UTC",
        localeIdentifier: String? = "en_US_POSIX"
    )
}

/// Simplified key JSON behavior for builder-style configuration.
public enum SwiftRestJSONKeys: Sendable, Equatable {
    /// Decode + encode keys exactly as declared in models.
    case useDefaultKeys
    /// Decode + encode snake_case keys automatically.
    case snakeCase
    /// Decode snake_case but encode default keys.
    case snakeCaseDecodingOnly
    /// Decode default keys but encode snake_case.
    case snakeCaseEncodingOnly
}

extension SwiftRestJSONDates {
    var decodingStrategy: SwiftRestJSONCoding.DateDecodingStrategy {
        switch self {
        case .deferredToDate:
            return .deferredToDate
        case .secondsSince1970:
            return .secondsSince1970
        case .millisecondsSince1970:
            return .millisecondsSince1970
        case .iso8601:
            return .iso8601
        case .iso8601WithFractionalSeconds:
            return .iso8601WithFractionalSeconds
        case .formatted(let format, let timeZoneIdentifier, let localeIdentifier):
            return .formatted(
                format: format,
                timeZoneIdentifier: timeZoneIdentifier,
                localeIdentifier: localeIdentifier
            )
        }
    }

    var encodingStrategy: SwiftRestJSONCoding.DateEncodingStrategy {
        switch self {
        case .deferredToDate:
            return .deferredToDate
        case .secondsSince1970:
            return .secondsSince1970
        case .millisecondsSince1970:
            return .millisecondsSince1970
        case .iso8601:
            return .iso8601
        case .iso8601WithFractionalSeconds:
            return .iso8601WithFractionalSeconds
        case .formatted(let format, let timeZoneIdentifier, let localeIdentifier):
            return .formatted(
                format: format,
                timeZoneIdentifier: timeZoneIdentifier,
                localeIdentifier: localeIdentifier
            )
        }
    }
}

extension SwiftRestJSONKeys {
    var decodingStrategy: SwiftRestJSONCoding.KeyDecodingStrategy {
        switch self {
        case .useDefaultKeys:
            return .useDefaultKeys
        case .snakeCase:
            return .convertFromSnakeCase
        case .snakeCaseDecodingOnly:
            return .convertFromSnakeCase
        case .snakeCaseEncodingOnly:
            return .useDefaultKeys
        }
    }

    var encodingStrategy: SwiftRestJSONCoding.KeyEncodingStrategy {
        switch self {
        case .useDefaultKeys:
            return .useDefaultKeys
        case .snakeCase:
            return .convertToSnakeCase
        case .snakeCaseDecodingOnly:
            return .useDefaultKeys
        case .snakeCaseEncodingOnly:
            return .convertToSnakeCase
        }
    }
}

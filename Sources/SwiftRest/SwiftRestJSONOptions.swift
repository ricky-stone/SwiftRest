import Foundation

/// Simplified date JSON behavior for builder-style configuration.
public enum SwiftRestJSONDates: Sendable, Equatable {
    case deferredToDate
    case secondsSince1970
    case millisecondsSince1970
    case iso8601
    case iso8601WithFractionalSeconds
    case formatted(
        format: String,
        timeZoneIdentifier: String? = "UTC",
        localeIdentifier: String? = "en_US_POSIX"
    )
}

/// Simplified key JSON behavior for builder-style configuration.
public enum SwiftRestJSONKeys: Sendable, Equatable {
    case useDefaultKeys
    case snakeCase
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
        }
    }

    var encodingStrategy: SwiftRestJSONCoding.KeyEncodingStrategy {
        switch self {
        case .useDefaultKeys:
            return .useDefaultKeys
        case .snakeCase:
            return .convertToSnakeCase
        }
    }
}

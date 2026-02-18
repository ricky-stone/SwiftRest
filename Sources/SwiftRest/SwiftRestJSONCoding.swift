import Foundation

/// JSON encoding and decoding options used by SwiftRest.
///
/// This type is `Sendable` and value-based, so it is safe to store in config
/// and pass across concurrency boundaries.
public struct SwiftRestJSONCoding: Sendable, Equatable {
    public enum DateDecodingStrategy: Sendable, Equatable {
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

    public enum DateEncodingStrategy: Sendable, Equatable {
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

    public enum KeyDecodingStrategy: Sendable, Equatable {
        case useDefaultKeys
        case convertFromSnakeCase
    }

    public enum KeyEncodingStrategy: Sendable, Equatable {
        case useDefaultKeys
        case convertToSnakeCase
    }

    public enum DataDecodingStrategy: Sendable, Equatable {
        case deferredToData
        case base64
    }

    public enum DataEncodingStrategy: Sendable, Equatable {
        case deferredToData
        case base64
    }

    public var dateDecodingStrategy: DateDecodingStrategy
    public var dateEncodingStrategy: DateEncodingStrategy
    public var keyDecodingStrategy: KeyDecodingStrategy
    public var keyEncodingStrategy: KeyEncodingStrategy
    public var dataDecodingStrategy: DataDecodingStrategy
    public var dataEncodingStrategy: DataEncodingStrategy
    public var outputFormatting: JSONEncoder.OutputFormatting

    public init(
        dateDecodingStrategy: DateDecodingStrategy = .deferredToDate,
        dateEncodingStrategy: DateEncodingStrategy = .deferredToDate,
        keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys,
        keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys,
        dataDecodingStrategy: DataDecodingStrategy = .base64,
        dataEncodingStrategy: DataEncodingStrategy = .base64,
        outputFormatting: JSONEncoder.OutputFormatting = []
    ) {
        self.dateDecodingStrategy = dateDecodingStrategy
        self.dateEncodingStrategy = dateEncodingStrategy
        self.keyDecodingStrategy = keyDecodingStrategy
        self.keyEncodingStrategy = keyEncodingStrategy
        self.dataDecodingStrategy = dataDecodingStrategy
        self.dataEncodingStrategy = dataEncodingStrategy
        self.outputFormatting = outputFormatting
    }

    /// Foundation defaults (no assumptions).
    public static let foundationDefault = SwiftRestJSONCoding()

    /// Beginner-friendly alias for Foundation defaults.
    public static let `default` = foundationDefault

    /// Useful when your API uses ISO8601 date strings.
    public static let iso8601 = SwiftRestJSONCoding(
        dateDecodingStrategy: .iso8601,
        dateEncodingStrategy: .iso8601
    )

    /// Useful for many web APIs: snake_case keys + ISO8601 dates.
    public static let webAPI = SwiftRestJSONCoding(
        dateDecodingStrategy: .iso8601,
        dateEncodingStrategy: .iso8601,
        keyDecodingStrategy: .convertFromSnakeCase,
        keyEncodingStrategy: .convertToSnakeCase
    )

    /// snake_case keys + ISO8601 dates with fractional seconds.
    public static let webAPIFractionalSeconds = SwiftRestJSONCoding(
        dateDecodingStrategy: .iso8601WithFractionalSeconds,
        dateEncodingStrategy: .iso8601WithFractionalSeconds,
        keyDecodingStrategy: .convertFromSnakeCase,
        keyEncodingStrategy: .convertToSnakeCase
    )

    /// snake_case keys + Unix seconds timestamps.
    public static let webAPIUnixSeconds = SwiftRestJSONCoding(
        dateDecodingStrategy: .secondsSince1970,
        dateEncodingStrategy: .secondsSince1970,
        keyDecodingStrategy: .convertFromSnakeCase,
        keyEncodingStrategy: .convertToSnakeCase
    )

    /// snake_case keys + Unix milliseconds timestamps.
    public static let webAPIUnixMilliseconds = SwiftRestJSONCoding(
        dateDecodingStrategy: .millisecondsSince1970,
        dateEncodingStrategy: .millisecondsSince1970,
        keyDecodingStrategy: .convertFromSnakeCase,
        keyEncodingStrategy: .convertToSnakeCase
    )

    public func dateDecodingStrategy(_ strategy: DateDecodingStrategy) -> Self {
        var copy = self
        copy.dateDecodingStrategy = strategy
        return copy
    }

    public func dateEncodingStrategy(_ strategy: DateEncodingStrategy) -> Self {
        var copy = self
        copy.dateEncodingStrategy = strategy
        return copy
    }

    public func keyDecodingStrategy(_ strategy: KeyDecodingStrategy) -> Self {
        var copy = self
        copy.keyDecodingStrategy = strategy
        return copy
    }

    public func keyEncodingStrategy(_ strategy: KeyEncodingStrategy) -> Self {
        var copy = self
        copy.keyEncodingStrategy = strategy
        return copy
    }

    public func outputFormatting(_ formatting: JSONEncoder.OutputFormatting) -> Self {
        var copy = self
        copy.outputFormatting = formatting
        return copy
    }

    public func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()

        switch dateDecodingStrategy {
        case .deferredToDate:
            decoder.dateDecodingStrategy = .deferredToDate
        case .secondsSince1970:
            decoder.dateDecodingStrategy = .secondsSince1970
        case .millisecondsSince1970:
            decoder.dateDecodingStrategy = .millisecondsSince1970
        case .iso8601:
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let value = try container.decode(String.self)
                let base = makeISO8601Formatter(withFractionalSeconds: false)
                let fractional = makeISO8601Formatter(withFractionalSeconds: true)
                if let date = base.date(from: value) ?? fractional.date(from: value) {
                    return date
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO8601 date string: \(value)"
                )
            }
        case .iso8601WithFractionalSeconds:
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let value = try container.decode(String.self)
                let base = makeISO8601Formatter(withFractionalSeconds: false)
                let fractional = makeISO8601Formatter(withFractionalSeconds: true)
                if let date = fractional.date(from: value) ?? base.date(from: value) {
                    return date
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO8601 date string: \(value)"
                )
            }
        case .formatted(let format, let timeZoneIdentifier, let localeIdentifier):
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let localeIdentifier {
                formatter.locale = Locale(identifier: localeIdentifier)
            }
            if let timeZoneIdentifier {
                formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
            }
            decoder.dateDecodingStrategy = .formatted(formatter)
        }

        switch keyDecodingStrategy {
        case .useDefaultKeys:
            decoder.keyDecodingStrategy = .useDefaultKeys
        case .convertFromSnakeCase:
            decoder.keyDecodingStrategy = .convertFromSnakeCase
        }

        switch dataDecodingStrategy {
        case .deferredToData:
            decoder.dataDecodingStrategy = .deferredToData
        case .base64:
            decoder.dataDecodingStrategy = .base64
        }

        return decoder
    }

    public func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()

        switch dateEncodingStrategy {
        case .deferredToDate:
            encoder.dateEncodingStrategy = .deferredToDate
        case .secondsSince1970:
            encoder.dateEncodingStrategy = .secondsSince1970
        case .millisecondsSince1970:
            encoder.dateEncodingStrategy = .millisecondsSince1970
        case .iso8601:
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var container = encoder.singleValueContainer()
                let formatter = makeISO8601Formatter(withFractionalSeconds: false)
                try container.encode(formatter.string(from: date))
            }
        case .iso8601WithFractionalSeconds:
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var container = encoder.singleValueContainer()
                let formatter = makeISO8601Formatter(withFractionalSeconds: true)
                try container.encode(formatter.string(from: date))
            }
        case .formatted(let format, let timeZoneIdentifier, let localeIdentifier):
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let localeIdentifier {
                formatter.locale = Locale(identifier: localeIdentifier)
            }
            if let timeZoneIdentifier {
                formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
            }
            encoder.dateEncodingStrategy = .formatted(formatter)
        }

        switch keyEncodingStrategy {
        case .useDefaultKeys:
            encoder.keyEncodingStrategy = .useDefaultKeys
        case .convertToSnakeCase:
            encoder.keyEncodingStrategy = .convertToSnakeCase
        }

        switch dataEncodingStrategy {
        case .deferredToData:
            encoder.dataEncodingStrategy = .deferredToData
        case .base64:
            encoder.dataEncodingStrategy = .base64
        }

        encoder.outputFormatting = outputFormatting
        return encoder
    }
}

private func makeISO8601Formatter(withFractionalSeconds: Bool) -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = withFractionalSeconds
        ? [.withInternetDateTime, .withFractionalSeconds]
        : [.withInternetDateTime]
    return formatter
}

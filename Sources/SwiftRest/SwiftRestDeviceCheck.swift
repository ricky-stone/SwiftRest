import Foundation

#if canImport(DeviceCheck)
import DeviceCheck
#endif

/// How DeviceCheck should work when App Attest is also configured.
public enum SwiftRestDeviceCheckMode: Sendable, Equatable {
    /// Use App Attest first. Use DeviceCheck only when App Attest is unavailable or not registered.
    case fallbackToAppAttest
    /// Add DeviceCheck whenever possible, even if App Attest also added headers.
    case always
    /// Use DeviceCheck only and skip App Attest request assertions.
    case only
}

/// What SwiftRest should do when DeviceCheck is enabled but unavailable.
public enum SwiftRestDeviceCheckUnavailableBehavior: Sendable, Equatable {
    /// Continue without DeviceCheck headers.
    case skip
    /// Throw `SwiftRestClientError.deviceCheckUnavailable`.
    case fail
}

/// Header names used when SwiftRest adds a DeviceCheck token to a request.
public struct SwiftRestDeviceCheckHeaders: Sendable, Equatable {
    public var token: String

    public init(token: String = "X-DeviceCheck-Token") {
        self.token = token
    }

    public static let standard = SwiftRestDeviceCheckHeaders()
}

/// DeviceCheck settings used by `SwiftRestAuthClient`.
public struct SwiftRestDeviceCheckConfig: Sendable, Equatable {
    public var mode: SwiftRestDeviceCheckMode
    public var unavailableBehavior: SwiftRestDeviceCheckUnavailableBehavior
    public var headers: SwiftRestDeviceCheckHeaders

    public init(
        mode: SwiftRestDeviceCheckMode = .fallbackToAppAttest,
        unavailableBehavior: SwiftRestDeviceCheckUnavailableBehavior = .skip,
        headers: SwiftRestDeviceCheckHeaders = .standard
    ) {
        self.mode = mode
        self.unavailableBehavior = unavailableBehavior
        self.headers = headers
    }
}

protocol SwiftRestDeviceCheckProviding: Sendable {
    func isSupported() async -> Bool
    func generateToken() async throws -> Data
}

struct SwiftRestDefaultDeviceCheckProvider: SwiftRestDeviceCheckProviding {
    func isSupported() async -> Bool {
        #if canImport(DeviceCheck)
        if #available(iOS 11.0, macOS 10.15, tvOS 11.0, watchOS 9.0, *) {
            return DCDevice.current.isSupported
        }
        #endif
        return false
    }

    func generateToken() async throws -> Data {
        #if canImport(DeviceCheck)
        guard #available(iOS 11.0, macOS 10.15, tvOS 11.0, watchOS 9.0, *) else {
            throw SwiftRestClientError.deviceCheckUnavailable
        }
        return try await DCDevice.current.generateToken()
        #else
        throw SwiftRestClientError.deviceCheckUnavailable
        #endif
    }
}

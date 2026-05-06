import CryptoKit
import Foundation

#if canImport(DeviceCheck) && os(iOS)
import DeviceCheck
#endif

/// What SwiftRest should do when App Attest is enabled but unavailable.
public enum SwiftRestAppAttestUnavailableBehavior: Sendable {
    /// Continue without App Attest headers.
    ///
    /// This is the default so Simulator, macOS, unsupported devices, and unsupported extensions
    /// can keep using normal token auth.
    case skip

    /// Throw `SwiftRestClientError.appAttestUnavailable`.
    case fail
}

/// Header names used when SwiftRest adds an App Attest assertion to a request.
public struct SwiftRestAppAttestHeaders: Sendable {
    public var keyID: String
    public var assertion: String
    public var clientData: String

    public init(
        keyID: String = "X-App-Attest-Key-ID",
        assertion: String = "X-App-Attest-Assertion",
        clientData: String = "X-App-Attest-Client-Data"
    ) {
        self.keyID = keyID
        self.assertion = assertion
        self.clientData = clientData
    }

    public static let standard = SwiftRestAppAttestHeaders()
}

/// App Attest settings used by `SwiftRestAuthClient`.
public struct SwiftRestAppAttestConfig: Sendable {
    public var challengeEndpoint: String
    public var registerEndpoint: String
    public var challengeMethod: HTTPMethod
    public var registerMethod: HTTPMethod
    public var unavailableBehavior: SwiftRestAppAttestUnavailableBehavior
    public var headers: [String: String]
    public var assertionHeaders: SwiftRestAppAttestHeaders

    public init(
        challengeEndpoint: String,
        registerEndpoint: String,
        challengeMethod: HTTPMethod = .post,
        registerMethod: HTTPMethod = .post,
        unavailableBehavior: SwiftRestAppAttestUnavailableBehavior = .skip,
        headers: [String: String] = [:],
        assertionHeaders: SwiftRestAppAttestHeaders = .standard
    ) {
        self.challengeEndpoint = challengeEndpoint
        self.registerEndpoint = registerEndpoint
        self.challengeMethod = challengeMethod
        self.registerMethod = registerMethod
        self.unavailableBehavior = unavailableBehavior
        self.headers = headers
        self.assertionHeaders = assertionHeaders
    }
}

protocol SwiftRestAppAttestProviding: Sendable {
    func isSupported() async -> Bool
    func generateKey() async throws -> String
    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data
    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data
}

struct SwiftRestDefaultAppAttestProvider: SwiftRestAppAttestProviding {
    func isSupported() async -> Bool {
        #if canImport(DeviceCheck) && os(iOS)
        if #available(iOS 14.0, *) {
            return DCAppAttestService.shared.isSupported
        }
        #endif
        return false
    }

    func generateKey() async throws -> String {
        #if canImport(DeviceCheck) && os(iOS)
        guard #available(iOS 14.0, *) else {
            throw SwiftRestClientError.appAttestUnavailable
        }
        return try await DCAppAttestService.shared.generateKey()
        #else
        throw SwiftRestClientError.appAttestUnavailable
        #endif
    }

    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data {
        #if canImport(DeviceCheck) && os(iOS)
        guard #available(iOS 14.0, *) else {
            throw SwiftRestClientError.appAttestUnavailable
        }
        return try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: clientDataHash)
        #else
        throw SwiftRestClientError.appAttestUnavailable
        #endif
    }

    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
        #if canImport(DeviceCheck) && os(iOS)
        guard #available(iOS 14.0, *) else {
            throw SwiftRestClientError.appAttestUnavailable
        }
        return try await DCAppAttestService.shared.generateAssertion(keyID, clientDataHash: clientDataHash)
        #else
        throw SwiftRestClientError.appAttestUnavailable
        #endif
    }
}

enum SwiftRestAppAttestPurpose: String, Sendable {
    case registration
    case assertion
}

struct SwiftRestAppAttestChallengeRequest: Encodable, Sendable {
    let purpose: String
}

struct SwiftRestAppAttestChallengeResponse: Decodable, Sendable {
    let challenge: String
}

struct SwiftRestAppAttestRegisterRequest: Encodable, Sendable {
    let keyId: String
    let attestationObject: String
    let clientData: String
}

struct SwiftRestAppAttestRegistrationClientData: Encodable, Sendable {
    let challenge: String
    let purpose: String = SwiftRestAppAttestPurpose.registration.rawValue
}

struct SwiftRestAppAttestClientData: Encodable, Sendable {
    let challenge: String
    let method: String
    let path: String
    let query: [SwiftRestAppAttestQueryItem]
    let bodySHA256: String?

    init(challenge: String, request: SwiftRestRequest, path: String) {
        self.challenge = challenge
        self.method = request.method.rawValue
        self.path = path
        self.query = request.parameters
            .map { SwiftRestAppAttestQueryItem(name: $0.key, value: $0.value) }
            .sorted()
        self.bodySHA256 = request.body.map { SwiftRestAppAttestSHA256.base64Hash(of: $0) }
    }
}

struct SwiftRestAppAttestQueryItem: Encodable, Sendable, Comparable {
    let name: String
    let value: String

    static func < (lhs: SwiftRestAppAttestQueryItem, rhs: SwiftRestAppAttestQueryItem) -> Bool {
        if lhs.name == rhs.name {
            return lhs.value < rhs.value
        }
        return lhs.name < rhs.name
    }
}

enum SwiftRestAppAttestSHA256 {
    static func hash(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    static func base64Hash(of data: Data) -> String {
        hash(data).base64EncodedString()
    }
}

enum SwiftRestAppAttestJSON {
    static func encodedData<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
}

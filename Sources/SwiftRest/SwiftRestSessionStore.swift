import Foundation

/// Storage used by the auth/session wrapper.
///
/// Built-in options include Keychain, UserDefaults, memory, and no storage.
public protocol SwiftRestSessionStore: Sendable {
    func load() async throws -> SwiftRestAuthSession?
    func save(_ session: SwiftRestAuthSession) async throws
    func clear() async throws
}

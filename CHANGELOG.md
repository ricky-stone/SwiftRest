# Changelog

## 2.0.0 - 2026-02-14

### Added
- `HTTPHeaders` for case-insensitive header access.
- `SwiftRestConfig` and `RetryPolicy` for simple client-wide behavior.
- Raw response support (`executeRaw`, `getRaw`, `postRaw`, etc.).
- Beginner-friendly verb methods (`get`, `post`, `put`, `patch`, `delete`).
- Response helpers: `text()`, `decodeBody(_:)`, `jsonObject()`, `prettyPrintedJSON()`.
- Source version marker: `SwiftRestVersion.current`.

### Changed
- `SwiftRestClient` initializer now validates base URL and can throw.
- Public APIs use Swift 6-style `Decodable & Sendable` constraints.
- Error payload model is `Sendable` and easier to inspect.
- README fully rewritten for beginner-first usage.

### Removed / Breaking
- Existing callers that assumed a non-throwing client init must add `try`.
- Protocol surface changed (`executeRaw` added, generic constraints tightened).

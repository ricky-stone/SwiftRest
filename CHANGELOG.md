# Changelog

## 3.0.0 - 2026-02-14

### Changed
- README examples were revised for clarity, including quick and `do/catch` patterns.
- Added stronger one-call examples for reading decoded data and response headers together.
- Standardized naming around `.standard` for default config/retry profiles.

### Removed / Breaking
- Removed legacy default-profile aliases in favor of `.standard` naming only.

## 2.0.1 - 2026-02-14

### Added
- Header-friendly typed convenience methods: `getResponse`, `postResponse`, `putResponse`, `patchResponse`, `deleteResponse`.

### Changed
- Preferred default config naming is now `SwiftRestConfig.standard` and `RetryPolicy.standard`.
- `SwiftRestClient` now defaults to `.standard` when no config is passed.
- README now includes explicit header-reading patterns, default config behavior, and license/author/acknowledgment guidance.

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
- README fully rewritten for easy onboarding usage.

### Removed / Breaking
- Existing callers that assumed a non-throwing client init must add `try`.
- Protocol surface changed (`executeRaw` added, generic constraints tightened).

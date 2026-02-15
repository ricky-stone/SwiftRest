# Changelog

## 3.1.0 - 2026-02-15

### Added
- Configurable JSON coding options via `SwiftRestJSONCoding`:
  - date decoding/encoding strategies
  - key decoding/encoding strategies
  - data decoding/encoding strategies
  - encoder output formatting
- Easy presets:
  - `.foundationDefault`
  - `.iso8601`
  - `.webAPI` (snake_case + ISO8601)
- `SwiftRestConfig` JSON customization helpers:
  - `.jsonCoding(...)`
  - `.dateDecodingStrategy(...)`
  - `.dateEncodingStrategy(...)`
  - `.keyDecodingStrategy(...)`
  - `.keyEncodingStrategy(...)`
- Per-request JSON strategy overrides in `SwiftRestRequest`.

### Changed
- `SwiftRestClient` now honors JSON strategy from request/config when decoding.
- Convenience write methods now encode JSON bodies using config JSON coding.
- README expanded with simple JSON strategy examples.

## 3.0.2 - 2026-02-14

### Added
- GitHub Actions CI workflow (`swift build` + `swift test` on macOS/Swift 6).
- Repository automation files:
  - `.github/CODEOWNERS`
  - `.github/dependabot.yml`
- Community health files:
  - `CONTRIBUTING.md`
  - `CODE_OF_CONDUCT.md`
  - `SECURITY.md`
  - issue templates and PR template
- README badges and community links for Discussions, Issues, and contribution/security guidance.

### Changed
- Repository metadata updated (description, topics, homepage).
- GitHub Discussions enabled.
- Published stable GitHub Release for `v3.0.1`.

## 3.0.1 - 2026-02-14

### Changed
- Refined README language and examples to keep both compact and `do/catch` flows clear.
- Added explicit beginner-friendly examples for:
  - posting with a model variable
  - success/failure-only POST calls with `NoContent`
  - optional status-based checks with `isSuccess`
- Removed wording that implied one usage style is less safe than another.

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

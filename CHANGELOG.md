# Changelog

## 4.2.0 - 2026-02-18

### Added
- Beginner-friendly endpoint refresh save hook:
  - `onTokensRefreshed` callback for persisting refreshed tokens.
- Optional endpoint refresh response field mapping:
  - `refreshTokenResponseField` for rotated refresh token responses.
- Expanded tests for endpoint refresh callback flows.

### Changed
- README refresh docs now explain field mapping in beginner detail:
  - what each closure/field does
  - exact matching behavior for request/response key names
  - simple session store pattern for read/write token flow
- README headers docs now clearly separate:
  - client default headers
  - per-request headers

## 4.1.0 - 2026-02-18

### Added
- Per-request auth override controls in the V4 request chain:
  - `.noAuth()` to skip `Authorization` on a single call.
  - `.autoRefresh(false)` to disable 401 refresh on a single call.
  - `.refreshTokenProvider { ... }` to override refresh token lookup for a single call.
- New tests covering per-request auth override behavior.

### Changed
- Endpoint auto refresh now honors per-request `refreshTokenProvider` overrides.
- Auth pipeline now respects per-request `.noAuth()` and `.autoRefresh(false)` in refresh decisions.
- README expanded with:
  - default client behavior section
  - beginner-friendly headers access example using `valueAndHeaders(...)`
  - per-request auth override examples

## 4.0.0 - 2026-02-18

### Added
- New chain-first setup API:
  - `SwiftRest.for(...). ... .client`
  - `SwiftRestBuilder` with chainable config methods.
- New chain-first request API:
  - `client.path(...).get()/post()/put()/patch()/delete()`
  - terminal output methods:
    - `.value(...)`
    - `.response(...)`
    - `.raw(...)`
    - `.result(error: ...)`
    - `.valueAndHeaders(...)`
- New simplified JSON options:
  - `SwiftRestJSONDates`
  - `SwiftRestJSONKeys`
- New safe refresh context for custom refresh handlers:
  - `SwiftRestRefreshContext`
- New beginner-friendly refresh strategy model:
  - `SwiftRestAuthRefresh.endpoint(...)`
  - `SwiftRestAuthRefresh.custom(...)`
  - `SwiftRestAuthRefreshMode`
  - `SwiftRestAuthRefreshEndpoint`
- New convenience aliases:
  - `SwiftRestConfig.default`
  - `SwiftRestJSONCoding.default`
  - `SwiftRestDebugLogging.off`
- New response helpers:
  - `SwiftRestResponse.value`
  - `SwiftRestResponse.headerInt(...)`
  - `SwiftRestResponse.headerDouble(...)`

### Changed
- Auto refresh now supports safe single-client usage in endpoint and custom modes.
- Custom refresh uses a bypass context so refresh calls skip normal auth middleware.
- README fully rewritten around one clean V4 chain style with Swift + SwiftUI examples.

## 3.4.0 - 2026-02-18

### Added
- Built-in auth refresh support:
  - `SwiftRestAuthRefresh`
  - `SwiftRestConfig.authRefresh`
  - `SwiftRestConfig.authRefresh(...)`
  - `SwiftRestClient.setAuthRefresh(...)`
  - `SwiftRestClient.clearAuthRefresh()`
- Automatic unauthorized flow (opt-in):
  - `401` triggers refresh callback
  - request retries once with refreshed token
  - single-flight refresh sharing across concurrent requests
- Typed result-style API for easy branching:
  - `SwiftRestResult<Success, APIError>`
  - `executeResult(...)`
  - `getResult(...)`
  - `deleteResult(...)`
  - `postResult(...)`
  - `putResult(...)`
  - `patchResult(...)`
- New `SwiftRestClientError.authRefreshFailed(...)` error case.
- Expanded test coverage for refresh, single-flight behavior, per-request policy, and result-style handling.

### Changed
- README rewritten with beginner and power-user sections, including Swift and SwiftUI examples.

## 3.3.0 - 2026-02-18

### Added
- Query model encoding helper: `SwiftRestQuery.encode(...)`.
- Request builder query helpers:
  - `SwiftRestRequest.addQuery(...)`
  - `SwiftRestRequest.query(...)`
- Beginner-friendly query-model overloads:
  - `getRaw(..., query: ...)`
  - `get(..., query: ...)`
  - `getResponse(..., query: ...)`
  - `deleteRaw(..., query: ...)`
  - `delete(..., query: ...)`
  - `deleteResponse(..., query: ...)`
- Debug logging configuration:
  - `SwiftRestDebugLogging`
  - `SwiftRestConfig.debugLogging`
  - `SwiftRestConfig.debugLogging(...)`
- New tests for query encoding, query overloads, and redacted logging output.

### Changed
- `SwiftRestClient` now logs request/response summaries when debug logging is enabled.
- Header logging automatically redacts sensitive header values (authorization, token-like, cookie, secret-like).
- README expanded with beginner-focused query-model and logging examples.

## 3.2.0 - 2026-02-18

### Added
- Global access token support in `SwiftRestConfig` and `SwiftRestClient`:
  - `SwiftRestConfig.accessToken`
  - `SwiftRestConfig.accessToken(_:)`
  - `SwiftRestClient.setAccessToken(_:)`
  - `SwiftRestClient.clearAccessToken()`
- Async token provider support for rotating/refreshing credentials:
  - `SwiftRestAccessTokenProvider`
  - `SwiftRestConfig.accessTokenProvider`
  - `SwiftRestConfig.accessTokenProvider(_:)`
  - `SwiftRestClient.setAccessTokenProvider(_:)`
  - `SwiftRestClient.clearAccessTokenProvider()`
- Auth resolution precedence:
  - per-request token
  - token provider
  - global token
- Tests that validate outgoing `Authorization` header behavior and precedence.

### Changed
- README now includes beginner-friendly authentication examples for global, per-request, and provider-based token flows.

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

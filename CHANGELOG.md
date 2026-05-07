# Changelog

## 6.2.0 - 2026-05-07

### Added
- Chainable no-body POST support:
  - `client.path(...).post().send()`
  - `auth.path(...).post().send()`
- README examples for POST endpoints that need headers or `.noAuth()` but do not need a request body.

### Changed
- Version marker updated to `6.2.0`.
- README install snippet updated to `6.2.0`.

### Compatibility
- Existing `.post(body:)` behavior is unchanged.
- This is a non-breaking v6 minor release.

## 6.1.0 - 2026-05-06

### Added
- Optional Apple DeviceCheck support for the auth/session client:
  - `.deviceCheck(mode:unavailableBehavior:headers:)`
  - `.deviceCheck(false)` per-request bypass
  - `SwiftRestDeviceCheckConfig`
  - `SwiftRestDeviceCheckMode`
  - `SwiftRestDeviceCheckUnavailableBehavior`
  - `SwiftRestDeviceCheckHeaders`
- Default App Attest fallback behavior:
  - App Attest is used first when registered and available.
  - DeviceCheck is used when App Attest is unavailable or not registered.
- DeviceCheck provider abstraction for testability.
- README DeviceCheck section with beginner examples and server responsibilities.

### Changed
- Version marker updated to `6.1.0`.
- README install snippet updated to `6.1.0`.

### Compatibility
- DeviceCheck tokens are not stored in Keychain.
- Existing Keychain session, session token, refresh token, App Attest, and refresh retry behavior remains supported.
- Existing v6 App Attest tests continue passing.

## 6.0.0 - 2026-05-06

### Added
- Optional Apple App Attest support for the auth/session client:
  - `.appAttest(challengeEndpoint:registerEndpoint:...)`
  - `ensureAppAttestRegistered()`
  - per-request `.appAttest(false)` bypass
  - default skip behavior when App Attest is unavailable
- App Attest key ID persistence on `SwiftRestAuthSession`.
- Beginner auth presets:
  - `.sessionTokens()` for `sessionToken` and `refreshToken`
  - `.accessTokens()` for `accessToken` and `refreshToken`
  - `.tokenFields(token:refresh:)` for custom token names
- Session inspection helpers:
  - `hasSession()`
  - `hasRefreshToken()`
  - `hasAppAttestKey()`

### Changed
- Version marker updated to `6.0.0`.
- README rewritten for the v6 beginner-first flow, including App Attest, session tokens, refresh tokens, Keychain storage, and server expectations.
- `HTTPMethod` now explicitly conforms to `Equatable`.

### Compatibility
- Existing v5 auth, Keychain, refresh, and request-chain behavior remains supported.
- Old saved sessions without an App Attest key decode normally.
- SwiftRest continues to use its built-in Keychain store. SwiftKey is not a package dependency.

## 5.1.0 - 2026-03-23

### Removed
- Legacy V3 convenience wrappers from `SwiftRestClient`, including:
  - `getRaw/get/getResponse`
  - `deleteRaw/delete/deleteResponse`
  - `postRaw/post/postResponse`
  - `putRaw/put/putResponse`
  - `patchRaw/patch/patchResponse`
  - `getResult/deleteResult/postResult/putResult/patchResult`
- The `makeRequest(...)` helper overloads that only existed to support those legacy wrappers.

### Changed
- Public API surface is now slimmer and the client autocomplete is focused on the chain-based V4/V5 path.
- README version snippets updated to `5.1.0`.
- Tests were updated to use the chain API exclusively.
- Version marker updated to `5.1.0`.

## 5.0.1 - 2026-03-23

### Fixed
- Replaced the external SwiftKey package dependency with a built-in Keychain session store so the package builds on the GitHub Actions Swift 6.0 runner.
- Updated the README and public comments to describe the built-in Keychain preset correctly.

## 5.0.0 - 2026-03-23

### Added
- New beginner-first plain client factory:
  - `SwiftRest.client(baseURL:config:session:)`
  - No `try` required for the normal URL-based setup path.
- New beginner-first auth/session wrapper:
  - `SwiftRest.auth(baseURL:config:session:)`
  - `SwiftRestAuthClient`
  - `SwiftRestAuthSession`
  - `SwiftRestSessionStore`
- Built-in session storage presets:
  - `.keychain()` backed by SwiftKey
  - `.defaults()`
  - `.memory()`
  - `.none()`
  - `.store(...)` for custom storage
- Token mapping helpers for both JSON body fields and response headers:
  - `.tokenField(...)`
  - `.tokenHeader(...)`
  - `.refreshTokenField(...)`
  - `.refreshTokenHeader(...)`
- Auth refresh configuration with simple recovery flow:
  - `.refresh(endpoint:method:requestRefreshField:triggerStatusCodes:headers:)`
  - automatic save + retry after refresh success
- Auth session helpers:
  - `currentSession()`
  - `session()`
  - `save(token:refreshToken:)`
  - `logout()`
- Beginner-friendly auth request chain with:
  - `.noAuth()`
  - `.authToken(...)`
  - `.valueAndHeaders(...)`
  - `.raw()`
  - `.send()`
- README rewritten around the new v5 beginner-first flow, with plain Swift and SwiftUI examples.

### Changed
- SwiftRest v5 now focuses docs on the new auth/session wrapper instead of the older auth-refresh configuration style.
- Keychain storage is now presented as the default beginner path.
- Version marker updated to `5.0.0`.

## 4.8.0 - 2026-02-19

### Added
- Typed path segment support for V4 request chains.
  - New `SwiftRestPathSegmentConvertible` protocol.
  - Built-in support for: `String`, `Substring`, all integer types, `Double`, `Float`, `Decimal`, `Bool`, and `UUID`.
- New URL path append helper:
  - `SwiftRestPathBuilder.path(url:)`
  - Appends only URL path components (ignores scheme, host, query, and fragment).
- New tests for typed path segments and URL-based path appending.

### Changed
- README chainable path docs now include primitive and URL examples for beginners.

## 4.7.0 - 2026-02-19

### Added
- Chainable path segment helpers on the V4 request chain:
  - `SwiftRestPathBuilder.path(_:)`
  - `SwiftRestPathBuilder.paths(_:)`
- Automatic path segment normalization:
  - leading/trailing slashes are trimmed while joining
  - duplicate separators are collapsed when segments are appended
- New tests for segment chaining and slash normalization behavior.

### Changed
- README now includes beginner-friendly chainable path examples and clearly notes that manual `/` separators are not required.

## 4.6.0 - 2026-02-18

### Added
- New V4 terminal request method:
  - `SwiftRestPreparedRequest.send()`
  - For success/failure-only calls (no response model required)
- New tests for `send()` success and failure behavior.

### Changed
- README now documents `send()` in core request flow.
- README includes beginner-friendly no-response examples including logout.

## 4.5.0 - 2026-02-18

### Changed
- Deprecated legacy V3-style convenience APIs on `SwiftRestClient`:
  - `getRaw/get/getResponse`
  - `deleteRaw/delete/deleteResponse`
  - `postRaw/post/postResponse`
  - `putRaw/put/putResponse`
  - `patchRaw/patch/patchResponse`
  - `getResult/deleteResult/postResult/putResult/patchResult`
- Added migration-focused deprecation messages pointing to the V4 chain API:
  - `client.path(...).verb().value()/response()/raw()/result()`
- Expanded inline API documentation comments across V4 types for better Xcode option-click help:
  - `SwiftRestBuilder`
  - `SwiftRestPathBuilder`
  - `SwiftRestPreparedRequest`
  - `SwiftRestAuthRefresh` and endpoint configuration
  - `SwiftRestJSONDates` and `SwiftRestJSONKeys`
- README migration section now explicitly notes that legacy V3-style methods are deprecated.

## 4.4.0 - 2026-02-18

### Added
- Configurable auth-refresh trigger status codes.
  - Default remains `[401]`.
  - Supports API-specific auth flows like `[401, 403]`.
- New endpoint builder parameter:
  - `triggerStatusCodes` in `.autoRefresh(endpoint:...)`.
- New `SwiftRestAuthRefresh` customization:
  - `.triggerStatusCodes(...)`.
- New tests for custom trigger code behavior and defaults.

### Changed
- Auth refresh execution now checks configured trigger status codes instead of hard-coded `401`.
- README refresh docs now explain trigger status code customization with beginner examples.

## 4.3.0 - 2026-02-18

### Added
- V4 request chain now includes:
  - `.head()`
  - `.options()`
- `SwiftRestRequest` static helpers now include:
  - `.head(...)`
  - `.options(...)`
- New JSON coding presets:
  - `SwiftRestJSONCoding.webAPIFractionalSeconds`
  - `SwiftRestJSONCoding.webAPIUnixSeconds`
  - `SwiftRestJSONCoding.webAPIUnixMilliseconds`
- New key strategy modes:
  - `SwiftRestJSONKeys.snakeCaseDecodingOnly`
  - `SwiftRestJSONKeys.snakeCaseEncodingOnly`

### Changed
- README expanded with:
  - all HTTP methods examples (`GET/POST/PUT/PATCH/DELETE/HEAD/OPTIONS`)
  - additional common JSON presets
  - additional key strategy examples

## 4.2.1 - 2026-02-18

### Changed
- README expanded with additional beginner-friendly examples:
  - query params without a model (`.parameters` / `.parameter`)
  - success-only request handling with `raw.isSuccess`
  - multipart upload with manual raw request body
  - pagination using response headers
  - auth-refresh failure handling (clear session + route to login)
- README token store example now includes `setAccessToken` and `clear` helpers for consistency.

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

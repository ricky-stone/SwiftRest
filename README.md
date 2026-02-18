# SwiftRest

[![CI](https://github.com/ricky-stone/SwiftRest/actions/workflows/ci.yml/badge.svg)](https://github.com/ricky-stone/SwiftRest/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.0+-F05138.svg)](https://www.swift.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/ricky-stone/SwiftRest/blob/main/LICENSE.txt)
[![Swift Package Index](https://img.shields.io/badge/Swift%20Package%20Index-SwiftRest-111111)](https://swiftpackageindex.com/ricky-stone/SwiftRest)
[![GitHub stars](https://img.shields.io/github/stars/ricky-stone/SwiftRest?style=social)](https://github.com/ricky-stone/SwiftRest/stargazers)

SwiftRest is a Swift 6 REST client with one clean chain-first API.

- Swift 6 concurrency-safe (`SwiftRestClient` is an `actor`)
- Simple setup chain (`SwiftRest.for(...).client`)
- Simple request chain (`client.path(...).get().value()`)
- Easy headers, typed results, and built-in auto refresh

## Requirements

- Swift 6.0+
- iOS 15+
- macOS 12+

## Installation

Use Swift Package Manager with:

- `https://github.com/ricky-stone/SwiftRest.git`

## Default Client Behavior

This is the minimum setup:

```swift
let client = try SwiftRest.for("https://api.example.com").client
```

Defaults used by this client:

- `Accept: application/json`
- `timeout = 30` seconds
- `retry = .standard` (3 attempts total)
- `json = .default` (Foundation key/date behavior)
- `logging = .off`
- no access token, no auto refresh

## Community

- Questions and ideas: [GitHub Discussions](https://github.com/ricky-stone/SwiftRest/discussions)
- Bugs and feature requests: [GitHub Issues](https://github.com/ricky-stone/SwiftRest/issues)
- Contributing guide: [`CONTRIBUTING.md`](./CONTRIBUTING.md)
- Security reports: [`SECURITY.md`](./SECURITY.md)

## 60-Second Start (Swift)

```swift
import SwiftRest

struct User: Decodable, Sendable {
    let id: Int
    let firstName: String
}

let client = try SwiftRest
    .for("https://api.example.com")
    .json(.default)
    .jsonDates(.iso8601)
    .jsonKeys(.useDefaultKeys)
    .client

let user: User = try await client.path("users/1").get().value()
print(user.firstName)
```

## 60-Second Start (SwiftUI)

```swift
import SwiftUI
import SwiftRest

struct User: Decodable, Sendable {
    let id: Int
    let firstName: String
}

@MainActor
final class UserViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var errorText: String?

    private let client: SwiftRestClient

    init() {
        client = try! SwiftRest
            .for("https://api.example.com")
            .json(.default)
            .jsonDates(.iso8601)
            .client
    }

    func load() async {
        do {
            let user: User = try await client.path("users/1").get().value()
            name = user.firstName
            errorText = nil
        } catch let error as SwiftRestClientError {
            errorText = error.userMessage
        } catch {
            errorText = error.localizedDescription
        }
    }
}
```

## One Request Flow

SwiftRest V4 keeps one request chain with 3 clear outputs.

```swift
let value: User = try await client.path("users/1").get().value()

let response: SwiftRestResponse<User> = try await client.path("users/1").get().response()

let result: SwiftRestResult<User, APIErrorModel> =
    await client.path("users/1").get().result(error: APIErrorModel.self)
```

## Headers Made Easy

### Client default headers (every request)

```swift
let client = try SwiftRest
    .for("https://api.example.com")
    .header("X-App", "SnookerLive")
    .headers([
        "X-Platform": "iOS",
        "Accept-Language": "en-GB"
    ])
    .client
```

### Per-request headers (one call only)

```swift
let result = try await client
    .path("users/1")
    .header("X-Trace-Id", UUID().uuidString)
    .headers(["X-Experiment": "A"])
    .get()
    .valueAndHeaders(as: User.self)

print(result.value.firstName)
print(result.headers["x-request-id"] ?? "missing")
print(result.headers["x-rate-limit-remaining"] ?? "0")
```

## Setup Chain Reference

```swift
let client = try SwiftRest
    .for("https://api.example.com")
    .accessToken("initial-token")
    .accessTokenProvider { await sessionStore.accessToken }
    .autoRefresh(
        endpoint: "auth/refresh",
        refreshTokenProvider: { await sessionStore.refreshToken },
        onTokensRefreshed: { accessToken, refreshToken in
            await sessionStore.setTokens(accessToken: accessToken, refreshToken: refreshToken)
        }
    )
    .json(.webAPI)
    .jsonDates(.iso8601)
    .jsonKeys(.snakeCase)
    .retry(.standard)
    .timeout(30)
    .logging(.off)
    .client
```

## Auto Refresh (Single Client, Safe)

Auto refresh is built-in and safe for single-client usage.

- On `401`, SwiftRest refreshes once and retries the original request once.
- Refresh calls bypass normal auth middleware to avoid recursion.
- Concurrent `401` requests share one refresh (single-flight).

### Beginner mode (endpoint-driven)

Step 1, make a token store:

```swift
actor SessionStore {
    private var accessTokenValue: String?
    private var refreshTokenValue: String?

    var accessToken: String? { accessTokenValue }   // read
    var refreshToken: String? { refreshTokenValue } // read

    func setTokens(accessToken: String, refreshToken: String?) {
        self.accessTokenValue = accessToken
        self.refreshTokenValue = refreshToken
    }
}
```

Step 2, configure refresh:

```swift
let client = try SwiftRest
    .for("https://api.example.com")
    .accessTokenProvider { await sessionStore.accessToken }
    .autoRefresh(
        endpoint: "auth/refresh",
        refreshTokenProvider: { await sessionStore.refreshToken },
        refreshTokenField: "refreshToken",
        tokenField: "accessToken",
        refreshTokenResponseField: "refreshToken",
        onTokensRefreshed: { accessToken, refreshToken in
            await sessionStore.setTokens(accessToken: accessToken, refreshToken: refreshToken)
        }
    )
    .client
```

Providers can also be simple closures when values are already available:

```swift
.accessTokenProvider { "token-value" }
.autoRefresh(endpoint: "auth/refresh", refreshTokenProvider: { "refresh-value" })
```

What each setting does:

- `accessTokenProvider`: reads your current access token before requests.
- `refreshTokenProvider`: reads your current refresh token when a `401` happens.
- `refreshTokenField`: JSON key sent to refresh endpoint in request body.
- `tokenField`: JSON key read from refresh response for the new access token.
- `refreshTokenResponseField`: optional key read from refresh response for rotated refresh token.
- `onTokensRefreshed`: callback to save refreshed token values to your store/keychain.

Example refresh response:

```json
{
  "accessToken": "...",
  "accessTokenExpiresUtc": "2026-02-18T23:10:04.5435334Z",
  "refreshToken": "...",
  "refreshTokenExpiresUtc": "2026-03-20T22:50:04.5435334Z",
  "tokenType": "Bearer"
}
```

Matching config for that response:

```swift
.autoRefresh(
    endpoint: "auth/refresh",
    refreshTokenProvider: { await sessionStore.refreshToken },
    refreshTokenField: "refreshToken",
    tokenField: "accessToken",
    refreshTokenResponseField: "refreshToken"
)
```

If your API uses different names, set exact key names:

```swift
.autoRefresh(
    endpoint: "auth/refresh",
    refreshTokenProvider: { await sessionStore.refreshToken },
    refreshTokenField: "refresh_token",
    tokenField: "token",
    refreshTokenResponseField: "refresh_token"
)
```

### Advanced mode (custom refresh logic with safe bypass context)

```swift
struct RefreshTokenBody: Encodable, Sendable {
    let refreshToken: String
}

struct RefreshTokenResponse: Decodable, Sendable {
    let accessToken: String
}

let refresh = SwiftRestAuthRefresh.custom { refresh in
    let dto: RefreshTokenResponse = try await refresh.post(
        "auth/refresh",
        body: RefreshTokenBody(refreshToken: await sessionStore.refreshToken)
    )
    await sessionStore.setAccessToken(dto.accessToken)
    return dto.accessToken
}

let client = try SwiftRest
    .for("https://api.example.com")
    .accessTokenProvider { await sessionStore.accessToken }
    .autoRefresh(refresh)
    .client
```

## Per-Request Auth Overrides

Use these when one call needs different auth behavior.

```swift
let user: User = try await client
    .path("users/1")
    .authToken("one-off-token") // per-request access token
    .get()
    .value()
```

```swift
let publicInfo: PublicInfo = try await client
    .path("public/info")
    .noAuth() // skips Authorization header for this call
    .get()
    .value()
```

```swift
let raw = try await client
    .path("secure/profile")
    .autoRefresh(false) // skip 401 refresh for this call
    .get()
    .raw()

print(raw.statusCode)
```

```swift
let user: User = try await client
    .path("secure/profile")
    .refreshTokenProvider { await sessionStore.temporaryRefreshToken }
    .get()
    .value()
```

`refreshTokenProvider` above is only used if that call hits `401` and refresh is enabled on the client.

## Query and Body Models

### Query model

```swift
struct UserQuery: Encodable, Sendable {
    let page: Int
    let search: String
    let includeInactive: Bool
}

let users: [User] = try await client
    .path("users")
    .query(UserQuery(page: 1, search: "ricky", includeInactive: false))
    .get()
    .value()
```

### POST model body

```swift
struct CreateUser: Encodable, Sendable {
    let firstName: String
}

let created: User = try await client
    .path("users")
    .post(body: CreateUser(firstName: "Ricky"))
    .value()
```

### Value + headers together

```swift
let result = try await client
    .path("users/1")
    .get()
    .valueAndHeaders(as: User.self)

print(result.value.firstName)
print(result.headers["x-request-id"] ?? "missing")
```

## JSON Options (Flexible)

### Common presets

```swift
.json(.default) // Foundation defaults
.json(.webAPI)  // snake_case keys + ISO8601 dates
```

### Key strategies

```swift
.jsonKeys(.useDefaultKeys) // id, firstName, updatedUtc
.jsonKeys(.snakeCase)      // first_name, updated_utc
```

### Date strategies

```swift
.jsonDates(.iso8601)
.jsonDates(.iso8601WithFractionalSeconds)
.jsonDates(.secondsSince1970)
.jsonDates(.millisecondsSince1970)
.jsonDates(.formatted(format: "yyyy-MM-dd HH:mm:ss"))
```

### Per-request overrides

```swift
let config: AppConfig = try await client
    .path("app-config")
    .jsonDates(.iso8601)
    .jsonKeys(.useDefaultKeys)
    .get()
    .value()
```

## Result-Style API

Result-style calls are great for UI state management.

```swift
struct APIErrorModel: Decodable, Sendable {
    let message: String
    let code: String?
}

let result: SwiftRestResult<User, APIErrorModel> =
    await client.path("users/1").get().result(error: APIErrorModel.self)

switch result {
case .success(let response):
    print(response.value?.firstName ?? "none")

case .apiError(let decoded, let raw):
    print(raw.statusCode)
    print(decoded?.message ?? "Unknown API error")

case .failure(let error):
    print(error.userMessage)
}
```

## Debug Logging

```swift
let client = try SwiftRest
    .for("https://api.example.com")
    .logging(.headers)
    .client
```

Modes:

- `.logging(.off)` or `.logging(.disabled)`
- `.logging(.basic)`
- `.logging(.headers)`

Sensitive headers are redacted automatically.

## Retry Policy

```swift
let client = try SwiftRest
    .for("https://api.example.com")
    .retry(
        RetryPolicy(
            maxAttempts: 4,
            baseDelay: 0.4,
            backoffMultiplier: 2,
            maxDelay: 5
        )
    )
    .client
```

## Migration (V3 -> V4)

V4 preferred style:

- Setup: `SwiftRest.for(...). ... .client`
- Requests: `client.path(...).verb().value/response/result`

You can still keep your models (`Decodable & Sendable`, `Encodable & Sendable`) the same.

## License

SwiftRest is licensed under the MIT License. See `LICENSE.txt`.

Industry standard for MIT:

- You can use this in commercial/private/open-source projects.
- Keep the copyright + license notice when redistributing.
- Attribution is appreciated but not required by MIT.

## Author

Created and maintained by Ricky Stone.

## Acknowledgments

Thanks to everyone who tests, reports issues, and contributes improvements.

## Version

Current source version marker: `SwiftRestVersion.current == "4.2.0"`

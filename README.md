# SwiftRest

[![CI](https://github.com/ricky-stone/SwiftRest/actions/workflows/ci.yml/badge.svg)](https://github.com/ricky-stone/SwiftRest/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.0+-F05138.svg)](https://www.swift.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/ricky-stone/SwiftRest/blob/main/LICENSE.txt)
[![Swift Package Index](https://img.shields.io/badge/Swift%20Package%20Index-SwiftRest-111111)](https://swiftpackageindex.com/ricky-stone/SwiftRest)
[![GitHub stars](https://img.shields.io/github/stars/ricky-stone/SwiftRest?style=social)](https://github.com/ricky-stone/SwiftRest/stargazers)

SwiftRest 5 is a Swift 6 REST client that stays simple for beginners and still gives advanced teams the control they need.

The main ideas are:
- Use a plain HTTP client when you only want requests and responses.
- Use the auth/session client when you want SwiftRest to store tokens, attach them automatically, and refresh them after a `401`.
- Read headers, raw bodies, decoded values, or full response metadata with one request.
- Keep the API actor-safe and concurrency-safe.
- Choose simple storage presets like Keychain, `UserDefaults`, memory only, or no persistence.

## Contents
- [Requirements](#requirements)
- [Install](#install)
- [Defaults At A Glance](#defaults-at-a-glance)
- [Plain Client](#plain-client)
- [Auth And Session Client](#auth-and-session-client)
- [More Settings](#more-settings)
- [Storage Options](#storage-options)
- [Token Mapping](#token-mapping)
- [Login Refresh And Logout](#login-refresh-and-logout)
- [Headers Made Easy](#headers-made-easy)
- [Paths And Query](#paths-and-query)
- [HTTP Methods](#http-methods)
- [JSON Options](#json-options)
- [Error Handling](#error-handling)
- [SwiftUI Example](#swiftui-example)
- [Acknowledgements](#acknowledgements)
- [License](#license)

## Requirements

- Swift 6.0+
- iOS 15+
- macOS 12+

## Install

Swift Package Manager:

```swift
.package(url: "https://github.com/ricky-stone/SwiftRest.git", from: "5.0.1")
```

## Defaults At A Glance

These are the common defaults you get when you use SwiftRest 5 in the simplest way.

| Area | Default |
| --- | --- |
| Plain client setup | `SwiftRest.client(baseURL: ...)` |
| Auth client setup | `SwiftRest.auth(baseURL: ...)` |
| Auth storage | Built-in Keychain store |
| Primary token field | `accessToken` |
| Refresh token field | Not assumed unless you set it |
| Refresh request field | `refreshToken` |
| Refresh trigger | `401` |
| Plain client config | `SwiftRestConfig.standard` |
| Common web API config | `SwiftRestConfig.webAPI` |
| Default timeout | 30 seconds |
| Default retry policy | `RetryPolicy.standard` |
| Default JSON coding | Foundation defaults |

If your API uses snake_case keys and ISO8601 dates, `SwiftRestConfig.webAPI` is usually the quickest start.

## Plain Client

Use the plain client when you only want to call endpoints and decode responses.

```swift
import SwiftRest

struct User: Decodable, Sendable {
    let id: Int
    let firstName: String
}

guard let apiURL = URL(string: "https://api.example.com") else {
    fatalError("Invalid API URL")
}

let client = SwiftRest.client(baseURL: apiURL)

let user: User = try await client
    .path("users/1")
    .get()
    .value()

print(user.firstName)
```

If you want the common web API preset, use `SwiftRestConfig.webAPI`:

```swift
let client = SwiftRest.client(baseURL: apiURL, config: .webAPI)
```

### Plain client headers

For plain clients, set default headers in the config before creating the client.

```swift
var config = SwiftRestConfig.standard
config.baseHeaders["X-App-Version"] = "5.0.0"
config.baseHeaders["X-Platform"] = "iOS"

let client = SwiftRest.client(baseURL: apiURL, config: config)
```

You can also add headers for just one request:

```swift
let raw = try await client
    .path("users/1")
    .header("X-Trace-ID", UUID().uuidString)
    .get()
    .raw()
```

## Auth And Session Client

Use the auth/session client when you want SwiftRest to keep a token for you.

If you do not choose a store, Keychain is the default.

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .client
```

If you want to be explicit, this does the same thing and makes the storage choice obvious:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .client
```

The auth/session client does this for you:
- loads the saved session before authenticated requests
- adds the bearer token automatically
- saves token values after a successful login or refresh when the response matches your configured field names
- tries the refresh endpoint once after a configured status code, usually `401`
- retries the original request once if the refresh succeeds
- lets you clear the session with `logout()`

## More Settings

These settings are optional, but they are useful when you want to make one client behave a certain way.

### Timeout

Change the request timeout in seconds:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .timeout(10)
    .client
```

### Retry

Use the standard retry policy or turn retries off:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .retry(.standard)
    .client
```

### Logging

Logging is off by default. Turn it on when you want to see requests and responses:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .logging(.basic)
    .client
```

If you want headers in the logs too, use `SwiftRestDebugLogging.headers`.

### Custom URLSession

This is useful in tests and when you want an ephemeral or custom session configuration:

```swift
let sessionConfiguration = URLSessionConfiguration.ephemeral
let session = URLSession(configuration: sessionConfiguration)

let client = SwiftRest.client(baseURL: apiURL, session: session)
let auth = SwiftRest.auth(baseURL: apiURL, session: session).client
```

## Storage Options

SwiftRest gives you four simple storage choices plus a custom option.

### Keychain, built in

This is the recommended choice for real apps.

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .client
```

The Keychain preset is built into SwiftRest so you do not need any extra package for the common path.

### UserDefaults

Useful for simple apps, demos, and non-sensitive data.

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .defaults()
    .client
```

You can also point it at a specific `UserDefaults` store:

```swift
let customDefaults = UserDefaults(suiteName: "SwiftRest.example")!

let auth = SwiftRest
    .auth(baseURL: apiURL)
    .defaults(customDefaults, key: "auth.session")
    .client
```

### Memory only

Best for tests, previews, and temporary sessions.

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .memory()
    .client
```

You can also start with an existing session in memory:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .memory(session: SwiftRestAuthSession(token: "seed-token"))
    .client
```

### No persistence

Use this when you do not want SwiftRest to save anything between requests.

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .none()
    .client
```

### Custom store

If you want your own storage, conform to `SwiftRestSessionStore`.

```swift
actor AppSessionStore: SwiftRestSessionStore {
    private var session: SwiftRestAuthSession?

    func load() async throws -> SwiftRestAuthSession? {
        session
    }

    func save(_ session: SwiftRestAuthSession) async throws {
        self.session = session
    }

    func clear() async throws {
        session = nil
    }
}

let auth = SwiftRest
    .auth(baseURL: apiURL)
    .store(AppSessionStore())
    .client
```

## Token Mapping

SwiftRest does not guess field names. You tell it where your API puts the token values.

### Common JSON field names

Most APIs use these names:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .tokenField("accessToken")
    .refreshTokenField("refreshToken")
    .client
```

Notes:
- `tokenField("accessToken")` means the top-level JSON field must be named `accessToken`.
- `refreshTokenField("refreshToken")` is optional.
- If your API does not return a refresh token, leave `refreshTokenField(...)` out.

### Different JSON field names

If your API uses other names, just point SwiftRest at them:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .tokenField("sessionToken")
    .refreshTokenField("sessionRefreshToken")
    .client
```

### Tokens in response headers

If your API returns a token in a header instead of JSON, use `tokenHeader(...)`.

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .tokenHeader("X-Session-Token")
    .refreshTokenHeader("X-Refresh-Token")
    .client
```

Header names are read case-insensitively.

## Login Refresh And Logout

### Login with automatic saving

When the login response contains the token field names you configured, SwiftRest saves them automatically.

```swift
struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
}

struct LoginResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
}

let login = LoginRequest(email: "ricky@example.com", password: "secret")

let response: LoginResponse = try await auth
    .path("v1/auth/login")
    .noAuth()
    .post(body: login)
    .value()

print(response.accessToken)
```

If you want to check what SwiftRest stored, read the session back:

```swift
if let session = try await auth.currentSession() {
    print(session.token ?? "none")
    print(session.refreshToken ?? "none")
}
```

### Refresh after `401`

Add a refresh endpoint when your API can issue a new token automatically.

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .refresh(endpoint: "v1/auth/refresh")
    .tokenField("accessToken")
    .refreshTokenField("refreshToken")
    .client
```

What this means:
- if a request gets `401`, SwiftRest calls the refresh endpoint once
- it uses the saved refresh token unless you override it for one request
- if refresh succeeds, SwiftRest saves the new tokens and retries the original request once
- if refresh fails, you can log the user out

If your refresh endpoint needs a different request field name, change `requestRefreshField`:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .refresh(
        endpoint: "v1/session/refresh",
        method: .post,
        requestRefreshField: "sessionRefreshToken",
        triggerStatusCodes: [401, 403],
        headers: ["X-App-Version": "5.0.0"]
    )
    .client
```

### Logout

Logging out usually means clearing the stored session.

```swift
try await auth.logout()
```

If your server also has a logout endpoint, you can call it and then clear the local session:

```swift
try await auth
    .path("v1/auth/logout")
    .post(body: [String: String]())
    .send()

try await auth.logout()
```

### Manual save

If your app already has token values, or if you want to store them yourself, save them directly.

```swift
try await auth.save(token: "access-token", refreshToken: "refresh-token")
```

## Headers Made Easy

### Global headers for auth requests

The auth builder can set default headers for every request.

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .header("X-App-Version", "5.0.0")
    .header("X-Platform", "iOS")
    .client
```

You can also add several at once:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .headers([
        "X-App-Version": "5.0.0",
        "X-Platform": "iOS"
    ])
    .client
```

### Per-request headers

Use request headers when only one call needs something extra.

```swift
let profile: User = try await auth
    .path("v1/me")
    .header("X-Trace-ID", UUID().uuidString)
    .get()
    .value()
```

### Reading response headers

There are two easy ways to read headers back.

#### Option 1: decode the value and keep the headers

```swift
let (user, headers) = try await auth
    .path("v1/users/1")
    .get()
    .valueAndHeaders()

print(user.firstName)
print(headers["x-request-id"] ?? "none")
```

#### Option 2: inspect the full response object

```swift
let response: SwiftRestResponse<User> = try await auth
    .path("v1/users/1")
    .get()
    .response()

print(response.statusCode)
print(response.data?.firstName ?? "none")
print(response.header("x-request-id") ?? "none")
print(response.headerInt("x-total-count") ?? 0)
```

### Raw response when you only want status and headers

This is useful when you want to inspect a `401`, `404`, or any other HTTP response directly.

```swift
let raw = try await auth
    .path("v1/users/1")
    .get()
    .raw()

print(raw.statusCode)
print(raw.header("x-request-id") ?? "none")
print(raw.rawValue ?? "no body")
```

## Paths And Query

### Chainable path segments

You do not need to add `/` between path segments. SwiftRest joins them for you.

```swift
let user: User = try await auth
    .path("v1")
    .path("users")
    .path(42)
    .get()
    .value()
```

Supported path segment types include:
- `String`
- `Substring`
- all integer types
- `Double`
- `Float`
- `Decimal`
- `Bool`
- `UUID`

You can also append several segments at once:

```swift
let user: User = try await auth
    .path("v1")
    .paths("users", 42, UUID(uuidString: "D2719D2A-E7DE-48E1-A5FD-2241F0587B37")!)
    .get()
    .value()
```

If you already have a full URL path, you can append that too:

```swift
let raw = try await auth
    .path(url: URL(string: "/v1/users/42")!)
    .get()
    .raw()
```

### Query with a model

Use a model when you want strongly-typed query parameters.

```swift
struct UserQuery: Encodable, Sendable {
    let page: Int
    let search: String
    let includeInactive: Bool
}

let users: [User] = try await auth
    .path("v1/users")
    .query(UserQuery(page: 1, search: "ricky", includeInactive: false))
    .get()
    .value()
```

### Query without a model

If you only need a few query values, use `parameter(...)` or `parameters(...)`.

```swift
let users: [User] = try await auth
    .path("v1/users")
    .parameter("page", "1")
    .parameter("search", "ricky")
    .parameter("includeInactive", "false")
    .get()
    .value()
```

## HTTP Methods

SwiftRest supports all the common HTTP methods on the request chain.

### GET

```swift
let user: User = try await auth.path("users/1").get().value()
```

### POST

```swift
struct CreateUser: Encodable, Sendable {
    let name: String
}

let created: User = try await auth
    .path("users")
    .post(body: CreateUser(name: "Ricky"))
    .value()
```

### PUT

```swift
let updated: User = try await auth
    .path("users/1")
    .put(body: CreateUser(name: "Ricky Stone"))
    .value()
```

### PATCH

```swift
let patched: User = try await auth
    .path("users/1")
    .patch(body: ["name": "Ricky S."])
    .value()
```

### DELETE

If you only care whether it worked, use `send()`.

```swift
try await auth
    .path("users/1")
    .delete()
    .send()
```

### HEAD

```swift
let health = try await auth
    .path("health")
    .head()
    .raw()

print(health.statusCode)
```

### OPTIONS

```swift
let options = try await auth
    .path("users")
    .options()
    .raw()

print(options.header("allow") ?? "none")
```

## JSON Options

SwiftRest gives you a few ways to choose JSON behavior without making the call site noisy.

### Common web API preset

If your API uses snake_case keys and ISO8601 dates, this is the quickest start:

```swift
let client = SwiftRest.client(baseURL: apiURL, config: .webAPI)
```

### ISO8601 dates only

```swift
let client = SwiftRest.client(
    baseURL: apiURL,
    config: SwiftRestConfig.standard.jsonCoding(.iso8601)
)
```

### Dates and keys separately

For more control, set dates and keys independently.

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .jsonDates(.iso8601WithFractionalSeconds)
    .jsonKeys(.snakeCaseDecodingOnly)
    .client
```

### Other useful presets

You can also use these common presets directly:
- `SwiftRestJSONCoding.iso8601`
- `SwiftRestJSONCoding.webAPI`
- `SwiftRestJSONCoding.webAPIFractionalSeconds`
- `SwiftRestJSONCoding.webAPIUnixSeconds`
- `SwiftRestJSONCoding.webAPIUnixMilliseconds`

And these key modes:
- `SwiftRestJSONKeys.useDefaultKeys`
- `SwiftRestJSONKeys.snakeCase`
- `SwiftRestJSONKeys.snakeCaseDecodingOnly`
- `SwiftRestJSONKeys.snakeCaseEncodingOnly`

## Error Handling

All request methods throw, so beginners can start with `do/catch` and advanced users can branch on the specific error.

```swift
do {
    let profile: User = try await auth
        .path("v1/me")
        .get()
        .value()
    print(profile.firstName)
} catch let error as SwiftRestClientError {
    print(error.localizedDescription)
} catch {
    print(error.localizedDescription)
}
```

If you only care about success or failure, `send()` is the simplest path.

```swift
try await auth
    .path("v1/auth/logout")
    .post(body: [String: String]())
    .send()
```

If you need to inspect a status code without throwing on HTTP errors, use `raw()`.

```swift
let raw = try await auth
    .path("v1/me")
    .get()
    .raw()

if raw.statusCode == 401 {
    try await auth.logout()
}
```

## SwiftUI Example

This is a simple SwiftUI pattern that loads a profile after login.

```swift
import SwiftUI
import SwiftRest

struct Profile: Decodable, Sendable {
    let firstName: String
}

struct ProfileView: View {
    let auth: SwiftRestAuthClient
    @State private var profile: Profile?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if let profile {
                Text(profile.firstName)
            } else if let errorMessage {
                Text(errorMessage)
            } else {
                ProgressView()
            }
        }
        .task {
            do {
                profile = try await auth
                    .path("v1/me")
                    .get()
                    .value()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
```

## Acknowledgements

Special thanks to Ricky Stone for [SwiftKey](https://github.com/ricky-stone/SwiftKey), which helped shape the simple keychain ergonomics that inspired this preset.

## License

SwiftRest is released under the MIT License. See [`LICENSE.txt`](LICENSE.txt).

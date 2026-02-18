# SwiftRest

[![CI](https://github.com/ricky-stone/SwiftRest/actions/workflows/ci.yml/badge.svg)](https://github.com/ricky-stone/SwiftRest/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.0+-F05138.svg)](https://www.swift.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/ricky-stone/SwiftRest/blob/main/LICENSE.txt)
[![Swift Package Index](https://img.shields.io/badge/Swift%20Package%20Index-SwiftRest-111111)](https://swiftpackageindex.com/ricky-stone/SwiftRest)
[![GitHub stars](https://img.shields.io/github/stars/ricky-stone/SwiftRest?style=social)](https://github.com/ricky-stone/SwiftRest/stargazers)

SwiftRest is a Swift 6 REST client focused on clear APIs and safe concurrency.

- `SwiftRestClient` is an `actor`.
- Public models are `Sendable`.
- You can decode payloads and inspect headers in the same call.
- You can choose throw-based APIs or result-style APIs.

## Requirements

- Swift 6.0+
- iOS 15+
- macOS 12+

## Installation

Use Swift Package Manager with:

- `https://github.com/ricky-stone/SwiftRest.git`

## Community

- Questions and ideas: [GitHub Discussions](https://github.com/ricky-stone/SwiftRest/discussions)
- Bugs and feature requests: [GitHub Issues](https://github.com/ricky-stone/SwiftRest/issues)
- Contributing guide: [`CONTRIBUTING.md`](./CONTRIBUTING.md)
- Security reports: [`SECURITY.md`](./SECURITY.md)

## Quick Start (Beginners)

### Swift

```swift
import SwiftRest

struct User: Decodable, Sendable {
    let id: Int
    let name: String
}

let client = try SwiftRestClient("https://api.example.com")
let user: User = try await client.get("users/1")
print(user.name)
```

### SwiftUI

```swift
import SwiftUI
import SwiftRest

struct User: Decodable, Sendable {
    let id: Int
    let name: String
}

@MainActor
final class UserViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var errorText: String?

    private let client = try? SwiftRestClient("https://api.example.com")

    func load() async {
        guard let client else {
            errorText = "Client setup failed"
            return
        }

        do {
            let user: User = try await client.get("users/1")
            name = user.name
            errorText = nil
        } catch let error as SwiftRestClientError {
            errorText = error.userMessage
        } catch {
            errorText = error.localizedDescription
        }
    }
}
```

## Data + Headers in One Call

### Swift

```swift
let response: SwiftRestResponse<User> = try await client.getResponse("users/1")

if let user = response.data {
    print("Name:", user.name)
}

print("Status:", response.statusCode)
print("Request-Id:", response.headers["x-request-id"] ?? "missing")
```

### SwiftUI

```swift
@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var requestId: String = ""

    private let client = try! SwiftRestClient("https://api.example.com")

    func load() async {
        do {
            let response: SwiftRestResponse<User> = try await client.getResponse("users/1")
            name = response.data?.name ?? ""
            requestId = response.headers["x-request-id"] ?? ""
        } catch {
            name = ""
            requestId = ""
        }
    }
}
```

## Write Calls with Model Bodies

```swift
struct CreateUser: Encodable, Sendable {
    let name: String
}

let payload = CreateUser(name: "Ricky")

let created: User = try await client.post("users", body: payload)
let updated: User = try await client.put("users/1", body: CreateUser(name: "Ricky Stone"))
let patched: User = try await client.patch("users/1", body: ["name": "Ricky S."])
```

### Success/Failure only (no payload needed)

```swift
let _: NoContent = try await client.delete("users/1")

let raw = try await client.deleteRaw("users/1", allowHTTPError: true)
print(raw.statusCode, raw.isSuccess)
```

## Authentication

## 1) Global token

```swift
let client = try SwiftRestClient(
    "https://api.example.com",
    config: .standard.accessToken("YOUR_ACCESS_TOKEN")
)
```

Runtime update:

```swift
await client.setAccessToken("NEW_TOKEN")
await client.clearAccessToken()
```

## 2) Per-request token override

```swift
let adminUser: User = try await client.get("users/1", authToken: "ONE_OFF_TOKEN")
```

## 3) Rotating token provider

```swift
await client.setAccessTokenProvider {
    // Return latest token (refresh from keychain/service if needed)
    return "LATEST_TOKEN"
}
```

Auth precedence:

1. per-request token (`authToken:` / `request.authToken(...)`)
2. provider token (`setAccessTokenProvider` / `config.accessTokenProvider(...)`)
3. global token (`setAccessToken` / `config.accessToken(...)`)

## 4) Built-in 401 refresh + retry once (opt-in)

When enabled, SwiftRest will:

1. receive `401`
2. call your refresh callback
3. retry the same request once with the refreshed token

```swift
let refresh = SwiftRestAuthRefresh {
    // Call refresh endpoint and return new access token
    return "fresh-token"
}

let client = try SwiftRestClient(
    "https://api.example.com",
    config: .standard
        .accessToken("expired-token")
        .authRefresh(refresh)
)

let profile: User = try await client.get("users/me")
```

By default, refresh does not run for explicit per-request tokens.

Enable it if needed:

```swift
let refresh = SwiftRestAuthRefresh {
    return "fresh-token"
}.appliesToPerRequestToken(true)
```

### SwiftUI token store pattern

```swift
import SwiftUI
import SwiftRest

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var accessToken: String = "expired-token"

    func updateToken(_ token: String) {
        accessToken = token
    }
}

func makeClient(session: SessionStore) throws -> SwiftRestClient {
    let refresh = SwiftRestAuthRefresh {
        // Example only. Replace with your refresh API call.
        let newToken = "fresh-token"
        await session.updateToken(newToken)
        return newToken
    }

    return try SwiftRestClient(
        "https://api.example.com",
        config: .standard
            .accessToken(session.accessToken)
            .authRefresh(refresh)
    )
}
```

## Query Models (No Manual Dictionaries)

### Swift

```swift
struct UserQuery: Encodable, Sendable {
    let page: Int
    let search: String
    let includeInactive: Bool
}

let query = UserQuery(page: 1, search: "ricky", includeInactive: false)
let users: [User] = try await client.get("users", query: query)
```

### SwiftUI

```swift
@MainActor
final class SearchViewModel: ObservableObject {
    @Published var users: [User] = []

    private let client = try! SwiftRestClient("https://api.example.com")

    func search(term: String) async {
        struct UserQuery: Encodable, Sendable {
            let page: Int
            let search: String
            let includeInactive: Bool
        }

        do {
            let query = UserQuery(page: 1, search: term, includeInactive: false)
            users = try await client.get("users", query: query)
        } catch {
            users = []
        }
    }
}
```

Notes:

- Query models follow your client JSON key encoding strategy.
  - Example: `.webAPI` converts `includeInactive` to `include_inactive`.
- You can also encode query models manually with `SwiftRestQuery.encode(...)`.

## Result-Style API (Great for UI State)

Use result APIs when you want explicit branches for success, API errors, and transport failures.

```swift
struct APIErrorModel: Decodable, Sendable {
    let message: String
    let code: String?
}

let result: SwiftRestResult<User, APIErrorModel> =
    await client.getResult("users/1")

switch result {
case .success(let response):
    print(response.data?.name ?? "none")

case .apiError(let decoded, let response):
    print("Status:", response.statusCode)
    print(decoded?.message ?? "No typed API error body")

case .failure(let error):
    print(error.userMessage)
}
```

### SwiftUI result-state example

```swift
@MainActor
final class ResultViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(String)
        case apiError(String)
        case transportError(String)
    }

    @Published var state: State = .idle
    private let client = try! SwiftRestClient("https://api.example.com")

    struct APIErrorModel: Decodable, Sendable {
        let message: String
    }

    func load() async {
        state = .loading

        let result: SwiftRestResult<User, APIErrorModel> =
            await client.getResult("users/1")

        switch result {
        case .success(let response):
            state = .loaded(response.data?.name ?? "No data")
        case .apiError(let decoded, _):
            state = .apiError(decoded?.message ?? "Request failed")
        case .failure(let error):
            state = .transportError(error.userMessage)
        }
    }
}
```

Available result APIs:

- `executeResult(...)`
- `getResult(...)`
- `deleteResult(...)`
- `postResult(...)`
- `putResult(...)`
- `patchResult(...)`

## Debug Logging (Secrets Redacted)

### Quick toggle

```swift
let client = try SwiftRestClient(
    "https://api.example.com",
    config: .standard.debugLogging(true)
)
```

### Include headers (with redaction)

```swift
let client = try SwiftRestClient(
    "https://api.example.com",
    config: .standard.debugLogging(.headers)
)
```

### Custom log handler

```swift
let logging = SwiftRestDebugLogging(
    isEnabled: true,
    includeHeaders: true,
    handler: { line in
        print("NETWORK:", line)
    }
)

let client = try SwiftRestClient(
    "https://api.example.com",
    config: .standard.debugLogging(logging)
)
```

Sensitive headers are redacted by default (for example: `Authorization`, cookies, token/secret-like headers).

## JSON Strategies

### Standard default

```swift
let client = try SwiftRestClient("https://api.example.com")
```

### ISO8601 dates

```swift
let client = try SwiftRestClient(
    "https://api.example.com",
    config: .standard.dateDecodingStrategy(.iso8601)
)
```

### Common web API preset (snake_case + ISO8601)

```swift
let client = try SwiftRestClient("https://api.example.com", config: .webAPI)
```

### Per-request override

```swift
var request = SwiftRestRequest(path: "legacy-endpoint", method: .get)
request.configureDateDecodingStrategy(.formatted(format: "yyyy-MM-dd HH:mm:ss"))

let legacy: User = try await client.execute(request, as: User.self)
```

## Request Builder Styles

### Mutating style

```swift
var request = SwiftRestRequest(path: "users", method: .get)
request.addHeader("X-App", "Demo")
request.addParameter("page", "1")
request.configureRetries(maxRetries: 2, retryDelay: 0.5)
```

### Chainable style

```swift
let request = try SwiftRestRequest.get("users")
    .header("X-App", "Demo")
    .query(UserQuery(page: 1, search: "ricky", includeInactive: false))
```

## Error Handling (Throw-based)

```swift
do {
    let user: User = try await client.get("users/does-not-exist")
    print(user)
} catch let error as SwiftRestClientError {
    print(error.userMessage)

    if case .httpError(let details) = error {
        print(details.statusCode)
        print(details.headers["content-type"] ?? "n/a")
        print(details.rawPayload ?? "")
    }
} catch {
    print(error.localizedDescription)
}
```

## Default Config (`.standard`)

When no config is passed, SwiftRest uses `SwiftRestConfig.standard`:

- Base header: `Accept: application/json`
- Timeout: `30` seconds
- Retry policy: `RetryPolicy.standard`
  - Max attempts: `3`
  - Base delay: `0.5` seconds
  - Retryable status codes: `408, 429, 500, 502, 503, 504`
- JSON coding: `SwiftRestJSONCoding.foundationDefault`
- Global token: none
- Debug logging: disabled
- Auth refresh: disabled

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

Current source version marker: `SwiftRestVersion.current == "3.4.0"`

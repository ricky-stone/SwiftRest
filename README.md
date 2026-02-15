# SwiftRest

[![CI](https://github.com/ricky-stone/SwiftRest/actions/workflows/ci.yml/badge.svg)](https://github.com/ricky-stone/SwiftRest/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.0+-F05138.svg)](https://www.swift.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/ricky-stone/SwiftRest/blob/main/LICENSE.txt)
[![Swift Package Index](https://img.shields.io/badge/Swift%20Package%20Index-SwiftRest-111111)](https://swiftpackageindex.com/ricky-stone/SwiftRest)
[![GitHub stars](https://img.shields.io/github/stars/ricky-stone/SwiftRest?style=social)](https://github.com/ricky-stone/SwiftRest/stargazers)

SwiftRest is a Swift 6 REST client designed to stay simple.

- `SwiftRestClient` is an `actor`.
- Public models are `Sendable`.
- You can decode models and read headers from the same call.

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

## Quick Start

### Compact

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

### With `do/catch`

```swift
import SwiftRest

struct User: Decodable, Sendable {
    let id: Int
    let name: String
}

let client = try SwiftRestClient("https://api.example.com")

do {
    let user: User = try await client.get("users/1")
    print("User name: \(user.name)")
} catch let error as SwiftRestClientError {
    print(error.userMessage)
} catch {
    print(error.localizedDescription)
}
```

## One Call: Data + Headers

### Compact

```swift
let response: SwiftRestResponse<User> = try await client.getResponse("users/1")
print(response.data?.name ?? "none")
print(response.headers["content-type"] ?? "missing")
```

### Checked

```swift
do {
    let response: SwiftRestResponse<User> = try await client.getResponse("users/1")

    guard let user = response.data else {
        print("No user payload returned")
        return
    }

    print("Status: \(response.statusCode)")
    print("User name: \(user.name)")
    print("Content-Type: \(response.headers["content-type"] ?? "missing")")
    print("X-Request-Id: \(response.headers["x-request-id"] ?? "missing")")
} catch let error as SwiftRestClientError {
    print(error.userMessage)
} catch {
    print(error.localizedDescription)
}
```

Use the same pattern for writes when you want decoded data + headers:

- `postResponse(...)`
- `putResponse(...)`
- `patchResponse(...)`
- `deleteResponse(...)`

## Complete Example: POST with Model + Response + Headers

Here's an end-to-end example showing how to create an `Encodable` model, send it with `postResponse`, and read both the decoded data and response headers:

```swift
import SwiftRest

// 1) Define your request model (Encodable)
struct CreatePost: Encodable, Sendable {
    let title: String
    let content: String
    let authorId: Int
}

// 2) Define your response model (Decodable)
struct Post: Decodable, Sendable {
    let id: Int
    let title: String
    let content: String
    let authorId: Int
    let createdAt: Date
}

// 3) Make the request and get both data + headers
let client = try SwiftRestClient("https://api.example.com")
let newPost = CreatePost(
    title: "Hello World",
    content: "This is my first post!",
    authorId: 42
)

do {
    let response: SwiftRestResponse<Post> = try await client.postResponse("posts", body: newPost)
    
    // Access the decoded data
    guard let post = response.data else {
        print("No post returned")
        return
    }
    
    // Access response headers
    print("Created post ID: \(post.id)")
    print("Location header: \(response.headers["location"] ?? "none")")
    print("X-Request-Id: \(response.headers["x-request-id"] ?? "none")")
    print("Rate-Limit-Remaining: \(response.headers["rate-limit-remaining"] ?? "none")")
    
    // Access status code
    print("Response status: \(response.statusCode)")
    
} catch let error as SwiftRestClientError {
    print(error.userMessage)
} catch {
    print(error.localizedDescription)
}
```

This pattern is useful when:
- You need the created resource's ID or full data returned from the server
- You want to read correlation IDs, rate limits, or other headers
- You're implementing optimistic UI and need immediate feedback

Use the same pattern with:
- `postResponse(path:body:)`
- `putResponse(path:body:)`
- `patchResponse(path:body:)`

## POST/PUT/PATCH with a Model Body

```swift
struct CreateUser: Encodable, Sendable {
    let name: String
}

let ricky = CreateUser(name: "Ricky")

let created: User = try await client.post("users", body: ricky)
let updated: User = try await client.put("users/1", body: CreateUser(name: "Ricky Stone"))
let patched: User = try await client.patch("users/1", body: ["name": "Ricky S."])
```

## POST That Only Needs Success/Failure (No Data Body)

### Throw-based flow (simple default)

```swift
let payload = CreateUser(name: "Ricky")

do {
    let _: NoContent = try await client.post("users", body: payload, as: NoContent.self)
    print("Created successfully")
} catch {
    print("Create failed: \(error)")
}
```

### Status-check flow (`isSuccess`)

```swift
let payload = CreateUser(name: "Ricky")
let raw = try await client.postRaw("users", body: payload, allowHTTPError: true)

if raw.isSuccess {
    print("Created successfully (\(raw.statusCode))")
} else {
    print("Create failed (\(raw.statusCode))")
    print(raw.text() ?? "")
}
```

## DELETE Example

```swift
let _: NoContent = try await client.delete("users/1")

// If you also want status + headers:
let rawDelete = try await client.deleteRaw("users/1", allowHTTPError: true)
print(rawDelete.statusCode)
print(rawDelete.headers["x-request-id"] ?? "missing")
```

## Other Decode Styles

```swift
// 1) Inferred type
let user1: User = try await client.get("users/1")

// 2) Explicit `as:`
let user2 = try await client.get("users/1", as: User.self)

// 3) Request object
let request = SwiftRestRequest(path: "users/1", method: .get)
let user3 = try await client.execute(request, as: User.self)
```

## Raw Response Access

```swift
let raw = try await client.getRaw("users/1")

print(raw.statusCode)
print(raw.headers["content-type"] ?? "missing")
print(raw.headers.values(for: "set-cookie"))
print(raw.text() ?? "")

let user = try raw.decodeBody(User.self)
let jsonObject = try raw.jsonObject()
let prettyJSON = try raw.prettyPrintedJSON()
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
let request = SwiftRestRequest.get("users")
    .header("X-App", "Demo")
    .parameter("page", "1")
    .retries(maxRetries: 2, retryDelay: 0.5)
```

## Default Config (`.standard`)

When no config is passed, SwiftRest uses `SwiftRestConfig.standard`:

- Base header: `Accept: application/json`
- Timeout: `30` seconds
- Retry policy: `RetryPolicy.standard`
  - Max attempts: `3`
  - Base delay: `0.5` seconds
  - Retryable status codes: `408, 429, 500, 502, 503, 504`
- JSON coding: `SwiftRestJSONCoding.foundationDefault` (no date/key assumptions)

Custom config:

```swift
let config = SwiftRestConfig(
    baseHeaders: ["accept": "application/json", "x-app": "Demo"],
    timeout: 20,
    retryPolicy: RetryPolicy(
        maxAttempts: 4,
        baseDelay: 0.4,
        backoffMultiplier: 2,
        maxDelay: 5
    )
)

let client = try SwiftRestClient("https://api.example.com", config: config)
```

## JSON Strategies (Easy + Customizable)

### 1) One line for ISO8601 dates

```swift
let client = try SwiftRestClient(
    "https://api.example.com",
    config: .standard.dateDecodingStrategy(.iso8601)
)
```

Use `.iso8601WithFractionalSeconds` if your API consistently sends fractional timestamps.

### 2) One line for common web APIs (snake_case + ISO8601)

```swift
let client = try SwiftRestClient("https://api.example.com", config: .webAPI)
```

### 3) Your API example (camelCase + `updatedUtc` date string)

This payload style does not need snake_case conversion. Just set date decoding:

```swift
struct AppConfig: Decodable, Sendable {
    let maintenanceMode: Bool
    let maintenanceMessage: String
    let featureFlags: FeatureFlags
    let parameters: [String: String]
    let updatedUtc: Date
}

struct FeatureFlags: Decodable, Sendable {
    let vision: Bool
    let matches: Bool
    let players: Bool
    let events: Bool
    let rankings: Bool
}

let client = try SwiftRestClient(
    "https://api.example.com",
    config: .standard.dateDecodingStrategy(.iso8601)
)

let config: AppConfig = try await client.get("app-config")
```

### 4) Per-request override (when one endpoint is different)

```swift
var request = SwiftRestRequest(path: "legacy-endpoint", method: .get)
request.configureDateDecodingStrategy(.formatted(format: "yyyy-MM-dd HH:mm:ss"))

let legacy: LegacyModel = try await client.execute(request, as: LegacyModel.self)
```

## Error Handling Pattern

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

Current source version marker: `SwiftRestVersion.current == "3.1.0"`

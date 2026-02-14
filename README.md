# SwiftRest (v2)

SwiftRest is a lightweight **Swift 6** REST client focused on beginner ergonomics and actor-based concurrency safety.

## Why v2

- `SwiftRestClient` stays an `actor` for safe concurrent use.
- Raw responses are first-class (`status`, `headers`, `payload`).
- Typed decoding is simple and available in multiple styles.
- Retry behavior is configurable but easy by default.

## Requirements

- Swift 6.0+
- iOS 15+
- macOS 12+

## Installation

Add this package with Swift Package Manager:

- URL: `https://github.com/ricky-stone/SwiftRest.git`

## Quick Start

```swift
import SwiftRest

struct User: Decodable, Sendable {
    let id: Int
    let name: String
}

let client = try SwiftRestClient(
    "https://api.example.com",
    config: .beginner
)

let user: User = try await client.get("users/1")
print(user.name)
```

## Decoding: All Common Styles

### 1) Inferred from variable type

```swift
let user: User = try await client.get("users/1")
```

### 2) Explicit type with `as:`

```swift
let user = try await client.get("users/1", as: User.self)
```

### 3) Build request object + decode directly

```swift
let request = SwiftRestRequest(path: "users/1", method: .get)
let user = try await client.execute(request, as: User.self)
```

### 4) Build request object + keep metadata + decoded payload

```swift
let request = SwiftRestRequest(path: "users/1", method: .get)
let response: SwiftRestResponse<User> = try await client.executeAsyncWithResponse(request)

print(response.statusCode)
print(response.headers["content-type"] ?? "n/a")
print(response.data?.name ?? "none")
```

## Read Headers and Raw Payload Easily

```swift
let raw = try await client.getRaw("users/1")

print(raw.statusCode)
print(raw.headers["content-type"] ?? "n/a")
print(raw.headers.values(for: "set-cookie"))
print(raw.text() ?? "")
```

Parse payload manually if you want:

```swift
let user = try raw.decodeBody(User.self)
let json = try raw.jsonObject()
let pretty = try raw.prettyPrintedJSON()
```

## POST / PUT / PATCH / DELETE

```swift
struct CreateUser: Encodable, Sendable { let name: String }

let created: User = try await client.post(
    "users",
    body: CreateUser(name: "Ricky")
)

let updated: User = try await client.put(
    "users/1",
    body: CreateUser(name: "Ricky Stone")
)

let patched: User = try await client.patch(
    "users/1",
    body: ["name": "Ricky S."]
)

let _: NoContent = try await client.delete("users/1")
```

## Request Builder Styles

Mutating style:

```swift
var request = SwiftRestRequest(path: "users", method: .get)
request.addHeader("X-App", "Demo")
request.addParameter("page", "1")
request.configureRetries(maxRetries: 2, retryDelay: 0.5)
```

Chainable style:

```swift
let request = SwiftRestRequest.get("users")
    .header("X-App", "Demo")
    .parameter("page", "1")
    .retries(maxRetries: 2, retryDelay: 0.5)
```

## Configuration

```swift
let config = SwiftRestConfig(
    baseHeaders: ["accept": "application/json"],
    timeout: 20,
    retryPolicy: RetryPolicy(
        maxAttempts: 3,
        baseDelay: 0.5
    )
)

let client = try SwiftRestClient("https://api.example.com", config: config)
```

## Error Handling

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
}
```

## Concurrency Safety Notes

- `SwiftRestClient` is an `actor`.
- Public request/response/config models are `Sendable`.
- APIs are built for `async/await` usage in Swift 6 projects.

## Version

Current source version marker: `SwiftRestVersion.current == "2.0.0"`

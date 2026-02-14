# SwiftRest

SwiftRest is a Swift 6 REST client that is simple to use and concurrency-safe.

- `SwiftRestClient` is an `actor`.
- Public models are `Sendable`.
- You can decode typed models and still read headers/body easily.

## Requirements

- Swift 6.0+
- iOS 15+
- macOS 12+

## Installation

Use Swift Package Manager with:

- `https://github.com/ricky-stone/SwiftRest.git`

## Quick Start (Fast)

```swift
import SwiftRest

struct User: Decodable, Sendable {
    let id: Int
    let name: String
}

// No config passed -> SwiftRestConfig.standard is used.
let client = try SwiftRestClient("https://api.example.com")

let user: User = try await client.get("users/1")
print(user.name)
```

## Quick Start (With `do/catch`)

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

## One Call: Get Data and Headers Together

### Fast version

```swift
let response: SwiftRestResponse<User> = try await client.getResponse("users/1")
print(response.data?.name ?? "none")
print(response.headers["content-type"] ?? "missing")
```

### Safer version (recommended)

```swift
do {
    let response: SwiftRestResponse<User> = try await client.getResponse("users/1")

    guard response.isSuccess else {
        print("Request failed with status: \(response.statusCode)")
        print("Body: \(response.text() ?? "<empty>")")
        return
    }

    guard let user = response.data else {
        print("No user payload in successful response")
        return
    }

    print("User name: \(user.name)")
    print("Content-Type: \(response.headers["content-type"] ?? "missing")")
    print("X-Request-Id: \(response.headers["x-request-id"] ?? "missing")")
} catch let error as SwiftRestClientError {
    print(error.userMessage)
} catch {
    print(error.localizedDescription)
}
```

Use the same pattern for write operations when you want decoded data + headers:

- `postResponse(...)`
- `putResponse(...)`
- `patchResponse(...)`
- `deleteResponse(...)`

## Decode Models: Common Styles

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

## POST / PUT / PATCH / DELETE

```swift
struct CreateUser: Encodable, Sendable { let name: String }

let created: User = try await client.post("users", body: CreateUser(name: "Ricky"))
let updated: User = try await client.put("users/1", body: CreateUser(name: "Ricky Stone"))
let patched: User = try await client.patch("users/1", body: ["name": "Ricky S."])
let _: NoContent = try await client.delete("users/1")
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

Custom config example:

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

Current source version marker: `SwiftRestVersion.current == "3.0.0"`

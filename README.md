# SwiftRest

SwiftRest is a Swift 6 REST client that is simple for beginners and safe for concurrency.

- `SwiftRestClient` is an `actor`.
- Request/response models are `Sendable`.
- You can decode models fast, or inspect raw headers/body when needed.

## Requirements

- Swift 6.0+
- iOS 15+
- macOS 12+

## Installation

Use Swift Package Manager with:

- `https://github.com/ricky-stone/SwiftRest.git`

## Fastest Start

```swift
import SwiftRest

struct User: Decodable, Sendable {
    let id: Int
    let name: String
}

// No config passed -> SwiftRestConfig.standard is used automatically.
let client = try SwiftRestClient("https://api.example.com")

let user: User = try await client.get("users/1")
print(user.name)
```

## Default Config (`.standard`)

When you do not pass a config, SwiftRest uses `SwiftRestConfig.standard`:

- Base header: `Accept: application/json`
- Timeout: `30` seconds
- Retry policy: `RetryPolicy.standard`
  - Max attempts: `3`
  - Base delay: `0.5` seconds
  - Retryable status codes: `408, 429, 500, 502, 503, 504`

You can still use `.beginner` as a compatibility alias, but `.standard` is the preferred name.

## Decoding Models: All Common Ways

### 1) Inferred type (shortest)

```swift
let user: User = try await client.get("users/1")
```

### 2) Explicit type with `as:`

```swift
let user = try await client.get("users/1", as: User.self)
```

### 3) Request object + direct decode

```swift
let request = SwiftRestRequest(path: "users/1", method: .get)
let user = try await client.execute(request, as: User.self)
```

### 4) Request object + decoded response metadata

```swift
let request = SwiftRestRequest(path: "users/1", method: .get)
let response: SwiftRestResponse<User> = try await client.executeAsyncWithResponse(request)

print(response.statusCode)
print(response.data?.name ?? "none")
```

## Read Headers and Payload (Very Simple)

### Option A: Typed response + headers

```swift
let response: SwiftRestResponse<User> = try await client.getResponse("users/1")

print(response.statusCode)
print(response.header("content-type") ?? "n/a")
print(response.headers["x-request-id"] ?? "missing")
print(response.data?.name ?? "none")
```

### Option B: Raw response (no decoding required)

```swift
let raw = try await client.getRaw("users/1")

print(raw.statusCode)
print(raw.headers["content-type"] ?? "n/a")
print(raw.headers.values(for: "set-cookie"))
print(raw.text() ?? "")
```

### Option C: Decode later from raw body

```swift
let raw = try await client.getRaw("users/1")
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

If you want metadata + headers from write calls, use:

- `postResponse(...)`
- `putResponse(...)`
- `patchResponse(...)`
- `deleteResponse(...)`

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

## Custom Configuration

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

## License

SwiftRest is licensed under the MIT License. See `LICENSE.txt`.

Industry-standard reminder for MIT:

- You can use this in commercial/private/open-source projects.
- Keep the copyright and license notice when redistributing.
- Attribution in app UI/docs is appreciated but not required by MIT.

## Author

Created and maintained by Ricky Stone.

## Acknowledgments

Thanks to everyone who tests, reports issues, and contributes improvements.

## Version

Current source version marker: `SwiftRestVersion.current == "2.0.1"`

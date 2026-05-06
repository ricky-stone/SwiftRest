# SwiftRest

[![CI](https://github.com/ricky-stone/SwiftRest/actions/workflows/ci.yml/badge.svg)](https://github.com/ricky-stone/SwiftRest/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.0+-F05138.svg)](https://www.swift.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/ricky-stone/SwiftRest/blob/main/LICENSE.txt)
[![Swift Package Index](https://img.shields.io/badge/Swift%20Package%20Index-SwiftRest-111111)](https://swiftpackageindex.com/ricky-stone/SwiftRest)

SwiftRest is a small Swift REST client.

It is for code like this:

```swift
let profile: Profile = try await auth
    .path("me")
    .get()
    .value()
```

That line means:

1. Go to the `me` endpoint.
2. Make a `GET` request.
3. Decode the JSON response into `Profile`.

SwiftRest 6 also has a simple auth client. It can:

- save your login token in Keychain
- add the token to requests
- save a refresh token
- refresh after a `401`
- retry the failed request once
- optionally add Apple App Attest
- skip App Attest when App Attest is not available
- optionally add Apple DeviceCheck
- use DeviceCheck as a fallback when App Attest is not ready

SwiftRest does not use SwiftKey. SwiftRest has its own built-in Keychain store.

## Contents

- [Install](#install)
- [The Two Clients](#the-two-clients)
- [Plain Requests](#plain-requests)
- [Auth In 30 Seconds](#auth-in-30-seconds)
- [Session Tokens](#session-tokens)
- [Login](#login)
- [Refresh Tokens](#refresh-tokens)
- [Apple App Attest](#apple-app-attest)
- [Apple DeviceCheck](#apple-devicecheck)
- [Storage](#storage)
- [Headers](#headers)
- [Paths](#paths)
- [Query](#query)
- [HTTP Methods](#http-methods)
- [JSON Settings](#json-settings)
- [Responses](#responses)
- [Errors](#errors)
- [SwiftUI Example](#swiftui-example)
- [Testing](#testing)
- [Common Questions](#common-questions)

## Install

Use Swift Package Manager.

```swift
.package(url: "https://github.com/ricky-stone/SwiftRest.git", from: "6.1.0")
```

Then import it:

```swift
import SwiftRest
```

Requirements:

- Swift 6.0+
- iOS 15+
- macOS 12+

## The Two Clients

SwiftRest gives you two main clients.

### 1. Plain client

Use this when you do not need login tokens.

```swift
let client = SwiftRest.client(baseURL: apiURL)
```

### 2. Auth client

Use this when your API has login, tokens, refresh tokens, or App Attest.

```swift
let auth = SwiftRest.auth(baseURL: apiURL).client
```

Most apps with accounts should use the auth client.

## Plain Requests

Start with a base URL:

```swift
let apiURL = URL(string: "https://api.example.com")!
let client = SwiftRest.client(baseURL: apiURL)
```

Make a simple model:

```swift
struct User: Decodable, Sendable {
    let id: Int
    let name: String
}
```

Call an endpoint:

```swift
let user: User = try await client
    .path("users/1")
    .get()
    .value()
```

The full URL is:

```text
https://api.example.com/users/1
```

You do not need to write `URLRequest`.
You do not need to manually decode `Data`.
You do not need to manually check the response body for this common case.

## Auth In 30 Seconds

This is the common setup for an app with login.

```swift
let apiURL = URL(string: "https://api.example.com")!

let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .refresh(endpoint: "auth/refresh")
    .client
```

This means:

- save auth data in Keychain
- read the main token from `sessionToken`
- read the refresh token from `refreshToken`
- call `auth/refresh` after a `401`
- retry the original request one time after refresh works

Then call protected endpoints like this:

```swift
let profile: Profile = try await auth
    .path("me")
    .get()
    .value()
```

SwiftRest loads the saved token and adds this header for you:

```http
Authorization: Bearer your-session-token
```

## Session Tokens

Many APIs return a login response like this:

```json
{
  "sessionToken": "abc123",
  "refreshToken": "refresh456"
}
```

Use this preset:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .client
```

`.sessionTokens()` is just a shortcut for:

```swift
.tokenField("sessionToken")
.refreshTokenField("refreshToken")
```

If your API uses `accessToken` instead, use:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .accessTokens()
    .client
```

`.accessTokens()` is just a shortcut for:

```swift
.tokenField("accessToken")
.refreshTokenField("refreshToken")
```

If your API uses custom names, say the names out loud in code:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .tokenFields(token: "token", refresh: "refresh")
    .client
```

## Login

Make request and response models:

```swift
struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
}

struct LoginResponse: Decodable, Sendable {
    let sessionToken: String
    let refreshToken: String
}
```

Call login:

```swift
let login = LoginRequest(
    email: "person@example.com",
    password: "password"
)

let response: LoginResponse = try await auth
    .path("auth/login")
    .noAuth()
    .post(body: login)
    .value()
```

Why `.noAuth()`?

Because login usually happens before you have a token.

After login succeeds, SwiftRest looks at the response. If the response has the token fields you configured, SwiftRest saves them.

With `.sessionTokens()`, SwiftRest saves:

- `sessionToken`
- `refreshToken`

You can check what was saved:

```swift
if let session = try await auth.session() {
    print(session.token ?? "no token")
    print(session.refreshToken ?? "no refresh token")
}
```

You can also ask simple yes/no questions:

```swift
let hasToken = try await auth.hasSession()
let hasRefresh = try await auth.hasRefreshToken()
```

## Refresh Tokens

A refresh token lets your app recover after the main token expires.

Use this setup:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .refresh(endpoint: "auth/refresh")
    .client
```

Here is what happens:

1. You call a protected endpoint.
2. SwiftRest adds the saved session token.
3. The server replies `401`.
4. SwiftRest sends the saved refresh token to `auth/refresh`.
5. The server returns a new session token.
6. SwiftRest saves the new token.
7. SwiftRest retries the original request once.

The default refresh request body is:

```json
{
  "refreshToken": "saved-refresh-token"
}
```

If your server wants a different request field:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .refresh(
        endpoint: "session/refresh",
        requestRefreshField: "refresh"
    )
    .client
```

If your server refreshes on `403` too:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .refresh(
        endpoint: "auth/refresh",
        triggerStatusCodes: [401, 403]
    )
    .client
```

If refresh fails, log the user out:

```swift
do {
    let profile: Profile = try await auth.path("me").get().value()
    print(profile)
} catch {
    try? await auth.logout()
}
```

## Apple App Attest

App Attest helps your server check that a request came from a real copy of your app.

App Attest is not a login system.
App Attest does not replace your session token.
App Attest sits next to your session token.

Your normal auth still works like this:

```http
Authorization: Bearer session-token
```

When App Attest is enabled and available, SwiftRest can also add App Attest headers.

### Important default

SwiftRest skips App Attest when App Attest is not available.

That means normal token auth still works on:

- Simulator
- macOS
- unsupported devices
- unsupported app extensions

This is the default because beginners should not have their whole app break just because App Attest is unavailable.

### App Attest setup

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .refresh(endpoint: "auth/refresh")
    .appAttest(
        challengeEndpoint: "app-attest/challenge",
        registerEndpoint: "app-attest/register"
    )
    .client
```

That is the whole client setup.

After login, SwiftRest can:

1. ask your server for a challenge
2. create an App Attest key
3. ask Apple to attest the key
4. send the attestation to your server
5. save the App Attest key ID beside the session token

Later, when you make protected requests, SwiftRest can:

1. ask your server for a fresh challenge
2. create an App Attest assertion
3. add App Attest headers to the request

### What gets saved

SwiftRest saves one more value in the same auth session:

```swift
SwiftRestAuthSession(
    token: "session-token",
    refreshToken: "refresh-token",
    appAttestKeyID: "apple-key-id"
)
```

The current built-in Keychain store saves this session.

Old saved sessions still work. If an old session does not have `appAttestKeyID`, SwiftRest reads it as `nil`.

### Check App Attest state

```swift
let hasAppAttestKey = try await auth.hasAppAttestKey()
```

### Register manually

Most apps can let SwiftRest register after login.

If you want to be explicit:

```swift
try await auth.ensureAppAttestRegistered()
```

A clear login flow can look like this:

```swift
let login: LoginResponse = try await auth
    .path("auth/login")
    .noAuth()
    .post(body: LoginRequest(
        email: "person@example.com",
        password: "password"
    ))
    .value()

try await auth.ensureAppAttestRegistered()
```

### Disable App Attest for one request

Use this if one endpoint must not include App Attest:

```swift
let publicInfo: PublicInfo = try await auth
    .path("public/info")
    .appAttest(false)
    .get()
    .value()
```

### Make App Attest required

The default is `.skip`.

If you want to throw when App Attest is unavailable:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .appAttest(
        challengeEndpoint: "app-attest/challenge",
        registerEndpoint: "app-attest/register",
        unavailableBehavior: .fail
    )
    .client
```

Most apps should start with the default `.skip`.

### Server endpoints SwiftRest expects

SwiftRest expects a challenge endpoint.

Default request:

```http
POST /app-attest/challenge
Content-Type: application/json
Authorization: Bearer session-token
```

Body:

```json
{
  "purpose": "registration"
}
```

or:

```json
{
  "purpose": "assertion"
}
```

Response:

```json
{
  "challenge": "a-unique-one-time-challenge"
}
```

The challenge should be unique.
The challenge should be used once.
The server should reject old challenges.

SwiftRest also expects a register endpoint.

Default request:

```http
POST /app-attest/register
Content-Type: application/json
Authorization: Bearer session-token
```

Body:

```json
{
  "keyId": "apple-app-attest-key-id",
  "attestationObject": "base64-attestation-object",
  "clientData": "base64-client-data"
}
```

The server must verify the attestation with Apple App Attest rules.
After verification, the server should store the public key for that user and device.

### App Attest request headers

After registration, protected requests can include:

```http
X-App-Attest-Key-ID: apple-app-attest-key-id
X-App-Attest-Assertion: base64-assertion-object
X-App-Attest-Client-Data: base64-client-data
```

The server should:

1. decode `X-App-Attest-Client-Data`
2. check the challenge inside it
3. check the method, path, query, and body hash
4. verify `X-App-Attest-Assertion` using the public key stored at registration

### Apple setup you still need

In your app target, enable the App Attest capability.

For development, Apple uses the App Attest sandbox unless you choose production in entitlements.
For TestFlight and App Store builds, Apple uses production.

SwiftRest handles the client requests.
Your server still must verify the attestation and assertions.

## Apple DeviceCheck

DeviceCheck helps your server ask Apple for a device token.

DeviceCheck is not a login system.
DeviceCheck does not replace your session token.
DeviceCheck does not replace your refresh token.
DeviceCheck does not sign the request body like App Attest does.

DeviceCheck is simpler than App Attest.
It can be useful when App Attest is not available yet, or when your server wants Apple DeviceCheck tokens for its own rules.

### Important default

SwiftRest skips DeviceCheck when DeviceCheck is not available.

That means normal token auth still works.

DeviceCheck tokens are not saved in Keychain.
SwiftRest asks Apple for a fresh token when a request needs one.
Apple says you should treat the token as single-use.

### DeviceCheck by itself

Use DeviceCheck without App Attest like this:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .refresh(endpoint: "auth/refresh")
    .deviceCheck()
    .client
```

SwiftRest will add this header when DeviceCheck is available:

```http
X-DeviceCheck-Token: base64-devicecheck-token
```

Your normal auth header is still there too:

```http
Authorization: Bearer session-token
```

### DeviceCheck as App Attest fallback

This is the recommended setup when your server supports both:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .refresh(endpoint: "auth/refresh")
    .appAttest(
        challengeEndpoint: "app-attest/challenge",
        registerEndpoint: "app-attest/register"
    )
    .deviceCheck()
    .client
```

This means:

1. Use App Attest when App Attest is working.
2. Use DeviceCheck when App Attest is unavailable.
3. Use DeviceCheck when App Attest has not registered a key yet.
4. Keep normal session token auth working either way.

In this default fallback mode, SwiftRest does not send both proofs at the same time.
It sends App Attest first when it can.
It sends DeviceCheck when App Attest cannot be used.

### Send DeviceCheck always

If your server wants DeviceCheck even when App Attest is also sent:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .appAttest(
        challengeEndpoint: "app-attest/challenge",
        registerEndpoint: "app-attest/register"
    )
    .deviceCheck(mode: .always)
    .client
```

### Use only DeviceCheck

If you configured App Attest elsewhere but want this SwiftRest client to use only DeviceCheck:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .appAttest(
        challengeEndpoint: "app-attest/challenge",
        registerEndpoint: "app-attest/register"
    )
    .deviceCheck(mode: .only)
    .client
```

### Disable DeviceCheck for one request

Use this if one endpoint must not include DeviceCheck:

```swift
let publicInfo: PublicInfo = try await auth
    .path("public/info")
    .deviceCheck(false)
    .get()
    .value()
```

### Make DeviceCheck required

The default is `.skip`.

If you want to throw when DeviceCheck is unavailable:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .deviceCheck(unavailableBehavior: .fail)
    .client
```

Most apps should start with the default `.skip`.

### Custom DeviceCheck header

If your server wants a different header name:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .deviceCheck(
        headers: SwiftRestDeviceCheckHeaders(
            token: "X-My-Device-Token"
        )
    )
    .client
```

### Server work you still need

SwiftRest only gets the DeviceCheck token and sends it to your server.

Your server must:

1. read the `X-DeviceCheck-Token` header
2. decode the base64 token
3. validate the token with Apple DeviceCheck server APIs
4. decide what the token means for your app

DeviceCheck can also support Apple's two server-side per-device bits.
SwiftRest does not manage those bits.
Your server owns that logic.

## Storage

SwiftRest auth needs somewhere to save the session.

### Keychain

Use this for real apps.

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .client
```

Keychain is the default if you do not choose a store:

```swift
let auth = SwiftRest.auth(baseURL: apiURL).client
```

You can choose the Keychain service and key:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain(
        service: "com.example.myapp",
        key: "auth.session"
    )
    .client
```

### UserDefaults

Useful for demos and non-sensitive test apps.

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .defaults()
    .client
```

### Memory

Useful for tests and previews.

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .memory()
    .client
```

Start with a fake session:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .memory(session: SwiftRestAuthSession(
        token: "test-token",
        refreshToken: "test-refresh"
    ))
    .client
```

### No storage

Use this when you do not want SwiftRest to save anything:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .none()
    .client
```

### Custom storage

Make your own store:

```swift
actor MySessionStore: SwiftRestSessionStore {
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
    .store(MySessionStore())
    .client
```

## Headers

Add one default header to every request:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .header("X-App-Version", "6.1.0")
    .client
```

Add many default headers:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .headers([
        "X-App-Version": "6.1.0",
        "X-Platform": "iOS"
    ])
    .client
```

Add one header to one request:

```swift
let profile: Profile = try await auth
    .path("me")
    .header("X-Trace-ID", UUID().uuidString)
    .get()
    .value()
```

## Paths

Start a request with `.path(...)`.

```swift
let user: User = try await auth
    .path("users/1")
    .get()
    .value()
```

You can build paths piece by piece:

```swift
let user: User = try await auth
    .path("users")
    .path(1)
    .get()
    .value()
```

That makes:

```text
/users/1
```

You can pass several parts:

```swift
let event: Event = try await auth
    .path("sessions")
    .paths("abc123", "events", 7)
    .get()
    .value()
```

You do not need to worry about extra slashes.

These are all fine:

```swift
.path("users")
.path("/users")
.path("users/")
.path("/users/")
```

## Query

Use simple query parameters:

```swift
let users: [User] = try await auth
    .path("users")
    .parameter("page", "1")
    .parameter("search", "ricky")
    .get()
    .value()
```

That makes:

```text
/users?page=1&search=ricky
```

Use a model if you prefer:

```swift
struct UserQuery: Encodable, Sendable {
    let page: Int
    let search: String
}

let users: [User] = try await auth
    .path("users")
    .query(UserQuery(page: 1, search: "ricky"))
    .get()
    .value()
```

## HTTP Methods

GET:

```swift
let user: User = try await auth.path("users/1").get().value()
```

POST:

```swift
struct CreateUser: Encodable, Sendable {
    let name: String
}

let user: User = try await auth
    .path("users")
    .post(body: CreateUser(name: "Ricky"))
    .value()
```

PUT:

```swift
let user: User = try await auth
    .path("users/1")
    .put(body: CreateUser(name: "Ricky Stone"))
    .value()
```

PATCH:

```swift
let user: User = try await auth
    .path("users/1")
    .patch(body: ["name": "Ricky"])
    .value()
```

DELETE:

```swift
try await auth
    .path("users/1")
    .delete()
    .send()
```

HEAD:

```swift
let raw = try await auth
    .path("health")
    .head()
    .raw()
```

OPTIONS:

```swift
let raw = try await auth
    .path("users")
    .options()
    .raw()
```

## JSON Settings

Default SwiftRest JSON uses Foundation defaults.

If your API uses `snake_case`, use `webAPI`:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL, config: .webAPI)
    .client
```

Or set JSON behavior on the builder:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .jsonKeys(.snakeCase)
    .jsonDates(.iso8601)
    .client
```

Useful presets:

- `SwiftRestConfig.standard`
- `SwiftRestConfig.webAPI`
- `SwiftRestJSONCoding.iso8601`
- `SwiftRestJSONCoding.webAPI`
- `SwiftRestJSONCoding.webAPIFractionalSeconds`

## Responses

### Decode only the value

```swift
let user: User = try await auth
    .path("users/1")
    .get()
    .value()
```

### Get value and headers

```swift
let result = try await auth
    .path("users/1")
    .get()
    .valueAndHeaders(as: User.self)

print(result.value.name)
print(result.headers["x-request-id"] ?? "no request id")
```

### Get the whole response

```swift
let response: SwiftRestResponse<User> = try await auth
    .path("users/1")
    .get()
    .response()

print(response.statusCode)
print(response.data?.name ?? "no user")
print(response.header("x-request-id") ?? "no request id")
```

### Get raw response

Use this when you want to inspect status codes yourself.

```swift
let raw = try await auth
    .path("users/1")
    .get()
    .raw()

print(raw.statusCode)
print(raw.rawValue ?? "no body")
```

### Send without a response model

Use this for logout or delete calls:

```swift
try await auth
    .path("auth/logout")
    .post(body: [String: String]())
    .send()
```

## Errors

Use normal Swift `do/catch`.

```swift
do {
    let profile: Profile = try await auth
        .path("me")
        .get()
        .value()

    print(profile)
} catch let error as SwiftRestClientError {
    print(error.userMessage)
} catch {
    print(error.localizedDescription)
}
```

Common errors:

- invalid URL
- network error
- decoding error
- HTTP error like `401` or `500`
- refresh failed
- Keychain storage failed
- App Attest failed

## SwiftUI Example

This is intentionally boring.

```swift
import SwiftUI
import SwiftRest

struct Profile: Decodable, Sendable {
    let name: String
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var name = ""
    @Published var errorMessage = ""

    private let auth: SwiftRestAuthClient

    init(auth: SwiftRestAuthClient) {
        self.auth = auth
    }

    func load() async {
        do {
            let profile: Profile = try await auth
                .path("me")
                .get()
                .value()

            name = profile.name
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ProfileView: View {
    @StateObject var model: ProfileViewModel

    var body: some View {
        VStack {
            if !model.name.isEmpty {
                Text(model.name)
            } else if !model.errorMessage.isEmpty {
                Text(model.errorMessage)
            } else {
                ProgressView()
            }
        }
        .task {
            await model.load()
        }
    }
}
```

## Testing

Use memory storage in tests:

```swift
let auth = SwiftRest
    .auth(baseURL: URL(string: "https://api.example.com")!)
    .memory(session: SwiftRestAuthSession(
        token: "test-token",
        refreshToken: "test-refresh"
    ))
    .client
```

Use a custom `URLSession` when you want to mock networking:

```swift
let configuration = URLSessionConfiguration.ephemeral
configuration.protocolClasses = [MyMockURLProtocol.self]
let session = URLSession(configuration: configuration)

let auth = SwiftRest
    .auth(baseURL: apiURL, session: session)
    .memory()
    .client
```

Run SwiftRest tests:

```bash
swift test
```

## Common Questions

### Does SwiftRest use SwiftKey?

No.

SwiftRest has its own built-in Keychain session store.

### Do I need App Attest?

No.

Most apps should start with normal session token auth.
Add App Attest when your server is ready to verify it.

### Do I need DeviceCheck?

No.

DeviceCheck is optional.
Add it when your server is ready to validate Apple DeviceCheck tokens.

### Should I use App Attest or DeviceCheck?

Use App Attest when your server supports it.
Use DeviceCheck as a fallback when App Attest is not available.

SwiftRest makes that setup simple:

```swift
.appAttest(
    challengeEndpoint: "app-attest/challenge",
    registerEndpoint: "app-attest/register"
)
.deviceCheck()
```

### What happens on devices that do not support App Attest?

SwiftRest skips App Attest by default.

Your normal bearer token auth still works.

### What happens when DeviceCheck is not available?

SwiftRest skips DeviceCheck by default.

Your normal bearer token auth still works.

### Does App Attest replace the refresh token?

No.

The refresh token still refreshes the session token.
App Attest helps prove the request came from your real app.

### Does DeviceCheck replace App Attest?

No.

DeviceCheck is simpler.
It gives your server a token to validate with Apple.
App Attest can prove more about your app and sign request data.

### Where are tokens saved?

By default, tokens are saved in Keychain.

The saved session can contain:

- token
- refresh token
- App Attest key ID

DeviceCheck tokens are not saved.
SwiftRest generates them when requests need them.

### How do I log out?

```swift
try await auth.logout()
```

This clears the saved SwiftRest session.

### What should I use for a real app?

Start here:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .refresh(endpoint: "auth/refresh")
    .client
```

Then add App Attest when your server supports it:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .refresh(endpoint: "auth/refresh")
    .appAttest(
        challengeEndpoint: "app-attest/challenge",
        registerEndpoint: "app-attest/register"
    )
    .client
```

Then add DeviceCheck fallback when your server supports it:

```swift
let auth = SwiftRest
    .auth(baseURL: apiURL)
    .keychain()
    .sessionTokens()
    .refresh(endpoint: "auth/refresh")
    .appAttest(
        challengeEndpoint: "app-attest/challenge",
        registerEndpoint: "app-attest/register"
    )
    .deviceCheck()
    .client
```

## License

SwiftRest is released under the MIT License. See [LICENSE.txt](LICENSE.txt).

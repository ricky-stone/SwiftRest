# SwiftRest

SwiftRest is a lightweight, easy-to-use Swift package for building REST API clients. It provides a flexible and robust solution for sending HTTP requests with built-in support for retries, base headers, and per-request authorization tokens—all while using a consistent JSON encoding/decoding strategy.

---

## Features

- **Simple API:** Easily construct and execute HTTP requests.
- **Retry Support:** Configure automatic retry behavior for transient errors.
- **Base Headers:** Define client-level headers that apply to every request.
- **Authorization:** Add per-request Bearer tokens for secure endpoints.
- **JSON Handling:** Built-in JSON encoding and decoding using a dedicated JSON helper.
- **Comprehensive Error Handling:** Detailed error types for troubleshooting.

---

## Requirements

- **Swift:** 5.5+
- **Platforms:** iOS 13+, macOS 10.15+, or equivalent
- **Xcode:** 13+

---

## Installation

Add SwiftRest to your project using the Swift Package Manager.

1. In Xcode, navigate to **File > Swift Packages > Add Package Dependency…**
2. Enter the repository URL: https://github.com/ricky-stone/SwiftRest.git
3. Follow the prompts to complete the integration.

---

## Usage

### Importing the Package

Begin by importing SwiftRest in your Swift file:

```swift
import SwiftRest
```

Creating a Request

Create a SwiftRestRequest instance by specifying the endpoint path and HTTP method. Then, customize the request by adding headers, URL parameters, a JSON body, an authorization token, and retry configurations as needed.

```swift
// Create a GET request to the "api/v1/users" endpoint
var request = SwiftRestRequest(path: "api/v1/users", method: .get)

// Optionally add a custom header
request.addHeader("Custom-Header", "Value")

// Optionally add URL parameters
request.addParameter("page", "1")

// Optionally add an authorization token (will be sent as a Bearer token)
request.addAuthToken("your_auth_token_here")

// Optionally configure retry behavior (3 attempts with a 0.5-second delay between retries)
request.configureRetries(maxRetries: 3, retryDelay: 0.5)
```

Initializing the REST Client

Initialize the SwiftRestClient with your base URL. You can also specify base headers that apply to every request made through this client.

```swift
let client = SwiftRestClient("https://api.example.com")
```

Executing a Request

SwiftRest provides two methods for executing requests asynchronously:

1. Executing with a Response

This method decodes the response into a specified type.

```swift
// Define a model for the expected response. The model must conform to Decodable & Sendable.
struct User: Decodable, Sendable {
    let id: Int
    let name: String
}

// Execute the request and decode the response.
    do {
        let response: SwiftRestResponse<User> = try await client.executeAsyncWithResponse(request)
        if response.isSuccess, let user = response.data {
            print("User Name: \(user.name)")
        } else {
            print("Request failed with status code: \(response.statusCode)")
        }
    } catch {
        print("Error executing request: \(error)")
    }
```

2. Executing without a Response

For requests that do not expect any response payload.

```swift
    do {
        try await client.executeAsyncWithoutResponse(request)
        print("Request executed successfully")
    } catch {
        print("Error executing request: \(error)")
    }
```

Error Handling

SwiftRest defines a set of error types in `SwiftRestClientError` for various failure scenarios:
- **invalidBaseURL:** The provided base URL is invalid.
- **invalidURLComponents:** URL components could not be properly constructed.
- **invalidFinalURL:** The final URL after appending query parameters is invalid.
- **invalidHTTPResponse:** The HTTP response is missing or malformed.
- **missingContentType:** The expected “Content-Type” header is missing.
- **retryLimitReached:** The maximum number of retry attempts has been reached without success.

⸻

Contributing

Contributions are welcome! If you have suggestions, bug fixes, or improvements, please open an issue or submit a pull request on GitHub.

⸻

License

This project is licensed under the MIT License.

⸻

Acknowledgments

Thank you for using SwiftRest! If you find this package useful, please consider starring the repository and sharing it with your community.

⸻

Happy coding!





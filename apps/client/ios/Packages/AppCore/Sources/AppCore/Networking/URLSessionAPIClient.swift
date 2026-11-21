import Foundation

public final class URLSessionAPIClient: APIClient {
    private struct AuthResponse: Decodable {
        let sessionToken: String
        let user: User
    }

    private struct DemoCardRequest: Encodable {
        let kind: CardKind
    }

    private struct DemoCardResponse: Decodable {
        let card: Card
    }

    private struct CurrentUserResponse: Decodable {
        let user: User
    }

    private struct ErrorEnvelope: Decodable {
        let code: String
        let error: String
    }

    private struct Credentials: Encodable {
        let email: String
        let password: String
    }

    private enum Method: String {
        case get = "GET"
        case post = "POST"
    }

    private let baseURL: URL
    private let session: URLSession
    private let tokenStore: SessionTokenStore

    public init(baseURL: URL, session: URLSession, tokenStore: SessionTokenStore) {
        self.baseURL = baseURL
        self.session = session
        self.tokenStore = tokenStore
    }

    // The session token travels in a header, so the system cookie jar must stay out of it.
    public static func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return configuration
    }

    public func createDemoCard(kind: CardKind) async throws -> Card {
        let body = try JSONEncoder().encode(DemoCardRequest(kind: kind))
        let data = try await send(.post, path: "/v1/demo/cards", body: body)
        return try decode(DemoCardResponse.self, from: data).card
    }

    public func fetchCurrentUser() async throws -> User {
        let data = try await send(.get, path: "/v1/auth/me")
        return try decode(CurrentUserResponse.self, from: data).user
    }

    public func login(email: String, password: String) async throws -> User {
        try await authenticate(path: "/v1/auth/login", email: email, password: password)
    }

    public func logout() async throws {
        _ = try await send(.post, path: "/v1/auth/logout")
    }

    public func register(email: String, password: String) async throws -> User {
        try await authenticate(path: "/v1/auth/register", email: email, password: password)
    }

    private func authenticate(path: String, email: String, password: String) async throws -> User {
        let body = try JSONEncoder().encode(Credentials(email: email, password: password))
        let data = try await send(.post, path: path, body: body, clearsTokenOnUnauthorized: false)
        let response = try decode(AuthResponse.self, from: data)
        do {
            try tokenStore.save(response.sessionToken)
        } catch {
            throw APIError.decoding
        }
        return response.user
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func send(
        _ method: Method,
        path: String,
        body: Data? = nil,
        clearsTokenOnUnauthorized: Bool = true
    ) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("token", forHTTPHeaderField: "X-Session-Transport")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        if let token = try? tokenStore.read() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.network }
        if (200..<300).contains(http.statusCode) { return data }

        if http.statusCode == 401 && clearsTokenOnUnauthorized {
            try? tokenStore.clear()
            throw APIError.unauthorized
        }
        if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            throw APIError.server(code: envelope.code, message: envelope.error, status: http.statusCode)
        }
        throw APIError.server(
            code: "UNKNOWN", message: "Something went wrong. Try again.", status: http.statusCode)
    }
}

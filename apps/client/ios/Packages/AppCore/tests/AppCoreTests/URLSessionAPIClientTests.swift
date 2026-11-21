import AppCore
import Foundation
import Testing

private struct Harness {
    let client: URLSessionAPIClient
    let store: InMemorySessionTokenStore
    let stub: StubURLProtocol.StubSession
}

private func makeHarness() -> Harness {
    let stub = StubURLProtocol.makeStubSession()
    let store = InMemorySessionTokenStore()
    let client = URLSessionAPIClient(baseURL: stub.baseURL, session: stub.session, tokenStore: store)
    return Harness(client: client, store: store, stub: stub)
}

private func jsonData(_ object: [String: Any]) -> Data {
    (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
}

private func userJSON(email: String) -> [String: Any] {
    [
        "createdAt": "2026-01-01T00:00:00.000Z",
        "email": email,
        "id": UUID().uuidString.lowercased(),
        "role": "user",
        "updatedAt": "2026-01-02T00:00:00.000Z",
    ]
}

private func authBody(token: String, email: String) -> Data {
    jsonData(["sessionToken": token, "user": userJSON(email: email)])
}

private func errorBody(code: String, message: String) -> Data {
    jsonData(["code": code, "error": message])
}

@Test func loginSendsRequiredHeadersAndSavesToken() async throws {
    let harness = makeHarness()
    let token = makeTestToken()
    let password = UUID().uuidString
    harness.stub.respond(status: 200, body: authBody(token: token, email: "ada@example.com"))

    let user = try await harness.client.login(email: "ada@example.com", password: password)

    let request = try #require(harness.stub.lastRequest)
    #expect(request.url.path == "/v1/auth/login")
    #expect(request.method == "POST")
    #expect(request.header("X-Requested-With") == "XMLHttpRequest")
    #expect(request.header("X-Session-Transport") == "token")
    #expect(request.header("Accept") == "application/json")
    #expect(request.header("Content-Type")?.hasPrefix("application/json") == true)
    #expect(request.header("Authorization") == nil)
    let sent = try #require(request.body)
    let sentObject = try #require(try JSONSerialization.jsonObject(with: sent) as? [String: String])
    #expect(sentObject == ["email": "ada@example.com", "password": password])
    #expect(user.email == "ada@example.com")
    #expect(try harness.store.read() == token)
}

@Test func registerPostsToRegisterAndSavesToken() async throws {
    let harness = makeHarness()
    let token = makeTestToken()
    harness.stub.respond(status: 201, body: authBody(token: token, email: "grace@example.com"))

    let user = try await harness.client.register(email: "grace@example.com", password: UUID().uuidString)

    let request = try #require(harness.stub.lastRequest)
    #expect(request.url.path == "/v1/auth/register")
    #expect(request.method == "POST")
    #expect(user.email == "grace@example.com")
    #expect(try harness.store.read() == token)
}

@Test func authenticatedRequestSendsBearer() async throws {
    let harness = makeHarness()
    let token = makeTestToken()
    try harness.store.save(token)
    harness.stub.respond(status: 200, body: jsonData(["user": userJSON(email: "ada@example.com")]))

    let user = try await harness.client.fetchCurrentUser()

    let request = try #require(harness.stub.lastRequest)
    #expect(request.url.path == "/v1/auth/me")
    #expect(request.method == "GET")
    #expect(request.header("Authorization") == "Bearer \(token)")
    #expect(request.header("X-Session-Transport") == "token")
    #expect(user.email == "ada@example.com")
}

@Test func loginWith401IsServerError() async throws {
    let harness = makeHarness()
    let existing = makeTestToken()
    try harness.store.save(existing)
    harness.stub.respond(
        status: 401,
        body: errorBody(code: "AUTH_INVALID_CREDENTIALS", message: "Invalid email or password")
    )

    await #expect(
        throws: APIError.server(code: "AUTH_INVALID_CREDENTIALS", message: "Invalid email or password", status: 401)
    ) {
        try await harness.client.login(email: "ada@example.com", password: UUID().uuidString)
    }
    #expect(try harness.store.read() == existing)
}

@Test func fetchCurrentUserWith401ClearsToken() async throws {
    let harness = makeHarness()
    try harness.store.save(makeTestToken())
    harness.stub.respond(status: 401, body: errorBody(code: "AUTH_REQUIRED", message: "Authentication required"))

    await #expect(throws: APIError.unauthorized) {
        try await harness.client.fetchCurrentUser()
    }
    #expect(try harness.store.read() == nil)
}

@Test func registerWith409IsServerError() async throws {
    let harness = makeHarness()
    harness.stub.respond(
        status: 409,
        body: errorBody(code: "AUTH_EMAIL_ALREADY_REGISTERED", message: "Email already registered")
    )

    await #expect(
        throws: APIError.server(code: "AUTH_EMAIL_ALREADY_REGISTERED", message: "Email already registered", status: 409)
    ) {
        try await harness.client.register(email: "ada@example.com", password: UUID().uuidString)
    }
    #expect(try harness.store.read() == nil)
}

@Test func transportFailureIsNetworkError() async {
    let harness = makeHarness()
    harness.stub.fail(with: URLError(.notConnectedToInternet))

    await #expect(throws: APIError.network) {
        try await harness.client.login(email: "ada@example.com", password: UUID().uuidString)
    }
}

@Test func htmlErrorBodyIsServerUnknown() async {
    let harness = makeHarness()
    harness.stub.respond(status: 502, headers: ["Content-Type": "text/html"], body: Data("<html>".utf8))

    await #expect(
        throws: APIError.server(code: "UNKNOWN", message: "Something went wrong. Try again.", status: 502)
    ) {
        try await harness.client.fetchCurrentUser()
    }
}

@Test func malformedSuccessBodyIsDecodingError() async {
    let harness = makeHarness()
    harness.stub.respond(status: 200, body: Data("not json".utf8))

    await #expect(throws: APIError.decoding) {
        try await harness.client.login(email: "ada@example.com", password: UUID().uuidString)
    }
}

@Test func logoutSendsBearerAndPostsToLogout() async throws {
    let harness = makeHarness()
    let token = makeTestToken()
    try harness.store.save(token)
    harness.stub.respond(status: 204)

    try await harness.client.logout()

    let request = try #require(harness.stub.lastRequest)
    #expect(request.url.path == "/v1/auth/logout")
    #expect(request.method == "POST")
    #expect(request.header("Authorization") == "Bearer \(token)")
    #expect(request.header("X-Requested-With") == "XMLHttpRequest")
}

@Test func sessionConfigurationStoresAndSendsNoCookies() {
    let configuration = URLSessionAPIClient.makeSessionConfiguration()
    #expect(configuration.httpCookieStorage == nil)
    #expect(configuration.httpShouldSetCookies == false)
    #expect(configuration.httpCookieAcceptPolicy == .never)
}

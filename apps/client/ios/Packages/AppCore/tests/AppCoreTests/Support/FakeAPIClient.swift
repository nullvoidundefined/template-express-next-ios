import AppCore
import Foundation

/// A run-time built user, so no fixture file or literal credential is needed.
func makeTestUser(email: String = "ada@example.com") -> User {
    let json: [String: Any] = [
        "createdAt": "2026-01-01T00:00:00.000Z",
        "email": email,
        "id": UUID().uuidString.lowercased(),
        "role": "user",
        "updatedAt": "2026-01-02T00:00:00.000Z",
    ]
    let data = try! JSONSerialization.data(withJSONObject: json)
    return try! JSONDecoder().decode(User.self, from: data)
}

/// 64 lowercase hex characters, built at run time.
func makeTestToken() -> String {
    let part = { UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased() }
    return part() + part()
}

/// Each method returns the next queued Result and counts calls. An empty queue returns
/// `.network` so an unexpected call shows up as a failed assertion instead of a crash.
/// `holdLogin()` makes login calls suspend after they are counted, until `releaseLogin()`.
actor FakeAPIClient: APIClient {
    private(set) var fetchCurrentUserCallCount = 0
    private(set) var lastLoginEmail: String?
    private(set) var loginCallCount = 0
    private(set) var logoutCallCount = 0
    private(set) var registerCallCount = 0

    private var enteredWaiter: CheckedContinuation<Void, Never>?
    private var fetchCurrentUserResults: [Result<User, APIError>] = []
    private var loginGate: CheckedContinuation<Void, Never>?
    private var loginResults: [Result<User, APIError>] = []
    private var logoutResults: [Result<Void, APIError>] = []
    private var registerResults: [Result<User, APIError>] = []
    private var shouldHoldLogin = false

    func queueFetchCurrentUser(_ result: Result<User, APIError>) { fetchCurrentUserResults.append(result) }
    func queueLogin(_ result: Result<User, APIError>) { loginResults.append(result) }
    func queueLogout(_ result: Result<Void, APIError>) { logoutResults.append(result) }
    func queueRegister(_ result: Result<User, APIError>) { registerResults.append(result) }

    func holdLogin() { shouldHoldLogin = true }

    func releaseLogin() {
        shouldHoldLogin = false
        loginGate?.resume()
        loginGate = nil
    }

    /// Returns once a login call has reached the fake (and, if held, is about to suspend).
    func waitForLoginToBeEntered() async {
        if loginCallCount > 0 { return }
        await withCheckedContinuation { enteredWaiter = $0 }
    }

    func createDemoCard(kind: CardKind) async throws -> Card {
        throw APIError.decoding
    }

    func fetchCurrentUser() async throws -> User {
        fetchCurrentUserCallCount += 1
        return try next(&fetchCurrentUserResults).get()
    }

    func login(email: String, password: String) async throws -> User {
        loginCallCount += 1
        lastLoginEmail = email
        enteredWaiter?.resume()
        enteredWaiter = nil
        if shouldHoldLogin {
            await withCheckedContinuation { loginGate = $0 }
        }
        return try next(&loginResults).get()
    }

    func logout() async throws {
        logoutCallCount += 1
        try next(&logoutResults).get()
    }

    func register(email: String, password: String) async throws -> User {
        registerCallCount += 1
        return try next(&registerResults).get()
    }

    private func next<Value>(_ queue: inout [Result<Value, APIError>]) -> Result<Value, APIError> {
        queue.isEmpty ? .failure(.network) : queue.removeFirst()
    }
}

import AppCore
import Foundation
import Testing

private let unauthorizedNotice = "You were signed out. Log in again."

@MainActor
private struct Harness {
    let fake = FakeAPIClient()
    let store = InMemorySessionTokenStore()
    let viewModel: AuthViewModel

    init() {
        viewModel = AuthViewModel(apiClient: fake, tokenStore: store)
    }
}

@MainActor
@Suite struct AuthViewModelTests {
    @Test func restoreWithoutTokenIsSignedOut() async {
        let harness = Harness()
        await harness.viewModel.restore()
        #expect(harness.viewModel.state == .signedOut(notice: nil))
    }

    @Test func restoreWithValidTokenIsSignedIn() async throws {
        let harness = Harness()
        let user = makeTestUser()
        try harness.store.save(makeTestToken())
        await harness.fake.queueFetchCurrentUser(.success(user))

        await harness.viewModel.restore()

        #expect(harness.viewModel.state == .signedIn(user))
    }

    @Test func restoreWithRejectedTokenIsSignedOut() async throws {
        let harness = Harness()
        try harness.store.save(makeTestToken())
        await harness.fake.queueFetchCurrentUser(.failure(.unauthorized))

        await harness.viewModel.restore()

        #expect(harness.viewModel.state == .signedOut(notice: nil))
    }

    @Test func restoreWhenServerUnreachableKeepsToken() async throws {
        let harness = Harness()
        let token = makeTestToken()
        try harness.store.save(token)
        await harness.fake.queueFetchCurrentUser(.failure(.network))

        await harness.viewModel.restore()

        #expect(harness.viewModel.state == .unreachable)
        #expect(try harness.store.read() == token)
    }

    @Test func loginSuccessIsSignedIn() async {
        let harness = Harness()
        let user = makeTestUser()
        await harness.fake.queueLogin(.success(user))

        await harness.viewModel.login(email: user.email, password: UUID().uuidString)

        #expect(harness.viewModel.state == .signedIn(user))
        #expect(harness.viewModel.errorMessage == nil)
        #expect(!harness.viewModel.isSubmitting)
    }

    @Test func registerSuccessIsSignedIn() async {
        let harness = Harness()
        let user = makeTestUser(email: "grace@example.com")
        await harness.fake.queueRegister(.success(user))

        await harness.viewModel.register(email: user.email, password: UUID().uuidString)

        #expect(harness.viewModel.state == .signedIn(user))
        #expect(!harness.viewModel.isSubmitting)
    }

    @Test func loginFailureSetsErrorMessage() async {
        let harness = Harness()
        let before = harness.viewModel.state
        await harness.fake.queueLogin(
            .failure(.server(code: "AUTH_INVALID_CREDENTIALS", message: "Invalid email or password", status: 401))
        )

        await harness.viewModel.login(email: "ada@example.com", password: UUID().uuidString)

        #expect(harness.viewModel.errorMessage == "Invalid email or password")
        #expect(harness.viewModel.state == before)
        #expect(!harness.viewModel.isSubmitting)
    }

    @Test func loginNetworkFailureSetsConnectionMessage() async {
        let harness = Harness()
        await harness.fake.queueLogin(.failure(.network))

        await harness.viewModel.login(email: "ada@example.com", password: UUID().uuidString)

        #expect(harness.viewModel.errorMessage == "Can't reach the server. Check your connection.")
    }

    @Test func loginIgnoresSecondCallWhileSubmitting() async {
        let harness = Harness()
        let user = makeTestUser()
        let password = UUID().uuidString
        await harness.fake.holdLogin()
        await harness.fake.queueLogin(.success(user))

        let first = Task { await harness.viewModel.login(email: user.email, password: password) }
        await harness.fake.waitForLoginToBeEntered()
        #expect(harness.viewModel.isSubmitting)

        await harness.viewModel.login(email: user.email, password: password)
        await harness.fake.releaseLogin()
        await first.value

        #expect(await harness.fake.loginCallCount == 1)
        #expect(harness.viewModel.state == .signedIn(user))
        #expect(!harness.viewModel.isSubmitting)
    }

    @Test func logoutClearsTokenEvenWhenServerFails() async throws {
        let harness = Harness()
        try harness.store.save(makeTestToken())
        await harness.fake.queueLogout(.failure(.network))

        await harness.viewModel.logout()

        #expect(try harness.store.read() == nil)
        #expect(harness.viewModel.state == .signedOut(notice: nil))
    }

    @Test func logoutSuccessClearsToken() async throws {
        let harness = Harness()
        try harness.store.save(makeTestToken())
        await harness.fake.queueLogout(.success(()))

        await harness.viewModel.logout()

        #expect(try harness.store.read() == nil)
        #expect(harness.viewModel.state == .signedOut(notice: nil))
    }

    @Test func handleUnauthorizedShowsNotice() throws {
        let harness = Harness()
        try harness.store.save(makeTestToken())

        harness.viewModel.handleUnauthorized()

        #expect(harness.viewModel.state == .signedOut(notice: unauthorizedNotice))
        #expect(try harness.store.read() == nil)
    }

    @Test func restoreWithServerErrorSignsOutWithNotice() async throws {
        let harness = Harness()
        try harness.store.save(makeTestToken())
        await harness.fake.queueFetchCurrentUser(.failure(.server(code: "X", message: "y", status: 400)))

        await harness.viewModel.restore()

        #expect(harness.viewModel.state == .signedOut(notice: "Something went wrong. Log in again."))
        #expect(try harness.store.read() == nil)
    }

    @Test func restoreWithDecodingErrorSignsOutWithNotice() async throws {
        let harness = Harness()
        try harness.store.save(makeTestToken())
        await harness.fake.queueFetchCurrentUser(.failure(.decoding))

        await harness.viewModel.restore()

        #expect(harness.viewModel.state == .signedOut(notice: "Something went wrong. Log in again."))
        #expect(try harness.store.read() == nil)
    }

    @Test func clearErrorRemovesMessage() async {
        let harness = Harness()
        await harness.fake.queueLogin(.failure(.network))
        await harness.viewModel.login(email: "ada@example.com", password: UUID().uuidString)
        #expect(harness.viewModel.errorMessage != nil)
        let before = harness.viewModel.state

        harness.viewModel.clearError()

        #expect(harness.viewModel.errorMessage == nil)
        #expect(harness.viewModel.state == before)
    }

    @Test func handleUnauthorizedClearsErrorMessage() async {
        let harness = Harness()
        await harness.fake.queueLogin(.failure(.network))
        await harness.viewModel.login(email: "ada@example.com", password: UUID().uuidString)
        #expect(harness.viewModel.errorMessage != nil)

        harness.viewModel.handleUnauthorized()

        #expect(harness.viewModel.errorMessage == nil)
    }
}

@MainActor
private final class SignedOutCounter {
    private(set) var count = 0
    func record() { count += 1 }
}

@MainActor
private struct SignOutHarness {
    let counter = SignedOutCounter()
    let fake = FakeAPIClient()
    let store = InMemorySessionTokenStore()
    let viewModel: AuthViewModel

    init() {
        let counter = counter
        viewModel = AuthViewModel(
            apiClient: fake,
            tokenStore: store,
            onSignedOut: { counter.record() }
        )
    }
}

@MainActor
@Suite struct AuthViewModelSignedOutCallbackTests {
    @Test func logoutCallsOnSignedOutOnce() async {
        let harness = SignOutHarness()
        await harness.fake.queueLogout(.success(()))

        await harness.viewModel.logout()

        #expect(harness.viewModel.state == .signedOut(notice: nil))
        #expect(harness.counter.count == 1)
    }

    @Test func logoutCallsOnSignedOutWhenServerCallFails() async {
        let harness = SignOutHarness()
        await harness.fake.queueLogout(.failure(.network))

        await harness.viewModel.logout()

        #expect(harness.viewModel.state == .signedOut(notice: nil))
        #expect(harness.counter.count == 1)
    }

    @Test func handleUnauthorizedCallsOnSignedOutOnce() {
        let harness = SignOutHarness()

        harness.viewModel.handleUnauthorized()

        #expect(harness.counter.count == 1)
    }

    @Test func restoreWithoutTokenCallsOnSignedOutOnce() async {
        let harness = SignOutHarness()

        await harness.viewModel.restore()

        #expect(harness.viewModel.state == .signedOut(notice: nil))
        #expect(harness.counter.count == 1)
    }

    @Test func restoreWithRejectedTokenCallsOnSignedOutOnce() async throws {
        let harness = SignOutHarness()
        try harness.store.save(makeTestToken())
        await harness.fake.queueFetchCurrentUser(.failure(.unauthorized))

        await harness.viewModel.restore()

        #expect(harness.viewModel.state == .signedOut(notice: nil))
        #expect(harness.counter.count == 1)
    }

    @Test func restoreWithOtherErrorCallsOnSignedOutOnce() async throws {
        let harness = SignOutHarness()
        try harness.store.save(makeTestToken())
        await harness.fake.queueFetchCurrentUser(.failure(.decoding))

        await harness.viewModel.restore()

        #expect(harness.viewModel.state != .checking)
        #expect(harness.viewModel.state != .unreachable)
        #expect(harness.counter.count == 1)
    }

    @Test func restoreSignedInDoesNotCallOnSignedOut() async throws {
        let harness = SignOutHarness()
        let user = makeTestUser()
        try harness.store.save(makeTestToken())
        await harness.fake.queueFetchCurrentUser(.success(user))

        await harness.viewModel.restore()

        #expect(harness.viewModel.state == .signedIn(user))
        #expect(harness.counter.count == 0)
    }

    @Test func restoreUnreachableDoesNotCallOnSignedOut() async throws {
        let harness = SignOutHarness()
        try harness.store.save(makeTestToken())
        await harness.fake.queueFetchCurrentUser(.failure(.network))

        await harness.viewModel.restore()

        #expect(harness.viewModel.state == .unreachable)
        #expect(harness.counter.count == 0)
    }

    @Test func failedLoginDoesNotCallOnSignedOut() async {
        let harness = SignOutHarness()
        await harness.fake.queueLogin(.failure(.network))

        await harness.viewModel.login(email: "ada@example.com", password: makeTestToken())

        #expect(harness.counter.count == 0)
    }

    @Test func failedRegisterDoesNotCallOnSignedOut() async {
        let harness = SignOutHarness()
        await harness.fake.queueRegister(.failure(.network))

        await harness.viewModel.register(email: "ada@example.com", password: makeTestToken())

        #expect(harness.counter.count == 0)
    }

    @Test func successfulLoginDoesNotCallOnSignedOut() async {
        let harness = SignOutHarness()
        let user = makeTestUser()
        await harness.fake.queueLogin(.success(user))

        await harness.viewModel.login(email: "ada@example.com", password: makeTestToken())

        #expect(harness.viewModel.state == .signedIn(user))
        #expect(harness.counter.count == 0)
    }
}

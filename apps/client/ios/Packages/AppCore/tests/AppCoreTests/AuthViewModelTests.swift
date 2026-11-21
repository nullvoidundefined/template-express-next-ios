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
}

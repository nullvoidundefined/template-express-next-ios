import Observation

public enum AuthState: Equatable {
    case checking
    case signedIn(User)
    case signedOut(notice: String?)
    case unreachable
}

@MainActor @Observable
public final class AuthViewModel {
    public private(set) var errorMessage: String?
    public private(set) var isSubmitting = false
    public private(set) var state: AuthState = .checking

    private let apiClient: APIClient
    private let tokenStore: SessionTokenStore

    public init(apiClient: APIClient, tokenStore: SessionTokenStore) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
    }

    public func handleUnauthorized() {
        try? tokenStore.clear()
        state = .signedOut(notice: "You were signed out. Log in again.")
    }

    public func login(email: String, password: String) async {
        await submit { try await self.apiClient.login(email: email, password: password) }
    }

    public func logout() async {
        try? await apiClient.logout()
        try? tokenStore.clear()
        errorMessage = nil
        state = .signedOut(notice: nil)
    }

    public func register(email: String, password: String) async {
        await submit { try await self.apiClient.register(email: email, password: password) }
    }

    public func restore() async {
        guard let token = try? tokenStore.read(), !token.isEmpty else {
            state = .signedOut(notice: nil)
            return
        }
        state = .checking
        do {
            state = .signedIn(try await apiClient.fetchCurrentUser())
        } catch APIError.unauthorized {
            state = .signedOut(notice: nil)
        } catch {
            state = .unreachable
        }
    }

    private func submit(_ action: () async throws -> User) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            state = .signedIn(try await action())
        } catch let error as APIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = Self.message(for: .network)
        }
    }

    private static func message(for error: APIError) -> String {
        switch error {
        case .network: "Can't reach the server. Check your connection."
        case .server(_, let message, _): message
        case .decoding, .unauthorized: "Something went wrong. Try again."
        }
    }
}

import AppCore
import Foundation

@MainActor
struct AppEnvironment {
    let authViewModel: AuthViewModel
    let makeHomeViewModel: () -> HomeViewModel

    private static let keychainService = Bundle.main.bundleIdentifier ?? "com.example.templateapp"

    static func make() -> AppEnvironment {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uiTestStubAPI") {
                return make(
                    apiClient: StubAPIClient(), tokenStore: InMemorySessionTokenStore(),
                    watchLink: UnavailableWatchLink())
            }
        #endif
        let tokenStore = KeychainSessionTokenStore(service: keychainService)
        let apiClient = URLSessionAPIClient(
            baseURL: apiBaseURL(),
            session: URLSession(configuration: URLSessionAPIClient.makeSessionConfiguration()),
            tokenStore: tokenStore)
        WatchConnectivityLink.shared.activate()
        return make(apiClient: apiClient, tokenStore: tokenStore, watchLink: WatchConnectivityLink.shared)
    }

    private static func make(
        apiClient: APIClient, tokenStore: SessionTokenStore, watchLink: WatchLink
    ) -> AppEnvironment {
        let authViewModel = AuthViewModel(apiClient: apiClient, tokenStore: tokenStore)
        return AppEnvironment(
            authViewModel: authViewModel,
            makeHomeViewModel: {
                HomeViewModel(
                    apiClient: apiClient,
                    onUnauthorized: { authViewModel.handleUnauthorized() },
                    watchLink: watchLink)
            })
    }

    private static func apiBaseURL() -> URL {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
            let url = URL(string: value), url.host != nil
        else {
            preconditionFailure("APIBaseURL is missing or not a URL. Set API_BASE_URL in the xcconfig files.")
        }
        return url
    }
}

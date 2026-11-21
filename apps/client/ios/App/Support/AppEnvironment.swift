import AppCore
import Foundation

@MainActor
enum AppEnvironment {
    private static let keychainService = Bundle.main.bundleIdentifier ?? "com.example.templateapp"

    static func makeAuthViewModel() -> AuthViewModel {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uiTestStubAPI") {
                return AuthViewModel(apiClient: StubAPIClient(), tokenStore: InMemorySessionTokenStore())
            }
        #endif
        let tokenStore = KeychainSessionTokenStore(service: keychainService)
        let apiClient = URLSessionAPIClient(
            baseURL: apiBaseURL(), session: makeSession(), tokenStore: tokenStore)
        return AuthViewModel(apiClient: apiClient, tokenStore: tokenStore)
    }

    private static func apiBaseURL() -> URL {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
            let url = URL(string: value), url.host != nil
        else {
            preconditionFailure("APIBaseURL is missing or not a URL. Set API_BASE_URL in the xcconfig files.")
        }
        return url
    }

    // The session token travels in a header, so the system cookie jar must stay out of it.
    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }
}

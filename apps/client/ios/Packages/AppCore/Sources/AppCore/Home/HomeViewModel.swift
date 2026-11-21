import Observation

@MainActor @Observable
public final class HomeViewModel {
    public private(set) var errorMessage: String?
    public private(set) var isSending = false
    public private(set) var lastCard: Card?
    public private(set) var lastDelivery: WatchDelivery?

    private let apiClient: APIClient
    private let onUnauthorized: @MainActor () -> Void
    private let watchLink: WatchLink

    public init(
        apiClient: APIClient,
        onUnauthorized: @escaping @MainActor () -> Void,
        watchLink: WatchLink
    ) {
        self.apiClient = apiClient
        self.onUnauthorized = onUnauthorized
        self.watchLink = watchLink
    }

    public func send(kind: CardKind) async {
        guard !isSending else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            let card = try await apiClient.createDemoCard(kind: kind)
            lastCard = card
            lastDelivery = watchLink.send(card)
        } catch APIError.unauthorized {
            onUnauthorized()
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

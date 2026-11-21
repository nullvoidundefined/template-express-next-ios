import AppCore
import Foundation
import WatchConnectivity

@MainActor
final class WatchContextReceiver: NSObject, WCSessionDelegate {
    private let store: LatestCardStore

    init(store: LatestCardStore) {
        self.store = store
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        deliver(Self.change(in: session.receivedApplicationContext))
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        deliver(Self.change(in: applicationContext))
    }

    /// What a received context asks the store to do. Sendable, so it can cross to the main actor.
    private enum Change: Sendable {
        case card(Data)
        case clear
        case none
    }

    private nonisolated static func change(in context: [String: Any]) -> Change {
        if CardContext.isClear(context) { return .clear }
        if let data = context[CardContext.key] as? Data { return .card(data) }
        return .none
    }

    private nonisolated func deliver(_ change: Change) {
        switch change {
        case .card(let data):
            Task { @MainActor in
                store.receive(context: [CardContext.key: data])
            }
        case .clear:
            Task { @MainActor in
                store.clear()
            }
        case .none:
            break
        }
    }
}

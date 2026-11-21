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
        guard let data = session.receivedApplicationContext[CardContext.key] as? Data else { return }
        deliver(data)
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let data = applicationContext[CardContext.key] as? Data else { return }
        deliver(data)
    }

    private nonisolated func deliver(_ data: Data) {
        Task { @MainActor in
            store.receive(context: [CardContext.key: data])
        }
    }
}

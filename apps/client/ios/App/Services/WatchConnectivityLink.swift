import AppCore
import Foundation
import WatchConnectivity

/// Sends the latest card to the paired Watch as application context.
/// WCSession is thread-safe for these calls, and its delegate callbacks arrive off the main
/// thread, so the delegate methods touch no mutable state of their own.
final class WatchConnectivityLink: NSObject, WatchLink, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchConnectivityLink()

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ card: Card) -> WatchDelivery {
        guard WCSession.isSupported() else { return .unavailable }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled
        else { return .unavailable }
        do {
            try session.updateApplicationContext(CardContext.encode(card))
            return .sent
        } catch {
            return .unavailable
        }
    }

    func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}

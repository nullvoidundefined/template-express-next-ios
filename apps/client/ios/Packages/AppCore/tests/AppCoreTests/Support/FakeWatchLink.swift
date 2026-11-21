import AppCore
import Foundation

/// Records every card it is asked to send and returns a configurable delivery.
/// `@unchecked Sendable` is safe here: all mutable state is read and written under `lock`.
final class FakeWatchLink: WatchLink, @unchecked Sendable {
    private let lock = NSLock()
    private var delivery: WatchDelivery
    private var clearCalls = 0
    private var received: [Card] = []

    init(delivery: WatchDelivery = .sent) {
        self.delivery = delivery
    }

    var clearCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return clearCalls
    }

    func clear() -> WatchDelivery {
        lock.lock()
        defer { lock.unlock() }
        clearCalls += 1
        return delivery
    }

    var receivedCards: [Card] {
        lock.lock()
        defer { lock.unlock() }
        return received
    }

    func send(_ card: Card) -> WatchDelivery {
        lock.lock()
        defer { lock.unlock() }
        received.append(card)
        return delivery
    }
}

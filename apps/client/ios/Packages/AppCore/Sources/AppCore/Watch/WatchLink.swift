public enum WatchDelivery: Equatable, Sendable {
    case sent
    case unavailable
}

public protocol WatchLink: Sendable {
    func clear() -> WatchDelivery
    func send(_ card: Card) -> WatchDelivery
}

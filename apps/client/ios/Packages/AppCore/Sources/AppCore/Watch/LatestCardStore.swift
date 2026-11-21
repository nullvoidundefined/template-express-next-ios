import Foundation
import Observation

@MainActor @Observable public final class LatestCardStore {
    private static let savedKey = "latestCard"

    public private(set) var card: Card?
    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        self.card = CardContext.decode([CardContext.key: defaults.object(forKey: Self.savedKey) as Any])
    }

    public func clear() {
        card = nil
        defaults.removeObject(forKey: Self.savedKey)
    }

    public func receive(context: [String: Any]) {
        if CardContext.isClear(context) {
            clear()
            return
        }
        guard let received = CardContext.decode(context),
            let data = context[CardContext.key] as? Data
        else { return }
        card = received
        defaults.set(data, forKey: Self.savedKey)
    }
}

import Foundation

public enum CardContext {
    public static let key = "card"

    public static let clearKey = "clear"

    public static func encodeClear() -> [String: Any] {
        [clearKey: true]
    }

    public static func isClear(_ context: [String: Any]) -> Bool {
        context[clearKey] as? Bool == true
    }

    public static func decode(_ context: [String: Any]) -> Card? {
        guard let data = context[key] as? Data else { return nil }
        return try? JSONDecoder().decode(Card.self, from: data)
    }

    public static func encode(_ card: Card) throws -> [String: Any] {
        [key: try JSONEncoder().encode(card)]
    }
}

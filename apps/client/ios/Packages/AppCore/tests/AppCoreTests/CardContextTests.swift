import AppCore
import Foundation
import Testing

private func makeCard(id: String = "card-1", title: String = "Message") throws -> Card {
    let json = """
        {"body": "Hello from the phone", "createdAt": "2026-11-20T10:00:00.000Z", \
        "id": "\(id)", "kind": "message", "title": "\(title)"}
        """
    return try JSONDecoder().decode(Card.self, from: Data(json.utf8))
}

@Test func encodeThenDecodeReturnsSameCard() throws {
    let card = try makeCard()
    let context = try CardContext.encode(card)
    #expect(context.count == 1)
    let data = try #require(context[CardContext.key] as? Data)
    #expect(try JSONDecoder().decode(Card.self, from: data) == card)
    #expect(CardContext.decode(context) == card)
}

@Test func decodeRejectsEmptyContext() {
    #expect(CardContext.decode([:]) == nil)
}

@Test func decodeRejectsWrongType() {
    #expect(CardContext.decode([CardContext.key: "text"]) == nil)
}

@Test func decodeRejectsCorruptData() {
    #expect(CardContext.decode([CardContext.key: Data([0x00])]) == nil)
}

@Test func encodeClearIsRecognizedAsClear() {
    let context = CardContext.encodeClear()
    #expect(context.count == 1)
    #expect(context[CardContext.clearKey] as? Bool == true)
    #expect(CardContext.isClear(context))
}

@Test func encodeClearDoesNotDecodeAsCard() {
    #expect(CardContext.decode(CardContext.encodeClear()) == nil)
}

@Test func isClearIsFalseForCardContext() throws {
    let card = try makeCard()
    #expect(!CardContext.isClear(try CardContext.encode(card)))
}

@Test func isClearIsFalseForEmptyContext() {
    #expect(!CardContext.isClear([:]))
}

@Test func isClearIsFalseForFalseValue() {
    #expect(!CardContext.isClear([CardContext.clearKey: false]))
}

@Test func isClearIsFalseForNonBoolValue() {
    #expect(!CardContext.isClear([CardContext.clearKey: "yes"]))
}

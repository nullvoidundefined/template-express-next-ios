import AppCore
import Foundation
import Testing

private func loadFixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Test func decodesUserFixture() throws {
    let user = try JSONDecoder().decode(User.self, from: loadFixture("user"))
    #expect(user.email == "ada@example.com")
    #expect(user.role == .user)
    #expect(user.updatedAt == nil)
}

@Test func decodesCardFixture() throws {
    let card = try JSONDecoder().decode(Card.self, from: loadFixture("card"))
    #expect(card.kind == .message)
    #expect(!card.body.isEmpty)
    #expect(card.title == "Message")
}

@Test func rejectsUnknownCardKind() throws {
    let raw = try #require(String(data: loadFixture("card"), encoding: .utf8))
    let mutated = raw.replacingOccurrences(of: "\"kind\": \"message\"", with: "\"kind\": \"other\"")
    #expect(mutated != raw)
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(Card.self, from: Data(mutated.utf8))
    }
}

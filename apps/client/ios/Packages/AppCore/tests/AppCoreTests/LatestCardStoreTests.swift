import AppCore
import Foundation
import Testing

private func makeCard(id: String, title: String) throws -> Card {
    let json = """
        {"body": "Body of \(id)", "createdAt": "2026-11-20T10:00:00.000Z", \
        "id": "\(id)", "kind": "prompt", "title": "\(title)"}
        """
    return try JSONDecoder().decode(Card.self, from: Data(json.utf8))
}

private func withSuite(_ body: (UserDefaults, String) async throws -> Void) async throws {
    let name = UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    try await body(defaults, name)
}

@MainActor @Test func storeStartsEmpty() async throws {
    try await withSuite { defaults, _ in
        #expect(LatestCardStore(defaults: defaults).card == nil)
    }
}

@MainActor @Test func storeReceivesValidContext() async throws {
    try await withSuite { defaults, _ in
        let card = try makeCard(id: "a", title: "First")
        let store = LatestCardStore(defaults: defaults)
        store.receive(context: try CardContext.encode(card))
        #expect(store.card == card)
    }
}

@MainActor @Test func storeKeepsLatestCardAcrossInstances() async throws {
    try await withSuite { defaults, _ in
        let card = try makeCard(id: "a", title: "First")
        let first = LatestCardStore(defaults: defaults)
        first.receive(context: try CardContext.encode(card))
        let second = LatestCardStore(defaults: defaults)
        #expect(second.card == card)
    }
}

@MainActor @Test func storeReplacesCardWithNewer() async throws {
    try await withSuite { defaults, _ in
        let older = try makeCard(id: "a", title: "First")
        let newer = try makeCard(id: "b", title: "Second")
        let store = LatestCardStore(defaults: defaults)
        store.receive(context: try CardContext.encode(older))
        store.receive(context: try CardContext.encode(newer))
        #expect(store.card == newer)
        #expect(LatestCardStore(defaults: defaults).card == newer)
    }
}

@MainActor @Test func storeIgnoresInvalidContextAndKeepsPreviousCard() async throws {
    try await withSuite { defaults, _ in
        let card = try makeCard(id: "a", title: "First")
        let store = LatestCardStore(defaults: defaults)
        store.receive(context: try CardContext.encode(card))
        store.receive(context: [:])
        store.receive(context: [CardContext.key: "text"])
        store.receive(context: [CardContext.key: Data([0x00])])
        #expect(store.card == card)
        #expect(LatestCardStore(defaults: defaults).card == card)
    }
}

@MainActor @Test func storeIgnoresInvalidContextWhenEmpty() async throws {
    try await withSuite { defaults, _ in
        let store = LatestCardStore(defaults: defaults)
        store.receive(context: [CardContext.key: Data([0x00])])
        #expect(store.card == nil)
        #expect(LatestCardStore(defaults: defaults).card == nil)
    }
}

@MainActor @Test func storeWithCorruptSavedDataStartsEmpty() async throws {
    try await withSuite { defaults, name in
        let card = try makeCard(id: "a", title: "First")
        LatestCardStore(defaults: defaults).receive(context: try CardContext.encode(card))
        // Corrupt whatever the store saved, without naming its key.
        let saved = try #require(defaults.persistentDomain(forName: name))
        #expect(!saved.isEmpty)
        for key in saved.keys { defaults.set(Data([0x00]), forKey: key) }
        #expect(LatestCardStore(defaults: defaults).card == nil)
    }
}

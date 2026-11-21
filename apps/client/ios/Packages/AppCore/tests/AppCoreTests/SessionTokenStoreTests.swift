import AppCore
import Foundation
import Testing

enum StoreKind: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case inMemory
    case keychain

    var testDescription: String { rawValue }

    func makeStore() -> SessionTokenStore {
        switch self {
        case .inMemory: InMemorySessionTokenStore()
        case .keychain: KeychainSessionTokenStore(service: "AppCoreTests-\(UUID())")
        }
    }
}

@Test(arguments: StoreKind.allCases)
func readIsNilWhenEmpty(kind: StoreKind) throws {
    let store = kind.makeStore()
    defer { try? store.clear() }
    #expect(try store.read() == nil)
}

@Test(arguments: StoreKind.allCases)
func saveThenReadReturnsToken(kind: StoreKind) throws {
    let store = kind.makeStore()
    defer { try? store.clear() }
    let token = UUID().uuidString
    try store.save(token)
    #expect(try store.read() == token)
}

@Test(arguments: StoreKind.allCases)
func saveTwiceReturnsSecondToken(kind: StoreKind) throws {
    let store = kind.makeStore()
    defer { try? store.clear() }
    let first = UUID().uuidString
    let second = UUID().uuidString
    try store.save(first)
    try store.save(second)
    #expect(try store.read() == second)
}

@Test(arguments: StoreKind.allCases)
func clearThenReadIsNil(kind: StoreKind) throws {
    let store = kind.makeStore()
    defer { try? store.clear() }
    try store.save(UUID().uuidString)
    try store.clear()
    #expect(try store.read() == nil)
}

@Test(arguments: StoreKind.allCases)
func clearWhenEmptyDoesNotThrow(kind: StoreKind) throws {
    let store = kind.makeStore()
    try store.clear()
    try store.clear()
}

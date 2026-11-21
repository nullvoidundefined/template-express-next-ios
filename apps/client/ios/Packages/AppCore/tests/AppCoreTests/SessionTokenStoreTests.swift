import AppCore
import Foundation
import Security
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

@Test func keychainItemUsesExpectedAccountAndService() throws {
    let service = "AppCoreTests-\(UUID())"
    let store = KeychainSessionTokenStore(service: service)
    defer { try? store.clear() }
    try store.save(UUID().uuidString)

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecReturnAttributes as String: true,
    ]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    #expect(status == errSecSuccess)
    let attributes = try #require(result as? [String: Any])
    #expect(attributes[kSecAttrAccount as String] as? String == "session-token")
    #expect(attributes[kSecAttrService as String] as? String == service)
    // The accessibility level cannot be read back under an unsigned macOS test host,
    // so it is not asserted here.
}

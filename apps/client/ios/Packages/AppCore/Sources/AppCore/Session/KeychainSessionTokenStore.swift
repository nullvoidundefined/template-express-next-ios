import Foundation
import Security

public struct KeychainError: Error, Equatable {
    public let status: OSStatus
}

public struct KeychainSessionTokenStore: SessionTokenStore {
    private static let account = "session-token"

    private let service: String

    public init(service: String) {
        self.service = service
    }

    public func clear() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    public func read() throws -> String? {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError(status: status)
        }
        return String(data: data, encoding: .utf8)
    }

    public func save(_ token: String) throws {
        let data = Data(token.utf8)
        let update = SecItemUpdate(
            baseQuery() as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw KeychainError(status: update) }

        var attributes = baseQuery()
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        attributes[kSecValueData as String] = data
        let add = SecItemAdd(attributes as CFDictionary, nil)
        guard add == errSecSuccess else { throw KeychainError(status: add) }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecAttrAccount as String: Self.account,
            kSecAttrService as String: service,
            kSecClass as String: kSecClassGenericPassword,
        ]
    }
}

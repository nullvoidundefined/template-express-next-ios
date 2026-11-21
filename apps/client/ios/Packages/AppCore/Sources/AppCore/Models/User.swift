import Foundation

// Mirrors packages/types/src/userTypes.ts.
public enum UserRole: String, Codable, Sendable {
    case admin
    case user
}

public struct User: Codable, Equatable, Sendable {
    public let createdAt: String
    public let email: String
    public let id: String
    public let role: UserRole
    public let updatedAt: String?
}

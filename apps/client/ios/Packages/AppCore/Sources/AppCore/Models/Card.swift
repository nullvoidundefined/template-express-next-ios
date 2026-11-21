import Foundation

// Mirrors packages/types/src/cardTypes.ts.
public enum CardKind: String, Codable, Sendable {
    case message
    case prompt
}

public struct Card: Codable, Equatable, Identifiable, Sendable {
    public let body: String
    public let createdAt: String
    public let id: String
    public let kind: CardKind
    public let title: String
}

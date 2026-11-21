import Foundation

// Matches the card shape the demo cards endpoint will return:
// { body, createdAt, id, kind, title }, with kind "message" or "prompt".
// packages/types/src/cardTypes.ts is added with that endpoint and must stay in step with this file.
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

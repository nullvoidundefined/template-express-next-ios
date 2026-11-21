public protocol SessionTokenStore: Sendable {
    func clear() throws
    func read() throws -> String?
    func save(_ token: String) throws
}

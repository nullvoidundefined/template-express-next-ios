public protocol APIClient: Sendable {
    func createDemoCard(kind: CardKind) async throws -> Card
    func fetchCurrentUser() async throws -> User
    func login(email: String, password: String) async throws -> User
    func logout() async throws
    func register(email: String, password: String) async throws -> User
}

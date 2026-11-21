#if DEBUG
    import AppCore
    import Foundation

    /// Canned responses for UI tests. Compiled in Debug builds only.
    struct StubAPIClient: APIClient {
        func createDemoCard(kind: CardKind) async throws -> Card {
            let json: [String: String] = [
                "body": "This card comes from the UI test stub.",
                "createdAt": "2026-01-03T00:00:00.000Z",
                "id": "00000000-0000-4000-8000-000000000002",
                "kind": kind.rawValue,
                "title": "Hello from the stub",
            ]
            return try JSONDecoder().decode(Card.self, from: JSONEncoder().encode(json))
        }

        func fetchCurrentUser() async throws -> User {
            try makeUser(email: "ada@example.com")
        }

        func login(email: String, password: String) async throws -> User {
            try makeUser(email: email)
        }

        func logout() async throws {}

        func register(email: String, password: String) async throws -> User {
            try makeUser(email: email)
        }

        private func makeUser(email: String) throws -> User {
            let json: [String: String] = [
                "createdAt": "2026-01-01T00:00:00.000Z",
                "email": email,
                "id": "00000000-0000-4000-8000-000000000001",
                "role": "user",
                "updatedAt": "2026-01-01T00:00:00.000Z",
            ]
            return try JSONDecoder().decode(User.self, from: JSONEncoder().encode(json))
        }
    }

    /// A Watch link for UI tests, so they never depend on WatchConnectivity.
    struct UnavailableWatchLink: WatchLink {
        func send(_ card: Card) -> WatchDelivery { .unavailable }
    }
#endif

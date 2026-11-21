import Synchronization

public final class InMemorySessionTokenStore: SessionTokenStore {
    private let token = Mutex<String?>(nil)

    public init() {}

    public func clear() throws {
        token.withLock { $0 = nil }
    }

    public func read() throws -> String? {
        token.withLock { $0 }
    }

    public func save(_ token: String) throws {
        self.token.withLock { $0 = token }
    }
}

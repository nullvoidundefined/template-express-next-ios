import Foundation

struct RecordedRequest: Sendable {
    let body: Data?
    let headers: [String: String]
    let method: String
    let url: URL

    func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}

/// A URLProtocol that serves canned responses. Each test builds its own `StubSession`, which owns a
/// unique host name; the protocol routes by host, so tests can run in parallel without sharing state.
final class StubURLProtocol: URLProtocol {
    enum Outcome: Sendable {
        case failure(URLError)
        case response(status: Int, headers: [String: String], body: Data)
    }

    private final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var outcomes: [String: Outcome] = [:]
        private var requests: [String: [RecordedRequest]] = [:]

        func outcome(for host: String) -> Outcome? {
            lock.withLock { outcomes[host] }
        }

        func record(_ request: RecordedRequest, for host: String) {
            lock.withLock { requests[host, default: []].append(request) }
        }

        func recorded(for host: String) -> [RecordedRequest] {
            lock.withLock { requests[host] ?? [] }
        }

        func set(_ outcome: Outcome, for host: String) {
            lock.withLock { outcomes[host] = outcome }
        }
    }

    private static let registry = Registry()

    static func makeStubSession() -> StubSession {
        StubSession(host: "\(UUID().uuidString.lowercased()).stub.test")
    }

    struct StubSession: Sendable {
        let host: String

        var baseURL: URL { URL(string: "https://\(host)")! }

        var lastRequest: RecordedRequest? { StubURLProtocol.registry.recorded(for: host).last }

        var session: URLSession {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [StubURLProtocol.self]
            return URLSession(configuration: configuration)
        }

        func fail(with error: URLError) {
            StubURLProtocol.registry.set(.failure(error), for: host)
        }

        func respond(status: Int, headers: [String: String] = [:], body: Data = Data()) {
            let outcome = Outcome.response(status: status, headers: headers, body: body)
            StubURLProtocol.registry.set(outcome, for: host)
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        Self.registry.record(
            RecordedRequest(
                body: Self.readBody(request),
                headers: request.allHTTPHeaderFields ?? [:],
                method: request.httpMethod ?? "GET",
                url: url
            ),
            for: host
        )
        switch Self.registry.outcome(for: host) {
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .response(let status, let headers, let body):
            let response = HTTPURLResponse(
                url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)
            guard let response else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
        }
    }

    override func stopLoading() {}

    private static func readBody(_ request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

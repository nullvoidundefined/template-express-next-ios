public enum APIError: Error, Equatable {
    case decoding
    case network
    case server(code: String, message: String, status: Int)
    case unauthorized
}

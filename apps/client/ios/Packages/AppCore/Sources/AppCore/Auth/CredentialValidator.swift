// Matches apps/server's authSchema.ts.
public enum CredentialValidator {
    public static func loginError(email: String, password: String) -> String? {
        if let message = emailError(email) { return message }
        return password.isEmpty ? "Password is required" : nil
    }

    public static func registerError(email: String, password: String) -> String? {
        if let message = emailError(email) { return message }
        // The server counts UTF-16 code units, like JavaScript string length.
        let length = password.utf16.count
        if length < 8 { return "Password must be at least 8 characters" }
        if length > 72 { return "Password must be at most 72 characters" }
        return nil
    }

    private static func emailError(_ email: String) -> String? {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !email.contains(where: \.isWhitespace) else {
            return "Invalid email"
        }
        let domain = parts[1]
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty }) else { return "Invalid email" }
        return nil
    }
}

import AppCore
import Testing

private func password(length: Int) -> String {
    String(repeating: "a", count: length)
}

@Test func validRegisterPairHasNoError() {
    #expect(CredentialValidator.registerError(email: "ada@example.com", password: password(length: 8)) == nil)
    #expect(CredentialValidator.registerError(email: "ada@example.com", password: password(length: 72)) == nil)
}

@Test func validLoginPairHasNoError() {
    #expect(CredentialValidator.loginError(email: "ada@example.com", password: password(length: 1)) == nil)
}

@Test(arguments: ["", "plain", "@example.com", "ada@", "ada@example"])
func malformedEmailIsInvalidForLoginAndRegister(email: String) {
    #expect(CredentialValidator.loginError(email: email, password: password(length: 10)) == "Invalid email")
    #expect(CredentialValidator.registerError(email: email, password: password(length: 10)) == "Invalid email")
}

@Test func registerPasswordUnderEightCharactersIsTooShort() {
    #expect(
        CredentialValidator.registerError(email: "ada@example.com", password: password(length: 7))
            == "Password must be at least 8 characters"
    )
    #expect(
        CredentialValidator.registerError(email: "ada@example.com", password: "")
            == "Password must be at least 8 characters"
    )
}

@Test func registerPasswordOf73CharactersIsTooLong() {
    #expect(
        CredentialValidator.registerError(email: "ada@example.com", password: password(length: 73))
            == "Password must be at most 72 characters"
    )
}

@Test func loginEmptyPasswordIsRequired() {
    #expect(CredentialValidator.loginError(email: "ada@example.com", password: "") == "Password is required")
}

@Test func loginDoesNotApplyRegisterLengthRules() {
    #expect(CredentialValidator.loginError(email: "ada@example.com", password: password(length: 3)) == nil)
    #expect(CredentialValidator.loginError(email: "ada@example.com", password: password(length: 73)) == nil)
}

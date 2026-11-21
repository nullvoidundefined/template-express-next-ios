import AppCore
import SwiftUI

struct RegisterView: View {
    let viewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var validationError: String?

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("register-email-field")
                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                    .accessibilityIdentifier("register-password-field")
            }
            if let message = validationError ?? viewModel.errorMessage {
                Section {
                    Text(message)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("register-error")
                }
            }
            Section {
                Button("Create account", action: submit)
                    .disabled(viewModel.isSubmitting)
                    .accessibilityIdentifier("register-submit-button")
            }
        }
        .navigationTitle("Create account")
    }

    private func submit() {
        validationError = CredentialValidator.registerError(email: email, password: password)
        guard validationError == nil else { return }
        Task { await viewModel.register(email: email, password: password) }
    }
}

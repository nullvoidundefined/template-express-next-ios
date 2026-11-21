import AppCore
import SwiftUI

struct LoginView: View {
    let viewModel: AuthViewModel
    let notice: String?

    @State private var email = ""
    @State private var password = ""
    @State private var validationError: String?

    var body: some View {
        Form {
            if let notice {
                Section {
                    Text(notice)
                        .accessibilityIdentifier("login-notice")
                }
            }
            Section {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("login-email-field")
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .accessibilityIdentifier("login-password-field")
            }
            if let message = validationError ?? viewModel.errorMessage {
                Section {
                    Text(message)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("login-error")
                }
            }
            Section {
                Button("Log in", action: submit)
                    .disabled(viewModel.isSubmitting)
                    .accessibilityIdentifier("login-submit-button")
                NavigationLink("Create an account") {
                    RegisterView(viewModel: viewModel)
                }
                .accessibilityIdentifier("login-register-link")
            }
        }
        .navigationTitle("Log in")
    }

    private func submit() {
        validationError = CredentialValidator.loginError(email: email, password: password)
        guard validationError == nil else { return }
        Task { await viewModel.login(email: email, password: password) }
    }
}

import AppCore
import SwiftUI

struct HomeView: View {
    let authViewModel: AuthViewModel
    let email: String
    @State private var viewModel: HomeViewModel

    init(authViewModel: AuthViewModel, email: String, makeViewModel: () -> HomeViewModel) {
        self.authViewModel = authViewModel
        self.email = email
        _viewModel = State(initialValue: makeViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Signed in as \(email)")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home-email")
                Button("Send message") {
                    Task { await viewModel.send(kind: .message) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSending)
                .accessibilityIdentifier("home-send-message-button")
                Button("Send prompt card") {
                    Task { await viewModel.send(kind: .prompt) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSending)
                .accessibilityIdentifier("home-send-prompt-button")
                if let card = viewModel.lastCard {
                    CardView(card: card)
                        .accessibilityIdentifier("home-last-card")
                }
                if let delivery = viewModel.lastDelivery {
                    Text(Self.statusText(for: delivery))
                        .font(.footnote)
                        .accessibilityIdentifier("home-watch-status")
                }
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("home-error")
                }
                Button("Log out") {
                    Task { await authViewModel.logout() }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("home-logout-button")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private static func statusText(for delivery: WatchDelivery) -> String {
        switch delivery {
        case .sent: "Sent to Apple Watch"
        case .unavailable: "No Apple Watch available. The card is shown here only."
        }
    }
}

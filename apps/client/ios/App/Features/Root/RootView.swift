import AppCore
import SwiftUI

struct RootView: View {
    let viewModel: AuthViewModel

    var body: some View {
        content
            .task { await viewModel.restore() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .checking:
            ProgressView("Loading")
        case .signedIn(let user):
            VStack(spacing: 16) {
                Text("Signed in as \(user.email)")
                    .font(.headline)
                Button("Log out") {
                    Task { await viewModel.logout() }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("home-logout-button")
            }
            .padding()
        case .signedOut(let notice):
            NavigationStack {
                LoginView(viewModel: viewModel, notice: notice)
            }
        case .unreachable:
            UnreachableView(viewModel: viewModel)
        }
    }
}

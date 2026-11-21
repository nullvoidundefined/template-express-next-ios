import AppCore
import SwiftUI

struct RootView: View {
    let makeHomeViewModel: () -> HomeViewModel
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
            HomeView(authViewModel: viewModel, email: user.email, makeViewModel: makeHomeViewModel)
        case .signedOut(let notice):
            NavigationStack {
                LoginView(viewModel: viewModel, notice: notice)
            }
        case .unreachable:
            UnreachableView(viewModel: viewModel)
        }
    }
}

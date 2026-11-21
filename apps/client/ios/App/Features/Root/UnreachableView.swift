import AppCore
import SwiftUI

struct UnreachableView: View {
    let viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Can't reach the server. Check your connection.")
                .font(.headline)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.restore() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("unreachable-retry-button")
        }
        .padding()
    }
}

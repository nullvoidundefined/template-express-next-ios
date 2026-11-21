import AppCore
import SwiftUI

@main
struct TemplateApp: App {
    @State private var environment = AppEnvironment.make()

    var body: some Scene {
        WindowGroup {
            RootView(
                makeHomeViewModel: environment.makeHomeViewModel,
                viewModel: environment.authViewModel
            )
            .tint(.appTint)
        }
    }
}

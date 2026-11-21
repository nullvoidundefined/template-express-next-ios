import AppCore
import SwiftUI

@main
struct TemplateApp: App {
    @State private var authViewModel = AppEnvironment.makeAuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: authViewModel)
                .tint(.appTint)
        }
    }
}

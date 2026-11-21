import AppCore
import SwiftUI

@main
struct TemplateWatchApp: App {
    @State private var store: LatestCardStore
    @State private var receiver: WatchContextReceiver

    init() {
        let store = LatestCardStore(defaults: .standard)
        _store = State(initialValue: store)
        _receiver = State(initialValue: WatchContextReceiver(store: store))
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView(store: store)
        }
    }
}

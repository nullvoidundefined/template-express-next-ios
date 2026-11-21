import AppCore
import SwiftUI

struct WatchRootView: View {
    let store: LatestCardStore

    var body: some View {
        if let card = store.card {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.title)
                        .font(.headline)
                        .accessibilityIdentifier("watch-card-title")
                    Text(card.body)
                        .font(.body)
                        .accessibilityIdentifier("watch-card-body")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text("Hello, world")
                .accessibilityIdentifier("watch-hello")
        }
    }
}

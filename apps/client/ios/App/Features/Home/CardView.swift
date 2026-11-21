import AppCore
import SwiftUI

struct CardView: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.title)
                .font(.headline)
            Text(card.body)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.title), \(card.body)")
    }
}

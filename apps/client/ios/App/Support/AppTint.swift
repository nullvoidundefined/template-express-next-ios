import SwiftUI
import UIKit

extension Color {
    // The default system blue is 4.0:1 on white, under the 4.5:1 WCAG 2.1 AA text minimum.
    static let appTint = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.4, green: 0.67, blue: 1.0, alpha: 1)
                : UIColor(red: 0.0, green: 0.3, blue: 0.72, alpha: 1)
        })
}

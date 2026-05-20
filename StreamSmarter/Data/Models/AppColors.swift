import SwiftUI

extension Color {
    static let brandBlue = Color(red: 0.0, green: 0.55, blue: 0.85)
    static let accentYellow = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let retroGray = Color(white: 0.12)
    static let lightGreen = Color(red: 0.8, green: 1.0, blue: 0.8)
    static let darkGray = Color(white: 0.3)
    static let lightGray = Color.gray // Used for providers text
    static let solidGreen = Color(red: 0.18, green: 0.49, blue: 0.2) // #2E7D32
    static let popcornYellow = Color(red: 0.945, green: 0.769, blue: 0.059) // #F1C40F sync with Android
    
    // MARK: - Retro TV Theme Sync (from Android Color.kt)
    static let retroTVDark = Color(red: 0.071, green: 0.071, blue: 0.071) // #121212
    static let retroTVGray = Color(red: 0.173, green: 0.173, blue: 0.173) // #2C2C2C
    static let curtainRed = Color(red: 0.753, green: 0.224, blue: 0.169) // #C0392B
    static let channelActive = Color(red: 0.0, green: 1.0, blue: 0.255) // #00FF41
    static let screenGlow = Color(red: 0.204, green: 0.604, blue: 0.859) // #3498DB
    static let mutedAvailableGreen = Color(red: 0.106, green: 0.18, blue: 0.106) // #1B2E1B
    static let mutedUnavailableYellow = Color(red: 0.2, green: 0.184, blue: 0.102) // #332F1A
    static let mutedWatchedGray = Color(red: 0.133, green: 0.133, blue: 0.133) // #222222
}
import SwiftUI
import UIKit

extension Color {
    static let ssBackground = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? 
            UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 1) : // #121212 (RetroTVDark)
            UIColor(red: 253/255, green: 253/255, blue: 253/255, alpha: 1) // #FDFDFD (RetroTVWhite)
    })
    
    static let ssSurface = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? 
            UIColor(red: 44/255, green: 44/255, blue: 44/255, alpha: 1) : // #2C2C2C (RetroTVGray)
            UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1) // #F0F0F0 (RetroTVLightSurface)
    })
    
    static let ssText = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? .white : UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 1)
    })
    
    static let ssPrimary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? 
            UIColor(red: 241/255, green: 196/255, blue: 15/255, alpha: 1) : // #F1C40F (PopcornYellow)
            UIColor(red: 183/255, green: 149/255, blue: 11/255, alpha: 1) // #B7950B (PopcornYellowDark)
    })
    
    static let ssSecondary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? 
            UIColor(red: 52/255, green: 152/255, blue: 219/255, alpha: 1) : // #3498DB (ScreenGlow)
            UIColor(red: 41/255, green: 128/255, blue: 185/255, alpha: 1) // #2980B9 (ScreenGlowDark)
    })
    
    static let ssTertiary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? 
            UIColor(red: 192/255, green: 57/255, blue: 43/255, alpha: 1) : // #C0392B (CurtainRed)
            UIColor(red: 169/255, green: 50/255, blue: 38/255, alpha: 1) // #A93226 (CurtainRedDark)
    })

    static let ssMutedAvailable = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 27/255, green: 46/255, blue: 27/255, alpha: 1) : UIColor(red: 232/255, green: 245/255, blue: 233/255, alpha: 1)
    })
    static let ssMutedUnavailable = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 51/255, green: 47/255, blue: 26/255, alpha: 1) : UIColor(red: 255/255, green: 249/255, blue: 196/255, alpha: 1)
    })
    static let ssMutedWatched = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 34/255, green: 34/255, blue: 34/255, alpha: 1) : UIColor(red: 224/255, green: 224/255, blue: 224/255, alpha: 1)
    })

    static let ssInactiveRed = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ?
            UIColor(red: 255/255, green: 204/255, blue: 203/255, alpha: 1) : // Light pink for dark bg
            UIColor(red: 139/255, green: 0/255, blue: 0/255, alpha: 1)       // Dark red for light bg
    })
}
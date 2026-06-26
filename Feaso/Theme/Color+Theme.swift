import SwiftUI
import UIKit

extension Color {
    enum Theme {
        // MARK: - Backgrounds
        static let background = Color(dynamicLight: 0xF1EFE8, dark: 0x1C1C1E)
        static let surface = Color(dynamicLight: 0xFFFFFF, dark: 0x2C2C2E)
        static let surface2 = Color(dynamicLight: 0xF7F6F1, dark: 0x3A3A3C)
        
        // MARK: - Borders
        static let border = Color(dynamicLight: 0xE3E0D6, dark: 0x3A3A3C)
        static let border2 = Color(dynamicLight: 0xD0CCBF, dark: 0x48484A)
        
        // MARK: - Text (Ink)
        static let ink = Color(dynamicLight: 0x1F1F1D, dark: 0xFFFFFF)
        static let ink2 = Color(dynamicLight: 0x5A5851, dark: 0xAEAEB2)
        static let ink3 = Color(dynamicLight: 0x8A877E, dark: 0x8E8E93)
        
        // MARK: - Accent
        static let accent = Color(dynamicLight: 0x2C5F8D, dark: 0x5A9BD5)
        static let accentBg = Color(dynamicLight: 0xE8EFF5, dark: 0x1E3A50)
        
        // MARK: - Success
        static let success = Color(dynamicLight: 0x2D7A4C, dark: 0x4CAF7A)
        static let successBg = Color(dynamicLight: 0xE8F3EB, dark: 0x1E3A2A)
        
        // MARK: - Warning
        static let warning = Color(dynamicLight: 0x9A6618, dark: 0xD4A03A)
        static let warningBg = Color(dynamicLight: 0xFAF0DB, dark: 0x3A3018)
        
        // MARK: - Danger
        static let danger = Color(dynamicLight: 0xA32D2D, dark: 0xE05555)
        static let dangerBg = Color(dynamicLight: 0xFBEAEA, dark: 0x3A1E1E)
    }
    
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
    
    init(dynamicLight: UInt32, dark: UInt32) {
        self.init(UIColor { traitCollection in
            let hex = traitCollection.userInterfaceStyle == .dark ? dark : dynamicLight
            let r = CGFloat((hex >> 16) & 0xFF) / 255.0
            let g = CGFloat((hex >> 8) & 0xFF) / 255.0
            let b = CGFloat(hex & 0xFF) / 255.0
            return UIColor(red: r, green: g, blue: b, alpha: 1.0)
        })
    }
}

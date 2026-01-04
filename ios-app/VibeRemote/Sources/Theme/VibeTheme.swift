import SwiftUI
import UIKit

// MARK: - Design System

/// VibeRemote Design System
/// Inspired by ChatGPT's clean, minimal aesthetic with Apple's design language
enum VibeTheme {
    
    // MARK: - Colors
    
    enum Colors {
        // Background layers (dark mode first)
        static let background = Color("Background", bundle: nil)
        static let surface = Color("Surface", bundle: nil)
        static let surfaceElevated = Color("SurfaceElevated", bundle: nil)
        
        // Text hierarchy
        static let textPrimary = Color("TextPrimary", bundle: nil)
        static let textSecondary = Color("TextSecondary", bundle: nil)
        static let textTertiary = Color("TextTertiary", bundle: nil)
        
        // Accent colors
        static let accent = Color("Accent", bundle: nil)
        static let accentSubtle = Color("AccentSubtle", bundle: nil)
        
        // Semantic colors
        static let success = Color("Success", bundle: nil)
        static let warning = Color("Warning", bundle: nil)
        static let error = Color("Error", bundle: nil)
        
        // Code block colors
        static let codeBackground = Color("CodeBackground", bundle: nil)
        static let codeBorder = Color("CodeBorder", bundle: nil)
        
        // Fallback colors (when asset catalog not available)
        enum Fallback {
            static let background = Color(light: .white, dark: Color(hex: "212121"))
            static let surface = Color(light: Color(hex: "F7F7F8"), dark: Color(hex: "2F2F2F"))
            static let surfaceElevated = Color(light: .white, dark: Color(hex: "3A3A3A"))
            
            static let textPrimary = Color(light: Color(hex: "1A1A1A"), dark: Color(hex: "ECECEC"))
            static let textSecondary = Color(light: Color(hex: "6B6B6B"), dark: Color(hex: "9A9A9A"))
            static let textTertiary = Color(light: Color(hex: "999999"), dark: Color(hex: "666666"))
            
            static let accent = Color(light: Color(hex: "0A84FF"), dark: Color(hex: "0A84FF"))
            static let accentSubtle = Color(light: Color(hex: "E8F4FF"), dark: Color(hex: "1A3A5C"))
            
            static let success = Color(hex: "34C759")
            static let warning = Color(hex: "FF9500")
            static let error = Color(hex: "FF3B30")
            
            static let codeBackground = Color(light: Color(hex: "F6F6F6"), dark: Color(hex: "1E1E1E"))
            static let codeBorder = Color(light: Color(hex: "E5E5E5"), dark: Color(hex: "3A3A3A"))
        }
    }
    
    // MARK: - Typography
    
    enum Typography {
        // Display
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 22, weight: .bold, design: .default)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
        
        // Body
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 17, weight: .medium, design: .default)
        static let bodySemibold = Font.system(size: 17, weight: .semibold, design: .default)
        
        // Supporting
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
        
        // Code
        static let code = Font.system(size: 14, weight: .regular, design: .monospaced)
        static let codeSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
        
        // Message-specific
        static let messageBody = Font.system(size: 16, weight: .regular, design: .default)
        static let userMessage = Font.system(size: 16, weight: .medium, design: .default)
        static let timestamp = Font.system(size: 11, weight: .regular, design: .default)
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
        
        // Content width
        static let maxContentWidth: CGFloat = 720
        static let sidebarWidth: CGFloat = 280
    }
    
    // MARK: - Corner Radius
    
    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let pill: CGFloat = 999
    }
    
    // MARK: - Shadows
    
    enum Shadow {
        static let subtle = ShadowStyle(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        static let small = ShadowStyle(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        static let medium = ShadowStyle(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        static let large = ShadowStyle(color: .black.opacity(0.16), radius: 16, x: 0, y: 8)
        
        // Input bar glow
        static let inputGlow = ShadowStyle(color: Color(hex: "0A84FF").opacity(0.2), radius: 8, x: 0, y: 0)
    }
    
    // MARK: - Animation
    
    enum Animation {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.35)
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.7)
        static let springBouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }
    
    // MARK: - Icons
    
    enum Icons {
        static let send = "arrow.up"
        static let stop = "stop.fill"
        static let plus = "plus"
        static let microphone = "mic"
        static let settings = "gearshape"
        static let sidebar = "sidebar.left"
        static let newChat = "square.and.pencil"
        static let search = "magnifyingglass"
        static let chevronDown = "chevron.down"
        static let chevronRight = "chevron.right"
        static let copy = "doc.on.doc"
        static let check = "checkmark"
        static let user = "person.circle"
        
        // Tool icons
        static let fileRead = "doc.text"
        static let fileWrite = "pencil"
        static let terminal = "terminal"
        static let folder = "folder"
        static let globe = "globe"
        static let tool = "wrench.and.screwdriver"
    }
}

// MARK: - Shadow Style

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions

extension View {
    func vibeShadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
    
    func vibeBackground(_ color: Color = VibeTheme.Colors.Fallback.surface) -> some View {
        self.background(color)
    }
    
    func maxContentWidth() -> some View {
        self.frame(maxWidth: VibeTheme.Spacing.maxContentWidth)
    }
}

// MARK: - Color Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - Semantic Color Accessors

extension VibeTheme.Colors {
    /// Safe color accessor that falls back to programmatic colors
    static var bg: Color { Fallback.background }
    static var fg: Color { Fallback.textPrimary }
    static var fgSecondary: Color { Fallback.textSecondary }
    static var fgTertiary: Color { Fallback.textTertiary }
    static var surfacePrimary: Color { Fallback.surface }
    static var surfaceSecondary: Color { Fallback.surfaceElevated }
    static var tint: Color { Fallback.accent }
    static var tintSubtle: Color { Fallback.accentSubtle }
    static var code: Color { Fallback.codeBackground }
    static var codeLine: Color { Fallback.codeBorder }
}

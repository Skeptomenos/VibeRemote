import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// OpenCode's official dark theme colors
/// Source: https://github.com/sst/opencode/blob/dev/packages/opencode/src/cli/cmd/tui/context/theme/opencode.json
enum OpenCodeTheme {
    // MARK: - Background Colors
    
    /// Primary background - nearly pure black (#0a0a0a)
    static let background = Color(hex: 0x0a0a0a)
    
    /// Panel/card background (#141414)
    static let backgroundPanel = Color(hex: 0x141414)
    
    /// Element background - buttons, inputs (#1e1e1e)
    static let backgroundElement = Color(hex: 0x1e1e1e)
    
    /// Elevated surface (#282828)
    static let backgroundElevated = Color(hex: 0x282828)
    
    // MARK: - Text Colors
    
    /// Primary text - off-white (#eeeeee)
    static let text = Color(hex: 0xeeeeee)
    
    /// Secondary/muted text (#808080)
    static let textMuted = Color(hex: 0x808080)
    
    /// Subtle text (#606060)
    static let textSubtle = Color(hex: 0x606060)
    
    // MARK: - Accent Colors
    
    /// Primary accent - warm orange/peach (#fab283)
    static let primary = Color(hex: 0xfab283)
    
    /// Secondary accent - blue (#5c9cf5)
    static let secondary = Color(hex: 0x5c9cf5)
    
    /// Tertiary accent - purple (#9d7cd8)
    static let accent = Color(hex: 0x9d7cd8)
    
    // MARK: - Semantic Colors
    
    /// Success - green (#7fd88f)
    static let success = Color(hex: 0x7fd88f)
    
    /// Error - red (#e06c75)
    static let error = Color(hex: 0xe06c75)
    
    /// Warning - orange (#f5a742)
    static let warning = Color(hex: 0xf5a742)
    
    /// Info - cyan (#56b6c2)
    static let info = Color(hex: 0x56b6c2)
    
    // MARK: - Border Colors
    
    /// Standard border (#484848)
    static let border = Color(hex: 0x484848)
    
    /// Active/focused border (#606060)
    static let borderActive = Color(hex: 0x606060)
    
    /// Subtle border (#3c3c3c)
    static let borderSubtle = Color(hex: 0x3c3c3c)
    
    // MARK: - Connection Status Colors
    
    /// Connected indicator
    static let connected = success
    
    /// Connecting indicator
    static let connecting = warning
    
    /// Disconnected indicator
    static let disconnected = textMuted
    
    /// Error indicator
    static let connectionError = error
    
    #if canImport(UIKit)
    // MARK: - UIKit Colors (for SwiftTerm)
    
    static let terminalBackground: UIColor = UIColor(
        red: 10/255,
        green: 10/255,
        blue: 10/255,
        alpha: 1.0
    )
    
    static let terminalForeground: UIColor = UIColor(
        red: 238/255,
        green: 238/255,
        blue: 238/255,
        alpha: 1.0
    )
    #endif
}

// MARK: - Color Extension

extension Color {
    /// Initialize Color from hex value
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - Glass Material Helpers

extension View {
    /// Apply OpenCode-styled glass background
    func openCodeGlass() -> some View {
        self
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
    }
    
    /// Apply OpenCode panel background
    func openCodePanel() -> some View {
        self
            .background(OpenCodeTheme.backgroundPanel)
    }
}

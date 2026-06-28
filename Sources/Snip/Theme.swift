import SwiftUI
import AppKit

/// Gruvbox dark palette, mirrored from the website tokens.
enum Gruv {
    static let bg0h = Color(hex: 0x1d2021)
    static let bg0 = Color(hex: 0x282828)
    static let bg1 = Color(hex: 0x3c3836)
    static let bg2 = Color(hex: 0x504945)
    static let bg3 = Color(hex: 0x665c54)

    static let fg0 = Color(hex: 0xfbf1c7)
    static let fg1 = Color(hex: 0xebdbb2)
    static let fg3 = Color(hex: 0xbdae93)
    static let gray = Color(hex: 0x928374)

    static let orange = Color(hex: 0xfe8019)
    static let yellow = Color(hex: 0xfabd2f)
    static let aqua = Color(hex: 0x8ec07c)
    static let green = Color(hex: 0xb8bb26)
    static let red = Color(hex: 0xfb4934)
    static let blue = Color(hex: 0x83a598)
}

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: 1
        )
    }
}

extension NSColor {
    convenience init(hex: UInt) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1
        )
    }
}

/// Gruvbox as NSColor for AppKit drawing (snippet image renderer).
enum GruvNS {
    static let bg0h = NSColor(hex: 0x1d2021)
    static let bg0 = NSColor(hex: 0x282828)
    static let bg1 = NSColor(hex: 0x3c3836)
    static let bg2 = NSColor(hex: 0x504945)
    static let fg1 = NSColor(hex: 0xebdbb2)
    static let fg3 = NSColor(hex: 0xbdae93)
    static let gray = NSColor(hex: 0x928374)
    static let orange = NSColor(hex: 0xfe8019)
    static let yellow = NSColor(hex: 0xfabd2f)
    static let aqua = NSColor(hex: 0x8ec07c)
    static let green = NSColor(hex: 0xb8bb26)
    static let red = NSColor(hex: 0xfb4934)
    static let blue = NSColor(hex: 0x83a598)
    static let purple = NSColor(hex: 0xd3869b)
    // macOS traffic-light colors
    static let tlRed = NSColor(hex: 0xff5f56)
    static let tlYellow = NSColor(hex: 0xfebc2e)
    static let tlGreen = NSColor(hex: 0x28c840)
}

/// Monospaced display font helper (JetBrains Mono not bundled; fall back to system mono).
extension Font {
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

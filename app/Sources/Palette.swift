import SwiftUI
import AppKit

struct ColorValue {
    static func normalize(_ input: String) -> String? {
        let s = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let digits = s.hasPrefix("#") ? String(s.dropFirst()) : s
        guard digits.count == 6, digits.allSatisfy({ $0.isHexDigit && $0.isASCII }) else { return nil }
        return "#" + digits
    }
    static func ns(_ hex: String) -> NSColor {
        let n = UInt32(hex.dropFirst(), radix: 16) ?? 0xFFFEFA
        return NSColor(srgbRed: CGFloat((n >> 16) & 255) / 255, green: CGFloat((n >> 8) & 255) / 255, blue: CGFloat(n & 255) / 255, alpha: 1)
    }
    static func ink(_ hex: String) -> Color {
        let c = ns(hex).usingColorSpace(.sRGB)!
        return 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent > 0.55 ? .black : .white
    }
}

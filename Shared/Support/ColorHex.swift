import SwiftUI
import UIKit

extension Color {
    /// Accepts "RRGGBB" or "RRGGBBAA", with or without a leading "#".
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        let number = UInt64(value, radix: 16) ?? 0
        let r, g, b, a: Double
        if value.count == 8 {
            r = Double((number >> 24) & 0xFF) / 255
            g = Double((number >> 16) & 0xFF) / 255
            b = Double((number >> 8) & 0xFF) / 255
            a = Double(number & 0xFF) / 255
        } else {
            r = Double((number >> 16) & 0xFF) / 255
            g = Double((number >> 8) & 0xFF) / 255
            b = Double(number & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// A color that switches with the system appearance.
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }

    var hexString: String {
        let color = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let clamp = { (v: CGFloat) in Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "%02X%02X%02X", clamp(r), clamp(g), clamp(b))
    }
}

enum ColorMath {
    /// Relative luminance of an sRGB hex color (0 = black, 1 = white).
    static func luminance(_ hex: String) -> Double {
        let color = UIColor(Color(hex: hex))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    static func isLight(_ hex: String) -> Bool {
        luminance(hex) > 0.42
    }

    /// Mixes a hex color toward black (negative amount) or white (positive amount).
    static func shade(_ hex: String, _ amount: Double) -> String {
        let color = UIColor(Color(hex: hex))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let target: CGFloat = amount >= 0 ? 1 : 0
        let t = CGFloat(min(abs(amount), 1))
        let mix = { (c: CGFloat) in c + (target - c) * t }
        let clamp = { (v: CGFloat) in Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "%02X%02X%02X", clamp(mix(r)), clamp(mix(g)), clamp(mix(b)))
    }
}

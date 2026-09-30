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

    /// The color between `from` (t = 0) and `to` (t = 1).
    static func mix(_ from: String, _ to: String, _ t: Double) -> String {
        let a = UIColor(Color(hex: from)), b = UIColor(Color(hex: to))
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let k = CGFloat(min(max(t, 0), 1))
        let clamp = { (v: CGFloat) in Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "%02X%02X%02X", clamp(r1 + (r2 - r1) * k), clamp(g1 + (g2 - g1) * k), clamp(b1 + (b2 - b1) * k))
    }

    // MARK: Recoloring a style

    /// Red, green and blue (0…1) of a "RRGGBB" hex (an alpha pair, if any, is ignored).
    static func rgb(_ hex: String) -> (r: Double, g: Double, b: Double) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        let number = UInt64(value.prefix(6), radix: 16) ?? 0
        return (Double((number >> 16) & 0xFF) / 255, Double((number >> 8) & 0xFF) / 255, Double(number & 0xFF) / 255)
    }

    static func hex(_ r: Double, _ g: Double, _ b: Double) -> String {
        let clamp = { (v: Double) in Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "%02X%02X%02X", clamp(r), clamp(g), clamp(b))
    }

    /// Hue (0…1), saturation and lightness of a hex color.
    static func hsl(_ hex: String) -> (h: Double, s: Double, l: Double) {
        let (r, g, b) = rgb(hex)
        let high = max(r, g, b), low = min(r, g, b)
        let l = (high + low) / 2
        guard high - low > 0.0001 else { return (0, 0, l) }
        let d = high - low
        let s = l > 0.5 ? d / (2 - high - low) : d / (high + low)
        var h: Double
        if high == r {
            h = (g - b) / d + (g < b ? 6 : 0)
        } else if high == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        h /= 6
        return (h, s, l)
    }

    static func fromHSL(_ h: Double, _ s: Double, _ l: Double) -> (r: Double, g: Double, b: Double) {
        guard s > 0.0001 else { return (l, l, l) }
        func channel(_ p: Double, _ q: Double, _ t0: Double) -> Double {
            var t = t0
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6 { return p + (q - p) * 6 * t }
            if t < 0.5 { return q }
            if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
            return p
        }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        return (channel(p, q, h + 1.0 / 3), channel(p, q, h), channel(p, q, h - 1.0 / 3))
    }

    /// Relative luminance computed without UIKit (same formula as `luminance`).
    static func relativeLuminance(_ r: Double, _ g: Double, _ b: Double) -> Double {
        func channel(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    /// A style's color in the hue of the main color: it keeps its brightness (so text stays readable
    /// on its background), takes the main color's hue, and grays or whites take a tint of it.
    /// `surface`: backgrounds and panels, which never stay pure white or pure black.
    static func recolor(_ hex: String, to main: String, surface: Bool = false) -> String {
        let (r, g, b) = rgb(hex)
        let original = hsl(hex)
        let target = hsl(main)
        var goal = relativeLuminance(r, g, b)
        if surface { goal = min(max(goal, 0.008), 0.8) }
        let isNeutral = original.s < 0.14 || original.l > 0.95 || original.l < 0.05
        var saturation: Double
        if isNeutral {
            // Surfaces take a clear tint, text a light one.
            let strength = surface || original.l > 0.85 || original.l < 0.15 ? 0.55 : 0.32
            saturation = target.s * strength
        } else {
            saturation = (original.s + target.s) / 2
        }
        // A gray main color gives a gray style.
        if target.s < 0.08 { saturation = target.s }
        // The lightness that gives the same brightness in the new hue.
        var low = 0.0, high = 1.0
        for _ in 0..<16 {
            let mid = (low + high) / 2
            let c = fromHSL(target.h, saturation, mid)
            if relativeLuminance(c.r, c.g, c.b) < goal { low = mid } else { high = mid }
        }
        let c = fromHSL(target.h, saturation, (low + high) / 2)
        return self.hex(c.r, c.g, c.b)
    }

    /// Colors for lines and parts of a whole (macros, categories) drawn from one main color:
    /// the color itself, then neighbouring hues and shades, all in the same family.
    static func series(from main: String, count: Int = 6) -> [String] {
        let base = hsl(main)
        let s = max(base.s, 0.35)
        let steps: [(Double, Double)] = [(0, 0), (0.08, 0.12), (-0.08, -0.1), (0.16, 0.2), (-0.14, 0.05), (0.04, -0.2)]
        return steps.prefix(count).enumerated().map { index, step in
            if index == 0 { return main.uppercased() }
            var h = base.h + step.0
            if h < 0 { h += 1 }
            if h > 1 { h -= 1 }
            let l = min(max(base.l + step.1, 0.28), 0.78)
            let c = fromHSL(h, base.s < 0.08 ? base.s : s, l)
            return hex(c.r, c.g, c.b)
        }
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

import SwiftUI

/// The one source of the Nutrition colors: the calorie ring is orange, the macros are red (proteins),
/// yellow (carbs) and blue (fats), whatever the app's accent. Nothing else in the app uses these.
enum NutritionColors {
    static let caloriesHex = "FF9500"
    static let proteinHex = "FF3B30"
    static let carbsHex = "FFCC00"
    static let fatHex = "0A84FF"

    static var calories: Color { Color(hex: caloriesHex) }
    static var protein: Color { Color(hex: proteinHex) }
    static var carbs: Color { Color(hex: carbsHex) }
    static var fat: Color { Color(hex: fatHex) }

    /// Neutral track behind the gauges, readable on light, dark and colored surfaces.
    static let track = Color.primary.opacity(0.15)
}

import Foundation

/// The habits proposed in one tap on the Bien-être page of the first launch, each with its own icon and its own
/// color (PDG, 2026-11-22): eight colors of Ardane's palette, far enough apart to tell the habits apart at a glance
/// in Habitudes, its widgets and Mon Quotidien (`Habit.colorHex` is what they all draw).
enum HabitSuggestions {
    struct Item: Hashable {
        let name: String
        let symbol: String
        let colorHex: String
    }

    static var all: [Item] {
        [
            Item(name: tr("Boire de l'eau"), symbol: "drop.fill", colorHex: "12A4B5"),
            Item(name: tr("Méditer"), symbol: "brain.head.profile", colorHex: "2F8F7A"),
            Item(name: tr("Lire"), symbol: "book.fill", colorHex: "F2A33A"),
            Item(name: tr("Marcher"), symbol: "figure.walk", colorHex: "7FA33A"),
            Item(name: tr("Dormir 8 h"), symbol: "bed.double.fill", colorHex: "8C6CFF"),
            Item(name: tr("S'étirer"), symbol: "figure.flexibility", colorHex: "F2588F"),
            Item(name: tr("Tenir un journal"), symbol: "pencil.line", colorHex: "FF6B57"),
            Item(name: tr("Moins d'écrans le soir"), symbol: "moon.fill", colorHex: "3366FF"),
        ]
    }

    /// The color the first version of these suggestions gave to all of them (the green of Habitudes).
    static let formerColorHex = "7FA33A"
    /// Set once the former suggestions were recolored at launch (it is done a single time).
    static let recoloredKey = "habitSuggestionsRecolored"

    /// The habits added from a suggestion by the first version (same name and icon, still in its single green) take
    /// the suggestion's own color. Any other habit, or one whose color the person changed, is left as it is.
    /// Returns whether something changed.
    @discardableResult
    static func recolor(_ habits: inout [Habit], items: [Item] = all) -> Bool {
        var changed = false
        for index in habits.indices where habits[index].colorHex == formerColorHex {
            let habit = habits[index]
            guard let item = items.first(where: { $0.symbol == habit.symbol && $0.name.caseInsensitiveCompare(habit.name) == .orderedSame }),
                  item.colorHex != habit.colorHex else { continue }
            habits[index].colorHex = item.colorHex
            changed = true
        }
        return changed
    }
}

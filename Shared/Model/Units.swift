import SwiftUI

/// The units shown for the body: metric (kg, cm) or imperial (lb, ft and in). Only the display and the
/// typing change: what is saved stays in kilograms and centimetres, so changing the unit never changes data.
enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case metric, imperial
    var id: String { rawValue }

    var title: String {
        switch self {
        case .metric: tr("Métrique")
        case .imperial: tr("Impérial")
        }
    }

    /// The short name of the weight unit.
    var weightUnit: String {
        switch self {
        case .metric: tr("kg")
        case .imperial: tr("lb")
        }
    }
}

/// Conversions and texts for the person's weight and height. Everything is computed from kilograms and
/// centimetres, the only units ever saved.
enum Units {
    static let poundsPerKilogram = 2.2046226218
    static let centimetresPerInch = 2.54

    // MARK: Conversions

    static func pounds(fromKilograms kg: Double) -> Double { kg * poundsPerKilogram }
    static func kilograms(fromPounds lb: Double) -> Double { lb / poundsPerKilogram }
    static func inches(fromCentimetres cm: Double) -> Double { cm / centimetresPerInch }
    static func centimetres(fromInches inches: Double) -> Double { inches * centimetresPerInch }

    /// Whole feet and inches (inches rounded to the nearest, never 12).
    static func feetAndInches(fromCentimetres cm: Double) -> (feet: Int, inches: Int) {
        let total = Int(safely: inches(fromCentimetres: cm).rounded())
        return (total / 12, total % 12)
    }

    static func centimetres(feet: Double, inches: Double) -> Double {
        centimetres(fromInches: feet * 12 + inches)
    }

    // MARK: Weight

    /// The body weight as a number in the chosen unit, rounded to one decimal (what is typed and shown).
    static func weightValue(kilograms kg: Double, in system: UnitSystem) -> Double {
        let value = system == .imperial ? pounds(fromKilograms: kg) : kg
        return (value * 10).rounded() / 10
    }

    /// The kilograms to save for a weight typed in the chosen unit.
    static func kilograms(fromTyped value: Double, in system: UnitSystem) -> Double {
        system == .imperial ? kilograms(fromPounds: value) : value
    }

    /// "78 kg" / "172 lb": up to one decimal, in the language's number format.
    static func weightText(kilograms kg: Double, in system: UnitSystem) -> String {
        let number = number(weightValue(kilograms: kg, in: system))
        switch system {
        case .metric: return tr("\(number) kg")
        case .imperial: return tr("\(number) lb")
        }
    }

    // MARK: Loads (exercise weights, records, volumes)

    /// A load saved in kilograms as a number in the chosen unit, without its unit: "62,5" / "137,8".
    static func loadNumber(kilograms kg: Double, in system: UnitSystem, digits: Int = 1) -> String {
        number(system == .imperial ? pounds(fromKilograms: kg) : kg, digits: digits)
    }

    /// A load with its unit: "62,5 kg" / "138 lb" (`digits` = most decimals shown; 0 for volumes and records).
    static func loadText(kilograms kg: Double, in system: UnitSystem, digits: Int = 1) -> String {
        let number = loadNumber(kilograms: kg, in: system, digits: digits)
        switch system {
        case .metric: return tr("\(number) kg")
        case .imperial: return tr("\(number) lb")
        }
    }

    /// The kilograms after one step up (+1) or down (-1) of the « Charge » stepper: 2.5 kg, or 5 lb counted
    /// on the displayed pounds (so 135 lb goes to 140 lb, not to 139.9). Never below zero.
    static func steppedLoad(kilograms kg: Double, direction: Double, in system: UnitSystem) -> Double {
        switch system {
        case .metric:
            return max(0, kg + 2.5 * direction)
        case .imperial:
            let shown = weightValue(kilograms: kg, in: .imperial)
            return kilograms(fromPounds: max(0, shown + 5 * direction))
        }
    }

    // MARK: Height

    /// "1,75 m" / "5 ft 9 in".
    static func heightText(centimetres cm: Double, in system: UnitSystem) -> String {
        switch system {
        case .metric:
            let metres = (cm / 100).formatted(.number.precision(.fractionLength(2)).locale(Fmt.locale))
            return tr("\(metres) m")
        case .imperial:
            let parts = feetAndInches(fromCentimetres: cm)
            return tr("\(String(parts.feet)) ft \(String(parts.inches)) in")
        }
    }

    private static func number(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)).locale(Fmt.locale))
    }
}

/// A load (always present) saved in kilograms, typed and shown in the chosen unit; same rule as below.
extension Binding where Value == Double {
    func weight(in system: UnitSystem) -> Binding<Double> {
        guard system == .imperial else { return self }
        return Binding<Double>(
            get: { Units.weightValue(kilograms: self.wrappedValue, in: .imperial) },
            set: { typed in
                if typed == Units.weightValue(kilograms: self.wrappedValue, in: .imperial) { return }
                self.wrappedValue = Units.kilograms(fromPounds: typed)
            }
        )
    }
}

/// Bindings that show a value saved in kg or cm in the chosen unit. Reading rounds for display; writing
/// converts back, and a value that only repeats what is displayed leaves the saved number untouched
/// (opening a screen never moves a weight by a rounding).
extension Binding where Value == Double? {
    /// A weight saved in kilograms, typed and shown in the chosen unit.
    func weight(in system: UnitSystem) -> Binding<Double?> {
        guard system == .imperial else { return self }
        return Binding<Double?>(
            get: { self.wrappedValue.map { Units.weightValue(kilograms: $0, in: .imperial) } },
            set: { typed in
                let current = self.wrappedValue.map { Units.weightValue(kilograms: $0, in: .imperial) }
                if typed == current { return }
                self.wrappedValue = typed.map { Units.kilograms(fromPounds: $0) }
            }
        )
    }

    /// The feet of a height saved in centimetres.
    func heightFeet() -> Binding<Double?> {
        Binding<Double?>(
            get: { self.wrappedValue.map { Double(Units.feetAndInches(fromCentimetres: $0).feet) } },
            set: { setHeight(editingFeet: true, value: $0) }
        )
    }

    /// The inches (0 to 11) of a height saved in centimetres.
    func heightInches() -> Binding<Double?> {
        Binding<Double?>(
            get: { self.wrappedValue.map { Double(Units.feetAndInches(fromCentimetres: $0).inches) } },
            set: { setHeight(editingFeet: false, value: $0) }
        )
    }

    /// Replaces the feet or the inches (the other one stays as displayed); nothing at all: no height.
    private func setHeight(editingFeet: Bool, value: Double?) {
        let shown = wrappedValue.map { Units.feetAndInches(fromCentimetres: $0) }
        let shownFeet = Double(shown?.feet ?? 0)
        let shownInches = Double(shown?.inches ?? 0)
        let feet = editingFeet ? (value ?? 0) : shownFeet
        let inches = editingFeet ? shownInches : (value ?? 0)
        if shown != nil, feet == shownFeet, inches == shownInches { return }
        let total = feet * 12 + inches
        wrappedValue = total > 0 ? Units.centimetres(fromInches: total) : nil
    }
}

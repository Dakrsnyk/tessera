import XCTest
import SwiftUI
@testable import Ardane

/// Metric / imperial: the display and the typing convert, what is saved stays in kg and cm.
@MainActor
final class UnitsTests: XCTestCase {
    func testKilogramsPoundsRoundTrip() {
        for kg in [45.0, 62.5, 78, 99.9, 140] {
            let back = Units.kilograms(fromPounds: Units.pounds(fromKilograms: kg))
            XCTAssertEqual(back, kg, accuracy: 0.000_001)
        }
        XCTAssertEqual(Units.pounds(fromKilograms: 100), 220.46, accuracy: 0.01)
    }

    func testCentimetresInchesRoundTrip() {
        for cm in [150.0, 162.5, 175, 183, 201] {
            let back = Units.centimetres(fromInches: Units.inches(fromCentimetres: cm))
            XCTAssertEqual(back, cm, accuracy: 0.000_001)
        }
        let height = Units.feetAndInches(fromCentimetres: 175)
        XCTAssertEqual(height.feet, 5)
        XCTAssertEqual(height.inches, 9)
        XCTAssertEqual(Units.centimetres(feet: 6, inches: 0), 182.88, accuracy: 0.001)
    }

    func testFeetAndInchesNeverShowTwelveInches() {
        for cm in stride(from: 140.0, through: 210.0, by: 0.5) {
            let parts = Units.feetAndInches(fromCentimetres: cm)
            XCTAssertTrue((0...11).contains(parts.inches), "\(cm) cm : \(parts)")
        }
        // 182 cm = 71,65 in: rounds to 72 in = 6 ft 0 in, not 5 ft 12 in.
        let near = Units.feetAndInches(fromCentimetres: 182)
        XCTAssertEqual(near.feet, 6)
        XCTAssertEqual(near.inches, 0)
    }

    func testDisplayRoundingToOneDecimal() {
        XCTAssertEqual(Units.weightValue(kilograms: 78, in: .metric), 78)
        XCTAssertEqual(Units.weightValue(kilograms: 78, in: .imperial), 172, accuracy: 0.0001)
        XCTAssertEqual(Units.weightValue(kilograms: 70.04, in: .metric), 70)
        XCTAssertEqual(Units.weightValue(kilograms: 80, in: .imperial), 176.4, accuracy: 0.0001)
        XCTAssertEqual(Units.kilograms(fromTyped: 176.4, in: .imperial), 80, accuracy: 0.05)
        XCTAssertEqual(Units.kilograms(fromTyped: 80, in: .metric), 80)
    }

    func testBindingsOnlySaveWhatIsTyped() {
        var weightKg: Double? = 78
        let weight = Binding<Double?>(get: { weightKg }, set: { weightKg = $0 })
        let pounds = weight.weight(in: .imperial)
        XCTAssertEqual(pounds.wrappedValue ?? 0, 172, accuracy: 0.0001)
        // Showing the screen writes back what it displays: the saved kilograms don't move.
        pounds.wrappedValue = pounds.wrappedValue
        XCTAssertEqual(weightKg, 78)
        pounds.wrappedValue = 180
        XCTAssertEqual(weightKg ?? 0, 81.646, accuracy: 0.001)
        pounds.wrappedValue = nil
        XCTAssertNil(weightKg)

        var heightCm: Double? = 183
        let height = Binding<Double?>(get: { heightCm }, set: { heightCm = $0 })
        XCTAssertEqual(height.heightFeet().wrappedValue, 6)
        XCTAssertEqual(height.heightInches().wrappedValue, 0)
        height.heightFeet().wrappedValue = 6
        height.heightInches().wrappedValue = 0
        XCTAssertEqual(heightCm, 183, "Repeating the displayed height leaves the centimetres as saved")
        height.heightInches().wrappedValue = 2
        XCTAssertEqual(heightCm ?? 0, 188.0, accuracy: 0.2)
        height.heightFeet().wrappedValue = nil
        height.heightInches().wrappedValue = nil
        XCTAssertNil(heightCm)
    }

    func testCaloriesDoNotDependOnTheUnit() {
        func goals() -> NutritionGoals {
            NutritionCalculator.goals(sex: .male, age: 30, heightCm: 180, weightKg: 80, activity: .moderate, goal: .maintain)
        }
        let before = goals()
        // Changing the unit changes the display only: the inputs stay the saved kg and cm.
        var settings = AppSettings()
        settings.unitSystem = .imperial
        let imperial = goals()
        XCTAssertEqual(before, imperial)
        XCTAssertEqual(
            NutritionCalculator.breakdown(sex: .male, age: 30, heightCm: 180, weightKg: 80, activity: .moderate, goal: .maintain).restingKcal,
            10 * 80 + 6.25 * 180 - 5 * 30 + 5, accuracy: 0.001)
        // Going through the displayed pounds and back stays within a fraction of a kilogram.
        let typed = Units.weightValue(kilograms: 80, in: .imperial)
        let kg = Units.kilograms(fromTyped: typed, in: .imperial)
        let viaPounds = NutritionCalculator.goals(sex: .male, age: 30, heightCm: 180, weightKg: kg, activity: .moderate, goal: .maintain)
        XCTAssertEqual(viaPounds.kcal, before.kcal, accuracy: 3)
    }

    func testOldSettingsWithoutUnitsAreMetric() throws {
        let old = #"{"currencyCode":"EUR","uses24HourClock":false}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppSettings.self, from: old)
        XCTAssertEqual(decoded.unitSystem, .metric)
        XCTAssertEqual(decoded.currencyCode, "EUR")

        let unknown = #"{"unitSystem":"martian"}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: unknown).unitSystem, .metric)

        var settings = AppSettings()
        settings.unitSystem = .imperial
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: data).unitSystem, .imperial)
    }

    // MARK: Exercise loads

    func testTypedLoadIsStoredInKilogramsAndShownAsTyped() {
        var stored = 20.0
        let binding = Binding<Double>(get: { stored }, set: { stored = $0 }).weight(in: .imperial)
        binding.wrappedValue = 135
        XCTAssertEqual(stored, 61.235, accuracy: 0.001)
        XCTAssertEqual(binding.wrappedValue, 135, accuracy: 0.0001)
        // Repeating what is displayed leaves the saved kilograms untouched.
        let before = stored
        binding.wrappedValue = binding.wrappedValue
        XCTAssertEqual(stored, before)
    }

    func testMetricLoadBindingIsTheSavedValue() {
        var stored = 62.5
        let binding = Binding<Double>(get: { stored }, set: { stored = $0 }).weight(in: .metric)
        XCTAssertEqual(binding.wrappedValue, 62.5)
        binding.wrappedValue = 65
        XCTAssertEqual(stored, 65)
    }

    func testOpeningAnImperialLoadDoesNotMoveIt() {
        var stored = 60.0
        let binding = Binding<Double>(get: { stored }, set: { stored = $0 }).weight(in: .imperial)
        XCTAssertEqual(binding.wrappedValue, 132.3, accuracy: 0.0001)
        binding.wrappedValue = binding.wrappedValue
        XCTAssertEqual(stored, 60)
    }

    func testLoadRoundTripStaysWithinRounding() {
        for kg in [2.5, 20, 42.5, 60, 100, 182.5] {
            let lb = Units.weightValue(kilograms: kg, in: .imperial)
            let back = Units.kilograms(fromTyped: lb, in: .imperial)
            XCTAssertEqual(back, kg, accuracy: 0.05, "\(kg) kg through \(lb) lb")
        }
    }

    func testVolumeAndRecordsStayInKilograms() {
        let sets = [
            SetLog(exercise: "Squat", reps: 5, weight: 100, date: Date()),
            SetLog(exercise: "Squat", reps: 8, weight: 80, date: Date()),
        ]
        let volume = sets.reduce(0) { $0 + $1.volume }
        XCTAssertEqual(volume, 1_140)
        // Only the display changes: 1 140 kg is about 2 513 lb, the volume itself does not.
        XCTAssertEqual(Units.pounds(fromKilograms: volume), 2_513.2, accuracy: 0.1)
        XCTAssertEqual(volume, 1_140)
        XCTAssertEqual(Units.loadNumber(kilograms: volume, in: .imperial, digits: 0).filter(\.isNumber), "2513")
        XCTAssertEqual(Units.loadNumber(kilograms: volume, in: .metric, digits: 0).filter(\.isNumber), "1140")
    }

    func testLoadStepIsTwoPointFiveKilogramsOrFivePounds() {
        XCTAssertEqual(Units.steppedLoad(kilograms: 60, direction: 1, in: .metric), 62.5)
        XCTAssertEqual(Units.steppedLoad(kilograms: 1, direction: -1, in: .metric), 0)
        let up = Units.steppedLoad(kilograms: Units.kilograms(fromPounds: 135), direction: 1, in: .imperial)
        XCTAssertEqual(Units.weightValue(kilograms: up, in: .imperial), 140, accuracy: 0.0001)
        XCTAssertEqual(Units.steppedLoad(kilograms: 1, direction: -1, in: .imperial), 0)
    }
}

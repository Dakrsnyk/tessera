import CoreMotion
import Foundation

/// Today's steps, from the iPhone's own motion sensor (no Health access needed). The access prompt
/// only appears when the person asks to see their steps; until then nothing is read.
@MainActor
@Observable
final class StepCounter {
    static let shared = StepCounter()

    private let pedometer = CMPedometer()
    private(set) var stepsToday: Int?

    /// A day of activity from the motion sensor.
    struct Day: Identifiable, Hashable {
        var date: Date
        var steps: Int
        /// Metres, when the iPhone measures it.
        var distance: Double?
        var floors: Int?
        var id: Date { date }
    }

    private(set) var today: Day?
    /// The last seven days, today last.
    private(set) var week: [Day] = []
    /// Bumped after the access prompt, so views asking `status` read it again.
    private(set) var revision = 0

    enum Status {
        case unavailable, notAsked, allowed, denied
    }

    var status: Status {
        _ = revision
        guard CMPedometer.isStepCountingAvailable() else { return .unavailable }
        switch CMPedometer.authorizationStatus() {
        case .authorized: return .allowed
        case .notDetermined: return .notAsked
        default: return .denied
        }
    }

    /// Reads today's steps when access is granted; asking for them the first time shows the prompt.
    func refresh(asking: Bool = false) async {
        let current = status
        guard current == .allowed || (asking && current == .notAsked) else { return }
        let start = DateMath.startOfDay(Date())
        let steps: Int? = await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: Date()) { data, _ in
                continuation.resume(returning: data?.numberOfSteps.intValue)
            }
        }
        stepsToday = steps
        revision += 1
    }

    /// One day's steps. The iPhone keeps about a week of them: each day read is saved with its date,
    /// so older days can still be looked at later.
    func day(_ date: Date) async -> Day? {
        let start = DateMath.startOfDay(date)
        let oldest = DateMath.startOfDay(DateMath.calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date())
        guard status == .allowed, start >= oldest, start <= Date() else { return Self.saved(start) }
        let isToday = DateMath.isSameDay(start, Date())
        let end = isToday ? Date() : (DateMath.calendar.date(byAdding: .day, value: 1, to: start) ?? Date())
        let day: Day = await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { data, _ in
                continuation.resume(returning: Day(date: start, steps: data?.numberOfSteps.intValue ?? 0,
                                                   distance: data?.distance?.doubleValue, floors: data?.floorsAscended?.intValue))
            }
        }
        Self.save(day)
        return day
    }

    static let historyKey = "stepHistory"

    /// Saved days, by « yyyy-MM-dd »: [steps, distance in metres (-1 if unknown), floors (-1 if unknown)].
    private static func save(_ day: Day) {
        var history = UserDefaults.standard.dictionary(forKey: historyKey) as? [String: [Double]] ?? [:]
        history[key(day.date)] = [Double(day.steps), day.distance ?? -1, Double(day.floors ?? -1)]
        UserDefaults.standard.set(history, forKey: historyKey)
    }

    private static func saved(_ date: Date) -> Day? {
        guard let values = (UserDefaults.standard.dictionary(forKey: historyKey) as? [String: [Double]])?[key(date)],
              values.count == 3 else { return nil }
        return Day(date: date, steps: Int(values[0]), distance: values[1] >= 0 ? values[1] : nil, floors: values[2] >= 0 ? Int(values[2]) : nil)
    }

    private static func key(_ date: Date) -> String {
        let c = DateMath.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Reads today in detail and the last seven days (the Fitness mini-app's activity).
    func refreshWeek() async {
        guard status == .allowed else { return }
        var days: [Day] = []
        for offset in (0..<7).reversed() {
            let start = DateMath.startOfDay(DateMath.calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date())
            let end = offset == 0 ? Date() : (DateMath.calendar.date(byAdding: .day, value: 1, to: start) ?? Date())
            let day: Day = await withCheckedContinuation { continuation in
                pedometer.queryPedometerData(from: start, to: end) { data, _ in
                    continuation.resume(returning: Day(
                        date: start,
                        steps: data?.numberOfSteps.intValue ?? 0,
                        distance: data?.distance?.doubleValue,
                        floors: data?.floorsAscended?.intValue
                    ))
                }
            }
            days.append(day)
            Self.save(day)
        }
        week = days
        today = days.last
        stepsToday = days.last?.steps
        revision += 1
    }

    /// Active calories estimated from the steps (about 0,04 kcal per step for 70 kg), clearly an estimate.
    static func estimatedCalories(steps: Int, weightKg: Double?) -> Double {
        Double(steps) * 0.04 * ((weightKg ?? 70) / 70)
    }
}

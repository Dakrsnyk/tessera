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
}

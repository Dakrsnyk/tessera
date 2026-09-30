import SwiftUI

/// A schematic figure doing the movement, drawn by the app: no outside video, so nothing to license,
/// and something to see for every exercise. Poses are in body units (y up, x toward where the figure
/// faces), joints found by two-bone inverse kinematics from the hands and feet.
struct ExerciseDemoView: View {
    let exercise: ExerciseInfo
    var colorHex = "E5484D"
    /// Seconds for one repetition.
    var period: Double = 2.6

    var body: some View {
        TimelineView(.animation) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let t = (seconds.truncatingRemainder(dividingBy: period)) / period
            Canvas { context, size in
                DemoRenderer.draw(DemoPoses.pose(exercise.pattern, t: t), pattern: exercise.pattern, equipment: exercise.equipment,
                                  in: &context, size: size, accent: Color(hex: colorHex))
            }
        }
        .accessibilityLabel(Text("Démonstration animée de \(exercise.name)"))
    }
}

struct DemoPose {
    /// Seen from the front (arms out to the sides) instead of from the side.
    var front = false
    var hip: CGPoint
    /// Degrees: 0 upright, 90 leaning forward flat, -90 lying with the head behind.
    var torso: Double
    var hand: CGPoint
    var farHand: CGPoint
    var foot: CGPoint
    var farFoot: CGPoint
    /// Elbows bend behind the arm line (true) or in front of it.
    var elbowsBack = true
    var kneesForward = true
    /// 0 flat feet, 1 on tiptoe.
    var tiptoe: Double = 0
    /// Shoulders lifted (shrugs).
    var shrug: Double = 0

    static func mix(_ a: DemoPose, _ b: DemoPose, _ t: Double) -> DemoPose {
        func m(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * t }
        func p(_ x: CGPoint, _ y: CGPoint) -> CGPoint { CGPoint(x: m(x.x, y.x), y: m(x.y, y.y)) }
        var pose = a
        pose.hip = p(a.hip, b.hip)
        pose.torso = a.torso + (b.torso - a.torso) * t
        pose.hand = p(a.hand, b.hand)
        pose.farHand = p(a.farHand, b.farHand)
        pose.foot = p(a.foot, b.foot)
        pose.farFoot = p(a.farFoot, b.farFoot)
        pose.tiptoe = a.tiptoe + (b.tiptoe - a.tiptoe) * t
        pose.shrug = a.shrug + (b.shrug - a.shrug) * t
        return pose
    }
}

/// Body proportions, in units (about 1/10 of the figure's height with arms up).
enum DemoBody {
    static let torso: CGFloat = 2.6
    static let upperArm: CGFloat = 1.5
    static let forearm: CGFloat = 1.4
    static let thigh: CGFloat = 2.1
    static let shin: CGFloat = 2.1
    static let neck: CGFloat = 0.75
    static let head: CGFloat = 0.45
    static let shoulderHalf: CGFloat = 0.75
    static let hipHalf: CGFloat = 0.38
}

enum DemoPoses {
    private static func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private static let stand = DemoPose(hip: pt(0, 4.1), torso: 0, hand: pt(0.2, 3.85), farHand: pt(0, 3.85), foot: pt(0.3, 0), farFoot: pt(-0.1, 0))

    /// Out and back: ease in, pause a little at each end.
    private static func pingPong(_ t: Double) -> Double {
        let x = t < 0.5 ? t * 2 : (1 - t) * 2
        let held = min(1, max(0, (x - 0.08) / 0.84))
        return held * held * (3 - 2 * held)
    }

    static func pose(_ pattern: MovementPattern, t: Double) -> DemoPose {
        let k = pingPong(t)
        switch pattern {
        case .squat:
            let a = DemoPose(hip: pt(0, 4.1), torso: 0, hand: pt(0.8, 6.1), farHand: pt(0.7, 6.1), foot: pt(0.3, 0), farFoot: pt(-0.1, 0))
            let b = DemoPose(hip: pt(-1.0, 2.35), torso: 35, hand: pt(1.3, 4.0), farHand: pt(1.2, 4.0), foot: pt(0.3, 0), farFoot: pt(-0.1, 0))
            return .mix(a, b, k)
        case .hinge:
            let a = DemoPose(hip: pt(0, 4.05), torso: 0, hand: pt(0.2, 3.9), farHand: pt(0.1, 3.9), foot: pt(0.3, 0), farFoot: pt(-0.1, 0))
            let b = DemoPose(hip: pt(-0.75, 3.65), torso: 75, hand: pt(1.75, 1.45), farHand: pt(1.65, 1.45), foot: pt(0.3, 0), farFoot: pt(-0.1, 0))
            return .mix(a, b, k)
        case .lunge:
            let a = DemoPose(hip: pt(0, 4.1), torso: 0, hand: pt(0.2, 3.85), farHand: pt(0, 3.85), foot: pt(0.3, 0), farFoot: pt(-0.1, 0))
            let b = DemoPose(hip: pt(0, 2.45), torso: 0, hand: pt(0.25, 2.25), farHand: pt(0.05, 2.25), foot: pt(1.75, 0), farFoot: pt(-1.7, 0.05), tiptoe: 0)
            return .mix(a, b, k)
        case .benchPress, .lyingExtension, .fly, .pullover:
            let base = DemoPose(hip: pt(1.0, 1.95), torso: -90, hand: pt(-1.5, 4.75), farHand: pt(-1.6, 4.75), foot: pt(2.7, 0), farFoot: pt(2.4, 0))
            var a = base
            var b = base
            switch pattern {
            case .benchPress:
                b.hand = pt(-1.2, 2.55); b.farHand = pt(-1.3, 2.55)
            case .lyingExtension:
                b.hand = pt(-2.75, 3.05); b.farHand = pt(-2.85, 3.05); b.elbowsBack = false; a.elbowsBack = false
            case .fly:
                b.hand = pt(-1.9, 2.35); b.farHand = pt(-1.3, 2.35)
            default:
                b.hand = pt(-4.3, 2.4); b.farHand = pt(-4.35, 2.4)
            }
            return .mix(a, b, k)
        case .pushUp, .mountainClimber:
            let a = DemoPose(hip: pt(-0.47, 1.73), torso: 65.7, hand: pt(1.9, 0), farHand: pt(1.8, 0), foot: pt(-4.3, 0), farFoot: pt(-4.4, 0))
            if pattern == .mountainClimber {
                var near = a
                near.foot = pt(-1.2, 0.5)
                var far = a
                far.farFoot = pt(-1.3, 0.5)
                return .mix(near, far, t < 0.5 ? t * 2 : (1 - t) * 2)
            }
            let b = DemoPose(hip: pt(-0.14, 0.56), torso: 82.4, hand: pt(1.9, 0), farHand: pt(1.8, 0), foot: pt(-4.3, 0), farFoot: pt(-4.4, 0))
            return .mix(a, b, k)
        case .plank:
            let a = DemoPose(hip: pt(-0.7, 0.9), torso: 77.6, hand: pt(3.1, 0.05), farHand: pt(3.0, 0.05), foot: pt(-4.8, 0), farFoot: pt(-4.9, 0))
            var b = a
            b.hip = pt(-0.7, 1.0)
            return .mix(a, b, k)
        case .dip:
            let a = DemoPose(hip: pt(-0.15, 4.25), torso: 10, hand: pt(0.35, 3.9), farHand: pt(0.25, 3.9), foot: pt(-1.3, 1.3), farFoot: pt(-1.4, 1.3))
            let b = DemoPose(hip: pt(-0.4, 2.7), torso: 16, hand: pt(0.35, 3.9), farHand: pt(0.25, 3.9), foot: pt(-1.6, 0.2), farFoot: pt(-1.7, 0.2))
            return .mix(a, b, k)
        case .verticalPush:
            let a = DemoPose(hip: pt(0, 4.1), torso: 0, hand: pt(0.5, 6.8), farHand: pt(0.4, 6.8), foot: pt(0.3, 0), farFoot: pt(-0.1, 0), elbowsBack: false)
            let b = DemoPose(hip: pt(0, 4.1), torso: 0, hand: pt(0.15, 9.5), farHand: pt(0.05, 9.5), foot: pt(0.3, 0), farFoot: pt(-0.1, 0), elbowsBack: false)
            return .mix(a, b, k)
        case .horizontalPull:
            let a = DemoPose(hip: pt(-0.6, 3.8), torso: 70, hand: pt(1.75, 1.9), farHand: pt(1.65, 1.9), foot: pt(0.2, 0), farFoot: pt(-0.2, 0))
            let b = DemoPose(hip: pt(-0.6, 3.8), torso: 70, hand: pt(0.95, 3.65), farHand: pt(0.85, 3.65), foot: pt(0.2, 0), farFoot: pt(-0.2, 0))
            return .mix(a, b, k)
        case .seatedRow:
            let a = DemoPose(hip: pt(-1.2, 1.55), torso: 8, hand: pt(1.75, 3.55), farHand: pt(1.65, 3.55), foot: pt(2.4, 0.9), farFoot: pt(2.3, 0.9))
            let b = DemoPose(hip: pt(-1.2, 1.55), torso: -4, hand: pt(-0.45, 3.2), farHand: pt(-0.55, 3.2), foot: pt(2.4, 0.9), farFoot: pt(2.3, 0.9))
            return .mix(a, b, k)
        case .verticalPull:
            let a = DemoPose(hip: pt(0, 3.95), torso: 0, hand: pt(0.3, 9.4), farHand: pt(0.2, 9.4), foot: pt(-1.2, 1.2), farFoot: pt(-1.3, 1.2), elbowsBack: false)
            let b = DemoPose(hip: pt(-0.05, 6.3), torso: 4, hand: pt(0.3, 9.4), farHand: pt(0.2, 9.4), foot: pt(-1.35, 3.6), farFoot: pt(-1.45, 3.6), elbowsBack: false)
            return .mix(a, b, k)
        case .curl:
            let a = DemoPose(hip: pt(0, 4.1), torso: 0, hand: pt(0.35, 3.9), farHand: pt(0.25, 3.9), foot: pt(0.3, 0), farFoot: pt(-0.1, 0))
            let b = DemoPose(hip: pt(0, 4.1), torso: 0, hand: pt(0.55, 6.25), farHand: pt(0.45, 6.25), foot: pt(0.3, 0), farFoot: pt(-0.1, 0))
            return .mix(a, b, k)
        case .tricepsExtension:
            let a = DemoPose(hip: pt(0, 4.1), torso: 12, hand: pt(1.4, 5.35), farHand: pt(1.3, 5.35), foot: pt(0.3, 0), farFoot: pt(-0.1, 0))
            let b = DemoPose(hip: pt(0, 4.1), torso: 12, hand: pt(0.75, 3.9), farHand: pt(0.65, 3.9), foot: pt(0.3, 0), farFoot: pt(-0.1, 0))
            return .mix(a, b, k)
        case .overheadExtension:
            let a = DemoPose(hip: pt(0, 4.1), torso: 0, hand: pt(0.1, 9.5), farHand: pt(0, 9.5), foot: pt(0.3, 0), farFoot: pt(-0.1, 0))
            let b = DemoPose(hip: pt(0, 4.1), torso: 0, hand: pt(-0.75, 7.25), farHand: pt(-0.85, 7.25), foot: pt(0.3, 0), farFoot: pt(-0.1, 0))
            return .mix(a, b, k)
        case .frontRaise:
            let a = DemoPose(hip: pt(0, 4.1), torso: 0, hand: pt(0.35, 3.9), farHand: pt(0.25, 3.9), foot: pt(0.3, 0), farFoot: pt(-0.1, 0))
            let b = DemoPose(hip: pt(0, 4.1), torso: 0, hand: pt(2.85, 6.7), farHand: pt(2.75, 6.7), foot: pt(0.3, 0), farFoot: pt(-0.1, 0))
            return .mix(a, b, k)
        case .uprightRow:
            let a = DemoPose(hip: pt(0, 4.1), torso: 0, hand: pt(0.35, 3.9), farHand: pt(0.25, 3.9), foot: pt(0.3, 0), farFoot: pt(-0.1, 0), elbowsBack: false)
            let b = DemoPose(hip: pt(0, 4.1), torso: 0, hand: pt(0.45, 6.0), farHand: pt(0.35, 6.0), foot: pt(0.3, 0), farFoot: pt(-0.1, 0), elbowsBack: false)
            return .mix(a, b, k)
        case .lateralRaise:
            let a = DemoPose(front: true, hip: pt(0, 4.1), torso: 0, hand: pt(1.05, 3.9), farHand: pt(-1.05, 3.9), foot: pt(0.45, 0), farFoot: pt(-0.45, 0))
            let b = DemoPose(front: true, hip: pt(0, 4.1), torso: 0, hand: pt(3.5, 6.45), farHand: pt(-3.5, 6.45), foot: pt(0.45, 0), farFoot: pt(-0.45, 0))
            return .mix(a, b, k)
        case .shrug:
            let a = DemoPose(front: true, hip: pt(0, 4.1), torso: 0, hand: pt(1.0, 3.9), farHand: pt(-1.0, 3.9), foot: pt(0.45, 0), farFoot: pt(-0.45, 0))
            var b = a
            b.shrug = 0.45
            b.hand = pt(1.0, 4.35)
            b.farHand = pt(-1.0, 4.35)
            return .mix(a, b, k)
        case .armCircles:
            // Straight arms turning around the shoulders.
            let angle = t * 2 * .pi - .pi / 2
            let shoulderY: CGFloat = 4.1 + DemoBody.torso
            let reach: CGFloat = DemoBody.upperArm + DemoBody.forearm - 0.05
            let dx = reach * CGFloat(cos(angle))
            let dy = reach * CGFloat(sin(angle))
            return DemoPose(front: true, hip: pt(0, 4.1), torso: 0,
                            hand: pt(DemoBody.shoulderHalf + abs(dx), shoulderY + dy),
                            farHand: pt(-DemoBody.shoulderHalf - abs(dx), shoulderY + dy),
                            foot: pt(0.45, 0), farFoot: pt(-0.45, 0))
        case .carry:
            var near = stand
            near.foot = pt(0.9, 0)
            near.farFoot = pt(-0.7, 0)
            var far = stand
            far.foot = pt(-0.7, 0)
            far.farFoot = pt(0.9, 0)
            return .mix(near, far, pingPong(t))
        case .run:
            let s = sin(t * 2 * .pi)
            var pose = stand
            pose.hip = pt(0, 3.95 + 0.12 * abs(s))
            pose.torso = 8
            pose.foot = pt(1.2 * s, 0.25 + max(0, s) * 1.1)
            pose.farFoot = pt(-1.2 * s, 0.25 + max(0, -s) * 1.1)
            pose.hand = pt(0.3 - 1.0 * s, 5.3 + 0.2 * s)
            pose.farHand = pt(0.3 + 1.0 * s, 5.3 - 0.2 * s)
            pose.elbowsBack = false
            return pose
        case .cycle:
            let angle = t * 2 * .pi
            var pose = DemoPose(hip: pt(-0.7, 3.65), torso: 30, hand: pt(1.95, 5.1), farHand: pt(1.85, 5.1), foot: .zero, farFoot: .zero)
            pose.foot = pt(0.55 + 0.9 * CGFloat(cos(angle)), 1.25 + 0.9 * CGFloat(sin(angle)))
            pose.farFoot = pt(0.55 - 0.9 * CGFloat(cos(angle)), 1.25 - 0.9 * CGFloat(sin(angle)))
            return pose
        case .rowing:
            let a = DemoPose(hip: pt(-0.3, 0.65), torso: 28, hand: pt(2.35, 2.25), farHand: pt(2.25, 2.25), foot: pt(1.95, 0.6), farFoot: pt(1.85, 0.6))
            let b = DemoPose(hip: pt(-2.1, 0.65), torso: -22, hand: pt(-1.3, 2.95), farHand: pt(-1.4, 2.95), foot: pt(1.95, 0.6), farFoot: pt(1.85, 0.6))
            return .mix(a, b, k)
        case .jump:
            let a = DemoPose(hip: pt(-0.5, 3.1), torso: 25, hand: pt(-0.4, 3.4), farHand: pt(-0.5, 3.4), foot: pt(0.3, 0), farFoot: pt(-0.1, 0))
            let b = DemoPose(hip: pt(0, 5.3), torso: 0, hand: pt(0.4, 9.5), farHand: pt(0.3, 9.5), foot: pt(0.3, 1.2), farFoot: pt(-0.1, 1.2), elbowsBack: false, tiptoe: 1)
            return .mix(a, b, k)
        case .crunch:
            let a = DemoPose(hip: pt(0.5, 0.3), torso: -90, hand: pt(-2.55, 0.95), farHand: pt(-2.65, 0.95), foot: pt(2.3, 0), farFoot: pt(2.2, 0), elbowsBack: false)
            let b = DemoPose(hip: pt(0.5, 0.3), torso: -58, hand: pt(-1.75, 2.45), farHand: pt(-1.85, 2.45), foot: pt(2.3, 0), farFoot: pt(2.2, 0), elbowsBack: false)
            return .mix(a, b, k)
        case .legRaise:
            let a = DemoPose(hip: pt(0.9, 0.3), torso: -90, hand: pt(0.4, 0.2), farHand: pt(0.3, 0.2), foot: pt(5.05, 0.35), farFoot: pt(5.0, 0.35))
            let b = DemoPose(hip: pt(0.9, 0.3), torso: -90, hand: pt(0.4, 0.2), farHand: pt(0.3, 0.2), foot: pt(1.1, 4.45), farFoot: pt(1.05, 4.45))
            return .mix(a, b, k)
        case .bridge:
            let a = DemoPose(hip: pt(0.55, 0.3), torso: -90, hand: pt(0.1, 0.15), farHand: pt(0.0, 0.15), foot: pt(2.2, 0), farFoot: pt(2.1, 0))
            let b = DemoPose(hip: pt(0.35, 1.7), torso: -122, hand: pt(0.1, 0.15), farHand: pt(0.0, 0.15), foot: pt(2.2, 0), farFoot: pt(2.1, 0))
            return .mix(a, b, k)
        case .legKickback:
            let a = DemoPose(hip: pt(-1.0, 2.3), torso: 90, hand: pt(1.75, 0.02), farHand: pt(1.65, 0.02), foot: pt(-3.0, 0.1), farFoot: pt(-3.1, 0.1), kneesForward: false)
            var b = a
            b.foot = pt(-5.15, 2.6)
            b.kneesForward = true
            return .mix(a, b, k)
        case .calfRaise:
            var b = stand
            b.hip = pt(0, 4.55)
            b.tiptoe = 1
            b.foot = pt(0.3, 0.45)
            b.farFoot = pt(-0.1, 0.45)
            return .mix(stand, b, k)
        case .legPress:
            let a = DemoPose(hip: pt(-1.4, 1.6), torso: -32, hand: pt(-0.6, 1.9), farHand: pt(-0.7, 1.9), foot: pt(0.8, 3.2), farFoot: pt(0.7, 3.2))
            let b = DemoPose(hip: pt(-1.4, 1.6), torso: -32, hand: pt(-0.6, 1.9), farHand: pt(-0.7, 1.9), foot: pt(2.45, 4.45), farFoot: pt(2.35, 4.45))
            return .mix(a, b, k)
        case .legExtension, .legCurl:
            let bent = DemoPose(hip: pt(-0.7, 2.25), torso: -6, hand: pt(-0.4, 2.0), farHand: pt(-0.5, 2.0), foot: pt(1.55, 0.2), farFoot: pt(1.45, 0.2))
            var straight = bent
            straight.foot = pt(3.5, 2.5)
            straight.farFoot = pt(3.4, 2.5)
            return pattern == .legExtension ? .mix(bent, straight, k) : .mix(straight, bent, k)
        case .rotation:
            let a = DemoPose(hip: pt(0, 0.3), torso: -35, hand: pt(0.55, 2.7), farHand: pt(0.45, 2.7), foot: pt(2.1, 0.5), farFoot: pt(2.0, 0.5), elbowsBack: false)
            let b = DemoPose(hip: pt(0, 0.3), torso: -30, hand: pt(-0.7, 1.1), farHand: pt(-0.8, 1.1), foot: pt(2.1, 0.5), farFoot: pt(2.0, 0.5), elbowsBack: false)
            return .mix(a, b, k)
        case .superman:
            let a = DemoPose(hip: pt(0, 0.4), torso: 90, hand: pt(5.25, 0.45), farHand: pt(5.2, 0.45), foot: pt(-4.15, 0.3), farFoot: pt(-4.2, 0.3))
            let b = DemoPose(hip: pt(0, 0.4), torso: 80, hand: pt(5.0, 1.45), farHand: pt(4.95, 1.45), foot: pt(-4.05, 1.0), farFoot: pt(-4.1, 1.0))
            return .mix(a, b, k)
        case .stretchFold:
            let a = DemoPose(hip: pt(-1.3, 0.35), torso: 8, hand: pt(-0.9, 0.6), farHand: pt(-1.0, 0.6), foot: pt(2.85, 0.3), farFoot: pt(2.75, 0.3))
            let b = DemoPose(hip: pt(-1.3, 0.35), torso: 68, hand: pt(2.6, 0.55), farHand: pt(2.5, 0.55), foot: pt(2.85, 0.3), farFoot: pt(2.75, 0.3))
            return .mix(a, b, min(1, k * 1.2))
        case .stretchStand:
            var b = stand
            b.foot = pt(-0.55, 2.9)
            b.kneesForward = true
            b.hand = pt(-0.6, 3.05)
            return .mix(stand, b, min(1, k * 1.2))
        case .generic:
            var b = stand
            b.hand = pt(0.9, 5.2)
            b.farHand = pt(0.8, 5.2)
            b.elbowsBack = false
            return .mix(stand, b, k * 0.6)
        }
    }
}

enum DemoRenderer {
    /// Two bones from a root toward a target: the middle joint and the reached end.
    static func limb(from root: CGPoint, to target: CGPoint, _ a: CGFloat, _ b: CGFloat, bendPositive: Bool) -> (CGPoint, CGPoint) {
        var dx = target.x - root.x
        var dy = target.y - root.y
        var d = max(hypot(dx, dy), 0.0001)
        let reach = (a + b) * 0.999
        if d > reach {
            dx *= reach / d
            dy *= reach / d
            d = reach
        }
        d = max(d, abs(a - b) + 0.001)
        let base = atan2(dy, dx)
        let cosine = min(1, max(-1, (a * a + d * d - b * b) / (2 * a * d)))
        let offset = acos(cosine)
        let angle = base + (bendPositive ? offset : -offset)
        return (CGPoint(x: root.x + a * cos(angle), y: root.y + a * sin(angle)), CGPoint(x: root.x + dx, y: root.y + dy))
    }

    static func draw(_ pose: DemoPose, pattern: MovementPattern, equipment: [Equipment], in context: inout GraphicsContext, size: CGSize, accent: Color) {
        let unit = size.height / 10.6
        let groundY = size.height - unit * 0.35
        func screen(_ p: CGPoint) -> CGPoint { CGPoint(x: size.width / 2 + p.x * unit, y: groundY - p.y * unit) }
        let ink = Color.primary
        let width = unit * 0.34

        func line(_ points: [CGPoint], _ color: Color, _ lineWidth: CGFloat) {
            var path = Path()
            guard let first = points.first else { return }
            path.move(to: screen(first))
            for point in points.dropFirst() { path.addLine(to: screen(point)) }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }

        // The ground.
        line([CGPoint(x: -6.4, y: 0), CGPoint(x: 6.4, y: 0)], Color.secondary.opacity(0.35), unit * 0.08)

        let theta = pose.torso * .pi / 180
        let up = CGPoint(x: sin(theta), y: cos(theta))
        let neckBase = CGPoint(x: pose.hip.x + up.x * DemoBody.torso, y: pose.hip.y + up.y * DemoBody.torso + pose.shrug)
        let head = CGPoint(x: neckBase.x + up.x * DemoBody.neck, y: neckBase.y + up.y * DemoBody.neck)

        // Props behind the figure.
        drawProps(pattern: pattern, equipment: equipment, pose: pose, context: &context, screen: screen, unit: unit)

        func arm(from shoulder: CGPoint, to hand: CGPoint, color: Color) {
            let (elbow, end) = limb(from: shoulder, to: hand, DemoBody.upperArm, DemoBody.forearm, bendPositive: !pose.elbowsBack)
            line([shoulder, elbow, end], color, width)
            drawWeight(at: end, equipment: equipment, pattern: pattern, context: &context, screen: screen, unit: unit, accent: accent)
        }

        func leg(from hip: CGPoint, to foot: CGPoint, color: Color, mirrored: Bool = false) {
            let (knee, ankle) = limb(from: hip, to: foot, DemoBody.thigh, DemoBody.shin, bendPositive: mirrored ? !pose.kneesForward : pose.kneesForward)
            let toeDirection: CGPoint = pose.front ? CGPoint(x: 0, y: 0) : CGPoint(x: 0.55 * (1 - pose.tiptoe * 0.4), y: -0.45 * pose.tiptoe)
            let toe = CGPoint(x: ankle.x + (pose.front ? (mirrored ? -0.25 : 0.25) : toeDirection.x), y: ankle.y + toeDirection.y)
            line([hip, knee, ankle, toe], color, width)
        }

        if pose.front {
            let shoulderY = neckBase.y
            let rightShoulder = CGPoint(x: neckBase.x + DemoBody.shoulderHalf, y: shoulderY)
            let leftShoulder = CGPoint(x: neckBase.x - DemoBody.shoulderHalf, y: shoulderY)
            let rightHip = CGPoint(x: pose.hip.x + DemoBody.hipHalf, y: pose.hip.y)
            let leftHip = CGPoint(x: pose.hip.x - DemoBody.hipHalf, y: pose.hip.y)
            leg(from: rightHip, to: pose.foot, color: ink)
            leg(from: leftHip, to: pose.farFoot, color: ink, mirrored: true)
            line([leftHip, rightHip, rightShoulder, leftShoulder, leftHip], ink, width)
            arm(from: rightShoulder, to: pose.hand, color: ink)
            // The other arm bends the other way when seen from the front.
            let (elbow, end) = limb(from: leftShoulder, to: pose.farHand, DemoBody.upperArm, DemoBody.forearm, bendPositive: pose.elbowsBack)
            line([leftShoulder, elbow, end], ink, width)
            drawWeight(at: end, equipment: equipment, pattern: pattern, context: &context, screen: screen, unit: unit, accent: accent)
        } else {
            let far = ink.opacity(0.32)
            leg(from: pose.hip, to: pose.farFoot, color: far)
            arm(from: neckBase, to: pose.farHand, color: far)
            leg(from: pose.hip, to: pose.foot, color: ink)
            line([pose.hip, neckBase], ink, width * 1.15)
            arm(from: neckBase, to: pose.hand, color: ink)
        }
        let headCenter = screen(head)
        let radius = DemoBody.head * unit
        context.fill(Path(ellipseIn: CGRect(x: headCenter.x - radius, y: headCenter.y - radius, width: radius * 2, height: radius * 2)), with: .color(ink))
    }

    private static func drawWeight(at hand: CGPoint, equipment: [Equipment], pattern: MovementPattern, context: inout GraphicsContext,
                                   screen: (CGPoint) -> CGPoint, unit: CGFloat, accent: Color) {
        let point = screen(hand)
        if equipment.contains(.barbell) {
            let r = unit * 0.62
            context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)), with: .color(accent.opacity(0.85)))
        } else if equipment.contains(.dumbbells) {
            let rect = CGRect(x: point.x - unit * 0.42, y: point.y - unit * 0.17, width: unit * 0.84, height: unit * 0.34)
            context.fill(Path(roundedRect: rect, cornerRadius: unit * 0.12), with: .color(accent.opacity(0.9)))
        } else if equipment.contains(.kettlebell) {
            let r = unit * 0.36
            context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y, width: r * 2, height: r * 2)), with: .color(accent.opacity(0.9)))
        } else if equipment.contains(.band) {
            var path = Path()
            path.addEllipse(in: CGRect(x: point.x - unit * 0.2, y: point.y - unit * 0.2, width: unit * 0.4, height: unit * 0.4))
            context.stroke(path, with: .color(accent), lineWidth: unit * 0.1)
        }
    }

    private static func drawProps(pattern: MovementPattern, equipment: [Equipment], pose: DemoPose, context: inout GraphicsContext,
                                  screen: (CGPoint) -> CGPoint, unit: CGFloat) {
        let prop = Color.secondary.opacity(0.4)
        func bar(_ a: CGPoint, _ b: CGPoint, _ width: CGFloat) {
            var path = Path()
            path.move(to: screen(a))
            path.addLine(to: screen(b))
            context.stroke(path, with: .color(prop), style: StrokeStyle(lineWidth: unit * width, lineCap: .round))
        }
        switch pattern {
        case .benchPress, .lyingExtension, .fly, .pullover:
            bar(CGPoint(x: -3.0, y: 1.4), CGPoint(x: 1.7, y: 1.4), 0.5)
            bar(CGPoint(x: -2.4, y: 1.3), CGPoint(x: -2.4, y: 0), 0.2)
            bar(CGPoint(x: 1.1, y: 1.3), CGPoint(x: 1.1, y: 0), 0.2)
        case .verticalPull where equipment.contains(.pullUpBar):
            bar(CGPoint(x: -1.6, y: 9.4), CGPoint(x: 2.0, y: 9.4), 0.22)
        case .verticalPull, .tricepsExtension:
            if equipment.contains(.cable) {
                bar(CGPoint(x: pose.hand.x, y: pose.hand.y), CGPoint(x: pose.hand.x + 0.6, y: 10.2), 0.07)
            }
        case .seatedRow:
            bar(CGPoint(x: -2.3, y: 1.1), CGPoint(x: -0.2, y: 1.1), 0.4)
            bar(CGPoint(x: 2.75, y: 0.3), CGPoint(x: 2.75, y: 1.6), 0.25)
            bar(pose.hand, CGPoint(x: 3.8, y: 3.4), 0.07)
        case .dip:
            bar(CGPoint(x: -0.4, y: 3.75), CGPoint(x: 1.3, y: 3.75), 0.2)
            bar(CGPoint(x: 1.1, y: 3.7), CGPoint(x: 1.1, y: 0), 0.16)
        case .legPress:
            bar(CGPoint(x: -2.6, y: 0.9), CGPoint(x: -0.8, y: 1.4), 0.4)
            bar(CGPoint(x: pose.foot.x + 0.35, y: pose.foot.y + 0.9), CGPoint(x: pose.foot.x + 0.35, y: pose.foot.y - 1.0), 0.25)
        case .legExtension, .legCurl:
            bar(CGPoint(x: -1.8, y: 2.0), CGPoint(x: 1.0, y: 2.0), 0.45)
            bar(CGPoint(x: -1.6, y: 2.0), CGPoint(x: -1.8, y: 4.4), 0.35)
            bar(CGPoint(x: -0.2, y: 1.9), CGPoint(x: -0.2, y: 0), 0.2)
        case .cycle:
            bar(CGPoint(x: -0.9, y: 3.4), CGPoint(x: 0.55, y: 1.25), 0.2)
            bar(CGPoint(x: 0.55, y: 1.25), CGPoint(x: 1.9, y: 4.9), 0.2)
            var wheel = Path()
            let center = screen(CGPoint(x: 0.55, y: 1.25))
            wheel.addEllipse(in: CGRect(x: center.x - unit * 1.1, y: center.y - unit * 1.1, width: unit * 2.2, height: unit * 2.2))
            context.stroke(wheel, with: .color(prop), lineWidth: unit * 0.1)
        case .rowing:
            bar(CGPoint(x: -3.2, y: 0.35), CGPoint(x: 2.6, y: 0.35), 0.25)
            bar(pose.hand, CGPoint(x: 2.9, y: 1.2), 0.07)
        default:
            break
        }
    }
}

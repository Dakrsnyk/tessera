import SwiftUI

// The sculpted plastic mannequin of the exercise demonstrations (CEO, 2026-11-23, validated on scripts/demos/sculpt.py):
// a body built as a volume around the demonstration's skeleton (rings of cross-sections, ball joints, ovoid hands and
// feet, a smooth egg head), muscles drawn on its surface from their origin to their insertion, one light from the upper
// left, a plastic sheen along the limbs, the muscles as a soft relief; the muscles worked in red (main) or pink
// (secondary). No blur is drawn at play time: soft edges are stacked strokes, so many thumbnails can loop at once.

/// The muscles lit on a figure: main ones in red, secondary ones in pink (keys of `Sculpt.muscles`).
struct DemoMuscles: Equatable {
    var primary: Set<String> = []
    var secondary: Set<String> = []

    init(primary: Set<String> = [], secondary: Set<String> = []) {
        self.primary = primary
        self.secondary = secondary.subtracting(primary)
    }

    init(primary: [Muscle], secondary: [Muscle]) {
        self.init(primary: Self.keys(primary), secondary: Self.keys(secondary))
    }

    static let everyGroup: Set<String> = ["chest", "shoulders", "biceps", "triceps", "forearms", "abs", "traps", "back",
                                           "lowerBack", "glutes", "quads", "adductors", "hamstrings", "calves"]

    static func keys(_ muscles: [Muscle]) -> Set<String> {
        var out = Set<String>()
        for muscle in muscles {
            switch muscle {
            case .chest: out.insert("chest")
            case .back: out.insert("back")
            case .traps: out.insert("traps")
            case .lowerBack: out.insert("lowerBack")
            case .shoulders: out.insert("shoulders")
            case .biceps: out.insert("biceps")
            case .triceps: out.insert("triceps")
            case .forearms: out.insert("forearms")
            case .quads: out.insert("quads")
            case .hamstrings: out.insert("hamstrings")
            case .glutes: out.insert("glutes")
            case .calves: out.insert("calves")
            case .abs, .obliques: out.insert("abs")
            case .fullBody: out.formUnion(everyGroup)
            case .heart: break
            }
        }
        return out
    }

    /// The muscles of a demonstration by its id: an anatomy figure lights its group, an exercise its own muscles.
    static func forDemo(_ id: String) -> DemoMuscles {
        if id.hasPrefix("anatomy-"), let group = MuscleGroup(rawValue: String(id.dropFirst("anatomy-".count))) {
            return DemoMuscles(primary: keys(Array(group.muscles)), secondary: [])
        }
        if let info = ExerciseLibrary.info(id) {
            return DemoMuscles(primary: info.primary, secondary: info.secondary)
        }
        return DemoMuscles()
    }
}

enum Sculpt {
    // MARK: Skeleton

    /// The joints exported with each sample (scripts/demos/demos.py, `SKELETON`).
    enum Joint: Int {
        case pelvis, pelvisU, pelvisR, pelvisF, chest, chestU, chestR, chestF, neck, head, headU, headF
        case shoulderR, shoulderL, elbowR, elbowL, gripR, gripL, hipR, hipL, kneeR, kneeL, ankleR, ankleL, toeR, toeL
    }

    struct Frame {
        let o: Vec3
        let u: Vec3
        let r: Vec3
        let f: Vec3

        func at(f df: Double = 0, u du: Double = 0, r dr: Double = 0) -> Vec3 {
            o + f * df + u * du + r * dr
        }
    }

    struct Limb {
        let a: Vec3
        let b: Vec3
        let front: Vec3
        let away: Vec3
        let profile: [(Double, Double)]
    }

    struct Body {
        let pelvis: Frame
        let chest: Frame
        let neck: Vec3
        let head: Vec3
        let headU: Vec3
        let headF: Vec3
        let headR: Vec3
        var shoulder: [Int: Vec3] = [:]
        var elbow: [Int: Vec3] = [:]
        var grip: [Int: Vec3] = [:]
        var hip: [Int: Vec3] = [:]
        var knee: [Int: Vec3] = [:]
        var ankle: [Int: Vec3] = [:]
        var toe: [Int: Vec3] = [:]
        var limbs: [String: Limb] = [:]

        init?(_ j: [Vec3]) {
            guard j.count >= 26 else { return nil }
            func frame(_ o: Int) -> Frame {
                Frame(o: j[o], u: unit(j[o + 1] - j[o]), r: unit(j[o + 2] - j[o]), f: unit(j[o + 3] - j[o]))
            }
            pelvis = frame(Joint.pelvis.rawValue)
            chest = frame(Joint.chest.rawValue)
            neck = j[Joint.neck.rawValue]
            head = j[Joint.head.rawValue]
            headU = unit(j[Joint.headU.rawValue] - head)
            headF = unit(j[Joint.headF.rawValue] - head)
            headR = cross(headF, headU)
            for (side, offset) in [(1, 0), (-1, 1)] {
                shoulder[side] = j[Joint.shoulderR.rawValue + offset]
                elbow[side] = j[Joint.elbowR.rawValue + offset]
                grip[side] = j[Joint.gripR.rawValue + offset]
                hip[side] = j[Joint.hipR.rawValue + offset]
                knee[side] = j[Joint.kneeR.rawValue + offset]
                ankle[side] = j[Joint.ankleR.rawValue + offset]
                toe[side] = j[Joint.toeR.rawValue + offset]
            }
            let c = chest
            for side in [1, -1] {
                let s = Double(side)
                guard let sh = shoulder[side], let el = elbow[side], let gr = grip[side] else { continue }
                let arm = unit(el - sh)
                let fore = unit(gr - el)
                let bend = fore - arm * dot(fore, arm)
                // A straight arm: its front is the trunk's front made square to it (the biceps faces forward).
                let straight = c.f - arm * dot(c.f, arm)
                let front: Vec3
                if length(bend) > 0.08 {
                    front = unit(bend)
                } else if length(straight) > 0.2 {
                    front = unit(straight)
                } else {
                    // A straight arm pointing forward or back: the biceps faces up. (The trunk's front, along the arm,
                    // made the arm a flat sheet.)
                    front = unit(c.u - arm * dot(c.u, arm))
                }
                var away = unit(cross(arm, front))
                if dot(away, c.r * s) < 0 { away = away * -1 }
                // The forearm's front is the arm's front turned by the bend of the elbow: never along the forearm (at a
                // right angle the arm's front IS the forearm's direction, and the forearm and the hand were flat sheets).
                var turned = front * dot(fore, arm) - arm * dot(fore, front)
                turned = turned - fore * dot(turned, fore)
                let ffront = length(turned) > 0.2 ? unit(turned) : unit(cross(away, fore))
                var faway = unit(cross(fore, ffront))
                if dot(faway, away) < 0 { faway = faway * -1 }
                limbs["arm\(side)"] = Limb(a: sh, b: el, front: front, away: away,
                                           profile: [(0, 0.06), (0.18, 0.058), (0.45, 0.053), (0.75, 0.046), (0.92, 0.04), (1, 0.04)])
                limbs["fore\(side)"] = Limb(a: el, b: gr, front: ffront, away: faway,
                                            profile: [(0, 0.042), (0.18, 0.047), (0.4, 0.043), (0.75, 0.031), (1, 0.026)])
            }
            for side in [1, -1] {
                let s = Double(side)
                guard let hp = hip[side], let kn = knee[side], let an = ankle[side] else { continue }
                let thigh = unit(kn - hp)
                let shin = unit(an - kn)
                // A leg along the hips' axis (side split): its front is the pelvis's front made square to it.
                let tCross = cross(pelvis.r, thigh), sCross = cross(pelvis.r, shin)
                let tf = length(tCross) > 0.2 ? unit(tCross) : unit(pelvis.f - thigh * dot(pelvis.f, thigh))
                let sf = length(sCross) > 0.2 ? unit(sCross) : unit(pelvis.f - shin * dot(pelvis.f, shin))
                // The outer side, square to the limb (the hips' axis itself squashed a leg opened to the side).
                var ta = cross(thigh, tf), sa = cross(shin, sf)
                if dot(ta, pelvis.r * s) < 0 { ta = ta * -1 }
                if dot(sa, pelvis.r * s) < 0 { sa = sa * -1 }
                if abs(dot(thigh, pelvis.r)) < 0.3 { ta = pelvis.r * s }
                if abs(dot(shin, pelvis.r)) < 0.3 { sa = pelvis.r * s }
                limbs["thigh\(side)"] = Limb(a: hp, b: kn, front: tf, away: ta,
                                             profile: [(-0.04, 0.072), (0.08, 0.084), (0.2, 0.086), (0.45, 0.076), (0.75, 0.063), (0.92, 0.052), (1, 0.05)])
                limbs["shin\(side)"] = Limb(a: kn, b: an, front: sf, away: sa,
                                            profile: [(0, 0.049), (0.12, 0.052), (0.3, 0.057), (0.5, 0.049), (0.75, 0.036), (0.92, 0.031), (1, 0.031)])
            }
        }

        /// Trunk sections (height from the waist): half-width, half-depth. A neutral build.
        static let trunkTable: [(Double, Double, Double)] = [
            (-0.215, 0.105, 0.08), (-0.19, 0.138, 0.096), (-0.15, 0.155, 0.104), (-0.08, 0.160, 0.107), (0.0, 0.133, 0.092),
            (0.10, 0.139, 0.098), (0.20, 0.152, 0.107), (0.27, 0.164, 0.111), (0.31, 0.172, 0.106), (0.34, 0.168, 0.096),
            (0.36, 0.148, 0.086), (0.375, 0.115, 0.074), (0.39, 0.078, 0.062), (0.405, 0.056, 0.054),
        ]

        func trunk(_ u: Double, _ phi: Double, _ s: Double, lift: Double = 1) -> Vec3 {
            let (w, d) = Sculpt.ease3(Self.trunkTable, u)
            let a = phi * .pi / 180
            return chest.at(f: d * cos(a) * lift, u: u, r: w * sin(a) * s * lift)
        }

        func trunkNormal(_ u: Double, _ phi: Double, _ s: Double) -> Vec3 {
            let (w, d) = Sculpt.ease3(Self.trunkTable, u)
            let a = phi * .pi / 180
            return unit(chest.r * (sin(a) * s / w) + chest.f * (cos(a) / d))
        }

        func limb(_ key: String, _ t: Double, _ theta: Double, lift: Double = 1) -> Vec3? {
            guard let l = limbs[key] else { return nil }
            let r = Sculpt.ease2(l.profile, t)
            let a = theta * .pi / 180
            return Sculpt.mix(l.a, l.b, t) + (l.front * cos(a) + l.away * sin(a)) * (r * lift)
        }

        func limbNormal(_ key: String, _ theta: Double) -> Vec3? {
            guard let l = limbs[key] else { return nil }
            let a = theta * .pi / 180
            return unit(l.front * cos(a) + l.away * sin(a))
        }

        func point(_ spot: Spot, _ side: Int, lift: Double) -> Vec3? {
            switch spot {
            case let .t(u, phi): trunk(u, phi, Double(side), lift: lift)
            case let .l(kind, t, theta): limb("\(kind)\(side)", t, theta, lift: lift)
            }
        }

        func normal(_ spot: Spot, _ side: Int) -> Vec3? {
            switch spot {
            case let .t(u, phi): trunkNormal(u, phi, Double(side))
            case let .l(kind, _, theta): limbNormal("\(kind)\(side)", theta)
            }
        }
    }

    // MARK: Muscles (origin → insertion), as on scripts/demos/sculpt.py

    /// A point of the surface: on the trunk (height, angle: 0 front, 90 the side, 180 back) or on a limb (arm, fore,
    /// thigh, shin; t along it; angle 0 front, 90 outer side, 180 back, -90 inner side).
    enum Spot {
        case t(Double, Double)
        case l(String, Double, Double)
    }

    struct MuscleShape {
        let group: String
        let outline: [Spot]
        var grooves: [[Spot]] = []
        var lift: Double = 1.03
    }

    static let muscles: [MuscleShape] = [
        // Pectoralis major: clavicle and sternum → humerus; clavicular and sternal parts.
        MuscleShape(group: "chest", outline: [.t(0.372, 4), .t(0.378, 30), .t(0.362, 56), .l("arm", 0.14, -25), .l("arm", 0.21, -40),
                                              .t(0.275, 74), .t(0.225, 58), .t(0.205, 34), .t(0.2, 4)],
                    grooves: [[.t(0.33, 4), .t(0.335, 30), .l("arm", 0.16, -30)]]),
        // Deltoid: clavicle, acromion, scapular spine → deltoid tuberosity; anterior, lateral, posterior heads.
        MuscleShape(group: "shoulders", outline: [.t(0.368, 44), .l("arm", 0.1, -52), .l("arm", 0.3, -32), .l("arm", 0.47, 28),
                                                  .l("arm", 0.3, 118), .l("arm", 0.1, 150), .t(0.352, 128), .t(0.376, 88)],
                    grooves: [[.t(0.372, 64), .l("arm", 0.4, 12)], [.t(0.366, 110), .l("arm", 0.4, 60)]], lift: 1.12),
        // Biceps: shoulder → radius below the elbow; long and short heads. Brachialis beside it.
        MuscleShape(group: "biceps", outline: [.l("arm", 0.2, -28), .l("arm", 0.2, 22), .l("arm", 0.55, 42), .l("arm", 0.86, 26),
                                               .l("fore", 0.1, 12), .l("arm", 0.86, -14), .l("arm", 0.55, -38)],
                    grooves: [[.l("arm", 0.22, -3), .l("arm", 0.82, 5)]], lift: 1.1),
        MuscleShape(group: "biceps", outline: [.l("arm", 0.58, 52), .l("arm", 0.9, 70), .l("fore", 0.06, 50), .l("arm", 0.9, 38)], lift: 1.04),
        // Triceps: scapula and humerus → olecranon; long, lateral and medial heads.
        MuscleShape(group: "triceps", outline: [.l("arm", 0.16, 118), .l("arm", 0.16, 210), .l("arm", 0.55, 228), .l("arm", 0.82, 200),
                                                .l("arm", 0.99, 182), .l("arm", 0.82, 150), .l("arm", 0.55, 112)],
                    grooves: [[.l("arm", 0.2, 165), .l("arm", 0.62, 172)], [.l("arm", 0.62, 140), .l("arm", 0.72, 175), .l("arm", 0.62, 215)]], lift: 1.08),
        // Forearm: brachioradialis, flexors, extensors.
        MuscleShape(group: "forearms", outline: [.l("arm", 0.68, 62), .l("arm", 0.72, 95), .l("fore", 0.3, 85), .l("fore", 0.82, 55), .l("fore", 0.3, 45)], lift: 1.08),
        MuscleShape(group: "forearms", outline: [.l("fore", 0.02, -15), .l("fore", 0.02, -85), .l("fore", 0.45, -75), .l("fore", 0.85, -30), .l("fore", 0.45, 8)], lift: 1.05),
        MuscleShape(group: "forearms", outline: [.l("fore", 0.04, 100), .l("fore", 0.04, 175), .l("fore", 0.5, 175), .l("fore", 0.86, 130), .l("fore", 0.5, 105)], lift: 1.05),
        // Rectus abdominis (with its tendinous lines), external oblique, serratus anterior.
        MuscleShape(group: "abs", outline: [.t(0.205, 3), .t(0.205, 27), .t(0.1, 27), .t(0, 24), .t(-0.1, 16), .t(-0.165, 5)],
                    grooves: [[.t(0.155, 3), .t(0.158, 27)], [.t(0.105, 3), .t(0.108, 27)], [.t(0.05, 3), .t(0.052, 25)]]),
        MuscleShape(group: "abs", outline: [.t(0.2, 50), .t(0.19, 82), .t(0.02, 95), .t(-0.08, 86), .t(-0.11, 60), .t(-0.02, 34), .t(0.12, 30)]),
        MuscleShape(group: "abs", outline: [.t(0.29, 68), .t(0.27, 84), .t(0.19, 86), .t(0.17, 72), .t(0.23, 62)],
                    grooves: [[.t(0.25, 64), .t(0.245, 85)], [.t(0.215, 66), .t(0.21, 85)]]),
        // Trapezius: skull and spine → clavicle, acromion, scapular spine; upper, middle, lower parts.
        MuscleShape(group: "traps", outline: [.t(0.41, 178), .t(0.405, 140), .t(0.372, 110), .t(0.335, 122), .t(0.315, 150), .t(0.17, 177)],
                    grooves: [[.t(0.392, 168), .t(0.35, 128)], [.t(0.3, 177), .t(0.318, 152)]]),
        // Infraspinatus, teres major, latissimus dorsi (spine and pelvis → under the armpit).
        MuscleShape(group: "back", outline: [.t(0.31, 152), .t(0.312, 122), .t(0.245, 115), .t(0.21, 135), .t(0.25, 160)]),
        MuscleShape(group: "back", outline: [.t(0.245, 112), .t(0.27, 100), .l("arm", 0.14, 185), .t(0.225, 112)], lift: 1.04),
        MuscleShape(group: "back", outline: [.t(0.24, 176), .t(0.235, 150), .t(0.215, 120), .t(0.27, 104), .t(0.14, 98), .t(0.02, 104),
                                             .t(-0.04, 150), .t(-0.02, 176)]),
        // Erector spinae.
        MuscleShape(group: "lowerBack", outline: [.t(0.21, 177), .t(0.21, 162), .t(0.02, 160), .t(-0.06, 165), .t(-0.07, 177)]),
        // Gluteus maximus (pelvis and sacrum → femur), gluteus medius.
        MuscleShape(group: "glutes", outline: [.t(-0.06, 172), .t(-0.05, 128), .t(-0.12, 104), .l("thigh", 0.2, 105), .l("thigh", 0.22, 160), .t(-0.21, 176)], lift: 1.06),
        MuscleShape(group: "glutes", outline: [.t(-0.01, 100), .t(0, 138), .t(-0.05, 145), .t(-0.1, 104)]),
        // Quadriceps: rectus femoris, vastus lateralis, vastus medialis; sartorius.
        MuscleShape(group: "quads", outline: [.l("thigh", 0.04, -8), .l("thigh", 0.04, 14), .l("thigh", 0.5, 22), .l("thigh", 0.9, 9),
                                              .l("thigh", 0.9, -9), .l("thigh", 0.5, -20)], lift: 1.08),
        MuscleShape(group: "quads", outline: [.l("thigh", 0.12, 26), .l("thigh", 0.12, 100), .l("thigh", 0.55, 104), .l("thigh", 0.92, 62),
                                              .l("thigh", 0.96, 22), .l("thigh", 0.55, 26)], lift: 1.06),
        MuscleShape(group: "quads", outline: [.l("thigh", 0.55, -22), .l("thigh", 0.72, -58), .l("thigh", 0.93, -50), .l("thigh", 0.97, -16),
                                              .l("thigh", 0.82, -12)], lift: 1.08),
        MuscleShape(group: "quads", outline: [.l("thigh", -0.02, 48), .l("thigh", 0.06, 36), .l("thigh", 0.5, -32), .l("thigh", 0.95, -78),
                                              .l("thigh", 0.97, -95), .l("thigh", 0.55, -52), .l("thigh", 0.1, 20)], lift: 1.1),
        // Adductors.
        MuscleShape(group: "adductors", outline: [.l("thigh", 0, -32), .l("thigh", 0, -118), .l("thigh", 0.5, -112), .l("thigh", 0.62, -72),
                                                  .l("thigh", 0.25, -34)]),
        // Hamstrings: biceps femoris and semitendinosus (ischium → below the knee).
        MuscleShape(group: "hamstrings", outline: [.l("thigh", 0.1, 116), .l("thigh", 0.1, 215), .l("thigh", 0.6, 238), .l("thigh", 0.97, 230),
                                                   .l("thigh", 0.97, 120), .l("thigh", 0.6, 110)],
                    grooves: [[.l("thigh", 0.12, 168), .l("thigh", 0.9, 172)]], lift: 1.06),
        // Calf: gastrocnemius (femoral condyles → Achilles tendon), soleus; tibialis anterior in front.
        MuscleShape(group: "calves", outline: [.l("shin", -0.02, 110), .l("shin", -0.02, 250), .l("shin", 0.3, 255), .l("shin", 0.58, 205),
                                               .l("shin", 0.6, 175), .l("shin", 0.5, 140), .l("shin", 0.26, 105)],
                    grooves: [[.l("shin", 0, 178), .l("shin", 0.5, 180)]], lift: 1.1),
        MuscleShape(group: "calves", outline: [.l("shin", 0.32, 100), .l("shin", 0.32, 260), .l("shin", 0.82, 215), .l("shin", 0.82, 145)]),
        MuscleShape(group: "calves", outline: [.l("shin", 0.05, 8), .l("shin", 0.05, 58), .l("shin", 0.6, 42), .l("shin", 0.92, 4), .l("shin", 0.6, 12)], lift: 1.05),
    ]

    // MARK: Pieces

    /// One thing to draw at its depth: a piece of the plastic body (with its limb axis for the sheen) or a muscle.
    /// The body comes in slices (2026-11-24): each pair of sections of the trunk or of a limb is a piece at its own
    /// depth, so a pad or a bar that touches the body is painted on the right side of every slice (a whole trunk sorted
    /// by its middle let a backrest be painted over the shoulders lying on it). `DemoRenderer` draws together the
    /// slices of a part that nothing separates, and each muscle right after the slices it lies on.
    struct Piece {
        enum Kind {
            case skin(axis: (CGPoint, CGPoint, Double)?, far: Double)
            case muscle(level: Int, grooves: [Path])
        }
        let depth: Double
        let path: Path
        let kind: Kind
        /// Skin: the body part whose slices it belongs to (`Part`); -1 for a muscle.
        var part: Int = -1
        /// Skin: where the piece lies (part, position along it; a ball joint lies on the two limbs it joins).
        /// Muscle: the stretch of each part it is drawn on.
        var spans: [Span] = []
        /// What it covers on screen.
        var box: CGRect = .null
        /// Skin: how thick the body is there, from its axis to its surface, in metres.
        var radius: Double = 0
        /// Muscle: the contours of its belly above the outline, from the widest to the top of the dome.
        var layers: [Path] = []
    }

    /// How far the belly of each muscle rises above the skin, in metres (CEO, 2026-11-24: « une représentation des tissus
    /// musculaires en 3D et pas juste des plans »). Athletic, not a bodybuilder. The same as scripts/demos/sculpt.py.
    static let bulge: [String: Double] = [
        "chest": 0.018, "shoulders": 0.018, "biceps": 0.02, "triceps": 0.016, "forearms": 0.011, "abs": 0.008, "traps": 0.011,
        "back": 0.012, "lowerBack": 0.008, "glutes": 0.022, "quads": 0.018, "adductors": 0.011, "hamstrings": 0.018,
        "calves": 0.02,
    ]

    /// A stretch of a body part: the trunk by its height from the waist, a limb by the fraction along it.
    struct Span {
        let part: Int
        let lo: Double
        let hi: Double
    }

    /// The body parts, as numbers (the keys of the slices drawn together).
    enum Part {
        static let trunk = 0, neck = 1, head = 2, joint = 30, hand = 40, foot = 42

        static func limb(_ kind: String, _ side: Int) -> Int {
            let base: Int
            switch kind {
            case "arm": base = 10
            case "fore": base = 12
            case "thigh": base = 14
            default: base = 16
            }
            return base + (side == 1 ? 0 : 1)
        }
    }

    /// What is seen of a volume is its surface, in front of its axis: a slice of the body, a bar or a ball is sorted
    /// nearer than its axis by this share of its radius (measured on every demonstration with
    /// scripts/demos/occlusion.py).
    static let lift = 0.6

    static func bounds(_ points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points.dropFirst() {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// The camera of a demonstration's view: screen point and depth (larger is farther).
    struct Camera {
        let project: (Vec3) -> (CGPoint, Double)
        let toward: Vec3
        let scale: Double
    }

    /// The pieces of the body and its muscles for a skeleton. `fine`: the demonstration sheet (more sections); thumbnails
    /// use fewer.
    static func pieces(joints: [Vec3], camera: Camera, muscles lit: DemoMuscles, fine: Bool) -> (pieces: [Piece], body: Path)? {
        guard let body = Body(joints) else { return nil }
        var out: [Piece] = []
        var union = Path()
        let step = fine ? 15.0 : 30.0
        let angles: [Double] = stride(from: 0.0, to: 360.0, by: step).map { $0 }
        let c = body.chest

        // Which side is farther from the camera: drawn a little darker.
        let rightDepth = camera.project(body.shoulder[1] ?? c.o).1
        let leftDepth = camera.project(body.shoulder[-1] ?? c.o).1
        let farSide = min(1, max(-1, (leftDepth - rightDepth) / 0.35))   // > 0: the left is farther
        func far(_ side: Int) -> Double { side == 1 ? max(0, -farSide) : max(0, farSide) }

        /// A swept volume, one piece per pair of sections; `positions`: where each section lies along its part.
        func add(_ rings: [[Vec3]], at positions: [Double], part: Int, axis: (Vec3, Vec3, Double)?, far shade: Double = 0) {
            var screenAxis: (CGPoint, CGPoint, Double)?
            if let axis { screenAxis = (camera.project(axis.0).0, camera.project(axis.1).0, axis.2 * camera.scale) }
            var slices: [(points: [CGPoint], depth: Double, radius: Double)] = []
            slices.reserveCapacity(rings.count)
            for ring in rings {
                var pts: [CGPoint] = []
                pts.reserveCapacity(ring.count)
                var depth = 0.0
                for q in ring {
                    let (pt, z) = camera.project(q)
                    pts.append(pt)
                    depth += z
                }
                // The first point of a section is its front, the middle one its back.
                let radius = ring.count >= 2 ? length(ring[0] - ring[ring.count / 2]) / 2 : 0
                slices.append((pts, depth, radius))
            }
            guard slices.count >= 2 else { return }
            for k in 0..<(slices.count - 1) {
                let pts = slices[k].points + slices[k + 1].points
                guard !pts.isEmpty else { continue }
                let path = smoothPath(hull(pts), tension: 9)
                union.addPath(path)
                let position = k + 1 < positions.count ? (positions[k] + positions[k + 1]) / 2 : 0
                out.append(Piece(depth: (slices[k].depth + slices[k + 1].depth) / Double(pts.count), path: path,
                                 kind: .skin(axis: screenAxis, far: shade), part: part,
                                 spans: [Span(part: part, lo: position, hi: position)], box: bounds(pts),
                                 radius: (slices[k].radius + slices[k + 1].radius) / 2))
            }
        }

        func ellipsoid(_ center: Vec3, _ a0: Vec3, _ a1: Vec3, _ a2: Vec3, part: Int, far shade: Double = 0, bias: Double = 0) {
            var pts: [CGPoint] = []
            let rows = fine ? 9 : 6, cols = fine ? 14 : 9
            for i in 1..<rows {
                let th = Double.pi * Double(i) / Double(rows)
                for jx in 0..<cols {
                    let ph = 2 * Double.pi * Double(jx) / Double(cols)
                    pts.append(camera.project(center + a0 * cos(th) + a1 * (sin(th) * cos(ph)) + a2 * (sin(th) * sin(ph))).0)
                }
            }
            pts.append(camera.project(center + a0).0)
            pts.append(camera.project(center - a0).0)
            let path = smoothPath(hull(pts), tension: 7)
            union.addPath(path)
            out.append(Piece(depth: camera.project(center).1 + bias, path: path, kind: .skin(axis: nil, far: shade),
                             part: part, box: bounds(pts), radius: min(length(a0), length(a1), length(a2))))
        }

        /// A ball joint, lying on the limbs it joins.
        var jointCount = 0
        func ball(_ center: Vec3, _ r: Double, on spans: [Span], far shade: Double) {
            let (pt, z) = camera.project(center)
            let rr = r * camera.scale
            let rect = CGRect(x: pt.x - rr, y: pt.y - rr, width: 2 * rr, height: 2 * rr)
            let path = Path(ellipseIn: rect)
            union.addPath(path)
            out.append(Piece(depth: z, path: path, kind: .skin(axis: nil, far: shade), part: Part.joint + jointCount,
                             spans: spans, box: rect, radius: r))
            jointCount += 1
        }

        // Trunk.
        let lo = Body.trunkTable.first!.0, hi = Body.trunkTable.last!.0
        let sections = fine ? 26 : 12
        let us = (0...sections).map { lo + (hi - lo) * Double($0) / Double(sections) }
        add(us.map { u in angles.map { body.trunk(u, $0, 1) } }, at: us, part: Part.trunk, axis: nil)
        // Neck and head.
        let nb = body.neck - c.u * 0.04, nt = body.head - body.headU * 0.07
        let neckSteps: [Double] = [0.0, 0.5, 1.0]
        add(neckSteps.map { t in angles.map { a in
            mix(nb, nt, t) + (c.r * sin(a * .pi / 180) + c.f * cos(a * .pi / 180)) * (0.056 - 0.01 * t)
        } }, at: neckSteps, part: Part.neck, axis: nil)
        ellipsoid(body.head + body.headU * 0.012, body.headU * 0.122, body.headF * 0.098, body.headR * 0.083, part: Part.head, bias: -0.01)
        ellipsoid(body.head - body.headU * 0.05 + body.headF * 0.02, body.headU * 0.06, body.headF * 0.07, body.headR * 0.062,
                  part: Part.head, bias: -0.008)
        // Limbs.
        let limbSections = fine ? 12 : 6
        for (key, l) in body.limbs.sorted(by: { $0.key < $1.key }) {
            let side = key.hasSuffix("-1") ? -1 : 1
            let kind = String(key.dropLast(side == -1 ? 2 : 1))
            let t0 = l.profile.first!.0, t1 = l.profile.last!.0
            let ts = (0...limbSections).map { t0 + (t1 - t0) * Double($0) / Double(limbSections) }
            add(ts.map { t in angles.compactMap { body.limb(key, t, $0) } }, at: ts, part: Part.limb(kind, side),
                axis: (l.a, l.b, ease2(l.profile, 0.5)), far: far(side))
        }
        // Ball joints, hands, feet.
        for side in [1, -1] {
            let shade = far(side)
            let arm = Part.limb("arm", side), fore = Part.limb("fore", side)
            let thigh = Part.limb("thigh", side), shin = Part.limb("shin", side)
            if let sh = body.shoulder[side], let el = body.elbow[side], let gr = body.grip[side] {
                ball(sh + unit(el - sh) * 0.03, 0.05, on: [Span(part: arm, lo: 0.1, hi: 0.1)], far: shade)
                ball(el, 0.041, on: [Span(part: arm, lo: 1, hi: 1), Span(part: fore, lo: 0, hi: 0)], far: shade)
                ball(gr - unit(gr - el) * 0.02, 0.028, on: [Span(part: fore, lo: 1, hi: 1)], far: shade)
                if let foreLimb = body.limbs["fore\(side)"] {
                    let d = unit(gr - el)
                    let hand = Part.hand + (side == 1 ? 0 : 1)
                    ellipsoid(gr + d * 0.035, d * 0.058, foreLimb.away * 0.034, foreLimb.front * 0.019, part: hand, far: shade)
                    ellipsoid(gr + d * 0.01 + foreLimb.front * 0.02 - foreLimb.away * 0.012, d * 0.03, foreLimb.front * 0.012,
                              foreLimb.away * 0.012, part: hand, far: shade, bias: -0.004)
                }
            }
            if let kn = body.knee[side], let an = body.ankle[side], let to = body.toe[side] {
                ball(kn, 0.05, on: [Span(part: thigh, lo: 1, hi: 1), Span(part: shin, lo: 0, hi: 0)], far: shade)
                ball(an, 0.033, on: [Span(part: shin, lo: 1, hi: 1)], far: shade)
                let dir = unit(to - an)
                let flat = Vec3(dir.x, 0, dir.z)
                var level = length(flat) > 1e-3 ? unit(flat) : dir
                var up = Vec3(0, 1, 0)
                var lateral = body.pelvis.r
                // A foot on the ground is built level, its sole down. A foot that points up or down (the back foot of a
                // stride, a handstand, a plank on the toes) takes its own top instead, toward the shin: built on the
                // vertical, it was a flat sheet.
                var steep = min(1.0, max(0.0, (abs(dir.y) - 0.45) / 0.35))
                steep = steep * steep * (3 - 2 * steep)
                if steep > 0 {
                    var top = kn - an
                    top = top - dir * dot(top, dir)
                    if length(top) < 0.15 { top = cross(lateral, dir) }
                    top = unit(top)
                    // Upside down (legs in the air): no blend with the vertical, they would cancel.
                    if dot(top, up) < 0.2 { steep = 1 }
                    up = unit(up * (1 - steep) + top * steep)
                    var along = level * (1 - steep) + dir * steep
                    along = along - up * dot(along, up)
                    level = length(along) > 0.2 ? unit(along) : dir
                }
                // The foot's width, square to its length and its height (the hips' axis squashed a foot turned to the side).
                if abs(dot(level, cross(up, lateral))) < 0.8 || abs(dot(dir, cross(up, lateral))) < 0.8 {
                    let across = cross(up, dir)
                    if length(across) > 0.2 { lateral = dot(across, lateral) >= 0 ? unit(across) : unit(across) * -1 }
                }
                let foot = Part.foot + (side == 1 ? 0 : 1)
                ellipsoid(an - level * 0.035 - up * 0.035, level * 0.04, up * 0.03, lateral * 0.032, part: foot, far: shade)
                ellipsoid(mix(an, to, 0.55) - up * 0.012, dir * 0.11, up * 0.026, lateral * 0.04, part: foot, far: shade)
            }
        }
        // Muscles.
        for shape in muscles {
            for side in [1, -1] {
                var pts: [CGPoint] = []
                var world: [Vec3] = []
                var normals: [Vec3] = []
                var depth = 0.0
                var sum = Vec3(0, 0, 0)
                var complete = true
                for spot in shape.outline {
                    guard let q = body.point(spot, side, lift: 1.01), let n = body.normal(spot, side) else { complete = false; break }
                    let (pt, z) = camera.project(q)
                    pts.append(pt)
                    world.append(q)
                    normals.append(n)
                    depth += z
                    sum += n
                }
                guard complete, !pts.isEmpty else { continue }
                let normal = unit(sum)
                if dot(normal, camera.toward) < -0.05 { continue }
                // A muscle is a volume (2026-11-24): its outline lies on the skin, its belly rises above it as a dome —
                // the outline drawn smaller and smaller toward the middle, higher and higher along the muscle's normal.
                var center = Vec3(0, 0, 0)
                for q in world { center += q }
                center = center / Double(world.count)
                // The skin itself is curved: over the middle of the outline it is already above the outline's plane.
                var sag = 0.0, reach = 0.0
                for (q, n) in zip(world, normals) {
                    sag += dot(q - center, n)
                    reach += length(q - center)
                }
                sag = max(0, 0.5 * sag / Double(world.count))
                reach = max(reach / Double(world.count), 1e-6)
                let height = bulge[shape.group] ?? 0.01
                var layers: [Path] = []
                var covered = pts
                let shares: [Double] = fine ? [0.82, 0.62, 0.4] : [0.6]
                for share in shares {
                    let rise = (sag + height) * (1 - share * share)
                    let contour = world.map { q in camera.project(center + (q - center) * share + normal * rise).0 }
                    covered += contour
                    layers.append(smoothPath(contour, tension: 6.5))
                }
                var grooves: [Path] = []
                for line in shape.grooves {
                    var gpts: [CGPoint] = []
                    for spot in line {
                        guard let q = body.point(spot, side, lift: 1.01) else { continue }
                        let share = min(1, length(q - center) / reach)
                        gpts.append(camera.project(q + normal * (height * (1 - share * share))).0)
                    }
                    guard gpts.count >= 2 else { continue }
                    var g = Path()
                    g.addLines(gpts)
                    grooves.append(g)
                }
                let level = lit.primary.contains(shape.group) ? 2 : (lit.secondary.contains(shape.group) ? 1 : 0)
                // The stretch of each part it lies on, one slice wider at both ends.
                var stretch: [Int: (Double, Double)] = [:]
                for spot in shape.outline {
                    let located: (part: Int, value: Double)
                    switch spot {
                    case let .t(u, _): located = (Part.trunk, u)
                    case let .l(kind, t, _): located = (Part.limb(kind, side), t)
                    }
                    let known = stretch[located.part] ?? (located.value, located.value)
                    stretch[located.part] = (min(known.0, located.value), max(known.1, located.value))
                }
                var spans: [Span] = []
                for part in stretch.keys.sorted() {
                    guard let range = stretch[part] else { continue }
                    let pad = part == Part.trunk ? (hi - lo) / Double(sections) : 1.0 / Double(limbSections)
                    spans.append(Span(part: part, lo: range.0 - pad, hi: range.1 + pad))
                }
                out.append(Piece(depth: depth / Double(pts.count) - 0.01, path: smoothPath(pts, tension: 6.5),
                                 kind: .muscle(level: level, grooves: grooves), spans: spans, box: bounds(covered),
                                 layers: layers))
            }
        }
        return (out, union)
    }

    // MARK: Drawing

    struct Palette {
        let skin: Color
        let hi: Color
        let lo: Color
        let groove: Color
        let red: Color
        let redHi: Color
        let redLo: Color
        let pink: Color
        let pinkHi: Color
        let pinkLo: Color

        init(dark: Bool) {
            if dark {
                skin = Color(hex: "C4C7CC"); hi = Color(hex: "EEF0F2"); lo = Color(hex: "7E838B"); groove = Color(hex: "5E636B")
            } else {
                skin = Color(hex: "D5D8DC"); hi = Color(hex: "FFFFFF"); lo = Color(hex: "959AA2"); groove = Color(hex: "7A7F87")
            }
            red = Color(hex: "E5484D"); redHi = Color(hex: "FF8F93"); redLo = Color(hex: "9E1C22")
            pink = Color(hex: "EF9A9D"); pinkHi = Color(hex: "FFC7C9"); pinkLo = Color(hex: "B8686C")
        }
    }

    /// `clip`: a muscle whose part is cut by the equipment is drawn once per run of slices, inside those slices only.
    static func draw(_ piece: Piece, body: Path, in context: inout GraphicsContext, size: CGSize, palette: Palette, fine: Bool,
                     clip: Path? = nil) {
        let w = Double(size.width), h = Double(size.height)
        let start = CGPoint(x: w * 0.15, y: 0), end = CGPoint(x: w * 0.85, y: h)
        let g = max(0.6, w / 220)
        func shading(_ a: Color, _ b: Color, _ c: Color) -> GraphicsContext.Shading {
            .linearGradient(Gradient(colors: [a, b, c]), startPoint: start, endPoint: end)
        }
        switch piece.kind {
        case let .skin(axis, far):
            context.fill(piece.path, with: shading(palette.hi, palette.skin, palette.lo))
            context.stroke(piece.path, with: shading(palette.hi, palette.skin, palette.lo), lineWidth: 0.6)
            if far > 0.02 { context.fill(piece.path, with: .color(.black.opacity(0.16 * far))) }
            if let axis {
                let (a, b, r) = axis
                let dx = Double(b.x - a.x), dy = Double(b.y - a.y)
                let n = (dx * dx + dy * dy).squareRoot()
                if n > 2 {
                    var px = -dy / n, py = dx / n
                    if px * -0.62 + py * -0.78 < 0 { px = -px; py = -py }
                    var layer = context
                    layer.clip(to: piece.path)
                    // Plastic sheen: light along the lit side, shade along the other; stacked strokes for soft edges.
                    // Thumbnails: one stroke each side (many loop at once); the sheet: stacked strokes for soft edges.
                    for (k, op) in (fine ? [(1.0, 0.10), (0.6, 0.14), (0.3, 0.2)] : [(0.6, 0.3)]) {
                        var line = Path()
                        line.move(to: CGPoint(x: Double(a.x) + px * r * 0.42, y: Double(a.y) + py * r * 0.42))
                        line.addLine(to: CGPoint(x: Double(b.x) + px * r * 0.42, y: Double(b.y) + py * r * 0.42))
                        layer.stroke(line, with: .color(.white.opacity(op)), style: StrokeStyle(lineWidth: CGFloat(r * 0.5 * k), lineCap: .round))
                    }
                    for (k, op) in (fine ? [(1.0, 0.07), (0.6, 0.09)] : [(0.8, 0.12)]) {
                        var line = Path()
                        line.move(to: CGPoint(x: Double(a.x) - px * r * 0.95, y: Double(a.y) - py * r * 0.95))
                        line.addLine(to: CGPoint(x: Double(b.x) - px * r * 0.95, y: Double(b.y) - py * r * 0.95))
                        layer.stroke(line, with: .color(.black.opacity(op)), style: StrokeStyle(lineWidth: CGFloat(r * 0.8 * k), lineCap: .round))
                    }
                }
            }
        case let .muscle(level, grooves):
            var layer = context
            if let clip { layer.clip(to: clip) } else if fine { layer.clip(to: body) }
            let fill: GraphicsContext.Shading
            let groove: Color
            switch level {
            case 2:
                fill = shading(palette.redHi, palette.red, palette.redLo)
                groove = palette.redLo
            case 1:
                fill = shading(palette.pinkHi, palette.pink, palette.pinkLo)
                groove = palette.pinkLo
            default:
                fill = shading(palette.hi, palette.skin, palette.lo)
                groove = palette.groove
            }
            layer.fill(piece.path, with: fill)
            // The belly of the muscle: each contour of its dome a little lighter than the one below, lit from the upper
            // left. It may rise past the outline of the body (a calf, a biceps seen from the side).
            func belly() {
                var top = context
                if let clip { top.clip(to: clip) }
                let count = piece.layers.count
                for (index, contour) in piece.layers.enumerated() {
                    top.fill(contour, with: fill)
                    let box = contour.boundingRect
                    top.fill(contour, with: .linearGradient(Gradient(colors: [.white.opacity(0.2), .clear, .black.opacity(0.2)]),
                                                            startPoint: CGPoint(x: box.minX, y: box.minY),
                                                            endPoint: CGPoint(x: box.maxX, y: box.maxY)))
                    let below = Double(count - 1 - index) / Double(max(count - 1, 1))
                    if below > 0 { top.fill(contour, with: .color(.black.opacity((level > 0 ? 0.1 : 0.045) * below))) }
                }
            }
            guard fine else {
                // Thumbnails: the outline as a light groove, no clipping (cheap enough for many at once).
                layer.stroke(piece.path, with: .color(groove.opacity(0.45)), lineWidth: max(0.5, g * 0.8))
                belly()
                return
            }
            // Relief: a shade inside the lower-right edge, a light inside the upper-left one, the grooves between portions.
            var inner = layer
            inner.clip(to: piece.path)
            let shade = piece.path.applying(CGAffineTransform(translationX: g * 1.2, y: g * 1.4))
            let light = piece.path.applying(CGAffineTransform(translationX: -g * 1.3, y: -g * 1.5))
            inner.stroke(shade, with: .color(groove.opacity(0.22)), lineWidth: g * 3.2)
            inner.stroke(shade, with: .color(groove.opacity(0.3)), lineWidth: g * 1.5)
            inner.stroke(light, with: .color(.white.opacity(level > 0 ? 0.14 : 0.22)), lineWidth: g * 2.2)
            inner.stroke(light, with: .color(.white.opacity(level > 0 ? 0.12 : 0.2)), lineWidth: g * 1.0)
            // The rim sits in the shade of the belly.
            layer.fill(piece.path, with: .color(.black.opacity(level > 0 ? 0.16 : 0.07)))
            belly()
            var over = context
            if let clip { over.clip(to: clip) }
            for line in grooves {
                over.stroke(line, with: .color(groove.opacity(0.22)), style: StrokeStyle(lineWidth: g * 2.4, lineCap: .round))
                over.stroke(line, with: .color(groove.opacity(0.35)), style: StrokeStyle(lineWidth: g * 1.1, lineCap: .round))
            }
        }
    }

    // MARK: Geometry

    static func hull(_ points: [CGPoint]) -> [CGPoint] {
        let pts = points.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
        guard pts.count >= 3 else { return pts }
        func turn(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat { (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) }
        var lower: [CGPoint] = []
        for p in pts {
            while lower.count >= 2 && turn(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }
            lower.append(p)
        }
        var upper: [CGPoint] = []
        for p in pts.reversed() {
            while upper.count >= 2 && turn(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }
            upper.append(p)
        }
        return Array(lower.dropLast()) + Array(upper.dropLast())
    }

    /// A closed smooth outline through the points (Catmull-Rom as cubic Béziers).
    static func smoothPath(_ p: [CGPoint], tension: Double) -> Path {
        var path = Path()
        let n = p.count
        guard n >= 3 else { return path }
        let k = CGFloat(tension)
        path.move(to: p[0])
        for i in 0..<n {
            let p0 = p[(i - 1 + n) % n], p1 = p[i], p2 = p[(i + 1) % n], p3 = p[(i + 2) % n]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / k, y: p1.y + (p2.y - p0.y) / k)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / k, y: p2.y - (p3.y - p1.y) / k)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }

    static func ease3(_ table: [(Double, Double, Double)], _ x: Double) -> (Double, Double) {
        let v = min(max(x, table.first!.0), table.last!.0)
        for k in 0..<(table.count - 1) {
            let a = table[k], b = table[k + 1]
            if a.0 <= v && v <= b.0 {
                var f = b.0 > a.0 ? (v - a.0) / (b.0 - a.0) : 0
                f = f * f * (3 - 2 * f)
                return (a.1 + (b.1 - a.1) * f, a.2 + (b.2 - a.2) * f)
            }
        }
        return (table.last!.1, table.last!.2)
    }

    static func ease2(_ table: [(Double, Double)], _ x: Double) -> Double {
        let v = min(max(x, table.first!.0), table.last!.0)
        for k in 0..<(table.count - 1) {
            let a = table[k], b = table[k + 1]
            if a.0 <= v && v <= b.0 {
                var f = b.0 > a.0 ? (v - a.0) / (b.0 - a.0) : 0
                f = f * f * (3 - 2 * f)
                return a.1 + (b.1 - a.1) * f
            }
        }
        return table.last!.1
    }

    static func mix(_ a: Vec3, _ b: Vec3, _ t: Double) -> Vec3 { a + (b - a) * t }
}

private func dot(_ a: Vec3, _ b: Vec3) -> Double { (a * b).sum() }
private func cross(_ a: Vec3, _ b: Vec3) -> Vec3 { Vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) }
private func length(_ a: Vec3) -> Double { (a * a).sum().squareRoot() }
private func unit(_ a: Vec3) -> Vec3 {
    let l = length(a)
    return l > 1e-12 ? a / l : a
}

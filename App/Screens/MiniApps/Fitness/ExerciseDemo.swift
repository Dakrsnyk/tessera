import SwiftUI

// MARK: - The demonstration of an exercise

/// A figure doing the exercise on the equipment it needs (bench at the right incline, machine, cable,
/// bar...), drawn by the app from `ExerciseDemos.json`: 3D positions sampled over one repetition,
/// interpolated, seen from a chosen angle. No outside video, so nothing to license, and the same
/// clean style as the rest of Ardane. The phases of the movement are named under the figure.
struct ExerciseDemoView: View {
    let exercise: ExerciseInfo
    var colorHex = "E5484D"
    var height: CGFloat = 236

    @State private var viewIndex = 0
    @State private var paused = false
    @State private var pausedAt: Double = 0
    @State private var startedAt = Date()
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let demo = ExerciseDemos.demo(for: exercise.id) {
            content(demo)
        } else {
            Text(tr("Démonstration indisponible"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120)
        }
    }

    private func content(_ demo: DemoModel) -> some View {
        let palette = DemoPalette(scheme: scheme, accentHex: colorHex)
        return VStack(spacing: 10) {
            TimelineView(.animation(minimumInterval: nil, paused: isPaused)) { timeline in
                let seconds = time(at: timeline.date, demo: demo)
                let phase = demo.phase(at: seconds)
                VStack(spacing: 10) {
                    Canvas { context, size in
                        DemoRenderer.draw(demo, p: phase.p, view: min(viewIndex, demo.views.count - 1),
                                          in: &context, size: size, palette: palette)
                    }
                    .frame(height: height)
                    .background(palette.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(.thinMaterial, in: Circle())
                            .padding(10)
                            .opacity(isPaused ? 1 : 0.55)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { togglePause(demo) }
                    .accessibilityElement()
                    .accessibilityLabel(Text(tr("Démonstration animée de \(exercise.name)")))
                    .accessibilityValue(Text(phase.label.map { demo.labels.indices.contains($0) ? demo.labels[$0] : "" } ?? ""))
                    .accessibilityHint(Text(isPaused ? tr("Touchez deux fois pour lancer l'animation") : tr("Touchez deux fois pour mettre en pause")))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("exercise-demo-canvas")

                    PhaseStrip(labels: demo.labels, current: phase.label, accent: Color(hex: colorHex))
                }
            }
            if demo.views.count > 1 {
                ViewPicker(names: demo.views.map(\.name), selection: $viewIndex)
            }
        }
        .onAppear { startedAt = Date() }
    }

    @State private var playingDespiteReduceMotion = false

    private var isPaused: Bool { paused || (reduceMotion && !playingDespiteReduceMotion) }

    private func time(at date: Date, demo: DemoModel) -> Double {
        if isPaused { return pausedAt }
        return pausedAt + date.timeIntervalSince(startedAt)
    }

    private func togglePause(_ demo: DemoModel) {
        if isPaused {
            startedAt = Date()
            paused = false
            playingDespiteReduceMotion = true
        } else {
            pausedAt += Date().timeIntervalSince(startedAt)
            paused = true
            playingDespiteReduceMotion = false
        }
    }
}

/// The phases of the repetition, the current one highlighted: « Départ → Descente → … ».
private struct PhaseStrip: View {
    let labels: [String]
    let current: Int?
    let accent: Color

    var body: some View {
        if labels.isEmpty {
            Text(tr("Mouvement continu"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(labels.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == current ? accent : Color.secondary.opacity(0.22))
                            .frame(height: 4)
                    }
                }
                Text(labels[min(max(current ?? 0, 0), labels.count - 1)])
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.opacity)
                    .accessibilityIdentifier("exercise-demo-phase")
            }
            .padding(.horizontal, 4)
        }
    }
}

/// « Profil · 3/4 · Face »: the angles offered for this exercise.
private struct ViewPicker: View {
    let names: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "video")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = index }
                } label: {
                    Text(name)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .foregroundStyle(selection == index ? Color(uiColor: .systemBackground) : .primary)
                        .background(selection == index ? Color.primary : Color.secondary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(tr("Vue \(name)")))
                .accessibilityAddTraits(selection == index ? .isSelected : [])
                .accessibilityIdentifier("exercise-demo-view-\(index)")
            }
        }
    }
}

// MARK: - Data

struct DemoFile: Decodable {
    let version: Int
    let demos: [String: DemoData]
}

struct DemoData: Decodable {
    struct ViewSpec: Decodable {
        let name: String
        let yaw: Double
        let pitch: Double
        let box: [Double]
    }

    let id: String
    let loop: Bool
    let n: Int
    let timeline: [[Double]]
    let labels: [String]
    let views: [ViewSpec]
    let `static`: String
    let dynamic: String
    let points: [Int]
    let prims: [[Int]]
    let shoulders: [Int]
    let marks: [Double]
}

/// The demonstrations of the library, loaded once, each prepared when first shown.
enum ExerciseDemos {
    private static let file: DemoFile? = {
        guard let url = Bundle.main.url(forResource: "ExerciseDemos", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DemoFile.self, from: data)
    }()

    private static var cache: [String: DemoModel] = [:]
    private static let lock = NSLock()

    static var ids: [String] { file.map { Array($0.demos.keys) } ?? [] }

    static func demo(for id: String) -> DemoModel? {
        lock.lock()
        defer { lock.unlock() }
        if let model = cache[id] { return model }
        guard let data = file?.demos[id], let model = DemoModel(data) else { return nil }
        cache[id] = model
        return model
    }
}

typealias Vec3 = SIMD3<Double>

struct DemoPrim {
    enum Kind: Int { case line = 0, poly = 1, disc = 2, ball = 3 }
    let kind: Kind
    let role: Int
    let width: Double
    let bias: Double
    let side: Int
    let cull: Bool
    let shade: Bool
    let indices: [Int]
}

struct DemoSegment {
    let duration: Double
    let from: Double
    let to: Double
    let label: Int
    let eased: Bool
}

/// One demonstration, ready to play: static points, the dynamic ones per sample, what to draw.
final class DemoModel {
    let id: String
    let loop: Bool
    let samples: Int
    let staticPoints: [Vec3]
    let dynamicPoints: [[Vec3]]
    let prims: [DemoPrim]
    let views: [DemoData.ViewSpec]
    let labels: [String]
    let segments: [DemoSegment]
    let shoulders: [Int]
    let marks: [Double]
    let duration: Double

    init?(_ data: DemoData) {
        guard data.points.count == 2, data.n > 1, !data.views.isEmpty else { return nil }
        let staticCount = data.points[0]
        let dynamicCount = data.points[1]
        let s = Self.decode(data.static)
        let d = Self.decode(data.dynamic)
        guard s.count >= staticCount * 3, d.count >= data.n * dynamicCount * 3 else { return nil }
        staticPoints = (0..<staticCount).map { Vec3(s[$0 * 3], s[$0 * 3 + 1], s[$0 * 3 + 2]) }
        var frames: [[Vec3]] = []
        frames.reserveCapacity(data.n)
        for f in 0..<data.n {
            var frame: [Vec3] = []
            frame.reserveCapacity(dynamicCount)
            for i in 0..<dynamicCount {
                let k = (f * dynamicCount + i) * 3
                frame.append(Vec3(d[k], d[k + 1], d[k + 2]))
            }
            frames.append(frame)
        }
        dynamicPoints = frames
        id = data.id
        loop = data.loop
        samples = data.n
        views = data.views
        labels = data.labels
        shoulders = data.shoulders
        marks = data.marks
        prims = data.prims.compactMap { raw in
            guard raw.count >= 7, let kind = DemoPrim.Kind(rawValue: raw[0]) else { return nil }
            return DemoPrim(kind: kind, role: raw[1], width: Double(raw[2]) / 1000, bias: Double(raw[3]) / 1000,
                            side: raw[4], cull: raw[5] & 1 != 0, shade: raw[5] & 2 != 0, indices: Array(raw[6...]))
        }
        let segs: [DemoSegment] = data.timeline.compactMap { seg in
            guard seg.count >= 4 else { return nil }
            return DemoSegment(duration: seg[0], from: seg[1], to: seg[2], label: Int(seg[3]),
                               eased: seg.count > 4 ? seg[4] != 0 : !data.loop)
        }
        segments = segs
        duration = max(0.1, segs.reduce(0.0) { $0 + $1.duration })
    }

    private static func decode(_ base64: String) -> [Double] {
        guard !base64.isEmpty, let data = Data(base64Encoded: base64) else { return [] }
        return data.withUnsafeBytes { raw -> [Double] in
            let values = raw.bindMemory(to: Int16.self)
            return values.map { Double(Int16(littleEndian: $0)) / 1000 }
        }
    }

    /// Where the movement is (0 start … 1 end) and its phase (an index in `labels`), t seconds into the loop.
    func phase(at seconds: Double) -> (p: Double, label: Int?) {
        var t = seconds.truncatingRemainder(dividingBy: duration)
        if t < 0 { t += duration }
        for segment in segments {
            if t <= segment.duration || segment.duration == 0 {
                let local = segment.duration > 0 ? t / segment.duration : 1
                let s = segment.eased ? local * local * (3 - 2 * local) : local
                return (segment.from + (segment.to - segment.from) * s, label(segment.label))
            }
            t -= segment.duration
        }
        let last = segments.last
        return (last?.to ?? 0, label(last?.label ?? -1))
    }

    private func label(_ index: Int) -> Int? {
        labels.indices.contains(index) ? index : nil
    }

    /// Every point at phase p: the dynamic ones interpolated between samples (Catmull-Rom).
    func points(at p: Double) -> [Vec3] {
        guard let first = dynamicPoints.first, !first.isEmpty else { return staticPoints }
        let n = samples
        let i: Int
        let f: Double
        let indices: [Int]
        if loop {
            var u = p.truncatingRemainder(dividingBy: 1) * Double(n)
            if u < 0 { u += Double(n) }
            i = Int(u.rounded(.down)) % n
            f = u - u.rounded(.down)
            indices = [(i - 1 + n) % n, i, (i + 1) % n, (i + 2) % n]
        } else {
            let u = min(max(p, 0), 1) * Double(n - 1)
            i = min(Int(u.rounded(.down)), n - 2)
            f = u - Double(i)
            indices = [max(i - 1, 0), i, i + 1, min(i + 2, n - 1)]
        }
        let p0 = dynamicPoints[indices[0]], p1 = dynamicPoints[indices[1]]
        let p2 = dynamicPoints[indices[2]], p3 = dynamicPoints[indices[3]]
        let f2 = f * f
        let f3 = f2 * f
        var out = staticPoints
        out.reserveCapacity(staticPoints.count + first.count)
        // Catmull-Rom weights for the four samples, so each point is a plain weighted sum.
        let w0: Double = 0.5 * (-f + 2 * f2 - f3)
        let w1: Double = 0.5 * (2 - 5 * f2 + 3 * f3)
        let w2: Double = 0.5 * (f + 4 * f2 - 3 * f3)
        let w3: Double = 0.5 * (f3 - f2)
        for k in 0..<first.count {
            var point: Vec3 = p0[k] * w0
            point += p1[k] * w1
            point += p2[k] * w2
            point += p3[k] * w3
            out.append(point)
        }
        return out
    }
}

// MARK: - Drawing

struct DemoPalette {
    let background: Color
    private let rgb: [Int: SIMD3<Double>]
    let backgroundRGB: SIMD3<Double>

    static let roleNames = ["ink", "muscle", "muscle2", "frame", "pad", "load", "cable", "floor", "mark", "metal"]

    init(scheme: ColorScheme, accentHex: String) {
        let dark = scheme == .dark
        let bg = dark ? "1A1B1E" : "F3F3F5"
        let accent = Self.parse(accentHex)
        let base = Self.parse(bg)
        let hexes: [String] = dark
            ? ["F1F2F4", "", "", "5A606B", "6B717C", "A3A9B4", "7C838F", "26282C", "34373E", "7B828E"]
            : ["1E2127", "", "", "B3B8C2", "808692", "4C525E", "8E95A1", "E4E5E9", "CDD0D6", "8A909C"]
        var table: [Int: SIMD3<Double>] = [:]
        for (index, hex) in hexes.enumerated() where !hex.isEmpty {
            table[index] = Self.parse(hex)
        }
        let toWhite: SIMD3<Double> = SIMD3<Double>(255, 255, 255) - accent
        let muscle: SIMD3<Double> = dark ? accent + toWhite * 0.12 : accent
        table[1] = muscle
        table[2] = muscle + (base - muscle) * 0.5
        rgb = table
        backgroundRGB = base
        background = Self.color(base)
    }

    func role(_ index: Int) -> SIMD3<Double> { rgb[index] ?? SIMD3(128, 128, 128) }

    static func parse(_ hex: String) -> SIMD3<Double> {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt32(clean.prefix(6), radix: 16) ?? 0
        return SIMD3(Double((value >> 16) & 0xFF), Double((value >> 8) & 0xFF), Double(value & 0xFF))
    }

    static func color(_ c: SIMD3<Double>) -> Color {
        Color(.sRGB, red: min(max(c.x, 0), 255) / 255, green: min(max(c.y, 0), 255) / 255,
              blue: min(max(c.z, 0), 255) / 255, opacity: 1)
    }
}

enum DemoRenderer {
    /// A little more muscle on every figure, the same in every exercise: the body's strokes (role
    /// « ink ») 12 % thicker, the muscles worked (roles « muscle », « muscle2 ») 18 %. Lengths,
    /// movements, the head and the equipment stay as they are: athletic, not a bodybuilder.
    static let bodyBulk = 1.12
    static let muscleBulk = 1.18

    private static func strokeWidth(_ prim: DemoPrim) -> Double {
        switch prim.role {
        case 0: prim.width * bodyBulk
        case 1, 2: prim.width * muscleBulk
        default: prim.width
        }
    }

    private struct Item {
        let depth: Double
        let order: Int
        let prim: DemoPrim
        let color: SIMD3<Double>
        let screen: [CGPoint]
    }

    static func basis(yaw: Double, pitch: Double) -> (Vec3, Vec3, Vec3) {
        let y = yaw * .pi / 180
        let p = pitch * .pi / 180
        let r = Vec3(cos(y), 0, -sin(y))
        let b = Vec3(sin(y), 0, cos(y))
        let u = Vec3(0, 1, 0)
        let u2 = u * cos(p) - b * sin(p)
        let b2 = b * cos(p) + u * sin(p)
        return (r, u2, b2)
    }

    static func draw(_ demo: DemoModel, p: Double, view index: Int, in context: inout GraphicsContext, size: CGSize,
                     palette: DemoPalette) {
        let spec = demo.views[max(0, index)]
        let (R, U, B) = basis(yaw: spec.yaw, pitch: spec.pitch)
        let points = demo.points(at: p)
        let projected = points.map { Vec3(($0 * R).sum(), ($0 * U).sum(), -($0 * B).sum()) }
        guard spec.box.count == 4 else { return }
        let margin = 14.0
        let width = Double(size.width)
        let height = Double(size.height)
        let w = max(spec.box[2] - spec.box[0], 0.01)
        let h = max(spec.box[3] - spec.box[1], 0.01)
        let scale: Double = min((width - 2 * margin) / w, (height - 2 * margin) / h, (height - 2 * margin) / 1.75)
        let cx = (spec.box[0] + spec.box[2]) / 2
        let cy = (spec.box[1] + spec.box[3]) / 2
        func screen(_ v: Vec3) -> CGPoint {
            CGPoint(x: width / 2 + (v.x - cx) * scale, y: height / 2 - (v.y - cy) * scale)
        }

        // Which side of the body is farther from the camera (the left if positive): drawn lighter.
        var sideFactor = 0.0
        if demo.shoulders.count == 2, demo.shoulders.allSatisfy({ projected.indices.contains($0) }) {
            sideFactor = min(1, max(-1, (projected[demo.shoulders[1]].z - projected[demo.shoulders[0]].z) / 0.35))
        }
        let light = normalizedSafe(Vec3(0.35, 1.0, 0.45))
        let white = SIMD3<Double>(255, 255, 255)
        var items: [Item] = []
        items.reserveCapacity(demo.prims.count + 16)
        for (order, prim) in demo.prims.enumerated() {
            guard prim.indices.allSatisfy({ projected.indices.contains($0) }) else { continue }
            let proj = prim.indices.map { projected[$0] }
            var depth = proj.reduce(0) { $0 + $1.z } / Double(proj.count) + prim.bias
            if prim.kind == .disc { depth = proj[0].z + prim.bias }
            if prim.cull {
                var area = 0.0
                for k in 0..<proj.count {
                    let a = proj[k], b = proj[(k + 1) % proj.count]
                    area += a.x * b.y - b.x * a.y
                }
                if area <= 2e-6 { continue }
            }
            var color = palette.role(prim.role)
            if prim.shade, prim.indices.count >= 3 {
                let w0 = points[prim.indices[0]], w1 = points[prim.indices[1]], w2 = points[prim.indices[2]]
                let normal = normalizedSafe(cross3(w1 - w0, w2 - w0))
                let lit = (normal * light).sum()
                color = lit > 0 ? color + (white - color) * (0.22 * lit) : color * (1 - 0.16 * -lit)
            }
            var fade = 0.0
            if prim.side == 1 { fade = max(0, -sideFactor) * 0.55 }
            if prim.side == 2 { fade = max(0, sideFactor) * 0.55 }
            if fade > 0 { color = color + (palette.backgroundRGB - color) * fade }
            items.append(Item(depth: depth, order: order, prim: prim, color: color, screen: proj.map(screen)))
        }
        // Floor marks scrolling under a figure that travels (walking, running, rowing on water...).
        if demo.marks.count >= 8 {
            let travel = demo.marks[0], spacing = max(demo.marks[1], 0.05)
            let x0 = demo.marks[2], x1 = demo.marks[3], z0 = demo.marks[4], z1 = demo.marks[5]
            let my = demo.marks[6], bias = demo.marks[7]
            let slope = demo.marks.count > 8 ? demo.marks[8] : 0
            var offset = (p * travel).truncatingRemainder(dividingBy: spacing)
            if offset < 0 { offset += spacing }
            var x = (x0 / spacing).rounded(.up) * spacing - offset
            let markRole = DemoPrim(kind: .line, role: 8, width: 0.03, bias: 0, side: 0, cull: false, shade: false, indices: [])
            while x <= x1 + 1e-9 {
                if x >= x0 - 1e-9 {
                    let y = my + slope * x
                    let a = Vec3(x, y, z0), b = Vec3(x, y, z1)
                    let pa = Vec3((a * R).sum(), (a * U).sum(), -(a * B).sum())
                    let pb = Vec3((b * R).sum(), (b * U).sum(), -(b * B).sum())
                    items.append(Item(depth: (pa.z + pb.z) / 2 + bias, order: -1, prim: markRole,
                                      color: palette.role(8), screen: [screen(pa), screen(pb)]))
                }
                x += spacing
            }
        }
        items.sort { $0.depth != $1.depth ? $0.depth > $1.depth : $0.order < $1.order }

        for item in items {
            let color = DemoPalette.color(item.color)
            switch item.prim.kind {
            case .line:
                var path = Path()
                path.addLines(item.screen)
                context.stroke(path, with: .color(color),
                               style: StrokeStyle(lineWidth: CGFloat(strokeWidth(item.prim) * scale), lineCap: .round, lineJoin: .round))
            case .poly:
                var path = Path()
                path.addLines(item.screen)
                path.closeSubpath()
                context.fill(path, with: .color(color))
                if item.prim.width > 0 {
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: CGFloat(strokeWidth(item.prim) * scale), lineJoin: .round))
                }
            case .ball:
                let c = item.screen[0]
                let r = CGFloat(item.prim.width * scale)
                context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(color))
            case .disc:
                guard item.prim.indices.count >= 2 else { continue }
                let axis = points[item.prim.indices[1]] - points[item.prim.indices[0]]
                let half = (axis * axis).sum().squareRoot()
                let n = half > 1e-9 ? axis / half : Vec3(0, 0, 1)
                let nr = (n * R).sum(), nu = (n * U).sum(), nb = (n * B).sum()
                let r = item.prim.width
                let minor = r * abs(nb) + half * max(0, 1 - nb * nb).squareRoot()
                let angle = atan2(-nu, nr)
                let ring = max(0.016, min(0.03, r * 0.16)) * scale
                let rx = max(minor * scale - ring / 2, 0.5)
                let ry = max(r * scale - ring / 2, 0.5)
                let c = item.screen[0]
                let transform = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: CGFloat(angle))
                let oval = CGRect(x: -rx, y: -ry, width: 2 * rx, height: 2 * ry)
                let path = Path(ellipseIn: oval).applying(transform)
                context.fill(path, with: .color(color.opacity(0.38)))
                context.stroke(path, with: .color(color), lineWidth: CGFloat(ring))
            }
        }
    }

    private static func cross3(_ a: Vec3, _ b: Vec3) -> Vec3 {
        Vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }
}

private func normalizedSafe(_ v: Vec3) -> Vec3 {
    let length = (v * v).sum().squareRoot()
    return length > 1e-12 ? v / length : v
}

import SwiftUI

/// Wallpapers drawn in code, at the size of the setup screens (402 × 874 pt).
/// The art sits in the middle and lower part, which the Lock Screen leaves visible.
struct SetupWallpaperView: View {
    let wallpaper: SetupWallpaper

    var body: some View {
        ZStack {
            switch wallpaper {
            case .midnight: MidnightWallpaper()
            case .cream: CreamWallpaper()
            case .aurora: AuroraWallpaper()
            case .topography: TopographyWallpaper()
            case .synthwave: SynthwaveWallpaper()
            case .dunes: DunesWallpaper()
            case .jade: JadeWallpaper()
            case .pastel: PastelWallpaper()
            case .graphite: GraphiteWallpaper()
            case .paper: PaperWallpaper()
            case .bureau: BureauWallpaper()
            case .bauhaus: BauhausWallpaper()
            case .ocean: OceanWallpaper()
            case .forest: ForestWallpaper()
            case .sunset: SunsetWallpaper()
            case .terrazzo: TerrazzoWallpaper()
            case .nebula: NebulaWallpaper()
            case .seventies: SeventiesWallpaper()
            }
        }
        .frame(width: W, height: H)
        .clipped()
        .accessibilityHidden(true)
    }
}

private let W = SetupScreen.size.width
private let H = SetupScreen.size.height

private func hex(_ value: String) -> Color { Color(hex: value) }

/// Same sequence on every launch, so the stars and dots never move.
private struct SeededRandom {
    var state: UInt64

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double((state >> 33) & 0xFFFFFF) / Double(0xFFFFFF)
    }
}

private struct Stars: View {
    var seed: UInt64 = 7
    var count = 160
    var maxY: Double = 1
    var brightness: Double = 1

    var body: some View {
        Canvas { context, size in
            var random = SeededRandom(state: seed)
            for index in 0..<count {
                let x = CGFloat(random.next()) * size.width
                let y = CGFloat(random.next() * maxY) * size.height
                let bright = index % 23 == 0
                let radius: CGFloat = bright ? 1.6 : CGFloat(0.4 + random.next())
                let alpha: Double = (bright ? 0.95 : 0.2 + random.next() * 0.6) * brightness
                if bright {
                    context.fill(Path(ellipseIn: CGRect(x: x - 6, y: y - 6, width: 12, height: 12)), with: .color(.white.opacity(0.08 * brightness)))
                }
                context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(.white.opacity(alpha)))
            }
        }
    }
}

private struct DotGrid: View {
    let spacing: CGFloat
    let radius: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, size in
            var y = spacing / 2
            while y < size.height {
                var x = spacing / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

// MARK: - Wallpapers

private struct MidnightWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [hex("0D1433"), hex("070A1C"), hex("020309")], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [hex("3B4C9B").opacity(0.45), .clear], center: UnitPoint(x: 0.75, y: 0.58), startRadius: 0, endRadius: 300)
            RadialGradient(colors: [hex("1B2A6B").opacity(0.5), .clear], center: UnitPoint(x: 0.05, y: 0.1), startRadius: 0, endRadius: 360)
            Stars(seed: 11, count: 190)
            // Crescent moon: a disc with a second disc cut out of it.
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [hex("FBF7EC"), hex("D9D1BD")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 70, height: 70)
                Circle()
                    .frame(width: 64, height: 64)
                    .offset(x: 20, y: -12)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .shadow(color: hex("F7F1DE").opacity(0.55), radius: 22)
            .position(x: W * 0.72, y: H * 0.56)
        }
    }
}

private struct CreamWallpaper: View {
    var body: some View {
        ZStack {
            hex("F3ECE0")
            RadialGradient(colors: [hex("E9D5B7").opacity(0.9), .clear], center: UnitPoint(x: 0.08, y: 0.1), startRadius: 0, endRadius: 340)
            RadialGradient(colors: [hex("FBF4E8"), .clear], center: UnitPoint(x: 0.95, y: 0.42), startRadius: 0, endRadius: 300)
            Group {
                Circle().stroke(hex("C4A57C").opacity(0.3), lineWidth: 1.2).frame(width: 340, height: 340)
                Circle().stroke(hex("C4A57C").opacity(0.45), lineWidth: 1.2).frame(width: 256, height: 256)
                Circle()
                    .fill(LinearGradient(colors: [hex("F0B57D"), hex("DE8A55")], startPoint: .top, endPoint: .bottom))
                    .frame(width: 176, height: 176)
            }
            .position(x: W / 2, y: 606)
            // The sea hides the lower half of the sun.
            LinearGradient(colors: [hex("E9DDC9"), hex("DCCBB0")], startPoint: .top, endPoint: .bottom)
                .frame(height: H - 646)
                .frame(maxHeight: .infinity, alignment: .bottom)
            Canvas { context, _ in
                let widths: [CGFloat] = [128, 96, 64, 38]
                for (index, width) in widths.enumerated() {
                    let y = 672 + CGFloat(index) * 26
                    var line = Path()
                    line.move(to: CGPoint(x: W / 2 - width / 2, y: y))
                    line.addLine(to: CGPoint(x: W / 2 + width / 2, y: y))
                    context.stroke(line, with: .color(hex("E29A66").opacity(0.55 - Double(index) * 0.1)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                }
            }
        }
    }
}

private struct AuroraWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [hex("040817"), hex("0A1433"), hex("071026")], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [hex("1FB89A").opacity(0.65), .clear], center: UnitPoint(x: 0.2, y: 0.45), startRadius: 0, endRadius: 280)
            RadialGradient(colors: [hex("6A3FD6").opacity(0.6), .clear], center: UnitPoint(x: 0.88, y: 0.32), startRadius: 0, endRadius: 300)
            RadialGradient(colors: [hex("1E6FD9").opacity(0.45), .clear], center: UnitPoint(x: 0.6, y: 0.72), startRadius: 0, endRadius: 320)
            Stars(seed: 3, count: 110, maxY: 0.8, brightness: 0.7)
            // Curtains of light.
            Canvas { context, size in
                for index in 0..<48 {
                    let t = Double(index) / 47
                    let x = -20 + CGFloat(t) * (size.width + 40)
                    let wave: Double = 70 * sin(t * 5.2) + 28 * sin(t * 13)
                    let top = CGFloat(300 + wave)
                    let bottom = top + CGFloat(210 + 80 * sin(t * 3.1 + 1))
                    let drift = CGFloat(26 * sin(t * 4))
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: top))
                    path.addLine(to: CGPoint(x: x + drift, y: bottom))
                    let color = t < 0.55 ? hex("3FF5C4") : hex("8AF0FF")
                    context.stroke(
                        path,
                        with: .linearGradient(Gradient(colors: [color.opacity(0), color.opacity(0.5), color.opacity(0)]),
                                              startPoint: CGPoint(x: x, y: top), endPoint: CGPoint(x: x, y: bottom)),
                        lineWidth: 7
                    )
                }
            }
            .blur(radius: 9)
            // Mountains.
            Canvas { context, size in
                let peaks: [(CGFloat, CGFloat)] = [(0, 770), (40, 735), (95, 760), (150, 700), (205, 748), (250, 722), (300, 765), (350, 718), (402, 752)]
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                for (x, y) in peaks { path.addLine(to: CGPoint(x: x, y: y)) }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(hex("03060F")))
            }
        }
    }
}

private struct TopographyWallpaper: View {
    var body: some View {
        ZStack {
            hex("E7ECDF")
            RadialGradient(colors: [hex("D7E2C8"), .clear], center: UnitPoint(x: 0.85, y: 0.2), startRadius: 0, endRadius: 380)
            Canvas { context, _ in
                contours(&context, center: CGPoint(x: W * 0.32, y: H * 0.6), rings: 17, spacing: 24, seed: 0.3)
                contours(&context, center: CGPoint(x: W * 0.95, y: H * 0.12), rings: 10, spacing: 26, seed: 1.7)
                contours(&context, center: CGPoint(x: W * 0.9, y: H * 0.95), rings: 8, spacing: 22, seed: 2.9)
            }
        }
    }

    private func contours(_ context: inout GraphicsContext, center: CGPoint, rings: Int, spacing: Double, seed: Double) {
        for ring in 1...rings {
            let k = Double(ring)
            var path = Path()
            for step in 0...140 {
                let theta: Double = Double(step) / 140 * 2 * .pi
                let first: Double = 0.11 * sin(3 * theta + k * 0.35 + seed)
                let second: Double = 0.06 * sin(5 * theta + 1.3 - k * 0.2)
                let third: Double = 0.04 * sin(2 * theta + seed * 2)
                let radius: Double = (14 + k * spacing) * (1 + first + second + third)
                let point = CGPoint(x: center.x + CGFloat(radius * cos(theta)), y: center.y + CGFloat(radius * sin(theta) * 0.92))
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            let isIndex = ring % 4 == 0
            context.stroke(path, with: .color(hex("7E9270").opacity(isIndex ? 0.55 : 0.38)), lineWidth: isIndex ? 1.7 : 1)
        }
    }
}

private struct SynthwaveWallpaper: View {
    private let horizon: CGFloat = 572

    var body: some View {
        ZStack {
            LinearGradient(colors: [hex("0B0224"), hex("2B0B4F"), hex("7A1C7A"), hex("F2477E")], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: horizon / H))
            Stars(seed: 5, count: 90, maxY: 0.5, brightness: 0.8)
            // Striped sun.
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [hex("FFE66D"), hex("FF9A5A"), hex("FF3D8B")], startPoint: .top, endPoint: .bottom))
                Canvas { context, size in
                    for band in 0..<6 {
                        let y = size.height * (0.56 + CGFloat(band) * 0.075)
                        let thickness = 2 + CGFloat(band) * 2.2
                        context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: thickness)), with: .color(.black))
                    }
                }
                .blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: 236, height: 236)
            .shadow(color: hex("FF3D8B").opacity(0.7), radius: 30)
            .position(x: W / 2, y: horizon - 78)
            // Ground and grid.
            LinearGradient(colors: [hex("1B0536"), hex("090114")], startPoint: .top, endPoint: .bottom)
                .frame(height: H - horizon)
                .frame(maxHeight: .infinity, alignment: .bottom)
            Group {
                grid.blur(radius: 3).opacity(0.8)
                grid
            }
            Rectangle()
                .fill(hex("FF8AD8"))
                .frame(height: 2)
                .shadow(color: hex("FF4FD8"), radius: 8)
                .position(x: W / 2, y: horizon)
        }
    }

    private var grid: some View {
        Canvas { context, size in
            let color = GraphicsContext.Shading.color(hex("FF4FD8").opacity(0.75))
            for line in 1...14 {
                let depth = CGFloat(pow(Double(line) / 14, 2.1))
                let y = horizon + depth * (size.height - horizon)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: color, lineWidth: 1.2)
            }
            for column in -12...12 {
                var path = Path()
                path.move(to: CGPoint(x: W / 2 + CGFloat(column) * 7, y: horizon))
                path.addLine(to: CGPoint(x: W / 2 + CGFloat(column) * 78, y: size.height))
                context.stroke(path, with: color, lineWidth: 1.2)
            }
        }
    }
}

private struct DunesWallpaper: View {
    private struct Layer {
        let base: Double
        let amplitude: Double
        let frequency: Double
        let phase: Double
        let color: String
    }

    private let layers = [
        Layer(base: 575, amplitude: 38, frequency: 1.3, phase: 0.4, color: "E8B089"),
        Layer(base: 640, amplitude: 32, frequency: 1.7, phase: 2.1, color: "DB966A"),
        Layer(base: 718, amplitude: 30, frequency: 1.1, phase: 4.0, color: "C77B50"),
        Layer(base: 800, amplitude: 24, frequency: 1.9, phase: 1.2, color: "A65D3A"),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [hex("FCE9D4"), hex("F8D3B1"), hex("F2B891")], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [hex("FFF7EA"), .clear], center: UnitPoint(x: 0.7, y: 0.47), startRadius: 0, endRadius: 170)
            Circle()
                .fill(hex("FFF4E2"))
                .frame(width: 96, height: 96)
                .position(x: W * 0.7, y: H * 0.47)
            Canvas { context, size in
                for layer in layers {
                    var ridge = Path()
                    for step in stride(from: CGFloat(0), through: size.width, by: 4) {
                        let t = Double(step / size.width)
                        let main: Double = layer.amplitude * sin(t * layer.frequency * .pi + layer.phase)
                        let ripple: Double = layer.amplitude * 0.35 * sin(t * layer.frequency * 3.1 * .pi + layer.phase * 1.7)
                        let point = CGPoint(x: step, y: CGFloat(layer.base - main - ripple))
                        if step == 0 { ridge.move(to: point) } else { ridge.addLine(to: point) }
                    }
                    var fill = ridge
                    fill.addLine(to: CGPoint(x: size.width, y: size.height))
                    fill.addLine(to: CGPoint(x: 0, y: size.height))
                    fill.closeSubpath()
                    context.fill(fill, with: .color(hex(layer.color)))
                    context.stroke(ridge, with: .color(.white.opacity(0.22)), lineWidth: 1.2)
                }
            }
        }
    }
}

private struct JadeWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [hex("1F4A40"), hex("12302A")], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [hex("2F8F7A").opacity(0.9), .clear], center: UnitPoint(x: 0.15, y: 0.08), startRadius: 0, endRadius: 420)
            RadialGradient(colors: [hex("F2A33A").opacity(0.4), .clear], center: UnitPoint(x: 0.95, y: 0.95), startRadius: 0, endRadius: 380)
            // The Ardane mosaic, very large and soft.
            HStack(spacing: 18) {
                tile(hex("3FB39A").opacity(0.32), height: 318)
                VStack(spacing: 18) {
                    tile(hex("EFEDE6").opacity(0.12), height: 150)
                    tile(hex("F2A33A").opacity(0.34), height: 150)
                }
            }
            .rotationEffect(.degrees(-12))
            .position(x: W * 0.55, y: H * 0.66)
        }
    }

    private func tile(_ color: Color, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(color)
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            }
            .frame(width: 150, height: height)
    }
}

private struct PastelWallpaper: View {
    var body: some View {
        ZStack {
            hex("FDF1F4")
            RadialGradient(colors: [hex("FFC6D5"), .clear], center: UnitPoint(x: 0.08, y: 0.1), startRadius: 0, endRadius: 380)
            RadialGradient(colors: [hex("D9CCFF"), .clear], center: UnitPoint(x: 0.98, y: 0.34), startRadius: 0, endRadius: 400)
            RadialGradient(colors: [hex("FFDFC0"), .clear], center: UnitPoint(x: 0.12, y: 0.74), startRadius: 0, endRadius: 380)
            RadialGradient(colors: [hex("C6EEDD"), .clear], center: UnitPoint(x: 0.92, y: 0.96), startRadius: 0, endRadius: 360)
            Circle().fill(Color.white.opacity(0.32)).frame(width: 160, height: 160).position(x: 292, y: 580)
            Circle().stroke(Color.white.opacity(0.7), lineWidth: 1.5).frame(width: 236, height: 236).position(x: 292, y: 580)
            Circle().fill(Color.white.opacity(0.28)).frame(width: 74, height: 74).position(x: 96, y: 500)
            Circle().fill(Color.white.opacity(0.4)).frame(width: 28, height: 28).position(x: 150, y: 690)
        }
    }
}

private struct GraphiteWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [hex("1B1B1D"), hex("0C0C0D"), hex("050505")], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.white.opacity(0.09), .clear], center: UnitPoint(x: 0.5, y: -0.05), startRadius: 0, endRadius: 560)
            DotGrid(spacing: 22, radius: 0.9, color: .white.opacity(0.08))
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 1).frame(width: 520, height: 520).position(x: W, y: H * 0.72)
            Circle().stroke(Color.white.opacity(0.06), lineWidth: 1).frame(width: 380, height: 380).position(x: W, y: H * 0.72)
        }
    }
}

private struct PaperWallpaper: View {
    var body: some View {
        ZStack {
            hex("F4F6FA")
            RadialGradient(colors: [hex("3366FF").opacity(0.12), .clear], center: UnitPoint(x: 0.95, y: 0.06), startRadius: 0, endRadius: 330)
            RadialGradient(colors: [hex("F2A33A").opacity(0.1), .clear], center: UnitPoint(x: 0.05, y: 0.96), startRadius: 0, endRadius: 320)
            DotGrid(spacing: 24, radius: 1.15, color: hex("8E9AB5").opacity(0.5))
            // A sticky note.
            VStack(alignment: .leading, spacing: 11) {
                Capsule().fill(hex("B38A1E").opacity(0.45)).frame(width: 70, height: 5)
                Capsule().fill(hex("B38A1E").opacity(0.45)).frame(width: 84, height: 5)
                Capsule().fill(hex("B38A1E").opacity(0.45)).frame(width: 48, height: 5)
            }
            .padding(18)
            .frame(width: 124, height: 124, alignment: .topLeading)
            .background(hex("FFE68F"), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 5)
            .rotationEffect(.degrees(-6))
            .position(x: W * 0.7, y: H * 0.62)
        }
    }
}

private struct BureauWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [hex("111D38"), hex("0A1428"), hex("050B18")], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [hex("C8A15A").opacity(0.24), .clear], center: UnitPoint(x: 0, y: 1), startRadius: 0, endRadius: 480)
            RadialGradient(colors: [hex("34528F").opacity(0.3), .clear], center: UnitPoint(x: 0.95, y: 0.08), startRadius: 0, endRadius: 380)
            // An art deco fan from the bottom-left corner.
            Canvas { context, size in
                let origin = CGPoint(x: 0, y: size.height)
                let gold = hex("C8A15A")
                for degrees in stride(from: 6.0, through: 84, by: 4) {
                    let angle = degrees * .pi / 180
                    var ray = Path()
                    ray.move(to: origin)
                    ray.addLine(to: CGPoint(x: origin.x + CGFloat(1100 * cos(angle)), y: origin.y - CGFloat(1100 * sin(angle))))
                    context.stroke(ray, with: .color(gold.opacity(0.12)), lineWidth: 1)
                }
                let radii: [CGFloat] = [170, 250, 330, 410]
                for radius in radii {
                    var arc = Path()
                    arc.addArc(center: origin, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
                    context.stroke(arc, with: .color(gold.opacity(0.2)), lineWidth: 1.2)
                }
            }
        }
    }
}

private struct BauhausWallpaper: View {
    var body: some View {
        ZStack {
            hex("F6E4D8")
            Circle().fill(hex("FF6B57")).frame(width: 300, height: 300).position(x: 64, y: 150)
            Circle().stroke(hex("F2A33A"), lineWidth: 28).frame(width: 200, height: 200).position(x: 318, y: 478)
            Circle().fill(hex("E0457B")).frame(width: 520, height: 520).position(x: W, y: H)
            RoundedRectangle(cornerRadius: 13, style: .continuous).fill(hex("2F3A56")).frame(width: 26, height: 250).position(x: 70, y: 650)
            Canvas { context, _ in
                for row in 0..<4 {
                    for column in 0..<4 {
                        let rect = CGRect(x: 128 + CGFloat(column) * 18, y: 500 + CGFloat(row) * 18, width: 8, height: 8)
                        context.fill(Path(ellipseIn: rect), with: .color(hex("2F3A56")))
                    }
                }
            }
        }
    }
}

/// A band of waves or hills: a sine line, filled down to the bottom of the screen.
private struct WaveLayer {
    let base: Double
    let amplitude: Double
    let frequency: Double
    let phase: Double
    let color: String

    func ridge(width: CGFloat) -> Path {
        var path = Path()
        for step in stride(from: CGFloat(0), through: width, by: 4) {
            let t = Double(step / width)
            let main: Double = amplitude * sin(t * frequency * 2 * Double.pi + phase)
            let ripple: Double = amplitude * 0.25 * sin(t * frequency * 5 * Double.pi + phase * 1.6)
            let point = CGPoint(x: step, y: CGFloat(base + main + ripple))
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    func fill(width: CGFloat, height: CGFloat) -> Path {
        var path = ridge(width: width)
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}

private struct OceanWallpaper: View {
    private let waves = [
        WaveLayer(base: 560, amplitude: 12, frequency: 2.2, phase: 0.3, color: "1B7FA8"),
        WaveLayer(base: 632, amplitude: 14, frequency: 1.8, phase: 1.9, color: "146A93"),
        WaveLayer(base: 708, amplitude: 16, frequency: 2.6, phase: 3.1, color: "0E557A"),
        WaveLayer(base: 790, amplitude: 18, frequency: 1.5, phase: 0.8, color: "093F5E"),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [hex("06223F"), hex("0A3D66"), hex("0D5C7E"), hex("0A2E4A")], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [hex("7FD6FF").opacity(0.35), .clear], center: UnitPoint(x: 0.7, y: 0.18), startRadius: 0, endRadius: 360)
            // Light falling from the surface.
            Canvas { context, size in
                let depth = size.height * 0.62
                for index in 0..<7 {
                    let x = CGFloat(30 + index * 60)
                    var ray = Path()
                    ray.move(to: CGPoint(x: x, y: 0))
                    ray.addLine(to: CGPoint(x: x + 26, y: 0))
                    ray.addLine(to: CGPoint(x: x - 40, y: depth))
                    ray.addLine(to: CGPoint(x: x - 96, y: depth))
                    ray.closeSubpath()
                    context.fill(ray, with: .linearGradient(
                        Gradient(colors: [Color.white.opacity(0.11), Color.white.opacity(0)]),
                        startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x, y: depth)
                    ))
                }
            }
            .blur(radius: 6)
            // Bubbles rising.
            Canvas { context, size in
                var random = SeededRandom(state: 29)
                for _ in 0..<26 {
                    let x = CGFloat(random.next()) * size.width
                    let y = 260 + CGFloat(random.next()) * 300
                    let radius = CGFloat(2 + random.next() * 6)
                    context.stroke(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                                   with: .color(.white.opacity(0.28)), lineWidth: 1)
                }
            }
            Canvas { context, size in
                for wave in waves {
                    context.fill(wave.fill(width: size.width, height: size.height), with: .color(hex(wave.color).opacity(0.92)))
                    context.stroke(wave.ridge(width: size.width), with: .color(.white.opacity(0.2)), lineWidth: 1.4)
                }
            }
        }
    }
}

private struct ForestWallpaper: View {
    private struct PineRow {
        let base: CGFloat
        let height: CGFloat
        let spacing: CGFloat
        let seed: UInt64
        let color: String
    }

    private let rows = [
        PineRow(base: 640, height: 110, spacing: 30, seed: 3, color: "3C6A55"),
        PineRow(base: 705, height: 140, spacing: 38, seed: 5, color: "285342"),
        PineRow(base: 785, height: 180, spacing: 48, seed: 8, color: "173A2D"),
        PineRow(base: 880, height: 230, spacing: 64, seed: 13, color: "0B2018"),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [hex("0B1F1A"), hex("17372D"), hex("3E6B57"), hex("A9C6A2")], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.74))
            Stars(seed: 17, count: 70, maxY: 0.42, brightness: 0.55)
            Circle()
                .fill(hex("F4EFD8"))
                .frame(width: 58, height: 58)
                .shadow(color: hex("F4EFD8").opacity(0.6), radius: 22)
                .position(x: W * 0.28, y: H * 0.43)
            Canvas { context, size in
                for row in rows {
                    var random = SeededRandom(state: row.seed)
                    var x = -CGFloat(random.next()) * row.spacing
                    while x < size.width + row.spacing {
                        let height = row.height * CGFloat(0.72 + random.next() * 0.5)
                        let width = height * 0.46
                        var tree = Path()
                        // Two tiers make a fir.
                        for tier in 0..<2 {
                            let top = row.base - height + CGFloat(tier) * height * 0.32
                            let bottom = row.base - CGFloat(1 - tier) * height * 0.3
                            let half = width / 2 * (tier == 0 ? 0.72 : 1)
                            tree.move(to: CGPoint(x: x, y: top))
                            tree.addLine(to: CGPoint(x: x + half, y: bottom))
                            tree.addLine(to: CGPoint(x: x - half, y: bottom))
                            tree.closeSubpath()
                        }
                        context.fill(tree, with: .color(hex(row.color)))
                        x += row.spacing * CGFloat(0.7 + random.next() * 0.6)
                    }
                    context.fill(Path(CGRect(x: 0, y: row.base - 2, width: size.width, height: size.height - row.base + 2)), with: .color(hex(row.color)))
                }
            }
        }
    }
}

private struct SunsetWallpaper: View {
    private let hills = [
        WaveLayer(base: 655, amplitude: 22, frequency: 0.9, phase: 0.6, color: "A2456A"),
        WaveLayer(base: 725, amplitude: 26, frequency: 0.7, phase: 2.4, color: "6E2A55"),
        WaveLayer(base: 805, amplitude: 22, frequency: 1.1, phase: 4.2, color: "3A1839"),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [hex("241845"), hex("5B2C6F"), hex("C4506E"), hex("F28A5B"), hex("FBCB86")],
                startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.74)
            )
            Stars(seed: 41, count: 60, maxY: 0.3, brightness: 0.6)
            Circle()
                .fill(LinearGradient(colors: [hex("FFE9A8"), hex("FFB067")], startPoint: .top, endPoint: .bottom))
                .frame(width: 150, height: 150)
                .shadow(color: hex("FFB067").opacity(0.8), radius: 40)
                .position(x: W * 0.5, y: 640)
            Canvas { context, size in
                for hill in hills {
                    context.fill(hill.fill(width: size.width, height: size.height), with: .color(hex(hill.color)))
                }
            }
        }
    }
}

private struct TerrazzoWallpaper: View {
    private static let colors = ["E4533D", "F2A33A", "2F8F7A", "3366FF", "F2588F", "2F3A56", "C9B79C", "E4533D"]

    var body: some View {
        ZStack {
            hex("F4EEE6")
            RadialGradient(colors: [Color.white.opacity(0.7), .clear], center: UnitPoint(x: 0.3, y: 0.2), startRadius: 0, endRadius: 420)
            Canvas { context, size in
                var random = SeededRandom(state: 61)
                for index in 0..<78 {
                    let center = CGPoint(x: CGFloat(random.next()) * size.width, y: CGFloat(random.next()) * size.height)
                    let radius = CGFloat(5 + pow(random.next(), 2) * 30)
                    let corners = 5 + index % 3
                    let turn = random.next() * 2 * Double.pi
                    var chip = Path()
                    for corner in 0..<corners {
                        let angle = turn + Double(corner) / Double(corners) * 2 * Double.pi
                        let reach = radius * CGFloat(0.6 + random.next() * 0.4)
                        let point = CGPoint(x: center.x + reach * CGFloat(cos(angle)), y: center.y + reach * CGFloat(sin(angle)))
                        if corner == 0 { chip.move(to: point) } else { chip.addLine(to: point) }
                    }
                    chip.closeSubpath()
                    let color = hex(Self.colors[index % Self.colors.count])
                    context.fill(chip, with: .color(color.opacity(0.85)))
                }
            }
        }
    }
}

private struct NebulaWallpaper: View {
    var body: some View {
        ZStack {
            hex("07051A")
            RadialGradient(colors: [hex("6B2FD6").opacity(0.75), .clear], center: UnitPoint(x: 0.25, y: 0.48), startRadius: 0, endRadius: 300)
            RadialGradient(colors: [hex("D6409F").opacity(0.6), .clear], center: UnitPoint(x: 0.78, y: 0.62), startRadius: 0, endRadius: 280)
            RadialGradient(colors: [hex("1E6FD9").opacity(0.5), .clear], center: UnitPoint(x: 0.55, y: 0.3), startRadius: 0, endRadius: 320)
            Ellipse()
                .fill(hex("B58CFF").opacity(0.25))
                .frame(width: 360, height: 140)
                .rotationEffect(.degrees(-24))
                .blur(radius: 40)
                .position(x: W * 0.5, y: H * 0.55)
            Stars(seed: 23, count: 240)
            // A ringed planet.
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [hex("F2B8FF"), hex("7A4BD6")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                Ellipse()
                    .stroke(hex("F6D9FF").opacity(0.75), lineWidth: 3)
                    .frame(width: 150, height: 34)
            }
            .rotationEffect(.degrees(-18))
            .shadow(color: hex("B58CFF").opacity(0.6), radius: 24)
            .position(x: W * 0.72, y: H * 0.74)
        }
    }
}

private struct SeventiesWallpaper: View {
    private static let bands = ["7A3B1E", "C0602A", "E8913A", "F2C14E", "EBDDB5"]

    var body: some View {
        ZStack {
            hex("FBEFD9")
            rainbow(center: CGPoint(x: W * 0.18, y: H + 10), outer: 430, width: 38)
            rainbow(center: CGPoint(x: W + 20, y: H * 0.34), outer: 190, width: 22)
                .opacity(0.9)
        }
    }

    private func rainbow(center: CGPoint, outer: CGFloat, width: CGFloat) -> some View {
        Canvas { context, _ in
            for (index, color) in Self.bands.enumerated() {
                let radius = outer - CGFloat(index) * width - width / 2
                guard radius > 0 else { continue }
                var arc = Path()
                arc.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                context.stroke(arc, with: .color(hex(color)), style: StrokeStyle(lineWidth: width, lineCap: .butt))
            }
        }
    }
}

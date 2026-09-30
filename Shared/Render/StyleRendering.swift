import SwiftUI
import UIKit
import WidgetKit

// MARK: - Icons

/// Picks the variant of an SF Symbol that matches an icon family (filled, outlined, in a circle, in a
/// square), so every icon of a widget looks alike. A variant that doesn't exist keeps the original.
enum SymbolFamily {
    private static var cache: [String: String] = [:]
    private static let lock = NSLock()

    static func resolve(_ name: String, family: IconFamily) -> String {
        guard family != .theme else { return name }
        let key = "\(family.rawValue)|\(name)"
        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let base = baseName(name)
        let candidates: [String]
        switch family {
        case .theme: candidates = [name]
        case .filled: candidates = [base + ".fill", name]
        case .outlined: candidates = [base, name]
        case .circled: candidates = [base + ".circle.fill", base + ".circle", name]
        case .squared: candidates = [base + ".square.fill", base + ".square", name]
        }
        let found = candidates.first { UIImage(systemName: $0) != nil } ?? name
        lock.lock()
        cache[key] = found
        lock.unlock()
        return found
    }

    /// "flame.circle.fill" → "flame".
    static func baseName(_ name: String) -> String {
        var result = name
        var changed = true
        while changed {
            changed = false
            for suffix in [".fill", ".circle", ".square"] where result.hasSuffix(suffix) && result.count > suffix.count {
                result.removeLast(suffix.count)
                changed = true
            }
        }
        return result
    }
}

/// An icon drawn with the widget's icon style: plain, in a colored circle or square, outlined, or hidden.
struct StyledIcon: View {
    let symbol: String
    let style: ResolvedStyle
    var size: CGFloat = 11
    var color: Color?

    var body: some View {
        let points = size * CGFloat(style.options.iconScale)
        let name = style.symbol(symbol)
        let tint = color ?? style.icon
        switch style.iconStyle {
        case .none:
            EmptyView()
        case .plain, .theme:
            Image(systemName: name)
                .font(.system(size: points, weight: .semibold))
                .foregroundStyle(tint)
        case .circle:
            Image(systemName: name)
                .font(.system(size: points * 0.9, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: points * 2, height: points * 2)
                .background(tint.opacity(0.18), in: Circle())
        case .square:
            Image(systemName: name)
                .font(.system(size: points * 0.9, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: points * 2, height: points * 2)
                .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: style.radius(points * 0.55), style: .continuous))
        case .outline:
            Image(systemName: name)
                .font(.system(size: points * 0.85, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: points * 2, height: points * 2)
                .overlay { Circle().strokeBorder(tint.opacity(0.75), lineWidth: 1) }
        }
    }
}

// MARK: - Depth

/// Shadows, glow and relief, drawn inside the widget: iOS draws the widget's own edge and doesn't
/// let an app shade it, so depth goes on the numbers, charts and cards.
struct StyleDepth: ViewModifier {
    let style: ResolvedStyle

    @ViewBuilder func body(content: Content) -> some View {
        let o = style.options
        let radius = CGFloat(o.shadowRadius)
        let opacity = o.shadowOpacity
        let offset = CGFloat(o.shadowOffset)
        switch o.depth {
        case .none:
            content
        case .soft:
            content.shadow(color: style.shadowColor.opacity(opacity * 0.7), radius: radius * 0.5, x: 0, y: offset * 0.6)
        case .strong:
            content.shadow(color: style.shadowColor.opacity(min(1, opacity * 1.6)), radius: radius * 0.8, x: 0, y: offset * 1.3)
        case .glow:
            content
                .shadow(color: style.shadowColor.opacity(min(1, opacity * 2.2)), radius: radius * 0.9)
                .shadow(color: style.shadowColor.opacity(min(1, opacity * 1.2)), radius: radius * 0.3)
        case .floating:
            content.shadow(color: style.shadowColor.opacity(opacity), radius: radius * 1.5, x: 0, y: offset * 2.5)
        case .embossed:
            content
                .shadow(color: Color.white.opacity(style.isDarkSurface ? 0.16 : 0.85), radius: 0, x: -0.8, y: -0.8)
                .shadow(color: Color.black.opacity(style.isDarkSurface ? 0.6 : 0.25), radius: 0.6, x: 0.8, y: 0.9)
        }
    }
}

extension View {
    func styleDepth(_ style: ResolvedStyle) -> some View {
        modifier(StyleDepth(style: style))
    }
}

// MARK: - Border

/// The border follows the widget's own outline (ContainerRelativeShape), whatever size iOS gives it.
struct StyleBorder: View {
    let style: ResolvedStyle

    var body: some View {
        let o = style.options
        let width = CGFloat(o.borderWidth)
        let color = style.borderColor
        switch o.border {
        case .none:
            EmptyView()
        case .solid:
            ContainerRelativeShape().strokeBorder(color, lineWidth: width)
        case .dashed:
            ContainerRelativeShape().strokeBorder(color, style: StrokeStyle(lineWidth: width, dash: [width * 4 + 2, width * 2.5 + 2]))
        case .dotted:
            ContainerRelativeShape().strokeBorder(color, style: StrokeStyle(lineWidth: width, lineCap: .round, dash: [0.1, width * 2.4 + 2]))
        case .double:
            ZStack {
                ContainerRelativeShape().strokeBorder(color, lineWidth: width)
                ContainerRelativeShape().inset(by: width * 2.5 + 1.5).strokeBorder(color, lineWidth: max(0.5, width * 0.6))
            }
        case .glow:
            ZStack {
                ContainerRelativeShape().strokeBorder(color, lineWidth: width * 2.5).blur(radius: width * 3 + 2)
                ContainerRelativeShape().strokeBorder(color, lineWidth: width)
            }
        case .gradient:
            ContainerRelativeShape().strokeBorder(
                AngularGradient(
                    colors: [color, style.primary.opacity(0.3 * o.borderOpacity), color, style.secondary.opacity(0.5 * o.borderOpacity), color],
                    center: .center
                ),
                lineWidth: width
            )
        }
    }
}

// MARK: - Texture

/// A fine pattern over the background: grain, paper, dots, grid, lines, stripes or noise.
struct TextureView: View {
    let kind: TextureKind
    let color: Color
    let opacity: Double

    var body: some View {
        TexturePattern(kind: kind)
            .fill(color.opacity(opacity * strength))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var strength: Double {
        switch kind {
        case .none: 0
        case .grain: 0.3
        case .paper: 0.22
        case .dots: 0.28
        case .grid: 0.2
        case .lines: 0.16
        case .diagonal: 0.12
        case .noise: 0.35
        }
    }
}

struct TexturePattern: Shape {
    let kind: TextureKind

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch kind {
        case .none:
            break
        case .dots:
            let step: CGFloat = 9
            var y = rect.minY + step / 2
            while y < rect.maxY {
                var x = rect.minX + step / 2
                while x < rect.maxX {
                    path.addEllipse(in: CGRect(x: x - 0.9, y: y - 0.9, width: 1.8, height: 1.8))
                    x += step
                }
                y += step
            }
        case .grid:
            let step: CGFloat = 14
            var x = rect.minX
            while x < rect.maxX {
                path.addRect(CGRect(x: x, y: rect.minY, width: 0.6, height: rect.height))
                x += step
            }
            var y = rect.minY
            while y < rect.maxY {
                path.addRect(CGRect(x: rect.minX, y: y, width: rect.width, height: 0.6))
                y += step
            }
        case .lines:
            var y = rect.minY
            while y < rect.maxY {
                path.addRect(CGRect(x: rect.minX, y: y, width: rect.width, height: 1))
                y += 3
            }
        case .diagonal:
            let step: CGFloat = 7
            var x = rect.minX - rect.height
            while x < rect.maxX {
                path.move(to: CGPoint(x: x, y: rect.maxY))
                path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
                path.addLine(to: CGPoint(x: x + rect.height + 2, y: rect.minY))
                path.addLine(to: CGPoint(x: x + 2, y: rect.maxY))
                path.closeSubpath()
                x += step
            }
        case .grain, .noise, .paper:
            var generator = TextureRandom(seed: kind == .paper ? 7 : (kind == .noise ? 13 : 3))
            let area = rect.width * rect.height
            let count = Int(area / (kind == .noise ? 22 : 38))
            let size: CGFloat = kind == .noise ? 1.4 : 1
            for _ in 0..<min(count, 6_000) {
                let x = rect.minX + CGFloat(generator.next()) * rect.width
                let y = rect.minY + CGFloat(generator.next()) * rect.height
                path.addRect(CGRect(x: x, y: y, width: size, height: size))
            }
            if kind == .paper {
                // Fibers: short, thin, slightly slanted strokes.
                for _ in 0..<Int(area / 900) {
                    let x = rect.minX + CGFloat(generator.next()) * rect.width
                    let y = rect.minY + CGFloat(generator.next()) * rect.height
                    let length = 6 + CGFloat(generator.next()) * 10
                    let slant = (CGFloat(generator.next()) - 0.5) * 4
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + length, y: y + slant))
                    path.addLine(to: CGPoint(x: x + length, y: y + slant + 0.5))
                    path.addLine(to: CGPoint(x: x, y: y + 0.5))
                    path.closeSubpath()
                }
            }
        }
        return path
    }
}

/// The same "random" pattern every time, so a texture never flickers between refreshes.
struct TextureRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 2_862_933_555_777_941_757 &+ 3_037_000_493 }

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double((state >> 33) & 0x7FFF_FFFF) / Double(0x7FFF_FFFF)
    }
}

// MARK: - Content

extension ResolvedStyle {
    /// The tile without the parts the person hid, with the colors they picked for its lines.
    func filtered(_ tile: Tile) -> Tile {
        let o = options
        guard !o.hidden.isEmpty || !o.rowColors.isEmpty || !series.isEmpty else { return tile }
        var t = tile
        // A palette or the main color gives the lines and parts their colors, in turn.
        if !series.isEmpty {
            var index = 0
            t.rows = t.rows.map { row in
                guard row.colorHex != nil else { return row }
                var copy = row
                copy.colorHex = seriesColor(at: index)
                index += 1
                return copy
            }
            switch t.visual {
            case let .segments(segments):
                t.visual = .segments(segments.enumerated().map { pair in
                    var copy = pair.element
                    copy.colorHex = seriesColor(at: pair.offset)
                    return copy
                })
            case let .grid(names, rows, colors):
                t.visual = .grid(names: names, rows: rows, colors: colors.indices.map { seriesColor(at: $0) })
            default:
                break
            }
        }
        if o.isHidden("value") {
            t.value = ""
            t.unit = nil
            t.timer = nil
        }
        if o.isHidden("caption") { t.caption = nil }
        if o.isHidden("detail") { t.detail = nil }
        if o.isHidden("visual") { t.visual = .none }
        if o.isHidden("buttons") {
            t.buttons = []
            t.headerButton = nil
        }
        if o.isHidden("footnote") { t.footnote = nil }
        if o.isHidden("rows") {
            t.rows = []
        } else {
            t.rows = t.rows
                .filter { !o.isHidden("row:\($0.id)") }
                .map { row in
                    var copy = row
                    if let hex = o.rowColors[row.id] { copy.colorHex = hex }
                    return copy
                }
        }
        if case let .segments(segments) = t.visual {
            t.visual = .segments(segments
                .filter { !o.isHidden("seg:\($0.label)") }
                .map { segment in
                    var copy = segment
                    if let hex = o.rowColors["seg:\(segment.label)"] { copy.colorHex = hex }
                    return copy
                })
        }
        return t
    }
}

extension ResolvedStyle {
    /// The color of the n-th line or part when a palette or the main color colors them.
    func seriesColor(at index: Int) -> String {
        series.isEmpty ? "" : series[index % series.count]
    }
}

extension TileVisual {
    var chartFamily: ChartFamily {
        switch self {
        case .bars, .line: .series
        case .ring, .bar: .progress
        case .segments: .segments
        default: .none
        }
    }

    var seriesValues: [Double]? {
        switch self {
        case let .bars(values, _, _): values
        case let .line(values): values
        default: nil
        }
    }

    var progressValue: Double? {
        switch self {
        case let .ring(progress), let .bar(progress): progress
        default: nil
        }
    }
}

enum ChartText {
    /// A short number for chart labels: 1 234 → "1,2k", 12.5 → "12,5".
    static func short(_ value: Double) -> String {
        let magnitude = abs(value)
        if magnitude >= 1_000_000 { return decimal(value / 1_000_000) + "M" }
        if magnitude >= 1_000 { return decimal(value / 1_000) + "k" }
        if magnitude >= 100 || value == value.rounded() { return String(Int(value.rounded())) }
        return decimal(value)
    }

    private static func decimal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}

// MARK: - Charts

/// A series drawn as a line, an area, a sparkline or an evolution.
struct SeriesLineChart: View {
    let values: [Double]
    let style: ResolvedStyle
    /// 0: no fill.
    var fillOpacity: Double = 0.28
    var lineWidth: CGFloat = 2
    var showsEndDot = false
    var showsEndValue = false
    var showsChange = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsChange, let first = values.first, let last = values.last {
                let change = first == 0 ? 0 : (last - first) / abs(first)
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(change >= 0 ? "+" : "")\(Fmt.percent(change))")
                        .font(style.text(10, .semibold).monospacedDigit())
                    Spacer(minLength: 0)
                    Text("\(ChartText.short(first)) → \(ChartText.short(last))")
                        .font(style.text(10).monospacedDigit())
                        .foregroundStyle(style.secondary)
                }
                .foregroundStyle(change >= 0 ? style.positive : style.negative)
                .lineLimit(1)
            }
            GeometryReader { geo in
                let rect = CGRect(origin: .zero, size: geo.size).insetBy(dx: showsEndDot || showsEndValue ? 4 : 0, dy: lineWidth)
                ZStack(alignment: .topLeading) {
                    if fillOpacity > 0 {
                        SparklineShape(values: values, closed: true)
                            .fill(LinearGradient(colors: [style.chart.opacity(fillOpacity), style.chart.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                            .frame(width: rect.width, height: rect.height)
                            .offset(x: rect.minX, y: rect.minY)
                    }
                    SparklineShape(values: values)
                        .stroke(style.chart, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                    if showsEndDot || showsEndValue, let end = endPoint(in: rect) {
                        Circle()
                            .fill(style.chart)
                            .frame(width: lineWidth * 2.6, height: lineWidth * 2.6)
                            .position(end)
                        if showsEndValue, let last = values.last {
                            Text(ChartText.short(last))
                                .font(style.text(9, .bold).monospacedDigit())
                                .foregroundStyle(style.primary)
                                .fixedSize()
                                .position(x: max(12, end.x - 12), y: max(6, end.y - 9))
                        }
                    }
                }
            }
        }
    }

    private func endPoint(in rect: CGRect) -> CGPoint? {
        guard values.count > 1, let low = values.min(), let high = values.max(), let last = values.last else { return nil }
        let range = max(high - low, 0.000_001)
        return CGPoint(x: rect.maxX, y: rect.maxY - CGFloat((last - low) / range) * rect.height)
    }
}

/// A series as dots joined by a faint line.
struct SeriesDotsChart: View {
    let values: [Double]
    let style: ResolvedStyle
    var dotSize: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size).insetBy(dx: dotSize, dy: dotSize)
            let points = positions(in: rect)
            ZStack(alignment: .topLeading) {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                }
                .stroke(style.chart.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                ForEach(Array(points.enumerated()), id: \.offset) { pair in
                    Circle()
                        .fill(pair.offset == points.count - 1 ? style.chart : style.chart.opacity(0.6))
                        .frame(width: dotSize, height: dotSize)
                        .position(pair.element)
                }
            }
        }
    }

    private func positions(in rect: CGRect) -> [CGPoint] {
        guard let low = values.min(), let high = values.max() else { return [] }
        let range = max(high - low, 0.000_001)
        let step = values.count > 1 ? rect.width / CGFloat(values.count - 1) : 0
        return values.enumerated().map { index, value in
            CGPoint(x: rect.minX + CGFloat(index) * step, y: rect.maxY - CGFloat((value - low) / range) * rect.height)
        }
    }
}

/// Two horizontal bars side by side: now against a reference (the average, the goal).
struct ComparisonChart: View {
    let current: Double
    let reference: Double
    let currentLabel: String
    let referenceLabel: String
    let style: ResolvedStyle
    var asPercent = false

    var body: some View {
        let top = max(current, reference, 0.000_1)
        VStack(alignment: .leading, spacing: 6) {
            bar(currentLabel, value: current, ratio: current / top, color: style.chart)
            bar(referenceLabel, value: reference, ratio: reference / top, color: style.secondary.opacity(0.5))
        }
        .frame(maxHeight: .infinity)
    }

    private func bar(_ label: String, value: Double, ratio: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(style.text(10, .medium)).foregroundStyle(style.secondary)
                Spacer(minLength: 2)
                Text(asPercent ? Fmt.percent(value) : ChartText.short(value))
                    .font(style.text(10, .semibold).monospacedDigit())
                    .foregroundStyle(style.primary)
            }
            .lineLimit(1)
            BarView(progress: ratio, color: color, track: style.track, height: 6 * CGFloat(style.options.chartThickness), radius: style.radius(3 * CGFloat(style.options.chartThickness)))
        }
    }
}

/// A half-circle gauge.
struct GaugeArcChart: View {
    let progress: Double
    let style: ResolvedStyle
    var lineWidth: CGFloat = 10
    var showsValue = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height * 2)
            ZStack {
                ArcShape(progress: 1)
                    .stroke(style.options.chartFill ? style.track : Color.clear, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                ArcShape(progress: min(1, max(0, progress)))
                    .stroke(style.chart, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                if showsValue {
                    Text(Fmt.percent(progress))
                        .font(style.number(max(11, side * 0.16)))
                        .foregroundStyle(style.numberColor)
                        .offset(y: side * 0.12)
                }
            }
            .frame(width: side, height: side / 2 + lineWidth / 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ArcShape: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width / 2, rect.height) - 6
        let center = CGPoint(x: rect.midX, y: rect.maxY - 3)
        path.addArc(center: center, radius: max(radius, 1), startAngle: .degrees(180), endAngle: .degrees(180 + 180 * progress), clockwise: false)
        return path
    }
}

struct PieSlice: Shape {
    let start: Double
    let end: Double
    /// 0: a full pie, otherwise the hole as a fraction of the radius.
    var hole: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let startAngle = Angle.degrees(-90 + 360 * start)
        let endAngle = Angle.degrees(-90 + 360 * end)
        if hole > 0 {
            path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            path.addArc(center: center, radius: radius * hole, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        } else {
            path.move(to: center)
            path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        }
        path.closeSubpath()
        return path
    }
}

/// One value as a filled pie.
struct ProgressPieChart: View {
    let progress: Double
    let style: ResolvedStyle
    var showsValue = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().fill(style.options.chartFill ? style.track : Color.clear)
                Circle().strokeBorder(style.chart.opacity(0.35), lineWidth: 1)
                PieSlice(start: 0, end: min(1, max(0.001, progress))).fill(style.chart)
                if showsValue {
                    Text(Fmt.percent(progress))
                        .font(style.number(max(10, side * 0.2)))
                        .foregroundStyle(style.onAccent)
                        .shadow(color: .black.opacity(0.25), radius: 2)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Parts of a whole as a donut or a pie.
struct SegmentsRoundChart: View {
    let segments: [TileSegment]
    let style: ResolvedStyle
    var hole: CGFloat = 0.6
    var showsLegend = false

    var body: some View {
        let total = max(segments.reduce(0) { $0 + max(0, $1.value) }, 0.000_1)
        let bounds = segments.reduce(into: [(Double, Double)]()) { result, segment in
            let start = result.last?.1 ?? 0
            result.append((start, start + max(0, segment.value) / total))
        }
        HStack(spacing: 12) {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    ForEach(Array(segments.enumerated()), id: \.offset) { pair in
                        PieSlice(start: bounds[pair.offset].0, end: bounds[pair.offset].1, hole: hole)
                            .fill(Color(hex: pair.element.colorHex))
                    }
                }
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(1, contentMode: .fit)
            if showsLegend {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(segments.prefix(5).enumerated()), id: \.offset) { pair in
                        HStack(spacing: 5) {
                            Circle().fill(Color(hex: pair.element.colorHex)).frame(width: 7, height: 7)
                            Text(pair.element.label)
                                .font(style.text(10))
                                .foregroundStyle(style.primary)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            if style.options.chartValues {
                                Text(Fmt.percent(max(0, pair.element.value) / total))
                                    .font(style.text(10, .semibold).monospacedDigit())
                                    .foregroundStyle(style.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Parts of a whole as vertical bars, each in its own color.
struct SegmentsBarsChart: View {
    let segments: [TileSegment]
    let style: ResolvedStyle

    var body: some View {
        let top = max(segments.map(\.value).max() ?? 0, 0.000_1)
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(segments.enumerated()), id: \.offset) { pair in
                    VStack(spacing: 2) {
                        if style.options.chartValues {
                            Text(ChartText.short(pair.element.value))
                                .font(style.text(9, .semibold).monospacedDigit())
                                .foregroundStyle(style.secondary)
                                .fixedSize()
                        }
                        RoundedRectangle(cornerRadius: style.radius(3), style: .continuous)
                            .fill(Color(hex: pair.element.colorHex))
                            .frame(height: max(3, (geo.size.height - (style.options.chartValues ? 14 : 0)) * CGFloat(max(0, pair.element.value) / top)))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

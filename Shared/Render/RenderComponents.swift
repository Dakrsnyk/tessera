import AppIntents
import SwiftUI
import WidgetKit

struct RenderContext {
    var design: WidgetDesign
    var style: ResolvedStyle
    var family: WidgetFamily
    var date: Date
    var payload: WidgetPayload
    /// False in app previews, where tapping must not change the user's data.
    var isInteractive: Bool
    /// Set by combined widgets: only one of their widgets shows the buttons that open the app.
    var linksAllowed: Bool? = nil

    /// Buttons that open the app are links, which iOS only allows on medium and large widgets.
    var allowsLinks: Bool { linksAllowed ?? (family == .systemMedium || family == .systemLarge || family == .systemExtraLarge) }

    var isSmall: Bool { family == .systemSmall }
    var isMedium: Bool { family == .systemMedium }
    var isLarge: Bool { family == .systemLarge || family == .systemExtraLarge }
    var settings: AppSettings { payload.settings }
    var options: DesignOptions { design.options }
}

/// Small caption used as a widget title.
struct WLabel: View {
    let text: String
    let style: ResolvedStyle
    var color: Color?

    var body: some View {
        Text(style.uppercaseLabels ? text.uppercased() : text)
            .font(style.text(11, .semibold))
            .tracking(style.uppercaseLabels ? 0.6 : 0)
            .foregroundStyle(color ?? style.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

struct RingView: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    let color: Color
    let track: Color

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

struct BarView: View {
    let progress: Double
    let color: Color
    let track: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(color)
                    .frame(width: max(height, geo.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: height)
    }
}

/// Line chart path normalized to the rect.
struct SparklineShape: Shape {
    let values: [Double]
    var closed = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1, let low = values.min(), let high = values.max() else { return path }
        let range = max(high - low, 0.000_001)
        let stepX = rect.width / CGFloat(values.count - 1)
        func point(_ index: Int) -> CGPoint {
            let y = rect.maxY - CGFloat((values[index] - low) / range) * rect.height
            return CGPoint(x: rect.minX + CGFloat(index) * stepX, y: y)
        }
        path.move(to: point(0))
        for index in 1..<values.count {
            path.addLine(to: point(index))
        }
        if closed {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// A grid of dots laid out row by row; only the dots whose index is in `range` are drawn.
struct DotGridShape: Shape {
    let total: Int
    let columns: Int
    let range: Range<Int>

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard total > 0, columns > 0 else { return path }
        let rows = Int(ceil(Double(total) / Double(columns)))
        let cell = min(rect.width / CGFloat(columns), rect.height / CGFloat(rows))
        let diameter = cell * 0.68
        let gridWidth = cell * CGFloat(columns)
        let gridHeight = cell * CGFloat(rows)
        let originX = rect.minX + (rect.width - gridWidth) / 2
        let originY = rect.minY + (rect.height - gridHeight) / 2
        for index in range where index >= 0 && index < total {
            let row = index / columns
            let column = index % columns
            let x = originX + CGFloat(column) * cell + (cell - diameter) / 2
            let y = originY + CGFloat(row) * cell + (cell - diameter) / 2
            path.addEllipse(in: CGRect(x: x, y: y, width: diameter, height: diameter))
        }
        return path
    }
}

/// Wraps an App Intent button so previews in the app stay inert.
struct IntentButton<Intent: AppIntent, Label: View>: View {
    let intent: Intent
    let isEnabled: Bool
    @ViewBuilder let label: () -> Label

    var body: some View {
        if isEnabled {
            Button(intent: intent) { label() }
                .buttonStyle(.plain)
        } else {
            label()
        }
    }
}

/// Centered symbol + message, used when a widget has nothing to show yet.
struct WidgetMessage: View {
    let symbol: String
    let title: String
    var message: String?
    let style: ResolvedStyle

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(style.accent)
            Text(title)
                .font(style.text(14, .semibold))
                .foregroundStyle(style.primary)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(style.text(11))
                    .foregroundStyle(style.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    /// Aligns content inside the widget according to the design's alignment setting.
    func widgetFrame(_ style: ResolvedStyle) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: style.alignment == .center ? .center : .topLeading)
    }
}

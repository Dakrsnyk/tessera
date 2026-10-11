import SwiftUI

/// Brand moment while the app loads: the two halves of the A slide in from each side, the name rises
/// under them, then the whole mark lifts away to reveal the app (see `RootView`).
struct LaunchView: View {
    @State private var settled = false
    @State private var showsName = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle().fill(.screenFill).ignoresSafeArea()
            VStack(spacing: 24) {
                ArdaneMark(size: 96, settled: settled || reduceMotion)
                Text(tr("Ardane"))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .tracking(0.5)
                    .opacity(showsName || reduceMotion ? 1 : 0)
                    .offset(y: showsName || reduceMotion ? 0 : 12)
                    .blur(radius: showsName || reduceMotion ? 0 : 6)
            }
        }
        .task {
            settled = true
            try? await Task.sleep(for: .milliseconds(330))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { showsName = true }
        }
        .accessibilityHidden(true)
    }
}

/// The app mark, as on the icon: an A in two halves split by a narrow gap, white and peach on the
/// coral gradient. With `settled` false the halves wait outside the frame, and slide in from each side
/// when it turns true. With a `tint` (tinted Home Screens), the halves take that color, without ground.
struct ArdaneMark: View {
    var size: CGFloat
    var settled = true
    var tint: Color?

    static let coral = Color(hex: "FF7A59")
    static let raspberry = Color(hex: "D9246A")
    static let peach = Color(hex: "FFE0CC")

    var body: some View {
        ZStack {
            if tint == nil {
                LinearGradient(colors: [Self.coral, Self.raspberry], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            half(.left, tint ?? .white, order: 0)
            half(.right, tint?.opacity(0.6) ?? Self.peach, order: 1)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
        .scaleEffect(settled ? 1 : 0.86)
        .opacity(settled ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: settled)
        .accessibilityHidden(true)
    }

    private func half(_ side: ArdaneHalf.Side, _ color: Color, order: Int) -> some View {
        ArdaneHalf(side: side)
            .fill(color)
            .offset(x: settled ? 0 : (side == .left ? -size * 0.6 : size * 0.6))
            .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.12 + Double(order) * 0.1), value: settled)
    }
}

/// One half of the A, in the icon's geometry (a 100 × 100 grid scaled to the frame).
struct ArdaneHalf: Shape {
    enum Side { case left, right }
    let side: Side

    func path(in rect: CGRect) -> Path {
        let points: [(CGFloat, CGFloat)] = side == .left
            ? [(47.5, 19.3), (47.5, 55.4), (34, 86), (16, 86)]
            : [(52.5, 19.3), (84, 86), (66, 86), (52.5, 55.4)]
        let k = min(rect.width, rect.height) / 100
        var path = Path()
        path.addLines(points.map { CGPoint(x: rect.minX + $0.0 * k, y: rect.minY + $0.1 * k) })
        path.closeSubpath()
        return path
    }
}

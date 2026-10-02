import SwiftUI

/// Brand moment while the app loads: the three tiles of the icon slide in one after the other and
/// their gaps draw the T, the name rises under them, then the whole mark lifts away to reveal the app
/// (see `RootView`).
struct LaunchView: View {
    @State private var settled = false
    @State private var showsName = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle().fill(.screenFill).ignoresSafeArea()
            VStack(spacing: 24) {
                TesseraMark(size: 96, settled: settled || reduceMotion)
                Text(tr("Tessera"))
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

/// The app mark, as on the icon: three tiles whose gaps draw a T (« T en creux »): red on top, orange
/// and charcoal below, on cream. With `settled` false the tiles wait outside the frame, and slide in one
/// after the other when it turns true. With a `tint` (tinted Home Screens), the tiles take that color.
struct TesseraMark: View {
    var size: CGFloat
    var settled = true
    var tint: Color?

    static let red = Color(hex: "E5383B")
    static let orange = Color(hex: "FF8A3D")
    static let white = Color(hex: "F7F4EF")
    static let charcoal = Color(hex: "211A1B")

    var body: some View {
        let k = size / 1024
        let gap = 92 * k
        let bar = 300 * k
        let over = 90 * k
        let stemLeft = 512 * k - gap / 2
        let below = bar + gap
        ZStack(alignment: .topLeading) {
            background
            tile(top, x: -over, y: -over, width: size + 2 * over, height: bar + over, order: 0, from: CGSize(width: 0, height: -size * 0.7))
            tile(left, x: -over, y: below, width: stemLeft + over, height: size - below + over, order: 1, from: CGSize(width: -size * 0.7, height: 0))
            tile(right, x: stemLeft + gap, y: below, width: size - stemLeft - gap + over, height: size - below + over, order: 2, from: CGSize(width: size * 0.7, height: size * 0.2))
        }
        .frame(width: size, height: size, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
        .scaleEffect(settled ? 1 : 0.86)
        .opacity(settled ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: settled)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var background: some View {
        if tint == nil {
            LinearGradient(colors: [Color(hex: "FBF8F3"), Color(hex: "EAE3D8")], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Color.clear
        }
    }

    private var top: AnyShapeStyle {
        if let tint { return AnyShapeStyle(tint) }
        return AnyShapeStyle(LinearGradient(colors: [Color(hex: "F04B4D"), Color(hex: "D62F33")], startPoint: .top, endPoint: .bottom))
    }

    private var left: AnyShapeStyle {
        if let tint { return AnyShapeStyle(tint.opacity(0.72)) }
        return AnyShapeStyle(LinearGradient(colors: [Color(hex: "FF9D55"), Color(hex: "F5782C")], startPoint: .top, endPoint: .bottom))
    }

    private var right: AnyShapeStyle {
        if let tint { return AnyShapeStyle(tint.opacity(0.45)) }
        return AnyShapeStyle(LinearGradient(colors: [Color(hex: "2B2223"), Color(hex: "0E0C0C")], startPoint: .top, endPoint: .bottom))
    }

    private func tile(_ fill: AnyShapeStyle, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, order: Int, from offset: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 56 * size / 1024, style: .continuous)
            .fill(fill)
            .frame(width: width, height: height)
            .offset(x: x + (settled ? 0 : offset.width), y: y + (settled ? 0 : offset.height))
            .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.12 + Double(order) * 0.1), value: settled)
    }
}

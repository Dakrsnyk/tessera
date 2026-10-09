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

/// The app mark, as on the icon (« Verre rouge »): three tiles whose gaps draw a T (« T en creux »),
/// two of clear glass and one of smoked glass, on the red and orange of the brand. With `settled` false
/// the tiles wait outside the frame, and slide in one after the other when it turns true. With a `tint`
/// (tinted Home Screens), the tiles take that color.
struct TesseraMark: View {
    var size: CGFloat
    var settled = true
    var tint: Color?

    private enum Look {
        case clear, smoke
    }

    var body: some View {
        let k = size / 1024
        let gap = 92 * k
        let bar = 300 * k
        let over = 90 * k
        let stemLeft = 512 * k - gap / 2
        let below = bar + gap
        ZStack(alignment: .topLeading) {
            background
            tile(.clear, tint.map { AnyShapeStyle($0) }, x: -over, y: -over, width: size + 2 * over, height: bar + over, order: 0, from: CGSize(width: 0, height: -size * 0.7))
            tile(.clear, tint.map { AnyShapeStyle($0.opacity(0.72)) }, x: -over, y: below, width: stemLeft + over, height: size - below + over, order: 1, from: CGSize(width: -size * 0.7, height: 0))
            tile(.smoke, tint.map { AnyShapeStyle($0.opacity(0.45)) }, x: stemLeft + gap, y: below, width: size - stemLeft - gap + over, height: size - below + over, order: 2, from: CGSize(width: size * 0.7, height: size * 0.2))
            if tint == nil {
                // The light on the top of the glass.
                LinearGradient(colors: [Color.white.opacity(0.16), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.38))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size, height: size, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
        .scaleEffect(settled ? 1 : 0.86)
        .opacity(settled ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: settled)
        .accessibilityHidden(true)
    }

    /// The red and orange of the brand, in soft patches (as on the icon).
    @ViewBuilder private var background: some View {
        if tint == nil {
            ZStack {
                Color(hex: "E8443A")
                RadialGradient(colors: [Color(hex: "FF9A3D"), .clear], center: UnitPoint(x: 0.15, y: 0.95), startRadius: 0, endRadius: size * 0.9)
                RadialGradient(colors: [Color(hex: "D61F3A"), .clear], center: UnitPoint(x: 0.9, y: 0.05), startRadius: 0, endRadius: size * 0.75)
                RadialGradient(colors: [Color(hex: "FFB36B"), .clear], center: UnitPoint(x: 0.85, y: 0.85), startRadius: 0, endRadius: size * 0.45)
            }
            .frame(width: size, height: size)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func tile(_ look: Look, _ tinted: AnyShapeStyle?, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, order: Int, from offset: CGSize) -> some View {
        let k = size / 1024
        let shape = RoundedRectangle(cornerRadius: 64 * k, style: .continuous)
        Group {
            if let tinted {
                shape.fill(tinted)
            } else if look == .clear {
                shape.fill(LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.18)], startPoint: UnitPoint(x: 0.35, y: 0), endPoint: UnitPoint(x: 0.65, y: 1)))
                    .overlay {
                        shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0.3)], startPoint: .top, endPoint: .bottom), lineWidth: max(0.5, 5 * k))
                    }
                    .shadow(color: .black.opacity(0.18), radius: 25 * k, x: 0, y: 20 * k)
            } else {
                shape.fill(LinearGradient(colors: [Color(hex: "14101E").opacity(0.55), Color(hex: "0A0810").opacity(0.78)], startPoint: UnitPoint(x: 0.35, y: 0), endPoint: UnitPoint(x: 0.65, y: 1)))
                    .overlay {
                        shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: max(0.5, 5 * k))
                    }
                    .shadow(color: .black.opacity(0.25), radius: 25 * k, x: 0, y: 20 * k)
            }
        }
        .frame(width: width, height: height)
        .offset(x: x + (settled ? 0 : offset.width), y: y + (settled ? 0 : offset.height))
        .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.12 + Double(order) * 0.1), value: settled)
    }
}

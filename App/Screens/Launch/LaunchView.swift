import SwiftUI

/// Brand moment while the app loads: the three tiles of the icon fly in one after the other,
/// the name rises under them, then the whole mark lifts away to reveal the app (see `RootView`).
struct LaunchView: View {
    @State private var settled = false
    @State private var showsName = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle().fill(.screenFill).ignoresSafeArea()
            VStack(spacing: 24) {
                TesseraMark(size: 96, settled: settled || reduceMotion)
                Text("Tessera")
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

/// The app mark: one tall tile and two small ones, as on the icon. Red, white and orange.
/// With `settled` false the tiles wait off their place, and fly in one after the other when it turns true.
struct TesseraMark: View {
    var size: CGFloat
    var settled = true

    static let red = Color(hex: "E5383B")
    static let orange = Color(hex: "FF8A3D")
    static let white = Color(hex: "F7F4EF")

    var body: some View {
        let gap = size * 0.08
        let column = (size - gap) / 2
        HStack(spacing: gap) {
            tile(Self.red, width: column, height: size, order: 0, from: CGSize(width: 0, height: -size * 0.55))
            VStack(spacing: gap) {
                tile(Self.white, width: column, height: column, order: 1, from: CGSize(width: size * 0.55, height: 0), outlined: true)
                tile(Self.orange, width: column, height: column, order: 2, from: CGSize(width: 0, height: size * 0.55))
            }
        }
        .frame(width: size, height: size)
    }

    private func tile(_ color: Color, width: CGFloat, height: CGFloat, order: Int, from offset: CGSize, outlined: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
        return shape
            .fill(color)
            .overlay {
                // The white tile keeps an edge on light backgrounds.
                if outlined {
                    shape.strokeBorder(Color.primary.opacity(0.12), lineWidth: max(0.5, size * 0.012))
                }
            }
            .frame(width: width, height: height)
            .scaleEffect(settled ? 1 : 0.4)
            .rotationEffect(.degrees(settled ? 0 : Double(order - 1) * 14))
            .offset(settled ? .zero : offset)
            .opacity(settled ? 1 : 0)
            .animation(.spring(response: 0.55, dampingFraction: 0.68).delay(Double(order) * 0.09), value: settled)
    }
}

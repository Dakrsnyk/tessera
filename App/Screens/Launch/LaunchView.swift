import SwiftUI

/// Brief brand moment while the app loads: the three tiles of the icon settle into place.
struct LaunchView: View {
    @State private var settled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.screenFill.ignoresSafeArea()
            VStack(spacing: 22) {
                TesseraMark(size: 88, settled: settled || reduceMotion)
                Text("Tessera")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .opacity(settled || reduceMotion ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { settled = true }
        }
        .accessibilityHidden(true)
    }
}

/// The app mark: one tall tile and two small ones, as on the icon.
struct TesseraMark: View {
    var size: CGFloat
    var settled = true

    var body: some View {
        let gap = size * 0.08
        let column = (size - gap) / 2
        let radius = size * 0.12
        HStack(spacing: gap) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color(hex: "2F8F7A"))
                .frame(width: column, height: size)
                .offset(y: settled ? 0 : -size * 0.3)
            VStack(spacing: gap) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(light: "1C2B27", dark: "EFEDE6"))
                    .frame(width: column, height: column)
                    .offset(x: settled ? 0 : size * 0.3)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(hex: "F2A33A"))
                    .frame(width: column, height: column)
                    .offset(y: settled ? 0 : size * 0.3)
            }
        }
        .opacity(settled ? 1 : 0)
        .frame(width: size, height: size)
    }
}

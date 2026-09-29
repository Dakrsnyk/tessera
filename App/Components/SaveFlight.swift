import SwiftUI
import WidgetKit

/// Widgets just saved from a space, on their way to « Mes widgets ».
struct SaveFlight: Identifiable {
    let id = UUID()
    let designs: [WidgetDesign]
    /// Where the widgets were on screen when saved (global coordinates).
    let source: CGRect
}

/// The widgets leave the place they were created, gather into a small stack when there are several,
/// then fly along a short curve into the « Mes widgets » tab. Short, drawn above everything, not touchable.
struct SaveFlightOverlay: View {
    let flight: SaveFlight
    let onFinish: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grouped = false
    @State private var lifted = false
    @State private var flying = false

    private var items: [WidgetDesign] { Array(flight.designs.prefix(4)) }
    private var isGroup: Bool { items.count > 1 }

    var body: some View {
        GeometryReader { geo in
            let origin = sourceCenter(in: geo.size)
            let target = Self.target(in: geo.size)
            ZStack {
                ForEach(Array(items.enumerated()), id: \.offset) { index, design in
                    let spread = CGFloat(index) - CGFloat(items.count - 1) / 2
                    tile(design)
                        .rotationEffect(.degrees(grouped ? Double(spread) * 7 : 0))
                        .scaleEffect(flying ? 0.12 : (lifted ? 1.06 : (grouped ? 0.9 : 1)))
                        .opacity(flying ? 0 : 1)
                        .animation(.easeIn(duration: 0.46), value: flying)
                        .position(
                            x: origin.x + (grouped ? spread * 6 : spread * 74),
                            y: origin.y + (grouped ? -CGFloat(index) * 4 : 0)
                        )
                        // Two curves, one per axis: the widgets glide sideways first and drop into the tab
                        // at the end, which draws a short arc.
                        .offset(x: flying ? target.x - origin.x : 0)
                        .animation(reduceMotion ? nil : .timingCurve(0.3, 0, 0.2, 1, duration: 0.5), value: flying)
                        .offset(y: flying ? target.y - origin.y : 0)
                        .animation(reduceMotion ? nil : .timingCurve(0.65, 0, 0.9, 0.55, duration: 0.5), value: flying)
                        .zIndex(Double(items.count - index))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { await run() }
    }

    private func tile(_ design: WidgetDesign) -> some View {
        let family = design.displayFormat.family
        let height: CGFloat = isGroup ? 104 : (family == .systemLarge ? 220 : 150)
        return WidgetPreview(design: design, family: family, payload: model.payload(for: design), width: height * family.aspectRatio)
            .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
    }

    private func sourceCenter(in size: CGSize) -> CGPoint {
        guard flight.source.width > 0 else { return CGPoint(x: size.width / 2, y: size.height * 0.42) }
        return CGPoint(x: flight.source.midX, y: flight.source.midY)
    }

    /// The « Mes widgets » tab: the last of the four tabs.
    static func target(in size: CGSize) -> CGPoint {
        if #available(iOS 26.0, *) {
            return CGPoint(x: size.width * 0.81, y: size.height - 60)
        }
        return CGPoint(x: size.width * 0.875, y: size.height - 58)
    }

    private func run() async {
        // Let the sheet slide away first: the widgets stay where they were created.
        try? await Task.sleep(for: .milliseconds(300))
        if isGroup {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) { grouped = true }
            try? await Task.sleep(for: .milliseconds(340))
        } else {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) { lifted = true }
            try? await Task.sleep(for: .milliseconds(180))
        }
        flying = true
        try? await Task.sleep(for: .milliseconds(480))
        Haptics.tap()
        onFinish()
    }
}

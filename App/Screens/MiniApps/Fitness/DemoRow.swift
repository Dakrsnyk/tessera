import SwiftUI

/// The small looping demonstration of the Fitness lists, 64 × 56 on its dark tile: an exercise's own figure, or the
/// anatomy figure of a muscle group (« anatomy-<group> », the group in red, framed on it). Same drawing as the
/// exercise sheet (`DemoRenderer`), 20 frames a second; still when Reduce Motion is on.
struct DemoThumbnail: View {
    let demoID: String
    var colorHex = MiniApp.fitness.colorHex
    var width: CGFloat = 64
    var height: CGFloat = 56

    @State private var startedAt = Date()
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let palette = DemoPalette(scheme: scheme, accentHex: colorHex)
        // The exercise's (or the muscle group's) own muscles, even when it shows a built-in exercise's movement.
        let muscles = DemoMuscles.forDemo(demoID)
        Group {
            if let demo = ExerciseDemos.demo(for: demoID) {
                TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { timeline in
                    let phase = demo.phase(at: reduceMotion ? 0 : timeline.date.timeIntervalSince(startedAt))
                    Canvas { context, size in
                        DemoRenderer.draw(demo, p: phase.p, view: 0, in: &context, size: size, palette: palette,
                                          muscles: muscles, dark: scheme == .dark)
                    }
                }
            } else {
                Color.clear
            }
        }
        .frame(width: width, height: height)
        .background(palette.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A row of the Fitness lists in the style of the « Progression » pages (CEO, 2026-11-23): the animated thumbnail, the
/// name on up to two lines, a detail line, a figure in bold grey, the chevron. Without a demonstration, the same tile
/// holds an icon, so every row lines up.
struct DemoRow: View {
    let demoID: String?
    let symbol: String
    let title: String
    var detail: String?
    var value: String?
    var showsChevron = true
    var colorHex = MiniApp.fitness.colorHex

    @Environment(\.colorScheme) private var scheme
    @Environment(\.appStyle) private var style

    var body: some View {
        HStack(spacing: 12) {
            if let demoID, ExerciseDemos.demo(for: demoID) != nil {
                DemoThumbnail(demoID: demoID, colorHex: colorHex)
            } else {
                let tint = CristalPalette.of(style.id).category(colorHex)
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 64, height: 56)
                    .background(DemoPalette(scheme: scheme, accentHex: colorHex).background,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let value, !value.isEmpty {
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

extension MuscleGroup {
    /// The anatomy figure of the group: the body, the group in red, framed on it (scripts/demos/anatomy.py).
    var anatomyID: String { "anatomy-\(rawValue)" }
}

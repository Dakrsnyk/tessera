import SwiftUI

#if DEBUG
/// Review captures of the exercise demonstrations: every exercise of the library, three moments of
/// the movement each (start, middle, end), as the app draws them. Mode: gallery-demos-<page>
/// (8 exercises a page), or gallery-demos-<page>-v<view> for another angle.
struct DemoGalleryView: View {
    let mode: String
    @Environment(\.colorScheme) private var scheme

    private var parts: [String] { mode.split(separator: "-").map(String.init) }
    private var page: Int { max(1, Int(parts[safe: 2] ?? "1") ?? 1) }
    private var view: Int { parts.first(where: { $0.hasPrefix("v") }).flatMap { Int($0.dropFirst()) } ?? 0 }

    private var exercises: [ExerciseInfo] {
        Array(ExerciseLibrary.all.dropFirst((page - 1) * 8).prefix(8))
    }

    var body: some View {
        let palette = DemoPalette(scheme: scheme, accentHex: MiniApp.fitness.colorHex)
        VStack(alignment: .leading, spacing: 6) {
            Text(tr("Démonstrations · page \(page)"))
                .font(.headline)
            ForEach(exercises) { exercise in
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    if let demo = ExerciseDemos.demo(for: exercise.id) {
                        HStack(spacing: 4) {
                            ForEach(phases(demo), id: \.self) { p in
                                Canvas { context, size in
                                    DemoRenderer.draw(demo, p: p, view: min(view, demo.views.count - 1), in: &context, size: size,
                                                      palette: palette)
                                }
                                .background(palette.background, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .frame(height: 74)
                    } else {
                        Text(tr("Pas de démonstration")).font(.caption2).foregroundStyle(.red)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.top, 54)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
    }

    private func phases(_ demo: DemoModel) -> [Double] {
        demo.loop ? [0.0, 0.33, 0.66] : [0.0, 0.5, 1.0]
    }
}
#endif

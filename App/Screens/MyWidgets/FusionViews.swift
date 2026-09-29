import SwiftUI
import WidgetKit

/// A merge in progress: the selected cards, where they were, and the widget they become.
struct FusionRun: Identifiable {
    struct Source {
        let design: WidgetDesign
        let payload: WidgetPayload
        /// The card on screen (global coordinates), zero when unknown.
        let frame: CGRect
    }

    let id = UUID()
    let sources: [Source]
    let merged: WidgetDesign
    let mergedPayload: WidgetPayload
    let keepsOriginals: Bool
    /// Set once the merged widget is saved.
    var isDone = false

    /// The real cards stay hidden while their copies move, until the merge is saved.
    func hides(_ id: UUID) -> Bool {
        !isDone && sources.contains { $0.design.id == id }
    }
}

/// Before merging: what goes in, what comes out, at its real size.
struct FusionSheet: View {
    let designs: [WidgetDesign]
    let merged: WidgetDesign
    let onConfirm: (_ keepsOriginals: Bool) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var keepsOriginals = false

    private var format: WidgetFormat { merged.displayFormat }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    stage
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Un widget \(format.title.lowercased())")
                            .font(.title3.weight(.semibold))
                        Text("Un vrai widget \(format.title.lowercased()) pour ton écran d'accueil : dans la galerie de widgets, choisis la taille \(format.title).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    EditorSection(title: "Contient", detail: Fmt.plural(merged.options.parts.count, "widget", "widgets")) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(merged.options.parts.enumerated()), id: \.offset) { _, part in
                                HStack(spacing: 12) {
                                    Image(systemName: part.kind.symbol)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 26)
                                    Text(part.name)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    Text(part.size == .small ? "Moitié de ligne" : "Ligne entière")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Toggle("Garder aussi les widgets d'origine", isOn: $keepsOriginals)
                        .card(padding: 14)
                    Text("Aucune information n'est perdue : chaque widget garde tout son contenu. Le widget fusionné reste personnalisable dans l'éditeur (style, couleur, fond, police).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(.screenFill)
            .safeAreaInset(edge: .bottom) {
                Button {
                    onConfirm(keepsOriginals)
                    dismiss()
                } label: {
                    Label("Fusionner", systemImage: "arrow.triangle.merge")
                        .font(.headline)
                        .foregroundStyle(.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .navigationTitle("Fusionner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }

    private var stage: some View {
        ZStack {
            LinearGradient(
                colors: [Color(light: "DCE3EA", dark: "1B1F26"), Color(light: "C9D3DD", dark: "11141A")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    ForEach(designs) { design in
                        let family = design.displayFormat.family
                        WidgetPreview(design: design, family: family, payload: model.payload(for: design), width: 66 * family.aspectRatio)
                    }
                }
                Image(systemName: "arrow.down")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                WidgetPreview(design: merged, family: format.family, payload: model.payload(for: merged))
                    .frame(maxWidth: 340)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// The merge: the cards come together, gather into a small stack, melt into one widget,
/// and the new widget appears at its size before taking its place in the collection.
struct FusionOverlay: View {
    enum Phase {
        case start, gathered, merged, finished
    }

    let run: FusionRun
    let onPhase: (Phase) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .start

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.42)
            let count = run.sources.count
            ZStack {
                Color.black
                    .opacity(phase == .gathered || phase == .merged ? 0.14 : 0)
                ForEach(Array(run.sources.enumerated()), id: \.offset) { index, source in
                    let spread = CGFloat(index) - CGFloat(count - 1) / 2
                    let family = source.design.displayFormat.family
                    let width = source.frame.width > 1 ? source.frame.width : 150
                    let height = width / family.aspectRatio
                    let start = source.frame.width > 1 ? CGPoint(x: source.frame.midX, y: source.frame.minY + height / 2) : center
                    let gathered = phase != .start
                    WidgetPreview(design: source.design, family: family, payload: source.payload, width: width)
                        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                        .rotationEffect(.degrees(gathered && !reduceMotion ? Double(spread) * 6 : 0))
                        .scaleEffect(phase == .start ? 1 : (phase == .gathered ? 118 / width : 60 / width))
                        .opacity(phase == .merged || phase == .finished ? 0 : 1)
                        .position(gathered ? CGPoint(x: center.x + spread * 16, y: center.y - CGFloat(index) * 5) : start)
                        .zIndex(Double(count - index))
                }
                WidgetPreview(design: run.merged, family: run.merged.displayFormat.family, payload: run.mergedPayload, width: min(geo.size.width - 48, 340))
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
                    .scaleEffect(phase == .merged ? 1 : (phase == .finished ? 0.94 : 0.55))
                    .opacity(phase == .merged ? 1 : 0)
                    .position(center)
                    .zIndex(Double(count + 1))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { await animate() }
    }

    private func animate() async {
        try? await Task.sleep(for: .milliseconds(40))
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) { phase = .gathered }
        try? await Task.sleep(for: .milliseconds(400))
        withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) { phase = .merged }
        onPhase(.merged)
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.easeOut(duration: 0.25)) { phase = .finished }
        try? await Task.sleep(for: .milliseconds(260))
        onPhase(.finished)
    }
}

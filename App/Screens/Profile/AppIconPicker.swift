import SwiftUI

/// « Icône de l'app »: Tessera's icon on the Home Screen, among the glass icons and the classic one.
/// Reached from Profil, or from a long press on the icon (« Changer d'icône »).
struct AppIconPicker: View {
    @State private var current: String?
    @State private var failed = false
    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(tr("Choisis l'icône de Tessera sur ton écran d'accueil. Pour revenir ici, touche et maintiens l'icône, puis « Changer d'icône »."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(AppIconChoice.all) { choice in
                        Button {
                            Task { await pick(choice) }
                        } label: {
                            cell(choice)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("icon-\(choice.asset)")
                    }
                }
            }
            .padding(20)
        }
        .background(.screenGradient)
        .navigationTitle(tr("Icône de l'app"))
        .navigationBarTitleDisplayMode(.inline)
        .task { current = AppIconSwitcher.current }
        .alert(tr("Icône de l'app"), isPresented: $failed) {
            Button(tr("OK"), role: .cancel) {}
        } message: {
            Text(tr("L'icône n'a pas pu être changée. Réessaie dans un instant."))
        }
    }

    private func cell(_ choice: AppIconChoice) -> some View {
        let isCurrent = choice.asset == current
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(spacing: 6) {
            Image(choice.preview)
                .resizable()
                .frame(width: 72, height: 72)
                .clipShape(shape)
                .overlay { shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                .padding(4)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: isCurrent ? 3 : 0)
                }
                .overlay(alignment: .topTrailing) {
                    if isCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color.white, Color.accentColor)
                            .offset(x: 6, y: -6)
                    }
                }
            Text(choice.title)
                .font(.caption.weight(isCurrent ? .semibold : .regular))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if choice.asset == AppIconChoice.main {
                Text(tr("Par défaut"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func pick(_ choice: AppIconChoice) async {
        if await AppIconSwitcher.apply(choice) {
            current = choice.asset
        } else {
            failed = true
        }
    }
}

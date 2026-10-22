import SwiftUI

/// « Icône de l'app »: Ardane's icon on the Home Screen, the classic one or one of the glass icons.
/// Reached from Profil, or from a long press on the icon (« Changer d'icône »). Changing it is Premium:
/// without it, the other icons carry the badge and open the paywall; the icon in place stays, and the main
/// one can always come back (see `AppIconChoice.isLocked`), after a warning since the other can't.
struct AppIconPicker: View {
    @Environment(AppModel.self) private var model
    @State private var current: String?
    @State private var failed = false
    @State private var paywall: PaywallContext?
    /// The main icon, touched by a free person who has another one: asked first.
    @State private var pendingMain: AppIconChoice?
    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(tr("Choisis l'icône d'Ardane sur ton écran d'accueil. Pour revenir ici, touche et maintiens l'icône, puis « Changer d'icône »."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(AppIconChoice.all) { choice in
                        Button {
                            if isLocked(choice) {
                                paywall = Self.paywallContext
                            } else if choice.asset == AppIconChoice.main, keptIcon != nil {
                                pendingMain = choice
                            } else {
                                Task { await pick(choice) }
                            }
                        } label: {
                            cell(choice)
                        }
                        .buttonStyle(.pressable)
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
        .confirmationDialog(tr("Revenir à l'icône par défaut ?"), isPresented: Binding(get: { pendingMain != nil }, set: { if !$0 { pendingMain = nil } }), titleVisibility: .visible) {
            Button(tr("Changer d'icône")) {
                if let choice = pendingMain {
                    Task { await pick(choice) }
                }
                pendingMain = nil
            }
        } message: {
            if let kept = keptIcon {
                Text(tr("Sans Premium, tu ne pourras plus revenir à « \(kept.title) »."))
            }
        }
        .sheet(item: $paywall) { PaywallView(context: $0) }
    }

    private func isLocked(_ choice: AppIconChoice) -> Bool {
        choice.isLocked(current: current ?? AppIconChoice.main, isPremium: model.isPremium)
    }

    /// The icon in place that a free person couldn't pick again once left (see `AppIconChoice.isLocked`).
    private var keptIcon: AppIconChoice? {
        guard !model.isPremium, let current, current != AppIconChoice.main else { return nil }
        return AppIconChoice.all.first { $0.asset == current }
    }

    private static var paywallContext: PaywallContext {
        let count = AppIconChoice.all.count
        return PaywallContext(
            symbol: "app.badge",
            title: tr("Toutes les icônes de l'app"),
            detail: tr("Avec Premium, choisis l'icône d'Ardane parmi \(count) et change-la quand tu veux. L'icône par défaut reste gratuite."),
            perk: .styles
        )
    }

    private func cell(_ choice: AppIconChoice) -> some View {
        let isCurrent = choice.asset == current
        let locked = isLocked(choice)
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
                    } else if locked {
                        PremiumBadge(compact: true)
                            .offset(x: 6, y: -4)
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

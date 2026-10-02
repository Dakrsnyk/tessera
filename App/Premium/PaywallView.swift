import StoreKit
import SwiftUI
import WidgetKit

struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(PremiumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selectedID = PremiumConfiguration.yearlyID
    @State private var message: String?
    @State private var didPurchase = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    hero
                    showcase
                    perks
                    if model.isPremium {
                        activeState
                    } else {
                        plans
                    }
                    comparison
                    legal
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(.screenFill)
            .screenshotScroll()
            .safeAreaInset(edge: .bottom) {
                if !model.isPremium { purchaseBar }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityLabel(Text(tr("Fermer")))
                }
            }
            .alert(tr("Achat"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button(tr("OK"), role: .cancel) {
                    if didPurchase { dismiss() }
                }
            } message: {
                Text(message ?? "")
            }
            .task {
                if store.products.isEmpty { await store.loadProducts() }
            }
        }
    }

    // MARK: Sections

    private var hero: some View {
        VStack(spacing: 12) {
            TesseraMark(size: 56)
            Text(tr("Tessera Premium"))
                .font(.largeTitle.weight(.bold))
            Text(tr("Tous les widgets, tous les styles, sans limite."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var showcase: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(["focus-futuristic", "money-net", "world-futuristic", "dots-glass", "calendar-elegant"], id: \.self) { id in
                    if let template = TemplateCatalog.template(id) {
                        let design = template.makeDesign()
                        WidgetPreview(design: design, family: .systemSmall, payload: SamplePayload.make(for: design), width: 130)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
        .accessibilityHidden(true)
    }

    private var perks: some View {
        VStack(alignment: .leading, spacing: 16) {
            PerkRow(symbol: "square.stack.3d.up.fill", title: tr("Tous les widgets des espaces"), detail: tr("Prochaine série, macros, bénéfice, MRR, devoirs, vol, carburant…"))
            PerkRow(symbol: "wand.and.stars", title: tr("Widgets intelligents"), detail: tr("« Maintenant » change selon le moment, et les analyses résument ta journée"))
            PerkRow(symbol: "bag.fill", title: tr("Tous les packs"), detail: tr("Étudiant, Sportif, Entrepreneur, Voyageur, Investisseur…"))
            PerkRow(symbol: "paintpalette", title: tr("8 styles en plus"), detail: tr("Verre, Aurore, Élégant, Digital, Rétro, Futuriste…"))
            PerkRow(symbol: "photo", title: tr("Fonds photo, couleurs libres"), detail: tr("Et les polices Serif et Mono"))
        }
        .card(padding: 20)
    }

    private var comparison: some View {
        VStack(spacing: 0) {
            HStack {
                Text("")
                Spacer()
                Text(tr("Gratuit")).frame(width: 72)
                Text(tr("Premium")).frame(width: 72).foregroundStyle(Color.premiumInk)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 8)
            comparisonRow(tr("Widgets"), free: "\(WidgetKind.allCases.filter { !$0.isPremium }.count)", premium: "\(WidgetKind.allCases.count)")
            comparisonRow(tr("Styles"), free: "\(ThemeCatalog.free.count)", premium: "\(ThemeCatalog.all.count)")
            comparisonRow(tr("Widgets enregistrés"), free: "\(AppModel.freeDesignLimit)", premium: "∞")
            comparisonRow(tr("Habitudes"), free: "\(AppModel.freeHabitLimit)", premium: "∞")
            comparisonRow(tr("Couleurs"), free: "\(Palette.freeAccents.count)", premium: "∞")
            comparisonRow(tr("Fonds et polices"), free: "—", premium: "✓")
        }
        .card(padding: 18)
    }

    private func comparisonRow(_ title: String, free: String, premium: String) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(free).frame(width: 72).foregroundStyle(.secondary)
                Text(premium).frame(width: 72).fontWeight(.semibold)
            }
            .font(.subheadline.monospacedDigit())
            .padding(.vertical, 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(tr("\(title) : gratuit \(free), Premium \(premium)")))
    }

    @ViewBuilder private var plans: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView(tr("Chargement des offres…"))
                .frame(maxWidth: .infinity, minHeight: 120)
        case let .failed(reason):
            VStack(spacing: 10) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(tr("Réessayer")) { Task { await store.loadProducts() } }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .card()
        case .loaded:
            VStack(spacing: 10) {
                ForEach(store.products, id: \.id) { product in
                    PlanCard(
                        product: product,
                        isSelected: selectedID == product.id,
                        badge: badge(for: product),
                        subtitle: subtitle(for: product)
                    ) {
                        selectedID = product.id
                    }
                }
            }
        }
    }

    private func badge(for product: Product) -> String? {
        if product.id == PremiumConfiguration.yearlyID {
            if let trial = store.trialDescription(for: product) { return trial }
            if let savings = store.yearlySavingsPercent { return "−\(savings) %" }
        }
        if product.id == PremiumConfiguration.lifetimeID { return tr("Paiement unique") }
        return nil
    }

    private func subtitle(for product: Product) -> String {
        switch product.id {
        case PremiumConfiguration.yearlyID:
            if let monthly = store.monthlyEquivalent(of: product) { return tr("\(product.displayPrice) par an, soit \(monthly) par mois") }
            return tr("\(product.displayPrice) par an")
        case PremiumConfiguration.monthlyID:
            return tr("\(product.displayPrice) par mois")
        default:
            return tr("\(product.displayPrice), une seule fois")
        }
    }

    private var activeState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
            Text(tr("Tu profites de Premium"))
                .font(.headline)
            Text(tr("Merci ! Tous les widgets et tous les styles sont débloqués."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 20)
    }

    private var purchaseBar: some View {
        let product = store.products.first { $0.id == selectedID }
        let isTrial = product.flatMap { store.trialDescription(for: $0) } != nil
        return VStack(spacing: 8) {
            if store.loadState == .loaded {
                purchaseButton(product: product, isTrial: isTrial)
            }
            Button {
                Task {
                    let found = await store.restore()
                    didPurchase = found
                    message = found ? tr("Ton accès Premium est rétabli.") : tr("Aucun achat Premium trouvé pour ce compte Apple.")
                }
            } label: {
                Text(store.isRestoring ? tr("Restauration…") : tr("Restaurer mes achats"))
                    .font(.footnote.weight(.medium))
                    .frame(minHeight: 32)
            }
            .disabled(store.isRestoring)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.bar)
    }

    private func purchaseButton(product: Product?, isTrial: Bool) -> some View {
        Button {
            guard let product else { return }
            Task { await buy(product) }
        } label: {
            HStack {
                if store.purchasingID != nil { ProgressView().tint(AppFill.onAccent) }
                Text(isTrial ? tr("Essayer gratuitement") : tr("Continuer"))
                    .font(.headline)
                    .foregroundStyle(.onAccent)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .disabled(product == nil || store.purchasingID != nil)
    }

    private var legal: some View {
        VStack(spacing: 10) {
            Text(tr("L'abonnement se renouvelle automatiquement, sauf annulation au moins 24 h avant la fin de la période en cours. Le paiement est débité sur ton compte Apple. Tu peux gérer ou annuler l'abonnement dans les réglages de ton compte App Store. Si tu profites d'un essai gratuit, il prend fin dès l'achat d'un abonnement."))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Button(tr("Conditions")) { openURL(PremiumConfiguration.termsURL) }
                Button(tr("Confidentialité")) { openURL(PremiumConfiguration.privacyURL) }
            }
            .font(.caption.weight(.medium))
        }
    }

    private func buy(_ product: Product) async {
        switch await store.purchase(product) {
        case .success:
            Haptics.success()
            didPurchase = true
            message = tr("Bienvenue dans Tessera Premium !")
        case .pending:
            message = tr("Ton achat est en attente d'approbation. Premium s'activera dès qu'il sera validé.")
        case .cancelled:
            break
        case let .failed(reason):
            message = reason
        }
    }
}

private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let badge: String?
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.premiumInk)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.premiumFill, in: Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

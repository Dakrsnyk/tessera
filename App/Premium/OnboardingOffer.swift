import StoreKit
import SwiftUI
import WidgetKit

/// The offer at the end of the first launch (« Vitrine », chosen by the PDG on 2026-11-23): real widgets of the
/// person's interests in the looks of Créer, what Premium adds, the yearly and the monthly plan side by side, and the
/// free week. Shown once, after the notifications page, never blocking: « Plus tard » enters the app.
struct OnboardingOffer: View {
    /// Called once: « Plus tard », a purchase, or Premium found by « Restaurer ».
    let onDone: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(PremiumStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var selectedID = PremiumConfiguration.yearlyID
    @State private var message: String?
    @State private var finishesAfterMessage = false

    private var plans: [Product] { [store.yearly, store.monthly].compactMap { $0 } }
    private var selected: Product? { plans.first { $0.id == selectedID } }
    private var trialDays: Int? { selected.flatMap { store.trialDays(for: $0) } }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    showcase
                    VStack(alignment: .leading, spacing: 14) {
                        Text(trialDays.map { tr("Tout Ardane, \($0) jours gratuits") } ?? tr("Tout Ardane, sans limite"))
                            .font(.largeTitle.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        VStack(alignment: .leading, spacing: 10) {
                            perk(tr("Widgets illimités, tous les types"))
                            perk(tr("\(ThemeCatalog.all.count) styles et \(AppStyleID.allCases.count) couleurs d'app"))
                            perk(tr("Statistiques, exercices, scans illimités"))
                        }
                    }
                    planCards
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
            }
            .screenshotScroll()
            .safeAreaInset(edge: .bottom, spacing: 0) { purchaseBar }
        }
        .cristalScreen()
        .accessibilityIdentifier("onboarding-offer")
        .alert(tr("Achat"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(tr("OK"), role: .cancel) {
                if finishesAfterMessage { onDone() }
            }
        } message: {
            Text(message ?? "")
        }
        .task {
            if store.products.isEmpty {
                await store.loadProducts()
            } else {
                await store.refreshIntroEligibility()
            }
        }
        // The yearly plan first; the monthly one when the App Store does not give the yearly (yet).
        .onChange(of: plans.map(\.id), initial: true) { _, ids in
            if !ids.contains(selectedID), let first = ids.first { selectedID = first }
        }
    }

    // MARK: Parts

    private var topBar: some View {
        HStack {
            Button {
                Task {
                    let outcome = await store.restore()
                    finishesAfterMessage = outcome == .restored
                    message = PremiumStore.message(for: outcome)
                }
            } label: {
                Text(store.isRestoring ? tr("Restauration…") : tr("Restaurer"))
            }
            .disabled(store.isRestoring || store.purchasingID != nil)
            .accessibilityIdentifier("onboarding-offer-restore")
            Spacer()
            Button(tr("Plus tard")) {
                Haptics.tap()
                onDone()
            }
            .accessibilityIdentifier("onboarding-offer-later")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(minHeight: 44)
        .padding(.horizontal, 22)
    }

    /// Three widgets of the person's interests (Nutrition, Fitness, Habitudes when none was chosen), each in the look
    /// of its category in Créer, scattered like on a table, with the number of styles Premium adds.
    private var showcase: some View {
        let designs = Self.showcaseDesigns(for: model.profile.preferredSpaces)
        let width: CGFloat = 148
        return ZStack(alignment: .topLeading) {
            ForEach(Array(designs.enumerated()), id: \.offset) { index, design in
                let place = Self.places[index]
                WidgetPreview(design: design, family: .systemSmall, payload: model.previewPayload(for: design), width: width)
                    .shadow(color: .black.opacity(0.28), radius: 16, y: 10)
                    .rotationEffect(.degrees(place.angle))
                    .offset(x: place.x, y: place.y)
            }
            Label(tr("+ \(ThemeCatalog.all.count - ThemeCatalog.free.count) styles"), systemImage: "sparkles")
                .font(.footnote.weight(.bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .rotationEffect(.degrees(2))
                .offset(x: 18, y: 176)
        }
        .frame(maxWidth: .infinity, minHeight: 278, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private static let places: [(x: CGFloat, y: CGFloat, angle: Double)] = [(4, 12, -6), (168, 0, 4), (172, 116, -3)]

    /// The small widget Créer would open for each of the first three interests, in its category's look.
    static func showcaseDesigns(for preferred: [Space]) -> [WidgetDesign] {
        let spaces = (preferred + [.nutrition, .fitness, .habits]).reduce(into: [Space]()) { list, space in
            if !list.contains(space) { list.append(space) }
        }
        return spaces.prefix(3).compactMap { space in
            guard let kind = SpaceCatalog.preset(for: space, format: .small).first else { return nil }
            var design = CreateCategory.space(space).design(for: kind)
            design.format = .small
            return design
        }
    }

    private func perk(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var planCards: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView(tr("Chargement des offres…"))
                .frame(maxWidth: .infinity, minHeight: 96)
        case let .failed(reason):
            VStack(spacing: 10) {
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(tr("Réessayer")) { Task { await store.loadProducts() } }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
        case .loaded:
            HStack(spacing: 10) {
                ForEach(plans, id: \.id) { product in
                    planCard(product)
                }
            }
            .padding(.top, 8)
        }
    }

    private func planCard(_ product: Product) -> some View {
        let isSelected = product.id == selectedID
        let yearly = product.id == PremiumConfiguration.yearlyID
        let detail = yearly ? store.monthlyEquivalent(of: product).map { tr("\($0) par mois") } : tr("par mois")
        return Button {
            Haptics.tap()
            selectedID = product.id
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .top) {
                    Text(yearly ? tr("Annuel") : tr("Mensuel"))
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 4)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                }
                Text(product.displayPrice)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(.primary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cristalPanel(radius: 20)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            }
            .overlay(alignment: .topTrailing) {
                if yearly, let savings = store.yearlySavingsPercent {
                    Text(verbatim: "−\(savings) %")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.onAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor, in: Capsule())
                        .offset(x: -12, y: -10)
                }
            }
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("onboarding-offer-\(yearly ? "yearly" : "monthly")")
    }

    private var purchaseBar: some View {
        VStack(spacing: 8) {
            Button {
                guard let selected else { return }
                Task { await buy(selected) }
            } label: {
                HStack {
                    if store.purchasingID != nil { ProgressView().tint(AppFill.onAccent) }
                    Text(trialDays.map { tr("Essayer \($0) jours gratuits") } ?? tr("Continuer"))
                        .font(.headline)
                        .foregroundStyle(.onAccent)
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .disabled(selected == nil || store.purchasingID != nil)
            .accessibilityIdentifier("onboarding-offer-buy")
            // What is charged and when, right under the button (App Store rule 3.1.2).
            if let selected {
                Text(store.purchaseTerms(for: selected))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 16) {
                Button(tr("Conditions")) { openURL(PremiumConfiguration.termsURL) }
                Button(tr("Confidentialité")) { openURL(PremiumConfiguration.privacyURL) }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.screenFill)
    }

    private func buy(_ product: Product) async {
        switch await store.purchase(product) {
        case .success:
            Haptics.success()
            finishesAfterMessage = true
            message = tr("Bienvenue dans Ardane Premium !")
        case .pending:
            finishesAfterMessage = true
            message = tr("Ton achat est en attente d'approbation. Premium s'activera dès qu'il sera validé.")
        case .cancelled:
            break
        case let .failed(reason):
            message = reason
        }
    }
}

import SwiftUI
import WidgetKit

struct OnboardingView: View {
    let onFinish: () -> Void
    @Environment(Router.self) private var router
    @State private var page = 0

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pageCount - 1 {
                    Button("Passer") { onFinish() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 20)

            TabView(selection: $page) {
                OnboardingPage(
                    title: "Ton écran d'accueil, à ta façon",
                    message: "Des widgets utiles et soignés : temps, tâches, météo, finances, habitudes.",
                    illustration: AnyView(CollageIllustration())
                ).tag(0)
                OnboardingPage(
                    title: "Choisis, puis personnalise",
                    message: "Style, couleur, fond, police : l'aperçu change en direct, tu vois exactement le résultat.",
                    illustration: AnyView(StylesIllustration())
                ).tag(1)
                OnboardingPage(
                    title: "Ajoute-le en quelques secondes",
                    message: "Ton widget t'attend dans la galerie de widgets d'iOS.",
                    illustration: AnyView(StepsIllustration())
                ).tag(2)
                OnboardingPage(
                    title: "Encore plus avec Premium",
                    message: "Tous les widgets et tous les styles, sans limite.",
                    illustration: AnyView(PremiumIllustration())
                ).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: page)

            HStack(spacing: 7) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: index == page ? 20 : 7, height: 7)
                }
            }
            .animation(.spring(response: 0.3), value: page)
            .padding(.bottom, 24)
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                Button {
                    if page < pageCount - 1 {
                        page += 1
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page < pageCount - 1 ? "Continuer" : "Commencer")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))

                if page == pageCount - 1 {
                    Button("Voir les offres Premium") {
                        onFinish()
                        router.isPaywallPresented = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color.screenFill.ignoresSafeArea())
    }
}

private struct OnboardingPage: View {
    let title: String
    let message: String
    let illustration: AnyView

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            illustration
                .frame(maxHeight: 360)
            VStack(spacing: 10) {
                Text(title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            Spacer(minLength: 0)
        }
    }
}

private struct CollageIllustration: View {
    var body: some View {
        let year = TemplateCatalog.design("progress-year")
        let tasks = TemplateCatalog.design("tasks-minimal")
        let weather = TemplateCatalog.design("weather-aurora")
        VStack(spacing: 12) {
            WidgetPreview(design: year, family: .systemMedium, payload: SamplePayload.make(for: .progress), width: 324)
            HStack(spacing: 12) {
                WidgetPreview(design: tasks, family: .systemSmall, payload: SamplePayload.make(for: .tasks), width: 156)
                WidgetPreview(design: weather, family: .systemSmall, payload: SamplePayload.make(for: .weather), width: 156)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct StylesIllustration: View {
    var body: some View {
        let themes: [ThemeID] = [.minimal, .aurora, .retro]
        VStack(spacing: 20) {
            HStack(spacing: -24) {
                ForEach(Array(themes.enumerated()), id: \.offset) { pair in
                    WidgetPreview(design: TemplateCatalog.design("countdown-holidays", theme: pair.element), family: .systemSmall, payload: WidgetPayload(), width: 130)
                        .rotationEffect(.degrees(Double(pair.offset - 1) * 6))
                        .offset(y: pair.offset == 1 ? -10 : 6)
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
                        .zIndex(pair.offset == 1 ? 1 : 0)
                }
            }
            HStack(spacing: 8) {
                ForEach(["Style", "Couleur", "Fond", "Police"], id: \.self) { label in
                    Text(label)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.cardFill, in: Capsule())
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct StepsIllustration: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AddStepRow(number: 1, symbol: "hand.tap", text: "Appuie longuement sur l'écran d'accueil")
            AddStepRow(number: 2, symbol: "plus", text: "Touche « Modifier », puis « Ajouter un widget »")
            AddStepRow(number: 3, symbol: "square.grid.2x2", text: "Cherche Tessera et choisis une taille")
            AddStepRow(number: 4, symbol: "slider.horizontal.3", text: "Touche le widget pour choisir ton design")
        }
        .card(padding: 20)
        .padding(.horizontal, 24)
    }
}

struct AddStepRow: View {
    let number: Int
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.14))
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Étape \(number)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PremiumIllustration: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PerkRow(symbol: "square.grid.3x3.fill", title: "Les 15 widgets", detail: "Focus en direct, flux d'argent, crypto, fuseaux horaires…")
            PerkRow(symbol: "paintpalette.fill", title: "12 styles", detail: "Verre, Aurore, Élégant, Rétro, Futuriste et plus")
            PerkRow(symbol: "photo.fill", title: "Fonds photo et couleurs libres", detail: "Et les polices Serif et Mono")
            PerkRow(symbol: "infinity", title: "Sans limite", detail: "Autant de widgets et d'habitudes que tu veux")
        }
        .card(padding: 20)
        .padding(.horizontal, 24)
    }
}

struct PerkRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

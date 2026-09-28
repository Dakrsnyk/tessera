import SwiftUI
import WidgetKit

/// A widget shown in a Store shelf, at a given size and in a given look.
struct ShowcaseItem: Identifiable {
    let widget: SetupWidget
    let title: String
    let subtitle: String

    var id: String { "\(widget.kind.rawValue)-\(widget.theme.rawValue)-\(widget.accent)-\(title)" }
}

/// A large card at the top of the Store: a promise and the widget that keeps it.
struct StoreFeature: Identifiable {
    let id: String
    let eyebrow: String
    let title: String
    let subtitle: String
    let colors: [String]
    let widget: SetupWidget
}

/// A themed shelf mixing small and medium widgets.
struct StoreCollection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let items: [ShowcaseItem]
}

enum StoreShowcase {
    private static func item(_ kind: WidgetKind, _ family: WidgetFamily, _ theme: ThemeID, _ accent: String,
                             _ template: String? = nil, title: String? = nil) -> ShowcaseItem {
        ShowcaseItem(
            widget: SetupWidget(kind: kind, family: family, theme: theme, accent: accent, template: template),
            title: title ?? kind.title,
            subtitle: ThemeCatalog.theme(theme).name
        )
    }

    static let features: [StoreFeature] = [
        StoreFeature(
            id: "now", eyebrow: "À la une", title: "Le bon widget au bon moment",
            subtitle: "Météo le matin, tâches la journée, bilan le soir.", colors: ["1C2566", "2A6F9B", "3FB5A3"],
            widget: SetupWidget(kind: .now, family: .systemMedium, theme: .glass, accent: "3366FF")
        ),
        StoreFeature(
            id: "money", eyebrow: "Budget", title: "Ton argent, enfin clair",
            subtitle: "Reste du mois, dépenses, épargne et factures.", colors: ["E4533D", "D13F72"],
            widget: SetupWidget(kind: .moneyDashboard, family: .systemMedium, theme: .light, accent: "FF6B57")
        ),
        StoreFeature(
            id: "fitness", eyebrow: "Sport", title: "Chaque série compte",
            subtitle: "Ta séance, tes records et ta régularité.", colors: ["2B2B30", "0E0E10"],
            widget: SetupWidget(kind: .fitnessDashboard, family: .systemMedium, theme: .dark, accent: "FF6B57")
        ),
        StoreFeature(
            id: "student", eyebrow: "Études", title: "Réussis ta session",
            subtitle: "Cours, examens et devoirs au même endroit.", colors: ["8A4B24", "D4532A"],
            widget: SetupWidget(kind: .studentDashboard, family: .systemMedium, theme: .retro, accent: "F2A33A")
        ),
        StoreFeature(
            id: "world", eyebrow: "Voyage", title: "Le monde à ton heure",
            subtitle: "Fuseaux horaires, décalage et heure sur place.", colors: ["070B1F", "171046", "3A1C7A"],
            widget: SetupWidget(kind: .worldClock, family: .systemMedium, theme: .futuristic, accent: "3366FF", template: "world-futuristic")
        ),
        StoreFeature(
            id: "habits", eyebrow: "Habitudes", title: "Tiens tes bonnes résolutions",
            subtitle: "Coche tes habitudes sans ouvrir l'app.", colors: ["2F8F7A", "16302A"],
            widget: SetupWidget(kind: .habits, family: .systemMedium, theme: .minimal, accent: "2F8F7A")
        ),
    ]

    static let mediums: [ShowcaseItem] = [
        item(.now, .systemMedium, .colorful, "8C6CFF"),
        item(.weather, .systemMedium, .aurora, "3366FF"),
        item(.calendar, .systemMedium, .elegant, "F2A33A"),
        item(.tasks, .systemMedium, .light, "2F8F7A"),
        item(.spendingByCategory, .systemMedium, .light, "FF6B57"),
        item(.portfolio, .systemMedium, .futuristic, "3366FF"),
        item(.todaysWorkout, .systemMedium, .dark, "F2A33A"),
        item(.worldClock, .systemMedium, .minimal, "3366FF", "world-minimal"),
        item(.progress, .systemMedium, .retro, "F2A33A", "progress-month-retro"),
        item(.weeklyForecast, .systemMedium, .glass, "8C6CFF"),
        item(.mealsToday, .systemMedium, .light, "F2A33A"),
        item(.timetable, .systemMedium, .typography, "F2588F"),
        item(.businessKPIs, .systemMedium, .elegant, "F2A33A"),
        item(.upNext, .systemMedium, .digital, "2F8F7A"),
    ]

    static let larges: [ShowcaseItem] = [
        item(.calendar, .systemLarge, .typography, "FF6B57"),
        item(.myDay, .systemLarge, .glass, "8C6CFF"),
        item(.weeklyForecast, .systemLarge, .aurora, "3366FF"),
        item(.habitWeek, .systemLarge, .light, "8C6CFF"),
        item(.spendingByCategory, .systemLarge, .dark, "F2A33A"),
        item(.yearDots, .systemLarge, .monochrome, "6B7280"),
        item(.mealsToday, .systemLarge, .retro, "F2A33A"),
        item(.weeklyVolume, .systemLarge, .futuristic, "3366FF"),
        item(.tasks, .systemLarge, .minimal, "2F8F7A"),
    ]

    static let lockScreen: [ShowcaseItem] = [
        item(.weather, .accessoryRectangular, .minimal, "3366FF"),
        item(.progress, .accessoryCircular, .minimal, "2F8F7A", "progress-year"),
        item(.caloriesLeft, .accessoryCircular, .minimal, "2F8F7A"),
        item(.tasks, .accessoryRectangular, .minimal, "2F8F7A"),
        item(.hydration, .accessoryCircular, .minimal, "3366FF"),
        item(.nextSet, .accessoryRectangular, .minimal, "FF6B57"),
        item(.trainingStreak, .accessoryCircular, .minimal, "FF6B57"),
        item(.budgetLeft, .accessoryRectangular, .minimal, "2F8F7A"),
        item(.countdown, .accessoryCircular, .minimal, "F2A33A", "countdown-holidays"),
        item(.nextClass, .accessoryRectangular, .minimal, "3366FF"),
        item(.moonPhase, .accessoryCircular, .minimal, "6B7280"),
        item(.flight, .accessoryRectangular, .minimal, "3366FF"),
        item(.savingsGoal, .accessoryCircular, .minimal, "2F8F7A"),
    ]

    /// The same countdown in each of the twelve styles.
    static var allStyles: [ShowcaseItem] {
        ThemeCatalog.all.enumerated().map { index, theme in
            ShowcaseItem(
                widget: SetupWidget(kind: .countdown, family: .systemSmall, theme: theme.id,
                                    accent: Palette.freeAccents[index % Palette.freeAccents.count].hex, template: "countdown-holidays"),
                title: theme.name,
                subtitle: theme.isPremium ? "Premium" : "Gratuit"
            )
        }
    }

    /// The same widget in each free color.
    static var allColors: [ShowcaseItem] {
        Palette.freeAccents.map { swatch in
            ShowcaseItem(
                widget: SetupWidget(kind: .habitStreak, family: .systemSmall, theme: .colorful, accent: swatch.hex),
                title: swatch.name,
                subtitle: "Série"
            )
        }
    }

    static let collectionsTop: [StoreCollection] = [
        StoreCollection(id: "sport", title: "Pour les sportifs", subtitle: "Séance, séries, repos et calories.", symbol: "figure.strengthtraining.traditional", items: [
            item(.nextSet, .systemMedium, .dark, "FF6B57"),
            item(.restTimer, .systemSmall, .dark, "FF6B57"),
            item(.personalRecords, .systemSmall, .retro, "F2A33A"),
            item(.caloriesLeft, .systemSmall, .colorful, "2F8F7A"),
            item(.weeklyVolume, .systemMedium, .futuristic, "3366FF"),
            item(.proteinLeft, .systemSmall, .glass, "8C6CFF"),
        ]),
        StoreCollection(id: "study", title: "Pour étudier", subtitle: "Cours, examens, devoirs et révisions.", symbol: "graduationcap.fill", items: [
            item(.timetable, .systemMedium, .retro, "D4532A"),
            item(.nextExam, .systemSmall, .light, "3366FF"),
            item(.flashcard, .systemSmall, .retro, "F2A33A", "flashcard-retro"),
            item(.assignments, .systemSmall, .minimal, "F2588F"),
            item(.studyHours, .systemMedium, .light, "8C6CFF"),
            item(.gradeAverage, .systemSmall, .typography, "3366FF"),
        ]),
        StoreCollection(id: "business", title: "Pour entreprendre", subtitle: "Ventes, objectifs, bénéfice et MRR.", symbol: "briefcase.fill", items: [
            item(.businessDashboard, .systemMedium, .elegant, "F2A33A"),
            item(.revenueGoal, .systemSmall, .elegant, "F2A33A"),
            item(.profit, .systemSmall, .dark, "2F8F7A"),
            item(.mrr, .systemSmall, .futuristic, "3366FF"),
            item(.revenueTrend, .systemMedium, .light, "2F8F7A"),
            item(.revenueToday, .systemSmall, .colorful, "F2A33A"),
        ]),
    ]

    static let collectionsBottom: [StoreCollection] = [
        StoreCollection(id: "minimal", title: "Minimal et noir", subtitle: "L'essentiel, sans une couleur de trop.", symbol: "circle.lefthalf.filled", items: [
            item(.clock, .systemSmall, .monochrome, "6B7280"),
            item(.progress, .systemMedium, .monochrome, "6B7280", "progress-day"),
            item(.calendar, .systemSmall, .monochrome, "6B7280"),
            item(.weekView, .systemMedium, .monochrome, "6B7280"),
            item(.moonPhase, .systemSmall, .monochrome, "6B7280"),
        ]),
        StoreCollection(id: "vivid", title: "Couleurs vives", subtitle: "Ta couleur en plein fond.", symbol: "paintpalette.fill", items: [
            item(.now, .systemMedium, .colorful, "FF6B57"),
            item(.weather, .systemSmall, .colorful, "3366FF"),
            item(.hydration, .systemSmall, .colorful, "8C6CFF"),
            item(.habitStreak, .systemSmall, .colorful, "F2588F"),
            item(.budgetLeft, .systemMedium, .colorful, "F2A33A"),
            item(.trainingStreak, .systemSmall, .colorful, "7FA33A"),
        ]),
        StoreCollection(id: "calm", title: "Bien-être", subtitle: "Habitudes, eau, soleil et lune.", symbol: "leaf.fill", items: [
            item(.habits, .systemMedium, .glass, "8C6CFF"),
            item(.hydration, .systemSmall, .aurora, "3366FF"),
            item(.habitRate, .systemSmall, .glass, "F2588F"),
            item(.sunCycle, .systemMedium, .light, "F2A33A"),
            item(.moonPhase, .systemSmall, .elegant, "F2A33A"),
        ]),
    ]
}

// MARK: - Views

/// A widget of any Home Screen size, at a given height, with its name and look below.
struct ShowcaseCard: View {
    let item: ShowcaseItem
    var height: CGFloat = 150
    let isPremiumUser: Bool

    var body: some View {
        let design = item.widget.makeDesign()
        let width = height * item.widget.family.aspectRatio
        VStack(alignment: .leading, spacing: 8) {
            WidgetPreview(design: design, family: item.widget.family, payload: SamplePayload.make(for: design), width: width)
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if design.usesPremiumFeatures && !isPremiumUser {
                    PremiumBadge(compact: true)
                }
            }
        }
        .frame(width: width)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Ouvre l'éditeur"))
    }
}

/// A Lock Screen widget on a small piece of wallpaper, under the clock.
struct LockShowcaseCard: View {
    let item: ShowcaseItem
    let index: Int
    let isPremiumUser: Bool

    private static let wallpapers: [[String]] = [
        ["1C2566", "2A6F9B"], ["16302A", "2F8F7A"], ["2B0B4F", "7A1C7A"], ["1B1B1D", "3A3A3F"], ["4A1628", "C0445F"], ["0A1428", "34528F"],
    ]

    var body: some View {
        let design = item.widget.makeDesign()
        let family = item.widget.family
        let width: CGFloat = family == .accessoryRectangular ? 212 : 132
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                LinearGradient(colors: Self.wallpapers[index % Self.wallpapers.count].map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 4) {
                    Text("9:41")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.92))
                    WidgetPreview(design: design, family: family, payload: SamplePayload.make(for: design), width: WidgetMetrics.size(family).width)
                }
            }
            .frame(width: width, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            HStack(spacing: 6) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if design.kind.isPremium && !isPremiumUser {
                    PremiumBadge(compact: true)
                }
            }
        }
        .frame(width: width)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A large promise card with a medium widget, one per page.
struct StoreFeatureCard: View {
    let feature: StoreFeature
    let isPremiumUser: Bool

    var body: some View {
        let design = feature.widget.makeDesign()
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(feature.eyebrow.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.75))
                    Text(feature.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(feature.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.82))
                        .lineLimit(2)
                }
                .frame(minHeight: 100, alignment: .topLeading)
                Spacer(minLength: 8)
                if design.usesPremiumFeatures && !isPremiumUser {
                    PremiumBadge()
                }
            }
            Spacer(minLength: 14)
            WidgetPreview(design: design, family: feature.widget.family, payload: SamplePayload.make(for: design))
                .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
        }
        .padding(16)
        .background {
            ZStack {
                LinearGradient(colors: feature.colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color.white.opacity(0.18), .clear], center: .topTrailing, startRadius: 0, endRadius: 260)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Ouvre l'éditeur"))
    }
}

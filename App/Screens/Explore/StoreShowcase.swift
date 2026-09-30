import SwiftUI
import WidgetKit

/// A widget shown in a Store shelf, at a given size and in a given look.
struct ShowcaseItem: Identifiable {
    let widget: SetupWidget
    let title: String
    let subtitle: String

    var id: String { "\(widget.kind.rawValue)-\(widget.theme.rawValue)-\(widget.accent)-\(title)" }
}

/// A themed set of widgets, shown as a colored tile in the Store and as a page of its own.
struct StoreCollection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let colorHex: String
    /// The interests it speaks to, to show it first to the people who have them.
    var categories: [WidgetCategory] = []
    let items: [ShowcaseItem]

    /// The widget shown on the tile: the first small one.
    var cover: ShowcaseItem { items.first { $0.widget.family == .systemSmall } ?? items[0] }
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

    static let collections: [StoreCollection] = [
        StoreCollection(id: "sport", title: "Pour les sportifs", subtitle: "Séance, séries, repos et calories.",
                        symbol: "figure.strengthtraining.traditional", colorHex: "E5484D", categories: [.fitness, .nutrition], items: [
            item(.nextSet, .systemSmall, .dark, "FF6B57"),
            item(.todaysWorkout, .systemMedium, .dark, "FF6B57"),
            item(.restTimer, .systemSmall, .dark, "FF6B57"),
            item(.personalRecords, .systemSmall, .retro, "F2A33A"),
            item(.weeklyVolume, .systemMedium, .futuristic, "3366FF"),
            item(.caloriesLeft, .systemSmall, .colorful, "2F8F7A"),
            item(.proteinLeft, .systemSmall, .glass, "8C6CFF"),
            item(.workoutMonth, .systemLarge, .dark, "FF6B57"),
            item(.trainingStreak, .systemSmall, .colorful, "FF6B57"),
            item(.caloriesBurned, .systemSmall, .light, "FF6B57"),
        ]),
        StoreCollection(id: "study", title: "Pour étudier", subtitle: "Cours, examens, devoirs et révisions.",
                        symbol: "graduationcap.fill", colorHex: "D6409F", categories: [.student], items: [
            item(.nextExam, .systemSmall, .light, "3366FF"),
            item(.timetable, .systemMedium, .retro, "F2A33A"),
            item(.flashcard, .systemSmall, .retro, "F2A33A", "flashcard-retro"),
            item(.assignments, .systemSmall, .minimal, "F2588F"),
            item(.studyHours, .systemMedium, .light, "8C6CFF"),
            item(.gradeAverage, .systemSmall, .typography, "3366FF"),
            item(.semesterProgress, .systemSmall, .colorful, "F2588F"),
            item(.nextClass, .systemSmall, .minimal, "3366FF"),
            item(.timetable, .systemLarge, .minimal, "F2588F"),
        ]),
        StoreCollection(id: "money", title: "Budget serré", subtitle: "Reste du mois, factures, épargne et abonnements.",
                        symbol: "creditcard.fill", colorHex: "2F8F7A", categories: [.finance, .investing], items: [
            item(.budgetLeft, .systemSmall, .light, "2F8F7A"),
            item(.spendingByCategory, .systemMedium, .light, "FF6B57"),
            item(.savingsGoal, .systemSmall, .colorful, "2F8F7A"),
            item(.quickExpense, .systemSmall, .colorful, "FF6B57"),
            item(.billsUpcoming, .systemMedium, .dark, "F2A33A"),
            item(.subscriptions, .systemSmall, .minimal, "8C6CFF"),
            item(.netWorth, .systemSmall, .elegant, "F2A33A"),
            item(.moneyFlow, .systemLarge, .light, "2F8F7A", "money-net"),
        ]),
        StoreCollection(id: "business", title: "Pour entreprendre", subtitle: "Ventes, objectifs, bénéfice et MRR.",
                        symbol: "briefcase.fill", colorHex: "C28A12", categories: [.business, .markets], items: [
            item(.revenueGoal, .systemSmall, .elegant, "F2A33A"),
            item(.businessDashboard, .systemMedium, .elegant, "F2A33A"),
            item(.profit, .systemSmall, .dark, "2F8F7A"),
            item(.mrr, .systemSmall, .futuristic, "3366FF"),
            item(.revenueTrend, .systemMedium, .light, "2F8F7A"),
            item(.revenueToday, .systemSmall, .colorful, "F2A33A"),
            item(.companySnapshot, .systemSmall, .futuristic, "3366FF", "company-futuristic"),
            item(.businessKPIs, .systemLarge, .elegant, "F2A33A"),
        ]),
        StoreCollection(id: "travel", title: "En voyage", subtitle: "Départ, vol, hôtel et heure sur place.",
                        symbol: "airplane", colorHex: "12A4B5", categories: [.travel], items: [
            item(.tripCountdown, .systemSmall, .aurora, "3366FF", "trip-aurora"),
            item(.flight, .systemMedium, .light, "3366FF"),
            item(.localTime, .systemSmall, .minimal, "2F8F7A"),
            item(.currency, .systemSmall, .glass, "8C6CFF"),
            item(.hotel, .systemSmall, .retro, "F2A33A"),
            item(.destinationWeather, .systemSmall, .aurora, "3366FF"),
            item(.nextActivity, .systemMedium, .light, "F2A33A"),
            item(.tripProgress, .systemSmall, .colorful, "3366FF"),
        ]),
        StoreCollection(id: "calm", title: "Bien-être", subtitle: "Habitudes, eau, soleil et lune.",
                        symbol: "leaf.fill", colorHex: "7FA33A", categories: [.wellbeing, .weather], items: [
            item(.hydration, .systemSmall, .aurora, "3366FF"),
            item(.habits, .systemMedium, .glass, "8C6CFF"),
            item(.habitRate, .systemSmall, .glass, "F2588F"),
            item(.moonPhase, .systemSmall, .elegant, "F2A33A"),
            item(.sunCycle, .systemMedium, .light, "F2A33A"),
            item(.habitStreak, .systemSmall, .colorful, "7FA33A"),
            item(.habitWeek, .systemLarge, .light, "8C6CFF"),
        ]),
        StoreCollection(id: "minimal", title: "Minimal et noir", subtitle: "L'essentiel, sans une couleur de trop.",
                        symbol: "circle.lefthalf.filled", colorHex: "3A3A3F", categories: [.time, .productivity], items: [
            item(.clock, .systemSmall, .monochrome, "6B7280"),
            item(.progress, .systemMedium, .monochrome, "6B7280", "progress-day"),
            item(.calendar, .systemSmall, .monochrome, "6B7280"),
            item(.moonPhase, .systemSmall, .monochrome, "6B7280"),
            item(.weekView, .systemMedium, .monochrome, "6B7280"),
            item(.countdown, .systemSmall, .monochrome, "6B7280", "countdown-since"),
            item(.tasks, .systemSmall, .monochrome, "6B7280"),
            item(.yearDots, .systemLarge, .monochrome, "6B7280"),
        ]),
        StoreCollection(id: "vivid", title: "Couleurs vives", subtitle: "Ta couleur en plein fond.",
                        symbol: "sparkles", colorHex: "F2588F", items: [
            item(.weather, .systemSmall, .colorful, "3366FF"),
            item(.now, .systemMedium, .colorful, "FF6B57"),
            item(.hydration, .systemSmall, .colorful, "8C6CFF"),
            item(.habitStreak, .systemSmall, .colorful, "F2588F"),
            item(.budgetLeft, .systemMedium, .colorful, "F2A33A"),
            item(.trainingStreak, .systemSmall, .colorful, "7FA33A"),
            item(.caloriesLeft, .systemSmall, .colorful, "2F8F7A"),
        ]),
        StoreCollection(id: "mediums", title: "Widgets moyens", subtitle: "Deux fois plus de place, pour tout voir d'un coup d'œil.",
                        symbol: "rectangle.fill", colorHex: "3366FF", items: [
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
        ]),
        StoreCollection(id: "larges", title: "Grands formats", subtitle: "Ta semaine, ton mois ou ta journée entière.",
                        symbol: "square.fill", colorHex: "5B6CFF", items: [
            item(.calendar, .systemLarge, .typography, "FF6B57"),
            item(.myDay, .systemLarge, .glass, "8C6CFF"),
            item(.weeklyForecast, .systemLarge, .aurora, "3366FF"),
            item(.habitWeek, .systemLarge, .light, "8C6CFF"),
            item(.spendingByCategory, .systemLarge, .dark, "F2A33A"),
            item(.yearDots, .systemLarge, .monochrome, "6B7280"),
            item(.mealsToday, .systemLarge, .retro, "F2A33A"),
            item(.weeklyVolume, .systemLarge, .futuristic, "3366FF"),
            item(.tasks, .systemLarge, .minimal, "2F8F7A"),
        ]),
        StoreCollection(id: "styles", title: "Un widget, 12 styles", subtitle: "Le même compte à rebours, dans chaque style.",
                        symbol: "paintbrush.fill", colorHex: "8C6CFF", items: allStyles),
        StoreCollection(id: "colors", title: "Toutes les couleurs", subtitle: "Choisis la tienne, ou n'importe quelle autre avec Premium.",
                        symbol: "eyedropper.halffull", colorHex: "F2A33A", items: allColors),
    ]

    static func collection(_ id: String) -> StoreCollection? {
        collections.first { $0.id == id }
    }

    /// The collections that match the person's interests first, the others after, each group in catalog order.
    static func collections(preferring categories: [WidgetCategory]) -> [StoreCollection] {
        func rank(_ collection: StoreCollection) -> Int {
            collection.categories.compactMap { categories.firstIndex(of: $0) }.min() ?? Int.max
        }
        return collections.enumerated()
            .sorted { lhs, rhs in
                let left = rank(lhs.element)
                let right = rank(rhs.element)
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .map(\.element)
    }
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

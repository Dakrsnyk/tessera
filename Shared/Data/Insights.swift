import Foundation

/// A short analysis built only from the user's own data. Every number in `text` comes from `facts`.
struct Insight: Hashable {
    var title: String
    var symbol: String
    var text: String
    var facts: [String]
    /// Detail lines shown on larger widgets.
    var points: [String] = []

    /// Stable fingerprint of the facts, used to know whether a cached phrasing still applies.
    var factsKey: String { InsightCache.fingerprint(facts.joined(separator: "|")) }
}

/// Phrasings written by the on-device model in the app, reused by widgets while the facts are unchanged.
struct InsightCache: Codable, Hashable {
    struct Entry: Codable, Hashable {
        var factsKey: String
        var text: String
        var createdAt: Date
    }

    var entries: [String: Entry] = [:]

    static func load() -> InsightCache {
        SharedStore.shared.read(InsightCache.self, from: .insights) ?? InsightCache()
    }

    func phrasing(for kind: WidgetKind, insight: Insight) -> String? {
        guard let entry = entries[kind.rawValue], entry.factsKey == insight.factsKey else { return nil }
        return entry.text
    }

    /// FNV-1a over UTF-8, stable across launches (unlike `hashValue`).
    static func fingerprint(_ text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }

    /// True when every number in `text` also appears in the facts: the model may rephrase, never invent.
    static func isGrounded(_ text: String, facts: [String]) -> Bool {
        let source = facts.joined(separator: " ")
        let known = Set(numbers(in: source))
        return numbers(in: text).allSatisfy { known.contains($0) }
    }

    static func numbers(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in text {
            if character.isNumber {
                current.append(character)
            } else if (character == "," || character == ".") && !current.isEmpty {
                current.append(".")
            } else if character == "\u{202F}" || character == "\u{00A0}" || (character == " " && !current.isEmpty && current.last != ".") {
                // Thousands separators in French numbers ("1 250") stay inside the number.
                continue
            } else {
                if !current.isEmpty { result.append(normalize(current)) }
                current = ""
            }
        }
        if !current.isEmpty { result.append(normalize(current)) }
        return result
    }

    private static func normalize(_ number: String) -> String {
        var value = number
        while value.hasSuffix(".") { value.removeLast() }
        if value.contains(".") {
            while value.hasSuffix("0") { value.removeLast() }
            if value.hasSuffix(".") { value.removeLast() }
        }
        return value
    }
}

/// Deterministic analyses. They never guess: when data is missing they say so.
enum InsightEngine {
    /// "1 122": calories with the thousands separator used everywhere else in the app.
    private static func kcal(_ value: Double) -> String {
        Fmt.number(Int(safely: value.rounded()))
    }

    static func nutrition(_ state: NutritionState, now: Date) -> Insight {
        let today = NutritionMath.totals(state, on: now)
        let goals = state.goals
        let left = goals.kcal - today.kcal
        let proteinLeft = goals.protein - today.protein
        var facts = [
            tr("Objectif : \(kcal(goals.kcal)) kcal"),
            tr("Mangé aujourd'hui : \(kcal(today.kcal)) kcal"),
            tr("Protéines : \(Int(safely: today.protein.rounded())) g sur \(Int(safely: goals.protein)) g"),
        ]
        var text: String
        if today.kcal == 0 {
            text = tr("Rien de noté aujourd'hui. Ton objectif est de \(kcal(goals.kcal)) kcal.")
        } else if left >= 0 {
            text = tr("Il te reste \(kcal(left)) kcal aujourd'hui")
            if proteinLeft > 0 {
                text += tr(" et \(Int(safely: proteinLeft.rounded())) g de protéines à trouver.")
            } else {
                text += tr(", et ton objectif de protéines est atteint.")
            }
        } else {
            text = tr("Tu as dépassé ton objectif de \(kcal(-left)) kcal aujourd'hui.")
        }
        facts.append(tr("Reste : \(kcal(left)) kcal"))
        facts.append(tr("Protéines restantes : \(Int(safely: max(0, proteinLeft).rounded())) g"))
        var points: [String] = []
        if let average = NutritionMath.average(state, days: 7, until: now) {
            let line = tr("Moyenne sur 7 jours : \(kcal(average)) kcal")
            facts.append(line)
            points.append(line)
        }
        let streak = NutritionMath.trackingStreak(state, until: now)
        if streak > 1 {
            let line = tr("Suivi \(streak) jours d'affilée")
            facts.append(line)
            points.append(line)
        }
        return Insight(title: tr("Nutrition"), symbol: "fork.knife", text: text, facts: facts, points: points)
    }

    static func finance(_ state: BudgetState, now: Date, currency: String) -> Insight {
        let spent = BudgetMath.spentThisMonth(state, at: now)
        let remaining = BudgetMath.remaining(state, at: now)
        let perDay = BudgetMath.perDayLeft(state, at: now)
        func money(_ value: Double) -> String { Fmt.money(value, currency: currency, decimals: 0) }
        var facts = [
            tr("Budget du mois : \(money(state.monthlyBudget))"),
            tr("Dépensé : \(money(spent))"),
            tr("Reste : \(money(remaining))"),
            tr("Par jour : \(money(perDay))"),
        ]
        var text = remaining >= 0
            ? tr("Il te reste \(money(remaining)) ce mois-ci, soit \(money(perDay)) par jour.")
            : tr("Tu as dépassé ton budget du mois de \(money(-remaining)).")
        var points: [String] = []
        let comparison = BudgetMath.weekComparison(state, at: now)
        if let biggest = comparison.filter({ $0.previous > 0 || $0.current > 0 }).max(by: { abs($0.current - $0.previous) < abs($1.current - $1.previous) }),
           abs(biggest.current - biggest.previous) >= 1 {
            let delta = biggest.current - biggest.previous
            let line = tr("\(biggest.name) : \(money(biggest.current)) cette semaine contre \(money(biggest.previous)) la semaine dernière")
            facts.append(line)
            points.append(line)
            text += delta > 0
                ? tr(" Plus forte hausse : \(biggest.name.lowercased()) (\(money(delta)) de plus).")
                : tr(" Belle baisse en \(biggest.name.lowercased()) (\(money(-delta)) de moins).")
        }
        if let bill = BudgetMath.upcomingBills(state, at: now, within: 7).first {
            let line = tr("\(bill.bill.name) : \(money(bill.bill.amount)) dans \(bill.days) j")
            facts.append(line)
            points.append(line)
        }
        return Insight(title: tr("Dépenses"), symbol: "creditcard", text: text, facts: facts, points: points)
    }

    static func productivity(_ state: ProductivityState, content: ContentState, now: Date) -> Insight {
        let focus = ProductivityMath.focusMinutes(state, weekOf: now) / 60
        let goal = state.weeklyFocusGoalHours
        let openTasks = content.tasks.filter { !$0.isDone }.count
        let doneToday = content.tasks.filter { task in task.completedAt.map { DateMath.isSameDay($0, now) } ?? false }.count
        let habitsDone = content.habits.filter { $0.isDone(on: now) }.count
        let focusText = Fmt.hours(focus)
        var facts = [
            tr("Focus cette semaine : \(focusText)"),
            tr("Objectif : \(Fmt.hours(goal))"),
            tr("Tâches ouvertes : \(openTasks)"),
            tr("Tâches faites aujourd'hui : \(doneToday)"),
            tr("Habitudes faites aujourd'hui : \(habitsDone) sur \(content.habits.count)"),
        ]
        var text = tr("\(focusText) de concentration cette semaine")
        if goal > 0 {
            let percent = Int(safely: (focus / goal * 100).rounded())
            facts.append(tr("Progression : \(percent) %"))
            text += tr(", \(percent) % de ton objectif.")
        } else {
            text += "."
        }
        if !content.habits.isEmpty {
            text += tr(" Habitudes du jour : \(habitsDone) sur \(content.habits.count).")
        }
        var points = [tr("\(Fmt.plural(openTasks, tr("tâche"), tr("tâches"))) à faire"), tr("\(Fmt.plural(doneToday, tr("faite"), tr("faites"))) aujourd'hui")]
        let best = content.habits.max { $0.streak(asOf: now) < $1.streak(asOf: now) }
        if let best, best.streak(asOf: now) > 1 {
            let line = tr("\(best.name) · série de \(best.streak(asOf: now)) j")
            facts.append(line)
            points.append(line)
        }
        return Insight(title: tr("Productivité"), symbol: "chart.line.uptrend.xyaxis", text: text, facts: facts, points: points)
    }

    /// The day in two sentences: what's next, what's left, and one number that matters.
    static func day(payload: WidgetPayload, now: Date) -> Insight {
        var facts: [String] = []
        var parts: [String] = []
        let settings = payload.settings
        if case let .ready(weather) = payload.weather {
            let line = "\(weather.locationName) : \(Fmt.temperature(weather.temperature, unit: settings.temperatureUnit)), \(WeatherCode.description(weather.code).lowercased())"
            facts.append(line)
            parts.append(tr("\(Fmt.temperature(weather.temperature, unit: settings.temperatureUnit)) et \(WeatherCode.description(weather.code).lowercased()) à \(weather.locationName)"))
        }
        if case let .ready(events) = payload.events, let next = events.first(where: { $0.end > now }) {
            let time = next.isAllDay ? tr("toute la journée") : "à \(Fmt.time(next.start, uses24Hour: settings.uses24HourClock))"
            facts.append(tr("Prochain : \(next.title) \(time)"))
            parts.append("\(next.title) \(time)")
        }
        let open = payload.content.tasks.filter { !$0.isDone }.count
        if !payload.content.tasks.isEmpty {
            facts.append(tr("Tâches : \(open)"))
            parts.append(open == 0 ? tr("toutes tes tâches sont faites") : tr("\(Fmt.plural(open, tr("tâche"), tr("tâches"))) à faire"))
        }
        let priorities = payload.domains.productivity.priorities
        if !priorities.isEmpty {
            let done = priorities.filter { $0.isDone(on: now) }.count
            facts.append(tr("Priorités : \(done) sur \(priorities.count)"))
        }
        let nutrition = payload.domains.nutrition
        let eaten = NutritionMath.totals(nutrition, on: now).kcal
        if eaten > 0 {
            let left = kcal(nutrition.goals.kcal - eaten)
            facts.append(tr("Calories restantes : \(left) kcal"))
            parts.append(tr("\(left) kcal restantes"))
        }
        let text: String
        if parts.isEmpty {
            text = tr("Ajoute ta ville, tes tâches ou tes repas dans Tessera pour voir ta journée résumée ici.")
        } else {
            let first = parts[0].capitalizedFirst
            let rest = parts.dropFirst().joined(separator: ", ")
            text = rest.isEmpty ? first + "." : first + ". " + rest.capitalizedFirst + "."
        }
        return Insight(title: tr("Ma journée"), symbol: "sparkles", text: text, facts: facts, points: Array(facts.prefix(5)))
    }

    static func insight(for kind: WidgetKind, payload: WidgetPayload, now: Date) -> Insight {
        switch kind {
        case .aiNutrition: return nutrition(payload.domains.nutrition, now: now)
        case .aiFinance: return finance(payload.domains.budget, now: now, currency: payload.settings.currencyCode)
        case .aiProductivity: return productivity(payload.domains.productivity, content: payload.content, now: now)
        default: return day(payload: payload, now: now)
        }
    }
}

extension Fmt {
    /// "3 h 20" / "45 min"
    static func hours(_ hours: Double) -> String {
        let minutes = Int(safely: (hours * 60).rounded())
        if minutes < 60 { return tr("\(minutes) min") }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(String(format: "%02d", m))"
    }

    static func minutes(_ minutes: Double) -> String {
        hours(minutes / 60)
    }
}

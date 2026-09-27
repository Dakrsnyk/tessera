import Foundation

/// Accrual math for the "Flux d'argent" widget: amounts are spread evenly over time.
struct MoneySummary: Hashable {
    var perDayIncome: Double
    var perDayExpense: Double
    var totalIncome: Double
    var totalExpense: Double
    var todayIncome: Double
    var todayExpense: Double
    var dayFraction: Double
    var startDate: Date

    var perDayNet: Double { perDayIncome - perDayExpense }
    var totalNet: Double { totalIncome - totalExpense }
    var todayNet: Double { todayIncome - todayExpense }

    func perDay(_ mode: MoneyMode) -> Double {
        switch mode {
        case .net: perDayNet
        case .income: perDayIncome
        case .expense: perDayExpense
        }
    }

    func total(_ mode: MoneyMode) -> Double {
        switch mode {
        case .net: totalNet
        case .income: totalIncome
        case .expense: totalExpense
        }
    }

    func today(_ mode: MoneyMode) -> Double {
        switch mode {
        case .net: todayNet
        case .income: todayIncome
        case .expense: todayExpense
        }
    }

    static let daysPerMonth = 365.0 / 12.0
}

enum MoneyMath {
    static func summary(_ state: MoneyState, at now: Date = Date()) -> MoneySummary {
        let income = state.items.filter(\.isIncome).reduce(0) { $0 + $1.perDay }
        let expense = state.items.filter { !$0.isIncome }.reduce(0) { $0 + $1.perDay }
        let start = DateMath.startOfDay(state.startDate)
        let elapsedDays = max(0, now.timeIntervalSince(start) / 86_400)
        let midnight = DateMath.startOfDay(now)
        let fraction: Double
        if now < start {
            fraction = 0
        } else {
            fraction = min(1, max(0, now.timeIntervalSince(max(midnight, start)) / 86_400))
        }
        return MoneySummary(
            perDayIncome: income,
            perDayExpense: expense,
            totalIncome: elapsedDays * income,
            totalExpense: elapsedDays * expense,
            todayIncome: fraction * income,
            todayExpense: fraction * expense,
            dayFraction: fraction,
            startDate: start
        )
    }
}

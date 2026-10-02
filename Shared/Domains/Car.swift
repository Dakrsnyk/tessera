import Foundation

struct FuelFill: Codable, Hashable, Identifiable {
    var id = UUID()
    var date = Date()
    var liters: Double
    var total: Double
    var odometer: Double
    /// Only full tanks give an exact consumption (full-to-full method).
    var isFull = true

    var pricePerLiter: Double { liters > 0 ? total / liters : 0 }
}

struct OdometerReading: Codable, Hashable {
    var date: Date
    var km: Double
}

struct ServiceItem: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var intervalKm: Double?
    var intervalMonths: Int?
    var lastKm: Double?
    var lastDate: Date?
    var cost: Double = 0
}

struct CarDeadline: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var date: Date
    var symbol: String = "calendar"
}

struct CarState: Codable, Hashable {
    var name = tr("Ma voiture")
    var fills: [FuelFill] = []
    var readings: [OdometerReading] = []
    var services: [ServiceItem] = []
    var deadlines: [CarDeadline] = []
    var insuranceMonthly: Double = 0
    var loanMonthly: Double = 0
    var parkingMonthly: Double = 0
    var otherMonthly: Double = 0
    /// Maintenance budget per year (tires, repairs…), spread over the months.
    var maintenanceYearly: Double = 0
    /// Tank size in litres, for the range.
    var tankLiters: Double?

    enum CodingKeys: String, CodingKey {
        case name, fills, readings, services, deadlines, insuranceMonthly, loanMonthly, parkingMonthly, otherMonthly, maintenanceYearly, tankLiters
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.value(.name, tr("Ma voiture"))
        fills = c.value(.fills, [])
        readings = c.value(.readings, [])
        services = c.value(.services, [])
        deadlines = c.value(.deadlines, [])
        insuranceMonthly = c.value(.insuranceMonthly, 0)
        loanMonthly = c.value(.loanMonthly, 0)
        parkingMonthly = c.value(.parkingMonthly, 0)
        otherMonthly = c.value(.otherMonthly, 0)
        maintenanceYearly = c.value(.maintenanceYearly, 0)
        tankLiters = c.optional(.tankLiters)
    }

    mutating func save(_ fill: FuelFill) {
        if let index = fills.firstIndex(where: { $0.id == fill.id }) { fills[index] = fill } else { fills.append(fill) }
    }

    mutating func markServiceDone(_ id: UUID, km: Double, at date: Date = Date()) {
        guard let index = services.firstIndex(where: { $0.id == id }) else { return }
        services[index].lastKm = km
        services[index].lastDate = date
    }
}

enum CarMath {
    /// Every known odometer value, from readings and fill-ups, oldest first.
    static func odometerPoints(_ state: CarState) -> [OdometerReading] {
        (state.readings + state.fills.map { OdometerReading(date: $0.date, km: $0.odometer) })
            .sorted { $0.date < $1.date }
    }

    static func odometer(_ state: CarState) -> Double? {
        odometerPoints(state).map(\.km).max()
    }

    /// Kilometres driven since the first reading of the month (or the last one before it).
    static func kmThisMonth(_ state: CarState, at date: Date) -> Double? {
        guard let month = DateMath.calendar.dateInterval(of: .month, for: date) else { return nil }
        let points = odometerPoints(state)
        guard let latest = points.last(where: { $0.date <= date }) else { return nil }
        let start = points.last(where: { $0.date < month.start }) ?? points.first(where: { month.contains($0.date) })
        guard let base = start else { return nil }
        return max(0, latest.km - base.km)
    }

    /// Litres per 100 km across the full-to-full fill-ups.
    static func consumption(_ state: CarState) -> Double? {
        let full = state.fills.sorted { $0.odometer < $1.odometer }
        guard let firstFull = full.firstIndex(where: \.isFull), let lastFull = full.lastIndex(where: \.isFull), lastFull > firstFull else { return nil }
        let distance = full[lastFull].odometer - full[firstFull].odometer
        let liters = full[(firstFull + 1)...lastFull].reduce(0) { $0 + $1.liters }
        guard distance > 0 else { return nil }
        return liters / distance * 100
    }

    static func lastPricePerLiter(_ state: CarState) -> Double? {
        state.fills.max { $0.date < $1.date }?.pricePerLiter
    }

    static func fuelCostPerKm(_ state: CarState) -> Double? {
        guard let perHundred = Self.consumption(state), let price = lastPricePerLiter(state) else { return nil }
        return perHundred / 100 * price
    }

    static func fuelSpent(_ state: CarState, in interval: DateInterval) -> Double {
        state.fills.filter { interval.contains($0.date) }.reduce(0) { $0 + $1.total }
    }

    /// Average fuel spending per month over the last three months (or since the first fill-up).
    static func fuelMonthlyAverage(_ state: CarState, at date: Date) -> Double {
        guard let first = state.fills.map(\.date).min() else { return 0 }
        let start = max(first, DateMath.calendar.date(byAdding: .month, value: -3, to: date) ?? first)
        let months = max(1, date.timeIntervalSince(start) / (30.44 * 86_400))
        return fuelSpent(state, in: DateInterval(start: start, end: max(start, date))) / months
    }

    struct MonthlyCost: Hashable {
        let fixed: Double
        let fuel: Double
        let maintenance: Double
        var total: Double { fixed + fuel + maintenance }
    }

    static func monthlyCost(_ state: CarState, at date: Date) -> MonthlyCost {
        MonthlyCost(
            fixed: state.insuranceMonthly + state.loanMonthly + state.parkingMonthly + state.otherMonthly,
            fuel: fuelMonthlyAverage(state, at: date),
            maintenance: state.maintenanceYearly / 12
        )
    }

    struct ServiceStatus: Hashable {
        let item: ServiceItem
        let kmLeft: Double?
        let daysLeft: Int?
        /// Share of the interval already used, 0 to 1 (or more when overdue).
        let used: Double
    }

    static func serviceStatus(_ state: CarState, at date: Date) -> [ServiceStatus] {
        let current = Self.odometer(state)
        return state.services.map { item -> ServiceStatus in
            var kmLeft: Double?
            var daysLeft: Int?
            var used = 0.0
            if let interval = item.intervalKm, interval > 0, let last = item.lastKm, let current {
                kmLeft = last + interval - current
                used = max(used, (current - last) / interval)
            }
            if let months = item.intervalMonths, months > 0, let last = item.lastDate,
               let due = DateMath.calendar.date(byAdding: .month, value: months, to: last) {
                daysLeft = DateMath.daysBetween(date, due)
                used = max(used, date.timeIntervalSince(last) / max(1, due.timeIntervalSince(last)))
            }
            return ServiceStatus(item: item, kmLeft: kmLeft, daysLeft: daysLeft, used: used)
        }
        .sorted { $0.used > $1.used }
    }

    static func upcomingDeadlines(_ state: CarState, at date: Date) -> [CarDeadline] {
        let today = DateMath.startOfDay(date)
        return state.deadlines.filter { $0.date >= today }.sorted { $0.date < $1.date }
    }

    // MARK: Mini-app

    /// What the tank still holds and how far it goes, estimated since the last full tank from the
    /// average consumption. Nil without a tank size, a full tank or a consumption.
    struct FuelRange: Hashable {
        let liters: Double
        let km: Double
        let share: Double
        let since: FuelFill
    }

    static func range(_ state: CarState) -> FuelRange? {
        guard let tank = state.tankLiters, tank > 0, let perHundred = consumption(state),
              let lastFull = state.fills.filter(\.isFull).max(by: { $0.odometer < $1.odometer }),
              let current = odometer(state) else { return nil }
        // Partial fill-ups since the last full tank add fuel back.
        let added = state.fills.filter { !$0.isFull && $0.odometer > lastFull.odometer }.reduce(0) { $0 + $1.liters }
        let used = max(0, current - lastFull.odometer) * perHundred / 100
        let liters = min(tank, max(0, tank - used + added))
        return FuelRange(liters: liters, km: liters / perHundred * 100, share: liters / tank, since: lastFull)
    }

    struct MonthDistance: Hashable, Identifiable {
        let start: Date
        let km: Double
        var id: Date { start }
    }

    /// Kilometres driven each month, oldest first, from the odometer values known.
    static func kmByMonth(_ state: CarState, count: Int, at date: Date) -> [MonthDistance] {
        let points = odometerPoints(state)
        guard !points.isEmpty, let current = DateMath.calendar.dateInterval(of: .month, for: date)?.start else { return [] }
        return (0..<count).reversed().compactMap { back in
            guard let start = DateMath.calendar.date(byAdding: .month, value: -back, to: current),
                  let end = DateMath.calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
            let before = points.last(where: { $0.date < start })
            let inside = points.filter { $0.date >= start && $0.date < end }
            guard let last = inside.last, let base = before ?? inside.first else { return MonthDistance(start: start, km: 0) }
            return MonthDistance(start: start, km: max(0, last.km - base.km))
        }
    }

    /// Consumption between two full tanks, for each full tank after the first.
    struct FillConsumption: Hashable, Identifiable {
        let fill: FuelFill
        let perHundred: Double
        var id: UUID { fill.id }
    }

    static func consumptionByFill(_ state: CarState) -> [FillConsumption] {
        let sorted = state.fills.sorted { $0.odometer < $1.odometer }
        var result: [FillConsumption] = []
        var lastFullIndex: Int?
        for (index, fill) in sorted.enumerated() where fill.isFull {
            if let previous = lastFullIndex {
                let distance = fill.odometer - sorted[previous].odometer
                let liters = sorted[(previous + 1)...index].reduce(0) { $0 + $1.liters }
                if distance > 0 { result.append(FillConsumption(fill: fill, perHundred: liters / distance * 100)) }
            }
            lastFullIndex = index
        }
        return result
    }
}

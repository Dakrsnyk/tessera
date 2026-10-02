import Charts
import SwiftUI

// MARK: - Fuel

/// Every fill-up (editable), the price per litre and the consumption between full tanks.
struct CarFuelPage: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: CarSheet?

    private var currency: String { model.settings.currencyCode }

    var body: some View {
        let state = model.car
        let fills = state.fills.sorted { $0.date > $1.date }
        let byFill = CarMath.consumptionByFill(state)
        MiniAppScroll {
            MiniActionButton(title: tr("Noter un plein"), symbol: "fuelpump.fill", colorHex: Car.fuelHex) { sheet = .fuel(nil) }
                .accessibilityIdentifier("fuel-new")
            if fills.isEmpty {
                Text(tr("Aucun plein noté. À chaque plein, note les litres, le prix et le compteur : la consommation se calcule entre deux pleins complets."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .card(padding: 14)
            }
            if byFill.count >= 2 {
                VStack(alignment: .leading, spacing: 10) {
                    MiniSectionTitle(title: tr("Consommation"), detail: CarMath.consumption(state).map { tr("moyenne \(TF.decimal($0, 1)) L/100") })
                    Chart(byFill) { item in
                        LineMark(x: .value("Date", item.fill.date), y: .value("L/100 km", item.perHundred))
                            .foregroundStyle(Color(hex: Car.fuelHex))
                            .symbol(.circle)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 140)
                    .card()
                }
            }
            if fills.count >= 2 {
                VStack(alignment: .leading, spacing: 10) {
                    MiniSectionTitle(title: tr("Prix au litre"), detail: CarMath.lastPricePerLiter(state).map { tr("dernier \(TF.money($0, currency, decimals: 3))") })
                    Chart(Array(fills.reversed())) { fill in
                        LineMark(x: .value("Date", fill.date), y: .value("Prix", fill.pricePerLiter))
                            .foregroundStyle(Color(hex: Car.accentHex))
                            .symbol(.circle)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 120)
                    .card()
                }
            }
            if !fills.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    MiniSectionTitle(title: tr("Pleins"), detail: "\(fills.count)")
                    MiniRowsCard {
                        ForEach(Array(fills.enumerated()), id: \.element.id) { index, fill in
                            if index > 0 { MiniDivider() }
                            Button { sheet = .fuel(fill) } label: {
                                MiniRow(symbol: fill.isFull ? "fuelpump.fill" : "fuelpump", colorHex: Car.fuelHex, title: Fmt.shortDay(fill.date),
                                        detail: tr("\(TF.decimal(fill.liters, 1)) L · \(TF.money(fill.pricePerLiter, currency, decimals: 3))/L · \(Fmt.number(Int(fill.odometer))) km\(fill.isFull ? "" : tr(" · partiel"))"),
                                        value: TF.money(fill.total, currency, decimals: 2), showsChevron: false)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("fuel-row")
                        }
                    }
                }
            }
        }
        .navigationTitle(tr("Carburant"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }
}

// MARK: - Mileage

struct CarMileagePage: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: CarSheet?

    var body: some View {
        let state = model.car
        let now = Date()
        let months = CarMath.kmByMonth(state, count: 6, at: now)
        let driven = months.filter { $0.km > 0 }
        let points = Array(CarMath.odometerPoints(state).reversed())
        MiniAppScroll {
            HStack(spacing: 10) {
                MiniStat(title: tr("Compteur"), value: CarMath.odometer(state).map { Fmt.number(Int($0)) } ?? "–", unit: tr("km"))
                MiniStat(title: tr("Moyenne"), value: driven.isEmpty ? "–" : Fmt.number(Int(driven.reduce(0) { $0 + $1.km } / Double(driven.count))), unit: "km/mois")
            }
            MiniActionButton(title: tr("Noter le kilométrage"), symbol: "speedometer", colorHex: Car.accentHex) { sheet = .odometer }
            if !driven.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    MiniSectionTitle(title: tr("Kilomètres par mois"))
                    Chart(months) { month in
                        BarMark(x: .value("Mois", month.start, unit: .month), y: .value("km", month.km))
                            .foregroundStyle(Color(hex: Car.accentHex).gradient)
                            .cornerRadius(3)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                        }
                    }
                    .frame(height: 170)
                    .card()
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("mileage-chart")
                }
            }
            if !points.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    MiniSectionTitle(title: tr("Relevés"))
                    MiniRowsCard {
                        ForEach(Array(points.prefix(12).enumerated()), id: \.offset) { index, point in
                            if index > 0 { MiniDivider() }
                            MiniRow(symbol: "gauge.with.dots.needle.33percent", colorHex: Car.accentHex, title: Fmt.shortDay(point.date),
                                    value: tr("\(Fmt.number(Int(point.km))) km"), showsChevron: false)
                        }
                    }
                    Text(tr("Les relevés viennent de tes pleins et des kilométrages notés.")).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(tr("Kilométrage"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }
}

// MARK: - Maintenance

struct CarMaintenancePage: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: CarSheet?

    var body: some View {
        let state = model.car
        let now = Date()
        let statuses = CarMath.serviceStatus(state, at: now)
        List {
            Section {
                ForEach(statuses, id: \.item.id) { status in
                    Button { sheet = .service(status.item) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            ServiceStatusRow(status: status)
                            Text(lastText(status.item)).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            let km = CarMath.odometer(state) ?? 0
                            model.update(\.car) { $0.markServiceDone(status.item.id, km: km) }
                            Haptics.success()
                        } label: {
                            Label(tr("Fait aujourd'hui"), systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            model.update(\.car) { $0.services.removeAll { $0.id == status.item.id } }
                        } label: {
                            Label(tr("Supprimer"), systemImage: "trash")
                        }
                    }
                    .accessibilityIdentifier("service-row")
                }
                Button {
                    sheet = .service(ServiceItem(name: "", intervalKm: 8_000, intervalMonths: 6, lastKm: CarMath.odometer(state), lastDate: now))
                } label: {
                    Label(tr("Nouvel entretien"), systemImage: "plus")
                }
            } footer: {
                Text(tr("Glisse vers la droite quand un entretien est fait : il repart du compteur d'aujourd'hui."))
            }
        }
        .styledList()
        .tint(Color(hex: "3366FF"))
        .navigationTitle(tr("Entretien"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }

    private func lastText(_ item: ServiceItem) -> String {
        var parts: [String] = []
        if let km = item.lastKm { parts.append(tr("dernier à \(Fmt.number(Int(km))) km")) }
        if let date = item.lastDate { parts.append(tr("le \(Fmt.shortDay(date))")) }
        if item.cost > 0 { parts.append(tr("environ \(TF.money(item.cost, model.settings.currencyCode))")) }
        return parts.isEmpty ? tr("Pas encore fait") : parts.joined(separator: " · ").capitalizedFirst
    }
}

// MARK: - Deadlines

struct CarDeadlinesPage: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: CarSheet?

    var body: some View {
        let state = model.car
        let now = Date()
        let sorted = state.deadlines.sorted { $0.date < $1.date }
        List {
            Section {
                ForEach(sorted) { deadline in
                    let days = DateMath.daysBetween(now, deadline.date)
                    Button { sheet = .deadline(deadline) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: deadline.symbol).frame(width: 24).foregroundStyle(days <= 14 ? Color(hex: Car.alertHex) : Color(hex: Car.accentHex))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(deadline.title).foregroundStyle(.primary)
                                Text(Fmt.format(deadline.date, template: "EEEEdMMMMyyyy").capitalizedFirst).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(days < 0 ? tr("passée") : (days == 0 ? tr("aujourd'hui") : "J-\(days)"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(days <= 14 && days >= 0 ? Color(hex: Car.alertHex) : Color.secondary)
                                .monospacedDigit()
                        }
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { sorted[$0].id }
                    model.update(\.car) { $0.deadlines.removeAll { ids.contains($0.id) } }
                }
                Button {
                    sheet = .deadline(CarDeadline(title: "", date: now.addingTimeInterval(60 * 86_400)))
                } label: {
                    Label(tr("Nouvelle échéance"), systemImage: "plus")
                }
            }
        }
        .styledList()
        .tint(Color(hex: Car.alertHex))
        .navigationTitle(tr("Échéances"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }
}

// MARK: - Costs

/// What the car costs each month: fixed costs, fuel (from the fill-ups) and the maintenance budget.
struct CarCostsPage: View {
    @Environment(AppModel.self) private var model

    private var currency: String { model.settings.currencyCode }

    private struct Share: Identifiable {
        let name: String
        let hex: String
        let value: Double
        var id: String { name }
    }

    var body: some View {
        let state = model.car
        let now = Date()
        let cost = CarMath.monthlyCost(state, at: now)
        let shares = [
            Share(name: tr("Frais fixes"), hex: "2F8F7A", value: cost.fixed),
            Share(name: tr("Carburant"), hex: Car.fuelHex, value: cost.fuel),
            Share(name: tr("Entretien"), hex: "3366FF", value: cost.maintenance),
        ].filter { $0.value > 0 }
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(tr("Par mois")).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text(TF.money(cost.total, currency)).font(.system(size: 36, weight: .bold, design: .rounded)).monospacedDigit()
                    if !shares.isEmpty {
                        Chart(shares) { share in
                            BarMark(x: .value("Montant", share.value), stacking: .normalized)
                                .foregroundStyle(Color(hex: share.hex))
                        }
                        .chartXAxis(.hidden)
                        .frame(height: 16)
                        .clipShape(Capsule())
                        HStack(spacing: 12) {
                            ForEach(shares) { share in
                                HStack(spacing: 4) {
                                    Circle().fill(Color(hex: share.hex)).frame(width: 8, height: 8)
                                    Text("\(share.name) \(TF.money(share.value, currency))").font(.caption)
                                }
                            }
                        }
                    }
                    if let perKm = perKilometre(state, total: cost.total, now: now) {
                        Text(tr("Soit environ \(TF.money(perKm, currency, decimals: 2)) par kilomètre parcouru.")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("car-costs")
            }
            Section {
                NumberRow(title: tr("Assurance"), value: binding(\.insuranceMonthly), unit: tr("/ mois"))
                NumberRow(title: tr("Prêt ou location"), value: binding(\.loanMonthly), unit: tr("/ mois"))
                NumberRow(title: tr("Stationnement"), value: binding(\.parkingMonthly), unit: tr("/ mois"))
                NumberRow(title: tr("Autres frais"), value: binding(\.otherMonthly), unit: tr("/ mois"))
                NumberRow(title: tr("Entretien prévu"), value: binding(\.maintenanceYearly), unit: tr("/ an"))
            } header: {
                Text(tr("Frais fixes"))
            } footer: {
                Text(tr("Le carburant est la moyenne de tes pleins des trois derniers mois ; l'entretien prévu est réparti sur douze mois."))
            }
        }
        .styledList()
        .navigationTitle(tr("Coûts"))
        .navigationBarTitleDisplayMode(.large)
    }

    private func perKilometre(_ state: CarState, total: Double, now: Date) -> Double? {
        let driven = CarMath.kmByMonth(state, count: 4, at: now).dropLast().filter { $0.km > 0 }
        guard !driven.isEmpty else { return nil }
        let average = driven.reduce(0) { $0 + $1.km } / Double(driven.count)
        return average > 0 ? total / average : nil
    }

    private func binding(_ keyPath: WritableKeyPath<CarState, Double>) -> Binding<Double> {
        Binding(
            get: { model.car[keyPath: keyPath] },
            set: { value in model.update(\.car) { $0[keyPath: keyPath] = max(0, value) } }
        )
    }
}

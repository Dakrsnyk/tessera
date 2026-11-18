import Charts
import SwiftUI

// MARK: - Fuel

/// Every fill-up (editable), the price per litre and the consumption between full tanks.
struct CarFuelPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style
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
                            .foregroundStyle(CristalPalette.of(style.id).category(Car.fuelHex))
                            .symbol(.circle)
                    }
                    .accessibilityLabel(tr("Consommation"))
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
                            .foregroundStyle(CristalPalette.of(style.id).category(Car.accentHex))
                            .symbol(.circle)
                    }
                    .accessibilityLabel(tr("Prix au litre"))
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
                            .buttonStyle(.pressable)
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
    @Environment(\.appStyle) private var style
    @State private var sheet: CarSheet?

    var body: some View {
        let state = model.car
        let now = Date()
        let months = CarMath.kmByMonth(state, count: 6, at: now)
        let driven = months.filter { $0.km > 0 }
        let points = pointsList(state)
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
                            .foregroundStyle(CristalPalette.of(style.id).category(Car.accentHex).gradient)
                            .cornerRadius(3)
                    }
                    .accessibilityLabel(tr("Kilomètres par mois"))
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
                        ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                            if index > 0 { MiniDivider() }
                            Button { sheet = point.sheet } label: {
                                MiniRow(symbol: "gauge.with.dots.needle.33percent", colorHex: Car.accentHex,
                                        title: tr("\(Fmt.number(Int(point.km))) km"),
                                        detail: "\(point.isReading ? tr("Relevé") : tr("Plein")) · \(Fmt.shortDay(point.date))")
                            }
                            .buttonStyle(.pressable)
                            .accessibilityIdentifier("reading-row")
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

    /// One known odometer value, with the sheet that corrects it: a reading, or the fill-up it comes from.
    private struct Point {
        let date: Date
        let km: Double
        let sheet: CarSheet
        let isReading: Bool
    }

    /// The 12 latest values, newest first.
    private func pointsList(_ state: CarState) -> [Point] {
        let all = state.readings.map { Point(date: $0.date, km: $0.km, sheet: .reading($0), isReading: true) }
            + state.fills.map { Point(date: $0.date, km: $0.odometer, sheet: .fuel($0), isReading: false) }
        return Array(all.sorted { $0.date > $1.date }.prefix(12))
    }
}

// MARK: - Maintenance

struct CarMaintenancePage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style
    @State private var sheet: CarSheet?
    /// The maintenance a deletion is asked for.
    @State private var deleting: ServiceItem?

    var body: some View {
        let state = model.car
        let now = Date()
        let statuses = CarMath.serviceStatus(state, at: now)
        MiniAppScroll {
            MiniActionButton(title: tr("Nouvel entretien"), symbol: "plus", colorHex: "3366FF") {
                sheet = .service(ServiceItem(name: "", intervalKm: 8_000, intervalMonths: 6, lastKm: CarMath.odometer(state), lastDate: now))
            }
            VStack(spacing: 10) {
                ForEach(statuses, id: \.item.id) { status in
                    VStack(alignment: .leading, spacing: 8) {
                        Button { sheet = .service(status.item) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                ServiceStatusRow(status: status)
                                Text(lastText(status.item)).font(.caption).foregroundStyle(Color.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable)
                        .accessibilityIdentifier("service-row")
                        history(status.item)
                        HStack(spacing: 10) {
                            MiniActionButton(title: tr("Fait aujourd'hui"), symbol: "checkmark", colorHex: "3366FF", isProminent: false) {
                                let km = CarMath.odometer(state) ?? 0
                                let id = status.item.id
                                model.update(\.car) { $0.markServiceDone(id, km: km) }
                                Haptics.success()
                            }
                            MiniActionButton(title: tr("Supprimer"), symbol: "trash", colorHex: Car.alertHex, isProminent: false) {
                                deleting = status.item
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .miniCard()
                }
            }
            MiniFootnote(text: tr("Fait aujourd'hui remet le compteur et la date de l'entretien à aujourd'hui."))
        }
        .navigationTitle(tr("Entretien"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
        .confirmationDialog(tr("Supprimer cet entretien ?"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button(tr("Supprimer"), role: .destructive) {
                if let id = deleting?.id { model.update(\.car) { $0.services.removeAll { $0.id == id } } }
                deleting = nil
            }
            Button(tr("Annuler"), role: .cancel) { deleting = nil }
        }
    }

    /// Each time it was done (newest first), when the app has kept them.
    @ViewBuilder
    private func history(_ item: ServiceItem) -> some View {
        let records = (item.history ?? []).sorted { $0.date > $1.date }
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text(tr("Historique")).font(.footnote.weight(.semibold)).foregroundStyle(.secondary).padding(.bottom, 4)
                ForEach(Array(records.prefix(5).enumerated()), id: \.element.id) { index, record in
                    if index > 0 { MiniDivider() }
                    HStack(spacing: 10) {
                        Text(Fmt.format(record.date, template: "dMMMMyyyy")).font(.subheadline)
                        Spacer()
                        if let km = record.km { Text(tr("\(Fmt.number(Int(km))) km")).font(.subheadline).foregroundStyle(.secondary).monospacedDigit() }
                        if record.cost > 0 { Text(TF.money(record.cost, model.settings.currencyCode)).font(.subheadline.weight(.semibold)).monospacedDigit() }
                    }
                    .frame(minHeight: 32)
                }
            }
        }
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
    @Environment(\.appStyle) private var style
    @State private var sheet: CarSheet?

    var body: some View {
        let state = model.car
        let now = Date()
        let sorted = state.deadlines.sorted { $0.date < $1.date }
        MiniAppScroll {
            MiniActionButton(title: tr("Nouvelle échéance"), symbol: "plus", colorHex: Car.alertHex) {
                sheet = .deadline(CarDeadline(title: "", date: now.addingTimeInterval(60 * 86_400)))
            }
            if !sorted.isEmpty {
                MiniRowsCard {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, deadline in
                        if index > 0 { MiniDivider() }
                        let days = DateMath.daysBetween(now, deadline.date)
                        let done = deadline.doneOn != nil
                        Button { sheet = .deadline(deadline) } label: {
                            MiniRow(symbol: done ? "checkmark.circle.fill" : deadline.symbol,
                                    colorHex: !done && days <= 14 ? Car.alertHex : Car.accentHex,
                                    title: deadline.title,
                                    detail: Fmt.format(deadline.date, template: "EEEEdMMMMyyyy").capitalizedFirst,
                                    value: done ? tr("fait") : (days < 0 ? tr("passée") : (days == 0 ? tr("aujourd'hui") : tr("J-\(days)"))))
                        }
                        .buttonStyle(.pressable)
                        .accessibilityIdentifier("deadline-row")
                    }
                }
            }
            MiniFootnote(text: tr("Touche une échéance pour la modifier, la marquer comme faite, la répéter chaque année ou la supprimer."))
        }
        .navigationTitle(tr("Échéances"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }
}

// MARK: - Costs

/// What the car costs each month: fixed costs, fuel (from the fill-ups) and the maintenance budget.
struct CarCostsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style

    private var currency: String { model.settings.currencyCode }

    private struct Share: Identifiable {
        let name: String
        let hex: String
        let value: Double
        /// Where the figure comes from.
        let source: String
        var id: String { name }
    }

    var body: some View {
        let state = model.car
        let now = Date()
        let cost = CarMath.monthlyCost(state, at: now)
        let shares = [
            Share(name: tr("Frais fixes"), hex: "2F8F7A", value: cost.fixed, source: tr("assurance, prêt, stationnement, autres")),
            Share(name: tr("Carburant"), hex: Car.fuelHex, value: cost.fuel, source: tr("moyenne des 3 derniers mois")),
            Share(name: tr("Entretien"), hex: "3366FF", value: cost.maintenance, source: tr("forfait par an ÷ 12")),
        ].filter { $0.value > 0 }
        MiniAppScroll {
            VStack(alignment: .leading, spacing: 10) {
                Text(tr("Par mois")).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text(TF.money(cost.total, currency)).font(.system(size: 36, weight: .bold, design: .rounded)).monospacedDigit()
                if !shares.isEmpty {
                    Chart(shares) { share in
                        BarMark(x: .value("Montant", share.value), stacking: .normalized)
                            .foregroundStyle(CristalPalette.of(style.id).category(share.hex))
                    }
                    .accessibilityLabel(tr("Par mois"))
                    .chartXAxis(.hidden)
                    .frame(height: 16)
                    .clipShape(Capsule())
                    // Each part says where its figure comes from: a real average, a forfait, or what was typed.
                    VStack(spacing: 0) {
                        ForEach(Array(shares.enumerated()), id: \.element.id) { index, share in
                            if index > 0 { MiniDivider() }
                            HStack(spacing: 10) {
                                Circle().fill(CristalPalette.of(style.id).category(share.hex)).frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(share.name).font(.subheadline.weight(.semibold))
                                    Text(share.source).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(TF.money(share.value, currency)).font(.subheadline.weight(.semibold)).monospacedDigit()
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
                if let perKm = perKilometre(state, total: cost.total, now: now) {
                    Text(tr("Soit environ \(TF.money(perKm, currency, decimals: 2)) par kilomètre parcouru.")).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("car-costs")
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Frais fixes"))
                VStack(spacing: 8) {
                    NumberRow(title: tr("Assurance"), value: binding(\.insuranceMonthly), unit: tr("/ mois"))
                    NumberRow(title: tr("Prêt ou location"), value: binding(\.loanMonthly), unit: tr("/ mois"))
                    NumberRow(title: tr("Stationnement"), value: binding(\.parkingMonthly), unit: tr("/ mois"))
                    NumberRow(title: tr("Autres frais"), value: binding(\.otherMonthly), unit: tr("/ mois"))
                    NumberRow(title: tr("Entretien prévu"), value: binding(\.maintenanceYearly), unit: tr("/ an"))
                }
                .card()
                MiniFootnote(text: tr("Le carburant est la moyenne de tes pleins des trois derniers mois ; l'entretien prévu est réparti sur douze mois."))
            }
        }
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

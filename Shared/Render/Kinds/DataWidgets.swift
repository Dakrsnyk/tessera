import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Weather

struct WeatherSymbol: View {
    let code: Int
    let isDay: Bool
    let style: ResolvedStyle
    var size: CGFloat

    var body: some View {
        let image = Image(systemName: WeatherCode.symbol(code, isDay: isDay))
            .font(.system(size: size, weight: .medium))
        if style.prefersMulticolorSymbols {
            image.symbolRenderingMode(.multicolor)
        } else {
            image.symbolRenderingMode(.hierarchical).foregroundStyle(style.primary)
        }
    }
}

struct WeatherWidgetView: View {
    let context: RenderContext

    var body: some View {
        let s = context.style
        switch context.payload.weather {
        case .needsLocation:
            WidgetMessage(symbol: "location.circle", title: tr("Choisis ta ville"), message: tr("Touche pour la définir dans Ardane"), style: s)
        case .unavailable(.none):
            WidgetMessage(symbol: "wifi.slash", title: tr("Météo indisponible"), message: tr("Nouvel essai dans quelques minutes"), style: s)
        case let .ready(snapshot):
            content(snapshot, isStale: false)
        case let .unavailable(.some(snapshot)):
            content(snapshot, isStale: true)
        }
    }

    private var unit: TemperatureUnit { context.settings.temperatureUnit }

    @ViewBuilder
    private func content(_ w: WeatherSnapshot, isStale: Bool) -> some View {
        switch context.family {
        case .systemMedium:
            HStack(spacing: 14) {
                current(w, isStale: isStale, tempSize: 42)
                    .frame(width: 118, alignment: .leading)
                hourly(w, count: 5)
            }
        case .systemLarge, .systemExtraLarge:
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    current(w, isStale: isStale, tempSize: 50)
                    Spacer()
                }
                .frame(height: 118)
                hourly(w, count: 6)
                    .frame(height: 62)
                Rectangle().fill(context.style.track).frame(height: 1)
                daily(w, count: 5)
            }
        default:
            current(w, isStale: isStale, tempSize: 44)
        }
    }

    private func current(_ w: WeatherSnapshot, isStale: Bool, tempSize: CGFloat) -> some View {
        let s = context.style
        return VStack(alignment: .leading, spacing: 2) {
            if s.showsTitle {
                HStack(spacing: 3) {
                    Image(systemName: "location.fill").font(.system(size: 9, weight: .bold))
                    Text(w.locationName).lineLimit(1)
                }
                .font(s.text(12, .semibold))
                .foregroundStyle(s.primary)
            }
            Spacer(minLength: 0)
            WeatherSymbol(code: w.code, isDay: w.isDay, style: s, size: tempSize * 0.5)
            Text(Fmt.temperature(w.temperature, unit: unit))
                .font(s.number(tempSize))
                .foregroundStyle(s.numberColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if s.showsDetails {
                Text(WeatherCode.description(w.code))
                    .font(s.text(12, .medium))
                    .foregroundStyle(s.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("↑\(Fmt.temperature(w.high, unit: unit))  ↓\(Fmt.temperature(w.low, unit: unit))")
                    .font(s.text(11).monospacedDigit())
                    .foregroundStyle(s.secondary)
            }
            if isStale {
                Text(tr("Mis à jour à \(Fmt.time(w.fetchedAt, uses24Hour: context.settings.uses24HourClock))"))
                    .font(s.text(9))
                    .foregroundStyle(s.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func hourly(_ w: WeatherSnapshot, count: Int) -> some View {
        let s = context.style
        let hours = w.upcomingHours(from: context.date, count: count)
        return HStack(spacing: 0) {
            ForEach(hours, id: \.date) { hour in
                VStack(spacing: 6) {
                    Text(Fmt.format(hour.date, template: context.settings.uses24HourClock ? "HH" : "ha"))
                        .font(s.text(11, .medium))
                        .foregroundStyle(s.secondary)
                    WeatherSymbol(code: hour.code, isDay: hour.isDay, style: s, size: 16)
                        .frame(height: 20)
                    Text(Fmt.temperature(hour.temperature, unit: unit))
                        .font(s.text(13, .semibold).monospacedDigit())
                        .foregroundStyle(s.primary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func daily(_ w: WeatherSnapshot, count: Int) -> some View {
        let s = context.style
        let days = Array(w.daily.prefix(count))
        let low = days.map(\.low).min() ?? 0
        let high = days.map(\.high).max() ?? 1
        let span = max(high - low, 1)
        return VStack(spacing: 7) {
            ForEach(Array(days.enumerated()), id: \.offset) { pair in
                let day = pair.element
                HStack(spacing: 10) {
                    Text(pair.offset == 0 ? "Auj." : Fmt.format(day.date, template: "EEE").capitalizedFirst)
                        .font(s.text(13, .medium))
                        .foregroundStyle(s.primary)
                        .frame(width: 44, alignment: .leading)
                    WeatherSymbol(code: day.code, isDay: true, style: s, size: 15)
                        .frame(width: 24)
                    Text(Fmt.temperature(day.low, unit: unit))
                        .font(s.text(13).monospacedDigit())
                        .foregroundStyle(s.secondary)
                        .frame(width: 34, alignment: .trailing)
                    GeometryReader { geo in
                        let start = (day.low - low) / span
                        let end = (day.high - low) / span
                        ZStack(alignment: .leading) {
                            Capsule().fill(s.track)
                            Capsule()
                                .fill(s.accent)
                                .frame(width: max(6, geo.size.width * (end - start)))
                                .offset(x: geo.size.width * start)
                        }
                    }
                    .frame(height: 5)
                    Text(Fmt.temperature(day.high, unit: unit))
                        .font(s.text(13, .semibold).monospacedDigit())
                        .foregroundStyle(s.primary)
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Crypto

struct CryptoWidgetView: View {
    let context: RenderContext

    var body: some View {
        let s = context.style
        switch context.payload.crypto {
        case let .ready(coin):
            content(coin, isStale: false)
        case let .unavailable(.some(coin)):
            content(coin, isStale: true)
        case .unavailable(.none):
            WidgetMessage(symbol: "wifi.slash", title: tr("Cours indisponible"), message: tr("Nouvel essai dans quelques minutes"), style: s)
        }
    }

    @ViewBuilder
    private func content(_ coin: CoinSnapshot, isStale: Bool) -> some View {
        let s = context.style
        let trendUp = (coin.sparkline.last ?? 0) >= (coin.sparkline.first ?? 0)
        let lineColor = trendUp ? s.positive : s.negative
        // An old price says when it was read, so it never passes for a fresh one.
        let showsTime = isStale || LivePrices.isOld(coin.fetchedAt, now: context.date)
        if context.isSmall {
            VStack(alignment: .leading, spacing: 3) {
                header(coin)
                Spacer(minLength: 0)
                Text(Fmt.price(coin.price, currency: coin.currency))
                    .font(s.number(24))
                    .foregroundStyle(s.numberColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                changeLabel(coin)
                if s.showsDetails {
                    sparkline(coin.sparkline, color: lineColor)
                        .frame(height: showsTime ? 26 : 32)
                        .padding(.top, 3)
                }
                if showsTime { timeLabel(coin) }
            }
        } else {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    header(coin)
                    Spacer(minLength: 0)
                    Text(coin.name)
                        .font(s.text(13, .medium))
                        .foregroundStyle(s.secondary)
                    Text(Fmt.price(coin.price, currency: coin.currency))
                        .font(s.number(30))
                        .foregroundStyle(s.numberColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    changeLabel(coin)
                    timeLabel(coin)
                }
                .frame(width: 140, alignment: .leading)
                VStack(alignment: .trailing, spacing: 4) {
                    if let high = coin.sparkline.max() {
                        Text(Fmt.price(high, currency: coin.currency))
                            .font(s.text(10).monospacedDigit())
                            .foregroundStyle(s.secondary)
                    }
                    sparkline(coin.sparkline, color: lineColor)
                    HStack {
                        Text(tr("7 jours"))
                        Spacer()
                        if let low = coin.sparkline.min() {
                            Text(Fmt.price(low, currency: coin.currency)).monospacedDigit()
                        }
                    }
                    .font(s.text(10))
                    .foregroundStyle(s.secondary)
                }
            }
        }
    }

    private func header(_ coin: CoinSnapshot) -> some View {
        let s = context.style
        return HStack(spacing: 6) {
            WLabel(text: coin.symbol, style: s, color: s.primary)
            Spacer(minLength: 0)
        }
    }

    /// « ▲ +1,45 % · 24 h »: the arrow and the sign still tell the way once iOS removes the colors.
    private func changeLabel(_ coin: CoinSnapshot) -> some View {
        let s = context.style
        let trend = PriceChange.trend(coin.change24h)
        return Text(PriceChange.text(coin.change24h, .day24h))
            .font(s.text(11, .semibold).monospacedDigit())
            .foregroundStyle(trend == true ? s.positive : (trend == false ? s.negative : s.secondary))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func sparkline(_ values: [Double], color: Color) -> some View {
        ZStack {
            SparklineShape(values: values, closed: true)
                .fill(LinearGradient(colors: [color.opacity(0.28), color.opacity(0)], startPoint: .top, endPoint: .bottom))
            SparklineShape(values: values)
                .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
    }

    /// « Cours de 14:05 », with the day when the price is from another one.
    private func timeLabel(_ coin: CoinSnapshot) -> some View {
        let clock = PriceClock(now: context.date, uses24Hour: context.settings.uses24HourClock)
        return Text(clock.asOf(coin.fetchedAt))
            .font(context.style.text(9))
            .foregroundStyle(context.style.secondary)
            .lineLimit(1)
    }
}

// MARK: - Money flow

struct MoneyFlowWidgetView: View {
    let context: RenderContext

    var body: some View {
        let s = context.style
        let money = context.payload.content.money
        let currency = context.settings.currencyCode
        let mode = context.options.moneyMode
        let summary = MoneyMath.summary(money, at: context.date)
        let total = summary.total(mode)
        let today = summary.today(mode)
        let color: Color = mode == .expense ? s.negative : mode == .income ? s.positive : (total >= 0 ? s.positive : s.negative)

        if money.items.isEmpty {
            WidgetMessage(symbol: "dollarsign.circle", title: tr("Aucun montant"), message: tr("Ajoute tes revenus et dépenses dans Ardane"), style: s)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                if s.showsTitle { WLabel(text: label(mode), style: s) }
                Text(mode == .net ? Fmt.signedMoney(total, currency: currency) : Fmt.money(total, currency: currency))
                    .font(s.number(context.isSmall ? 24 : 34))
                    .foregroundStyle(mode == .net ? color : s.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if context.isSmall {
                    Spacer(minLength: 0)
                    Text(todayText(today, mode: mode, currency: currency))
                        .font(s.text(12, .semibold))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if s.showsDetails {
                        Text(tr("\(Fmt.money(abs(summary.perDay(mode)) * MoneySummary.daysPerMonth, currency: currency, decimals: 0)) / mois"))
                            .font(s.text(11))
                            .foregroundStyle(s.secondary)
                    }
                } else {
                    Spacer(minLength: 0)
                    HStack {
                        WLabel(text: tr("Aujourd'hui"), style: s)
                        Spacer()
                        Text(todayText(today, mode: mode, currency: currency, short: true))
                            .font(s.text(15, .semibold).monospacedDigit())
                            .foregroundStyle(color)
                    }
                    BarView(progress: summary.dayFraction, color: color, track: s.track, height: 6)
                    if s.showsDetails {
                        Text(tr("\(Fmt.money(abs(summary.perDay(mode)), currency: currency)) / jour · \(Fmt.money(abs(summary.perDay(mode)) * MoneySummary.daysPerMonth, currency: currency, decimals: 0)) / mois"))
                            .font(s.text(12))
                            .foregroundStyle(s.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    if context.isLarge {
                        breakdown(summary: summary, money: money, mode: mode, currency: currency)
                            .padding(.top, 10)
                    }
                    Spacer(minLength: 0)
                    if s.showsDetails {
                        Text(tr("Depuis le \(Fmt.format(summary.startDate, template: "dMMMMyyyy"))"))
                            .font(s.text(10))
                            .foregroundStyle(s.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func label(_ mode: MoneyMode) -> String {
        switch mode {
        case .net: tr("Solde net")
        case .income: tr("Total gagné")
        case .expense: tr("Total dépensé")
        }
    }

    private func todayText(_ value: Double, mode: MoneyMode, currency: String, short: Bool = false) -> String {
        let amount: String
        switch mode {
        case .net: amount = Fmt.signedMoney(value, currency: currency)
        case .income: amount = "+" + Fmt.money(value, currency: currency)
        case .expense: amount = "−" + Fmt.money(value, currency: currency)
        }
        return short ? amount : tr("\(amount) aujourd'hui")
    }

    @ViewBuilder
    private func breakdown(summary: MoneySummary, money: MoneyState, mode: MoneyMode, currency: String) -> some View {
        let s = context.style
        let month = MoneySummary.daysPerMonth
        VStack(spacing: 8) {
            HStack {
                WLabel(text: mode == .net ? tr("Chaque mois") : tr("Détail"), style: s)
                Spacer()
                WLabel(text: tr("par mois"), style: s)
            }
            if mode == .net {
                row(tr("Revenus"), "+" + Fmt.money(summary.perDayIncome * month, currency: currency, decimals: 0), s.positive)
                row(tr("Dépenses"), "−" + Fmt.money(summary.perDayExpense * month, currency: currency, decimals: 0), s.negative)
                row(tr("Il te reste"), Fmt.signedMoney(summary.perDayNet * month, currency: currency, decimals: 0), summary.perDayNet >= 0 ? s.positive : s.negative, bold: true)
                if summary.perDayIncome > 0 {
                    row(tr("Part épargnée"), Fmt.percent(summary.perDayNet / summary.perDayIncome), s.primary)
                }
            } else {
                let items = money.items
                    .filter { $0.isIncome == (mode == .income) }
                    .sorted { $0.perDay > $1.perDay }
                ForEach(items.prefix(6)) { item in
                    row(item.name, Fmt.money(item.perDay * month, currency: currency, decimals: 0), s.primary)
                }
            }
        }
    }

    private func row(_ title: String, _ value: String, _ color: Color, bold: Bool = false) -> some View {
        let s = context.style
        return HStack {
            Text(title)
                .font(s.text(14, bold ? .semibold : .regular))
                .foregroundStyle(s.primary)
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(s.text(14, .semibold).monospacedDigit())
                .foregroundStyle(color)
        }
    }
}

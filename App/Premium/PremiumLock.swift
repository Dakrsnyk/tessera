import SwiftUI

/// What Premium adds, in place of an analysis or a long history: what it shows, that the data is
/// already kept, and the way to Premium. Nothing the person entered is ever locked away.
struct PremiumLockCard: View {
    let symbol: String
    let title: String
    let message: String
    @Environment(Router.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.premiumInk)
                    .frame(width: 40, height: 40)
                    .background(Color.premiumFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                router.isPaywallPresented = true
            } label: {
                Label(tr("Découvrir Premium"), systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("premium-lock-open")
        }
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("premium-lock")
    }
}

enum PremiumHistory {
    /// The oldest day a free plan shows: the last seven days (with their whole month in Finances).
    static func earliestFreeDay(now: Date = Date()) -> Date {
        DateMath.startOfDay(DateMath.calendar.date(byAdding: .day, value: -6, to: now) ?? now)
    }
}

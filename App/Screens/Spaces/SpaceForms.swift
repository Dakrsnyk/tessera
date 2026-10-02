import SwiftUI

/// A form presented as a sheet, with Annuler / Enregistrer buttons.
struct SheetForm<Content: View>: View {
    let title: String
    var canSave = true
    /// False when saving closes a parent sheet (which takes this one with it, in one motion).
    var dismissesOnSave = true
    let onSave: () -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                content()
                    .listRowBackground(Rectangle().fill(.cardFill))
            }
            .styledList()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Enregistrer")) {
                        onSave()
                        if dismissesOnSave { dismiss() }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

/// Units next to number fields: a currency code ("CAD") is shown as its symbol ("$").
enum UnitText {
    static func display(_ unit: String) -> String {
        guard unit.count == 3, unit.allSatisfy({ $0.isUppercase && $0.isLetter }) else { return unit }
        let formatter = NumberFormatter()
        formatter.locale = Fmt.locale
        formatter.numberStyle = .currency
        formatter.currencyCode = unit
        return formatter.currencySymbol ?? unit
    }
}

/// A labelled number field (amounts, weights, distances…).
struct NumberRow: View {
    let title: String
    @Binding var value: Double
    var unit: String?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: $value, format: .number.locale(Fmt.locale))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
            if let unit {
                Text(UnitText.display(unit)).foregroundStyle(Color.secondary)
            }
        }
    }
}

/// A number field that can stay empty: nothing typed means the value isn't known (never a made-up 0).
struct OptionalNumberRow: View {
    let title: String
    @Binding var value: Double?
    var unit: String?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(tr("À renseigner"), value: $value, format: .number.locale(Fmt.locale))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 130)
            if let unit {
                Text(UnitText.display(unit)).foregroundStyle(Color.secondary)
            }
        }
    }
}

struct IntRow: View {
    let title: String
    @Binding var value: Int
    var unit: String?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: $value, format: .number.locale(Fmt.locale))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
            if let unit {
                Text(UnitText.display(unit)).foregroundStyle(Color.secondary)
            }
        }
    }
}

/// A value shown on the right of a label, for summaries.
struct ValueRow: View {
    let title: String
    let value: String
    var symbol: String?
    var colorHex: String?

    var body: some View {
        HStack(spacing: 10) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(colorHex.map { Color(hex: $0) } ?? Color.accentColor)
                    .frame(width: 22)
            }
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(Color.secondary)
                .monospacedDigit()
        }
    }
}

struct HintRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color.secondary)
    }
}

/// Monday-first weekday chips, ISO numbering (1 = lundi … 7 = dimanche).
struct WeekdayPicker: View {
    @Binding var selection: [Int]

    var body: some View {
        let symbols = DateMath.weekdaySymbols()
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.removeAll { $0 == day } } else { selection.append(day); selection.sort() }
                } label: {
                    Text(day - 1 < symbols.count ? symbols[day - 1] : "\(day)")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .foregroundStyle(isOn ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.primary))
                        .background(isOn ? Color.accentColor : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

/// Minutes after midnight edited as a time.
struct MinuteTimePicker: View {
    let title: String
    @Binding var minutes: Int

    var body: some View {
        DatePicker(title, selection: Binding(
            get: { DateMath.startOfDay(Date()).addingTimeInterval(TimeInterval(minutes) * 60) },
            set: { date in
                let parts = DateMath.calendar.dateComponents([.hour, .minute], from: date)
                minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        ), displayedComponents: .hourAndMinute)
        .environment(\.locale, Fmt.locale)
    }
}

enum SpaceColors {
    static let choices = ["3366FF", "2F8F7A", "FF6B57", "F2A33A", "8C6CFF", "F2588F", "7FA33A", "6B7280", "12A4B5", "D6409F"]
}

struct ColorChoiceRow: View {
    @Binding var hex: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(SpaceColors.choices, id: \.self) { choice in
                    ColorDot(hex: choice, isSelected: hex == choice, size: 26) { hex = choice }
                }
            }
        }
    }
}

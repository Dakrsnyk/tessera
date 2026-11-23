import SwiftUI

/// The weight or the height of the first launch, chosen in a scrolling list where every row shows both units: pounds
/// (or feet and inches) on the left, kilograms (or centimetres) on the right (PDG, 2026-11-22). Nothing to switch,
/// no extra « Pouces » field. Saved in kg and cm, as everywhere; the field shows the unit of Réglages › Unités.
struct ProfileMeasureField: View {
    enum Measure {
        case weight, height

        /// Every value offered, in kg (by half a kilo) or in cm.
        var values: [Double] {
            switch self {
            case .weight: return Array(stride(from: 30.0, through: 250.0, by: 0.5))
            case .height: return Array(stride(from: 100.0, through: 230.0, by: 1))
            }
        }

        /// The row shown first while nothing is known yet.
        var start: Double { self == .weight ? 70 : 170 }

        var title: String { self == .weight ? tr("Poids") : tr("Taille", context: "height") }

        /// "70 kg" / "175 cm".
        func metric(_ value: Double) -> String {
            switch self {
            case .weight: return Units.weightText(kilograms: value, in: .metric)
            case .height: return "\(Int(safely: value.rounded())) " + tr("cm")
            }
        }

        /// "154 lb" / "5 ft 9 in".
        func imperial(_ value: Double) -> String {
            switch self {
            case .weight: return tr("\(String(Int(safely: Units.pounds(fromKilograms: value).rounded()))) lb")
            case .height: return Units.heightText(centimetres: value, in: .imperial)
            }
        }

        /// The offered value closest to a saved one (a weight typed before may not fall on a half kilo).
        func nearest(_ value: Double) -> Double {
            values.min(by: { abs($0 - value) < abs($1 - value) }) ?? start
        }
    }

    @Environment(AppModel.self) private var model
    let measure: Measure
    @Binding var value: Double?
    let identifier: String
    @State private var choosing = false
    @State private var selection = 0.0

    var body: some View {
        Button {
            Haptics.tap()
            selection = measure.nearest(value ?? measure.start)
            choosing = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(measure.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(shown)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(value == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(measure.title))
        .accessibilityValue(Text(value.map { "\(measure.imperial($0)), \(measure.metric($0))" } ?? ""))
        .accessibilityIdentifier(identifier)
        .sheet(isPresented: $choosing) { picker }
    }

    private var shown: String {
        guard let value else { return "—" }
        return model.settings.unitSystem == .imperial ? measure.imperial(value) : measure.metric(value)
    }

    private var picker: some View {
        NavigationStack {
            Picker(measure.title, selection: $selection) {
                ForEach(measure.values, id: \.self) { row in
                    HStack {
                        Text(measure.imperial(row))
                        Spacer(minLength: 16)
                        Text(measure.metric(row))
                    }
                    .monospacedDigit()
                    .padding(.horizontal, 32)
                    .tag(row)
                }
            }
            .pickerStyle(.wheel)
            .accessibilityIdentifier("\(identifier)-wheel")
            .navigationTitle(measure.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("OK")) {
                        value = selection
                        choosing = false
                    }
                    .accessibilityIdentifier("\(identifier)-done")
                }
            }
        }
        .presentationDetents([.height(320)])
    }
}

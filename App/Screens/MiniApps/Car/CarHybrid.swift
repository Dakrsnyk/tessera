import SwiftUI

/// An odometer reading to correct: its value and its day, or delete it (after a confirmation). A reading has no
/// identifier: it is found again by its own value, and left alone if it is gone.
struct CarReadingEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    private let original: OdometerReading
    @State private var km: Double
    @State private var date: Date
    @State private var confirmsDelete = false

    init(reading: OdometerReading) {
        original = reading
        _km = State(initialValue: reading.km)
        _date = State(initialValue: reading.date)
    }

    var body: some View {
        SheetForm(title: tr("Relevé"), canSave: km > 0, onSave: save) {
            Section {
                NumberRow(title: tr("Compteur"), value: $km, unit: tr("km"))
                DatePicker(tr("Date"), selection: $date, displayedComponents: .date).environment(\.locale, Fmt.locale)
            } footer: {
                Text(tr("Le compteur prend le plus grand kilométrage noté : corrige ici un relevé faux."))
            }
            Section {
                Button(tr("Supprimer le relevé"), role: .destructive) { confirmsDelete = true }
            }
        }
        .confirmationDialog(tr("Supprimer ce relevé ?"), isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button(tr("Supprimer le relevé"), role: .destructive) {
                let target = original
                model.update(\.car) { state in
                    if let index = state.readings.firstIndex(of: target) { state.readings.remove(at: index) }
                }
                dismiss()
            }
            Button(tr("Annuler"), role: .cancel) {}
        }
    }

    private func save() {
        let target = original
        let corrected = OdometerReading(date: date, km: km)
        model.update(\.car) { state in
            if let index = state.readings.firstIndex(of: target) { state.readings[index] = corrected }
        }
        Haptics.success()
    }
}

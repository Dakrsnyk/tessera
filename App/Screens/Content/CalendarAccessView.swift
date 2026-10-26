import SwiftUI

struct CalendarAccessView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 34))
                        .foregroundStyle(Color.accentColor)
                    Text(tr("Le widget À venir"))
                        .font(.headline)
                    Text(tr("Il affiche tes événements des 48 prochaines heures, directement depuis le calendrier de ton iPhone."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            Section {
                CalendarAccessRow()
            }
        }
        .styledList()
        .navigationTitle(tr("Calendrier"))
    }
}

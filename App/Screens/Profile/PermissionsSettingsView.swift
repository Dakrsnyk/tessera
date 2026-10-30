import SwiftUI
import UIKit

/// Profil › Autorisations: the real state of each permission (read without asking), the way to ask when it was
/// never asked, and the path to the iPhone's settings when it was refused. Nothing here is required.
struct PermissionsSettingsView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(tr("Ardane n'utilise que ces accès, et chacun reste facultatif : sans lui, la fonction concernée affiche simplement un message."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(PermissionsSetup.order) { permission in
                    PermissionRowCard(permission: permission)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Pour changer un accès déjà décidé : Réglages › Ardane."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Label(tr("Ouvrir les réglages de l'iPhone"), systemImage: "gearshape")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("permissions-open-settings")
                }
            }
            .padding(20)
        }
        .background(.screenGradient)
        .navigationTitle(tr("Autorisations"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

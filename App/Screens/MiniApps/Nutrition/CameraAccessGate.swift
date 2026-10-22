import SwiftUI
import AVFoundation

/// Puts the camera behind a clear explanation, before iOS asks anything.
///
/// - Never asked: an explanation (why the camera, what stays on the iPhone) with « Continuer », which
///   is the only thing that triggers the system request, and « Plus tard ».
/// - Refused or restricted: a plain message with « Ouvrir Réglages » and the way out (`onLater`). The
///   refusal is respected: the request is never repeated, not even when the screen comes back.
/// - Allowed: the content (the live camera).
///
/// The status is read again when the app comes back to the foreground, so allowing the camera in
/// Réglages is enough: the camera appears when the person returns.
struct CameraAccessGate<Content: View>: View {
    /// Why the camera is needed, in one sentence.
    let reason: String
    /// What stays on the iPhone, in one or two sentences.
    let privacy: String
    /// The way out when the camera is not used (« Chercher ou créer l'aliment »).
    let alternativeTitle: String
    /// « Plus tard » and the way out of a refusal.
    let onLater: () -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.scenePhase) private var scenePhase
    @State private var status = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var isAsking = false

    var body: some View {
        Group {
            switch status {
            case .authorized:
                content()
            case .notDetermined:
                explanation
            default:
                refused
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { status = AVCaptureDevice.authorizationStatus(for: .video) }
        }
    }

    // MARK: Before the system request

    private var explanation: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(tr("Utiliser la caméra"))
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 18) {
                    point(symbol: "questionmark.circle", title: tr("Pourquoi la caméra"), text: reason)
                    point(symbol: "lock.iphone", title: tr("Ce qui reste sur ton iPhone"), text: privacy)
                }
                Text(tr("iOS te demandera ensuite ton accord."))
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    Button {
                        ask()
                    } label: {
                        Text(tr("Continuer")).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAsking)
                    Button {
                        onLater()
                    } label: {
                        Text(tr("Plus tard")).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func point(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The system request, only from « Continuer » and only while the answer is still unknown.
    private func ask() {
        guard status == .notDetermined, !isAsking else { return }
        isAsking = true
        Task {
            _ = await AVCaptureDevice.requestAccess(for: .video)
            status = AVCaptureDevice.authorizationStatus(for: .video)
            isAsking = false
        }
    }

    // MARK: Refused

    private var refused: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)
                Text(tr("Caméra désactivée"))
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(tr("L'accès à la caméra est refusé pour Ardane. Tu peux l'autoriser dans Réglages › Ardane, ou continuer sans la caméra."))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text(tr("Ouvrir Réglages")).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        onLater()
                    } label: {
                        Text(alternativeTitle).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

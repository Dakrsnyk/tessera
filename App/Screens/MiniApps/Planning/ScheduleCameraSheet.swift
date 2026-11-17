import SwiftUI
import VisionKit

/// The pages photographed with the document camera: how many, and each one when it is asked for (they are opened
/// one by one, away from the main thread, by `ScheduleReader.lightPages`).
struct ScannedPages {
    let count: Int
    let page: (Int) -> UIImage
}

/// « Scanner avec la caméra » of the schedule import: the explanation first (`CameraAccessGate`: why the camera,
/// what stays on the iPhone, and the system request only after « Continuer »), then the document camera of iOS.
/// `onFinish` receives the pages photographed, or nil when the person leaves.
struct ScheduleCameraSheet: View {
    let onFinish: (ScannedPages?) -> Void

    var body: some View {
        CameraAccessGate(
            reason: tr("Elle photographie ton horaire, sur papier ou sur un écran, pour en lire les cours et les heures."),
            privacy: tr("La lecture se fait sur ton iPhone. Aucune photo n'est enregistrée ni envoyée."),
            alternativeTitle: tr("Choisir une photo ou un PDF"),
            onLater: { onFinish(nil) }
        ) {
            ScheduleDocumentCamera(onFinish: onFinish)
                .ignoresSafeArea()
        }
    }
}

/// The document camera of iOS (VisionKit), the one of Notes and Files: it finds the edges of the sheet, straightens
/// it, takes several pages, and has its own flash button (automatic by default: the flash fires by itself when it is
/// dark; the person can set it on or off). The pages are handed over and nothing is saved.
struct ScheduleDocumentCamera: UIViewControllerRepresentable {
    /// The pages photographed; nil when the person cancels or the camera fails.
    let onFinish: (ScannedPages?) -> Void

    /// False where there is no camera (the simulator): the source is then not offered.
    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let camera = VNDocumentCameraViewController()
        camera.delegate = context.coordinator
        return camera
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {
        context.coordinator.onFinish = onFinish
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var onFinish: (ScannedPages?) -> Void

        init(onFinish: @escaping (ScannedPages?) -> Void) {
            self.onFinish = onFinish
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // The scan is kept until its pages have been read (they are opened later, one by one).
            onFinish(scan.pageCount > 0 ? ScannedPages(count: scan.pageCount) { scan.imageOfPage(at: $0) } : nil)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish(nil)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onFinish(nil)
        }
    }
}

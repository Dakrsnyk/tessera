import SwiftUI
import VisionKit
import PhotosUI

/// How the food scanner closed.
enum FoodScanOutcome {
    /// The foods are in the journal.
    case logged
    /// Back to the food search (« Annuler », « Plus tard », « Chercher dans la liste »).
    case search
    /// A custom food to create, prefilled (the barcode, and the name when Open Food Facts has it).
    case create(FoodItem)
}

/// The one screen of the food scanner. No mode to choose: the live camera reads a barcode by itself (the
/// product is then looked up) and a shutter button photographs a dish (it is then analysed on the iPhone).
/// Both end in the same editable recap (`ScanRecapView`) before anything is logged.
///
/// - The camera sits behind `CameraAccessGate`: the explanation comes before the system request.
/// - A barcode is looked up in the person's own foods first (custom foods, favourites, recent), then on
///   Open Food Facts, one request per scan. Nothing found, or no connection: a screen says so and offers
///   to search the list, to create the food, or to try again. No product is ever made up.
/// - A photo is analysed by `MealAnalysisConfig.makeAnalyzer()` (Vision, on the iPhone). The photo is not
///   kept and nothing is sent.
struct FoodScanView: View {
    /// The meal the food goes to (chosen from a meal of the Nutrition mini-app), else the current one.
    var presetMeal: MealType? = nil
    /// The day the food is added to (today, or a day browsed in the mini-app).
    var day: Date = Date()
    let onFinish: (FoodScanOutcome) -> Void
    @Environment(AppModel.self) private var model
    @State private var stage: Stage = .camera
    @State private var recap = ScanRecap()
    @State private var source: ScanRecapSource = .barcode
    @State private var camera = ScanCameraHandle()
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var isCapturing = false

    private enum PhotoProblem {
        case nothingFound
        case failed
    }

    private enum Stage {
        case camera
        case looking(String)
        case analyzing
        case recap
        case notFound(String)
        case offline(String)
        /// A product Open Food Facts knows without its nutrition: a custom food to complete.
        case partial(FoodItem)
        case photoFailed(PhotoProblem)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(tr("Annuler")) { onFinish(.search) }
                    }
                    if case .recap = stage {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                rescan()
                            } label: {
                                Image(systemName: "camera").frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel(tr("Scanner à nouveau"))
                        }
                    }
                }
                .onChange(of: pickedPhoto) { _, item in
                    guard let item else { return }
                    pickedPhoto = nil
                    Task { await analyze(item) }
                }
        }
    }

    private var title: String {
        if case .recap = stage { return tr("Récapitulatif") }
        return tr("Scanner un aliment")
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .camera:
            CameraAccessGate(
                reason: tr("Elle lit le code-barres d'un aliment, ou photographie ton plat pour en estimer le contenu."),
                privacy: tr("L'analyse se fait sur ton iPhone. Aucune photo n'est enregistrée ni envoyée ; seul le numéro d'un code-barres est envoyé à Open Food Facts pour trouver le produit."),
                alternativeTitle: tr("Chercher ou créer l'aliment"),
                onLater: { onFinish(.search) }
            ) {
                cameraScreen
            }
        case .looking(let code):
            progress(tr("Recherche du produit \(code)…"))
        case .analyzing:
            progress(tr("Analyse du plat sur ton iPhone…"))
        case .recap:
            ScanRecapView(recap: $recap, source: source, presetMeal: presetMeal, day: day) {
                onFinish(.logged)
            }
        case .notFound(let code):
            ScanMessageView(
                symbol: "barcode",
                title: tr("Produit introuvable"),
                message: tr("Le produit \(code) n'est pas encore dans Open Food Facts."),
                detail: tr("Crée-le avec les valeurs de l'étiquette : le prochain scan le retrouvera.")
            ) {
                prominentButton(tr("Créer cet aliment")) { onFinish(.create(draft(for: code))) }
                plainButton(tr("Chercher dans la liste")) { onFinish(.search) }
                plainButton(tr("Scanner à nouveau")) { rescan() }
            }
        case .offline(let code):
            ScanMessageView(
                symbol: "wifi.slash",
                title: tr("Produit introuvable"),
                message: tr("Pas de connexion : le produit \(code) n'a pas pu être cherché.")
            ) {
                prominentButton(tr("Réessayer")) {
                    stage = .looking(code)
                    Task { await lookup(code) }
                }
                plainButton(tr("Créer cet aliment")) { onFinish(.create(draft(for: code))) }
                plainButton(tr("Chercher dans la liste")) { onFinish(.search) }
            }
        case .partial(let found):
            ScanMessageView(
                symbol: "barcode",
                title: found.displayName,
                message: tr("Open Food Facts connaît ce produit, mais pas ses valeurs nutritives : recopie-les depuis l'étiquette.")
            ) {
                prominentButton(tr("Créer cet aliment")) { onFinish(.create(found)) }
                plainButton(tr("Chercher dans la liste")) { onFinish(.search) }
                plainButton(tr("Scanner à nouveau")) { rescan() }
            }
        case .photoFailed(let problem):
            ScanMessageView(
                symbol: "fork.knife",
                title: tr("Plat non reconnu"),
                message: problem == .nothingFound
                    ? tr("Je n'ai reconnu aucun aliment sur cette photo. Rapproche-toi du plat, ou cherche l'aliment dans la liste.")
                    : tr("L'analyse de la photo a échoué. Réessaie, ou cherche l'aliment dans la liste.")
            ) {
                prominentButton(tr("Réessayer")) { rescan() }
                plainButton(tr("Chercher ou créer l'aliment")) { onFinish(.search) }
            }
        }
    }

    // MARK: Camera

    @ViewBuilder
    private var cameraScreen: some View {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            ScanCameraView(handle: camera, onScan: handleBarcode)
                .ignoresSafeArea(edges: .bottom)
                .overlay { ScanFrame() }
                .safeAreaInset(edge: .bottom) { controls }
        } else {
            ScanMessageView(
                symbol: "camera.fill",
                title: tr("Caméra indisponible"),
                message: tr("La caméra n'est pas disponible pour le moment. Tu peux chercher l'aliment dans la liste.")
            ) {
                prominentButton(tr("Chercher ou créer l'aliment")) { onFinish(.search) }
            }
        }
    }

    /// The shutter (a dish), the picker of a photo already taken, and the way to the search.
    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                        .foregroundStyle(Color.primary)
                        .frame(width: 52, height: 52)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel(tr("Choisir une photo"))
                Spacer()
                Button {
                    Task { await shoot() }
                } label: {
                    ZStack {
                        Circle().strokeBorder(Color.white, lineWidth: 4).frame(width: 72, height: 72)
                        Circle().fill(Color.white).frame(width: 58, height: 58)
                    }
                    .frame(width: 76, height: 76)
                    .contentShape(Circle())
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                }
                .disabled(isCapturing)
                .opacity(isCapturing ? 0.5 : 1)
                .accessibilityLabel(tr("Photographier le plat"))
                Spacer()
                Color.clear.frame(width: 52, height: 52)
            }
            .padding(.horizontal, 28)
            Text(tr("Photographier le plat"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.white)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                .accessibilityHidden(true)
            // No barcode, or a product the database doesn't know: the search is one tap away.
            Button {
                onFinish(.search)
            } label: {
                Label(tr("Chercher ou créer l'aliment"), systemImage: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: Barcode

    /// A barcode read by the camera: the product is looked up at once.
    private func handleBarcode(_ code: String) {
        guard case .camera = stage else { return }
        stage = .looking(code)
        Task { await lookup(code) }
    }

    /// A food already saved with this barcode (no connection needed), else Open Food Facts. Every outcome
    /// shows something: the recap, or what to do next.
    @MainActor
    private func lookup(_ code: String) async {
        let mine = model.nutrition.customFoods + model.nutrition.favorites + model.nutrition.recentFoods
        if let known = mine.first(where: { $0.barcode.map(OpenFoodFacts.barcodeForms)?.contains(code) == true }) {
            showRecap(of: known)
            return
        }
        do {
            switch try await OpenFoodFacts.lookup(barcode: code) {
            case .food(let food): showRecap(of: food)
            case .partial(let found): stage = .partial(found)
            case .unknown: stage = .notFound(code)
            }
        } catch {
            stage = .offline(code)
        }
    }

    private func showRecap(of food: FoodItem) {
        recap = ScanRecap(food: food)
        source = .barcode
        stage = .recap
    }

    private func draft(for code: String) -> FoodItem {
        FoodItem(id: "custom.draft", name: "", brand: nil, kcal: 0, protein: 0, carbs: 0, fat: 0, fiber: 0,
                 servingGrams: 100, servingName: "100 g", source: .custom, barcode: code)
    }

    // MARK: Dish

    /// The shutter: a photo of the live camera, then its analysis. A barcode read in the meantime wins.
    @MainActor
    private func shoot() async {
        guard !isCapturing, case .camera = stage else { return }
        isCapturing = true
        defer { isCapturing = false }
        let image: UIImage
        do {
            image = try await camera.capturePhoto()
        } catch {
            if case .camera = stage { stage = .photoFailed(.failed) }
            return
        }
        guard case .camera = stage else { return }
        await analyze(image)
    }

    /// A photo chosen with the system picker (no access to the photo library is asked).
    @MainActor
    private func analyze(_ item: PhotosPickerItem) async {
        guard case .camera = stage else { return }
        stage = .analyzing
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            stage = .photoFailed(.failed)
            return
        }
        await analyze(image)
    }

    /// Looks at the photo on the iPhone and shows what it seems to contain, as estimates. The photo is
    /// dropped as soon as the analysis is over.
    @MainActor
    private func analyze(_ image: UIImage) async {
        stage = .analyzing
        do {
            let analysis = try await MealAnalysisConfig.makeAnalyzer().analyzeMeal(image)
            guard !analysis.proposals.isEmpty else {
                stage = .photoFailed(.nothingFound)
                return
            }
            recap = analysis.recap
            source = .photo
            stage = .recap
        } catch {
            stage = .photoFailed(.failed)
        }
    }

    private func rescan() {
        recap = ScanRecap()
        stage = .camera
    }

    // MARK: Pieces

    private func progress(_ text: String) -> some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            Text(text)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .accessibilityElement(children: .combine)
    }

    private func prominentButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
    }

    private func plainButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }
}

/// A centred message with the ways out below it (not found, no connection, camera unavailable…).
struct ScanMessageView<Actions: View>: View {
    let symbol: String
    let title: String
    let message: String
    var detail: String? = nil
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 46))
                    .foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 10) {
                    actions()
                }
                .padding(.top, 6)
            }
            .padding(24)
        }
    }
}

// MARK: - Live camera

/// Hands the screen the live camera it does not own: to take a photo of a dish.
final class ScanCameraHandle {
    weak var scanner: DataScannerViewController?

    /// A still photo of what the camera sees (`DataScannerViewController.capturePhoto()`, iOS 16 and later).
    @MainActor
    func capturePhoto() async throws -> UIImage {
        guard let scanner else { throw MealAnalysisError.cameraUnavailable }
        return try await scanner.capturePhoto()
    }
}

/// The live camera with VisionKit: it reads EAN-13, EAN-8 and UPC-E barcodes on its own (iOS 16 and later,
/// on devices with a camera) and stops at the first one.
struct ScanCameraView: UIViewControllerRepresentable {
    let handle: ScanCameraHandle
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        handle.scanner = scanner
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        context.coordinator.onScan = onScan
        handle.scanner = controller
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScan: (String) -> Void
        private var didScan = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !didScan else { return }
            for item in addedItems {
                if case let .barcode(barcode) = item, let value = barcode.payloadStringValue {
                    didScan = true
                    dataScanner.stopScanning()
                    onScan(value)
                    return
                }
            }
        }
    }
}

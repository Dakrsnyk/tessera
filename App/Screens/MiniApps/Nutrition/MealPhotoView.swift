import PhotosUI
import SwiftUI
import UIKit
import Vision

/// What a photo of a meal may contain, recognized on the iPhone (Apple's Vision framework, nothing
/// leaves the phone): each label Vision gives is looked up in the food database, and only the labels
/// that match a food are kept. A guess, never a measure: the person checks it before anything is saved.
enum MealPhotoAnalyzer {
    struct Detection: Identifiable {
        let id = UUID()
        /// The label Vision gave (« pizza », « salad »…).
        let label: String
        /// The foods it may be, the most likely first.
        let candidates: [FoodItem]
    }

    /// Labels too broad to be a food (« food », « plate »…) or that only match by accident.
    private static let ignored: Set<String> = [
        "food", "meal", "dish", "dining", "tableware", "plate", "table", "utensil", "cutlery", "fork", "spoon", "knife",
        "cup", "bowl", "glass", "container", "people", "adult", "indoor", "outdoor", "produce", "ingredient", "cooking",
        "kitchen", "baked_goods", "dessert", "fruit", "vegetable", "seafood", "meat", "beverage", "drink", "snack",
        "breakfast", "lunch", "dinner", "fast_food", "sweets", "liquid", "sauce", "structure", "textile", "wood_processed",
    ]

    static func detect(in image: UIImage) async -> [Detection] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let labels: [(String, Float)] = await Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            try? VNImageRequestHandler(cgImage: cgImage, orientation: orientation).perform([request])
            return (request.results ?? [])
                .filter { $0.confidence >= 0.12 }
                .prefix(30)
                .map { ($0.identifier, $0.confidence) }
        }.value
        var seen = Set<String>()
        var detections: [Detection] = []
        for (identifier, _) in labels where !ignored.contains(identifier) {
            let query = identifier.replacingOccurrences(of: "_", with: " ")
            var candidates = FoodDatabase.search(query) + NutrientFile.search(query, limit: 6)
            candidates = candidates.filter { seen.insert($0.id).inserted }
            guard !candidates.isEmpty else { continue }
            detections.append(Detection(label: query, candidates: Array(candidates.prefix(6))))
            if detections.count == 6 { break }
        }
        return detections
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// Photo of a meal → the foods it seems to contain → quantities and macros estimated → the person
/// corrects them → added to the Nutrition log. Nothing is saved before « Ajouter au journal ».
struct MealPhotoSheet: View {
    var presetMeal: MealType? = nil
    var day: Date = Date()
    var onDone: (() -> Void)?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var showsCamera = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var isAnalyzing = false
    @State private var items: [ReviewItem] = []
    @State private var analyzed = false
    @State private var meal: MealType = .current()

    struct ReviewItem: Identifiable {
        let id = UUID()
        let label: String
        let candidates: [FoodItem]
        var choice = 0
        var grams: Double
        var included = true
        var food: FoodItem { candidates[min(choice, candidates.count - 1)] }
    }

    private var accentHex: String { MiniApp.nutrition.colorHex }

    private var totals: NutritionTotals {
        items.filter(\.included).reduce(NutritionTotals()) { $0 + $1.food.nutrients(grams: $1.grams) }
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                if isAnalyzing {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(tr("Analyse de la photo…")).foregroundStyle(Color.secondary)
                        }
                    }
                } else if analyzed && items.isEmpty {
                    Section {
                        Label(tr("Aucun aliment reconnu sur cette photo."), systemImage: "eye.slash")
                        Text(tr("Essaie une photo plus proche et bien éclairée, ou ajoute les aliments à la main depuis la recherche."))
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                        Button(tr("Chercher un aliment")) { dismiss() }
                    }
                } else if !items.isEmpty {
                    Section {
                        ForEach($items) { $item in
                            reviewRow($item)
                        }
                    } header: {
                        Text(tr("Aliments détectés"))
                    } footer: {
                        Text(tr("Touche un aliment pour en choisir un autre, et corrige la quantité : ce sont des estimations."))
                    }
                    Section(tr("Apport estimé")) {
                        ValueRow(title: tr("Calories"), value: tr("≈ \(TF.int(totals.kcal)) kcal"))
                        ValueRow(title: tr("Protéines"), value: "≈ \(TF.decimal(totals.protein, 1)) g")
                        ValueRow(title: tr("Glucides"), value: "≈ \(TF.decimal(totals.carbs, 1)) g")
                        ValueRow(title: tr("Lipides"), value: "≈ \(TF.decimal(totals.fat, 1)) g")
                    }
                    Section {
                        Picker(tr("Repas"), selection: $meal) {
                            ForEach(MealType.allCases) { Text($0.title).tag($0) }
                        }
                    }
                }
            }
            .styledList()
            .navigationTitle(tr("Photo du repas"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Ajouter au journal"), action: save)
                        .disabled(!items.contains(where: \.included))
                }
            }
            .onAppear { meal = presetMeal ?? .current() }
            .fullScreenCover(isPresented: $showsCamera) {
                CameraCapture { photo in
                    showsCamera = false
                    if let photo { use(photo) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let photo = UIImage(data: data) {
                        use(photo)
                    }
                    pickedItem = nil
                }
            }
        }
    }

    private var photoSection: some View {
        Section {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }
            HStack(spacing: 10) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showsCamera = true
                    } label: {
                        Label(image == nil ? tr("Prendre une photo") : tr("Reprendre"), systemImage: "camera.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: accentHex))
                }
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label(tr("Photos"), systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
            }
        } footer: {
            Text(tr("Estimation à partir de la photo, faite sur ton iPhone : vérifie les aliments et les quantités avant d'ajouter."))
        }
    }

    private func reviewRow(_ item: Binding<ReviewItem>) -> some View {
        let value = item.wrappedValue
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(isOn: item.included) {
                    Menu {
                        ForEach(Array(value.candidates.enumerated()), id: \.offset) { index, food in
                            Button(food.displayName) {
                                item.wrappedValue.choice = index
                                item.wrappedValue.grams = food.servingGrams
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(value.food.displayName).foregroundStyle(Color.primary).lineLimit(2)
                            Text(tr("Vu : \(value.label)")).font(.caption).foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
            if value.included {
                NumberRow(title: tr("Quantité estimée"), value: item.grams, unit: "g")
                Text(tr("≈ \(TF.int(value.food.nutrients(grams: value.grams).kcal)) kcal"))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func use(_ photo: UIImage) {
        image = photo
        items = []
        analyzed = false
        isAnalyzing = true
        Task {
            let detections = await MealPhotoAnalyzer.detect(in: photo)
            items = detections.map { ReviewItem(label: $0.label, candidates: $0.candidates, grams: $0.candidates[0].servingGrams) }
            isAnalyzing = false
            analyzed = true
        }
    }

    private func save() {
        let chosen = items.filter(\.included).map { SavedMeal.Item(food: $0.food, grams: max(1, $0.grams)) }
        guard !chosen.isEmpty else { return }
        let target = day
        let mealType = meal
        model.update(\.nutrition) { $0.log(chosen, meal: mealType, on: target) }
        Haptics.success()
        dismiss()
        onDone?()
    }
}

/// The camera, for one photo.
private struct CameraCapture: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void
        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

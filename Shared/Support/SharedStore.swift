import Foundation
import UIKit

/// Resolves the shared container used by the app and the widget extension.
enum AppGroup {
    /// Read from Info.plist (set by the APP_GROUP_ID build setting) so the identifier lives in one place.
    static var identifier: String {
        (Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String)?.trimmed.nonEmpty
            ?? "group.com.dakrsnyk.tessera"
    }

    /// Falls back to the app's own Application Support folder when the group isn't provisioned,
    /// so the app still works (widgets then show their default content).
    static let containerURL: URL = {
        let fileManager = FileManager.default
        if let url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        let fallback = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fileManager.temporaryDirectory
        return fallback
    }()

    static var isShared: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }
}

enum StoreFile: String {
    case designs, content, settings, premium, weather, crypto
}

/// Small JSON file store. Each domain lives in its own file so the widget refreshing a cache
/// can never overwrite designs or tasks the app just saved.
final class SharedStore {
    static let shared = SharedStore()

    private let directory: URL
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()
    private let lock = NSLock()

    init(directory: URL = AppGroup.containerURL.appendingPathComponent("Tessera", isDirectory: true)) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func url(_ file: StoreFile) -> URL {
        directory.appendingPathComponent("\(file.rawValue).json")
    }

    func read<T: Decodable>(_ type: T.Type, from file: StoreFile) -> T? {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url(file)) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func write<T: Encodable>(_ value: T, to file: StoreFile) {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url(file), options: [.atomic])
    }

    func remove(_ file: StoreFile) {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: url(file))
    }

    // MARK: Typed access

    var designs: [WidgetDesign] {
        get { read([WidgetDesign].self, from: .designs) ?? [] }
        set { write(newValue, to: .designs) }
    }

    var content: ContentState {
        get { read(ContentState.self, from: .content) ?? ContentState() }
        set { write(newValue, to: .content) }
    }

    var settings: AppSettings {
        get { read(AppSettings.self, from: .settings) ?? AppSettings() }
        set { write(newValue, to: .settings) }
    }

    var premium: PremiumState {
        get { read(PremiumState.self, from: .premium) ?? PremiumState() }
        set { write(newValue, to: .premium) }
    }

    /// Read-modify-write for small changes made from widget intents.
    func updateContent(_ change: (inout ContentState) -> Void) {
        var value = content
        change(&value)
        content = value
    }

    func design(id: UUID) -> WidgetDesign? {
        designs.first { $0.id == id }
    }
}

/// Photo backgrounds, stored downscaled in the shared container so widgets stay within their memory budget.
enum ImageStore {
    private static var directory: URL {
        let url = AppGroup.containerURL.appendingPathComponent("Tessera/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func save(_ image: UIImage, maxDimension: CGFloat = 900) -> String? {
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = resized.jpegData(compressionQuality: 0.82) else { return nil }
        let name = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: directory.appendingPathComponent(name), options: [.atomic])
            return name
        } catch {
            return nil
        }
    }

    static func image(named name: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(name).path)
    }

    static func delete(named name: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

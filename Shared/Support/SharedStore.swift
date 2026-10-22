import Foundation
import UIKit

/// Resolves the shared container used by the app and the widget extension.
enum AppGroup {
    /// Declared in Info.plist (set by the APP_GROUP_ID build setting) so the identifier lives in one place.
    static var declaredIdentifier: String {
        (Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String)?.trimmed.nonEmpty
            ?? "group.com.dakrsnyk.tessera"
    }

    /// The group actually granted to this install. Sideloading tools re-sign the app with a group
    /// of their own (their developer account can't use ours): it is read from the provisioning
    /// profile they embed, the same way in the app and in the widget extension.
    static let identifier: String = {
        let declared = declaredIdentifier
        let fileManager = FileManager.default
        if fileManager.containerURL(forSecurityApplicationGroupIdentifier: declared) != nil {
            return declared
        }
        var granted = ProvisioningProfile.appGroups()
        #if DEBUG
        granted = SignedEntitlements.appGroups + granted
        #endif
        let usable = granted.filter { fileManager.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil }
        return usable.first { $0.localizedCaseInsensitiveContains("tessera") } ?? usable.first ?? declared
    }()

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

/// Reads the provisioning profile embedded in the running bundle (the app, or the widget extension).
enum ProvisioningProfile {
    static func appGroups() -> [String] {
        guard let entitlements = entitlements() else { return [] }
        return entitlements["com.apple.security.application-groups"] as? [String] ?? []
    }

    static func entitlements() -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        return plist?[tr("Entitlements")] as? [String: Any]
    }
}

enum StoreFile: String {
    case designs, content, settings, premium, weather, crypto
    // Mini-apps (V2), one file each so a widget writing one domain never touches another.
    case nutrition, fitness, budget, business, portfolio, following, student, travel, car, productivity, life
    // « Mes informations »: what the user said about themselves.
    case profile
    // « Mes styles »: looks saved by the user to reuse on several widgets.
    case styles
    // Caches filled from the network.
    case markets, companies, fx, tripWeather, insights
}

/// A mini-app's saved data. Each type lives in its own file of the shared container.
protocol StoredState: Codable {
    static var file: StoreFile { get }
    init()
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
    /// Held from the read to the write of `update`: two buttons handled at the same time (a double tap
    /// on the Lock Screen) never both start from the same saved state. Recursive, so a change that
    /// itself updates the store can't block. It covers one process: the workout buttons all run in the
    /// app's (Live Activity intents). A lock between processes is left out: iOS ends an app suspended
    /// while it holds a file lock in the shared container.
    private let updateLock = NSRecursiveLock()

    /// Every file stays readable while the iPhone is locked (after its first unlock since it started):
    /// the buttons of the workout's Live Activity and of the widgets run on the Lock Screen.
    static let writingOptions: Data.WritingOptions = [.atomic, .completeFileProtectionUntilFirstUserAuthentication]

    init(directory: URL = AppGroup.containerURL.appendingPathComponent("Tessera", isDirectory: true)) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                 attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    }

    /// Files saved by an older version, or under a stricter default, become readable while the iPhone
    /// is locked. Called once the app is open (the iPhone is then unlocked).
    func relaxFileProtection() {
        lock.lock(); defer { lock.unlock() }
        let fileManager = FileManager.default
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        try? fileManager.setAttributes(attributes, ofItemAtPath: directory.path)
        for name in (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [] where name.hasSuffix(".json") {
            let path = directory.appendingPathComponent(name).path
            if (try? fileManager.attributesOfItem(atPath: path)[.protectionKey] as? FileProtectionType) != .completeUntilFirstUserAuthentication {
                try? fileManager.setAttributes(attributes, ofItemAtPath: path)
            }
        }
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
        try? data.write(to: url(file), options: Self.writingOptions)
    }

    /// Whether a file exists that can't be read or decoded right now (protected while the iPhone is
    /// locked, or damaged): a read-modify-write must then leave it alone rather than replace it.
    private func isUnreadable(_ file: StoreFile) -> Bool {
        let path = url(file)
        guard FileManager.default.fileExists(atPath: path.path) else { return false }
        return (try? Data(contentsOf: path)) == nil
    }

    func remove(_ file: StoreFile) {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: url(file))
    }

    /// The file as saved, untouched: what a backup carries.
    func rawData(_ file: StoreFile) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return try? Data(contentsOf: url(file))
    }

    /// Puts back a file from a backup; nil removes it.
    func setRawData(_ data: Data?, for file: StoreFile) {
        lock.lock(); defer { lock.unlock() }
        if let data {
            try? data.write(to: url(file), options: Self.writingOptions)
        } else {
            try? FileManager.default.removeItem(at: url(file))
        }
    }

    /// Whether the bytes read as a value of this type, the way the store reads its files.
    func decodes<T: Decodable>(_ type: T.Type, _ data: Data) -> Bool {
        (try? decoder.decode(T.self, from: data)) != nil
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
        updateLock.lock(); defer { updateLock.unlock() }
        guard !isUnreadable(.content) else { return }
        var value = content
        change(&value)
        content = value
    }

    func state<T: StoredState>(_ type: T.Type) -> T {
        read(T.self, from: T.file) ?? T()
    }

    func save<T: StoredState>(_ value: T) {
        write(value, to: T.file)
    }

    /// Read-modify-write of a mini-app's data (used by widget buttons and the app), atomic within the
    /// process (see `updateLock`). Returns false, and changes nothing, when the saved file can't be
    /// read: an empty state never replaces the person's data.
    @discardableResult
    func update<T: StoredState>(_ type: T.Type, _ change: (inout T) -> Void) -> Bool {
        updateLock.lock(); defer { updateLock.unlock() }
        guard !isUnreadable(T.file) else { return false }
        var value = state(T.self)
        change(&value)
        write(value, to: T.file)
        return true
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
            try data.write(to: directory.appendingPathComponent(name), options: SharedStore.writingOptions)
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

    /// The photos saved, for a backup.
    static func allNames() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).filter(isStoredName)
    }

    static func data(named name: String) -> Data? {
        guard isStoredName(name) else { return nil }
        return try? Data(contentsOf: directory.appendingPathComponent(name))
    }

    /// Puts back a photo from a backup, only under a name the store gives itself and only if it is an image.
    static func restore(_ data: Data, named name: String) {
        guard isStoredName(name), UIImage(data: data) != nil else { return }
        try? data.write(to: directory.appendingPathComponent(name), options: SharedStore.writingOptions)
    }

    /// The names `save` gives: a UUID and « .jpg ».
    static func isStoredName(_ name: String) -> Bool {
        name.hasSuffix(".jpg") && UUID(uuidString: String(name.dropLast(4))) != nil
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// A copy of everything the person entered, in one file they keep where they want (Files, iCloud
/// Drive, AirDrop…), that brings it all back on this iPhone or another one. Caches filled from the
/// network come back by themselves; premium status belongs to the App Store account.
enum DataBackup {
    struct Archive: Codable {
        /// The app's name when the backup was made (« Tessera » before it became Ardane).
        var app = "Ardane"
        var version = 1
        var date: Date
        /// The files of the store, as saved, by name.
        var files: [String: Data]
        /// The photos of widget backgrounds, by name.
        var images: [String: Data]
        /// The steps of the days already seen, by « yyyy-MM-dd ».
        var steps: [String: [Double]]?
    }

    enum Failure: Error {
        case notABackup, newerVersion, damaged(String)
    }

    /// The files that hold what the person entered.
    static let files: [StoreFile] = [
        .designs, .content, .settings, .nutrition, .fitness, .budget, .business, .portfolio, .following,
        .student, .travel, .car, .productivity, .life, .profile, .styles,
    ]

    static func make(store: SharedStore = .shared, now: Date = Date()) throws -> Data {
        var saved: [String: Data] = [:]
        for file in files {
            if let data = store.rawData(file) { saved[file.rawValue] = data }
        }
        var images: [String: Data] = [:]
        for name in ImageStore.allNames() {
            images[name] = ImageStore.data(named: name)
        }
        let steps = UserDefaults.standard.dictionary(forKey: StepCounter.historyKey) as? [String: [Double]]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Archive(date: now, files: saved, images: images, steps: steps))
    }

    /// Reads a backup and checks every file before anything is replaced: a damaged file changes nothing.
    static func read(_ data: Data, store: SharedStore = .shared) throws -> Archive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let archive = try? decoder.decode(Archive.self, from: data), ["Ardane", "Tessera"].contains(archive.app) else {
            throw Failure.notABackup
        }
        guard archive.version <= 1 else { throw Failure.newerVersion }
        for file in files {
            if let content = archive.files[file.rawValue], !decodes(file, content, store: store) {
                throw Failure.damaged(file.rawValue)
            }
        }
        return archive
    }

    /// Replaces the data of this iPhone by the backup's; a file the backup doesn't have is emptied.
    static func restore(_ archive: Archive, store: SharedStore = .shared) {
        for file in files {
            store.setRawData(archive.files[file.rawValue], for: file)
        }
        for (name, data) in archive.images {
            ImageStore.restore(data, named: name)
        }
        if let steps = archive.steps {
            UserDefaults.standard.set(steps, forKey: StepCounter.historyKey)
        }
    }

    /// « Ardane-sauvegarde-2026-10-08 ».
    static func fileName(_ date: Date) -> String {
        let c = DateMath.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "Ardane-%@-%04d-%02d-%02d", tr("sauvegarde"), c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func decodes(_ file: StoreFile, _ data: Data, store: SharedStore) -> Bool {
        switch file {
        case .designs: store.decodes([WidgetDesign].self, data)
        case .content: store.decodes(ContentState.self, data)
        case .settings: store.decodes(AppSettings.self, data)
        case .nutrition: store.decodes(NutritionState.self, data)
        case .fitness: store.decodes(FitnessState.self, data)
        case .budget: store.decodes(BudgetState.self, data)
        case .business: store.decodes(BusinessState.self, data)
        case .portfolio: store.decodes(PortfolioState.self, data)
        case .following: store.decodes(MarketsState.self, data)
        case .student: store.decodes(StudentState.self, data)
        case .travel: store.decodes(TravelState.self, data)
        case .car: store.decodes(CarState.self, data)
        case .productivity: store.decodes(ProductivityState.self, data)
        case .life: store.decodes(LifeState.self, data)
        case .profile: store.decodes(UserProfile.self, data)
        case .styles: store.decodes(StyleLibrary.self, data)
        default: false
        }
    }
}

/// The backup as a file the system saves where the person chooses.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

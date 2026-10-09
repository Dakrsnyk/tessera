import XCTest
@testable import Tessera

/// The backup: one file that brings back everything entered, and that changes nothing when it isn't
/// a backup or is damaged.
@MainActor
final class DataBackupTests: XCTestCase {
    private func temporaryStore() -> SharedStore {
        SharedStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true))
    }

    private func encoded(_ archive: DataBackup.Archive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    /// Everything entered comes back on another iPhone, as it was; what the backup doesn't have is emptied.
    func testABackupBringsEverythingBack() throws {
        let source = temporaryStore()
        var content = ContentState()
        content.tasks = [TaskItem(title: "Réviser", priority: .high)]
        source.content = content
        var student = StudentState()
        student.slots = [ClassSlot(courseID: nil, weekday: 2, startMinute: 600, endMinute: 660, kind: .work, title: "Boulot")]
        source.save(student)
        var settings = AppSettings()
        settings.profileName = "Alex"
        source.settings = settings
        let data = try DataBackup.make(store: source)

        let target = temporaryStore()
        var car = CarState()
        car.name = "Ancienne"
        target.save(car)
        let archive = try DataBackup.read(data, store: target)
        DataBackup.restore(archive, store: target)
        XCTAssertEqual(target.content.tasks.map(\.title), ["Réviser"])
        XCTAssertEqual(target.state(StudentState.self).slots.first?.title, "Boulot")
        XCTAssertEqual(target.state(StudentState.self).slots.first?.kind, .work)
        XCTAssertEqual(target.settings.profileName, "Alex")
        XCTAssertNil(target.rawData(.car), "A file missing from the backup isn't kept from before")
    }

    /// A file that isn't a backup, a damaged one or one from a newer version changes nothing.
    func testADamagedBackupIsRefused() throws {
        let store = temporaryStore()
        XCTAssertThrowsError(try DataBackup.read(Data("{}".utf8), store: store))
        XCTAssertThrowsError(try DataBackup.read(Data("pas du json".utf8), store: store))
        let damaged = DataBackup.Archive(date: Date(), files: ["content": Data("[1, 2]".utf8)], images: [:], steps: nil)
        XCTAssertThrowsError(try DataBackup.read(encoded(damaged), store: store))
        var newer = DataBackup.Archive(date: Date(), files: [:], images: [:], steps: nil)
        newer.version = 2
        XCTAssertThrowsError(try DataBackup.read(encoded(newer), store: store))
    }

    /// Photos come back only under the names the photo store gives itself.
    func testOnlyNamesOfThePhotoStoreAreAccepted() {
        XCTAssertTrue(ImageStore.isStoredName("\(UUID().uuidString).jpg"))
        XCTAssertFalse(ImageStore.isStoredName("../settings.json"))
        XCTAssertFalse(ImageStore.isStoredName("photo.png"))
    }
}

import UIKit
import XCTest
@testable import Ardane

/// After a restoration, the photos that neither the backup nor the restored widgets hold are deleted; a refused
/// backup deletes nothing.
final class BackupOrphanPhotosTests: XCTestCase {
    private func temporaryStore() -> SharedStore {
        SharedStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true))
    }

    private func savedPhotoName() throws -> String {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        return try XCTUnwrap(ImageStore.save(image))
    }

    private func archive(files: [String: Data] = [:], images: [String: Data]) -> DataBackup.Archive {
        DataBackup.Archive(date: Date(), files: files, images: images, steps: nil)
    }

    /// A photo of this iPhone absent from the backup goes; the backup's photo and the one a restored widget holds stay.
    func testRestoreDeletesOnlyTheOrphanPhotos() throws {
        let orphan = try savedPhotoName()
        let inBackup = try savedPhotoName()
        let heldByWidget = try savedPhotoName()
        defer { for name in [orphan, inBackup, heldByWidget] { ImageStore.delete(named: name) } }

        let backupData = try XCTUnwrap(ImageStore.data(named: inBackup))
        // The backup's widgets: one holds a photo that the backup's images don't carry.
        let source = temporaryStore()
        source.designs = [WidgetDesign(kind: .caloriesLeft, background: .photo(heldByWidget), format: .small)]
        let files = ["designs": try XCTUnwrap(source.rawData(.designs))]

        let target = temporaryStore()
        DataBackup.restore(archive(files: files, images: [inBackup: backupData]), store: target)

        XCTAssertNil(ImageStore.data(named: orphan), "a photo neither in the backup nor held by a widget is deleted")
        XCTAssertNotNil(ImageStore.data(named: inBackup))
        XCTAssertNotNil(ImageStore.data(named: heldByWidget))
    }

    /// A backup that is refused never reaches `restore`: nothing is deleted.
    func testARefusedBackupDeletesNothing() throws {
        let existing = try savedPhotoName()
        defer { ImageStore.delete(named: existing) }
        let store = temporaryStore()
        XCTAssertThrowsError(try DataBackup.read(Data("pas une sauvegarde".utf8), store: store))
        let damaged = archive(files: ["content": Data("[1, 2]".utf8)], images: [:])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        XCTAssertThrowsError(try DataBackup.read(try encoder.encode(damaged), store: store))
        XCTAssertNotNil(ImageStore.data(named: existing))
    }

    /// A name the photo store doesn't give itself is never written, and the cleanup stays inside the store.
    func testAForeignNameIsNotRestored() throws {
        let existing = try savedPhotoName()
        defer { ImageStore.delete(named: existing) }
        let data = try XCTUnwrap(ImageStore.data(named: existing))
        DataBackup.restore(archive(images: ["../escape.jpg": data]), store: temporaryStore())
        XCTAssertNil(ImageStore.data(named: "../escape.jpg"))
        // Nothing was written outside the photo folder either (« ../escape.jpg » from it is this file).
        let outside = AppGroup.containerURL.appendingPathComponent("Tessera/escape.jpg")
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.path), "Une photo a été écrite hors du dossier des photos")
    }
}

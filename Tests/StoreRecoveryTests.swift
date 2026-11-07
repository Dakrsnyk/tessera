import XCTest
@testable import Ardane

/// A data file that can't be read in full is copied to `Recovery/` when it is read, before any save can
/// replace it; a list with one unreadable element keeps the others.
final class StoreRecoveryTests: XCTestCase {
    private struct Entry: Codable, Equatable {
        var id: Int
        var name: String
    }

    private struct Holder: StoredState, Equatable {
        static let file = StoreFile.productivity
        var entries: [Entry] = []

        init() {}

        enum CodingKeys: String, CodingKey { case entries }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            entries = c.value(.entries, [])
        }
    }

    private let threeEntriesOneBroken = Data(#"{"entries":[{"id":1,"name":"a"},{"id":2},{"id":3,"name":"c"}]}"#.utf8)

    private func makeStore() -> (store: SharedStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (SharedStore(directory: directory), directory)
    }

    private func copies(in directory: URL) -> [URL] {
        let folder = directory.appendingPathComponent("Recovery", isDirectory: true)
        return ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }
    }

    func testAListWithOneUnreadableElementKeepsTheOthersAndReportsTheLoss() throws {
        _ = LossyDecoding.takeLosses()
        let holder = try JSONDecoder().decode(Holder.self, from: threeEntriesOneBroken)
        XCTAssertEqual(holder.entries.map(\.id), [1, 3])
        XCTAssertEqual(LossyDecoding.takeLosses(), 1)
    }

    func testAHealthyListReportsNoLoss() throws {
        _ = LossyDecoding.takeLosses()
        let data = Data(#"{"entries":[{"id":1,"name":"a"}]}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(Holder.self, from: data).entries.count, 1)
        XCTAssertEqual(LossyDecoding.takeLosses(), 0)
    }

    func testAFileReadWithALossIsCopiedByteForByte() {
        let (store, directory) = makeStore()
        store.setRawData(threeEntriesOneBroken, for: .productivity)
        XCTAssertEqual(store.state(Holder.self).entries.count, 2)
        let found = copies(in: directory)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first.flatMap { try? Data(contentsOf: $0) }, threeEntriesOneBroken)
    }

    func testACorruptFileIsCopiedAndASaveAfterwardsKeepsTheCopy() {
        let (store, directory) = makeStore()
        let corrupt = Data("{ this is not json".utf8)
        store.setRawData(corrupt, for: .productivity)
        XCTAssertNil(store.read(Holder.self, from: .productivity))
        let found = copies(in: directory)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first.flatMap { try? Data(contentsOf: $0) }, corrupt)

        var fresh = Holder()
        fresh.entries = [Entry(id: 9, name: "new")]
        store.save(fresh)
        XCTAssertEqual(store.state(Holder.self), fresh)
        XCTAssertEqual(copies(in: directory).count, 1)
        XCTAssertEqual(copies(in: directory).first.flatMap { try? Data(contentsOf: $0) }, corrupt)
    }

    func testAMissingFileCreatesNoCopy() {
        let (store, directory) = makeStore()
        XCTAssertNil(store.read(Holder.self, from: .productivity))
        XCTAssertEqual(store.state(Holder.self), Holder())
        XCTAssertTrue(copies(in: directory).isEmpty)
    }

    func testReadingTheSameCorruptFileTwiceCreatesOneCopy() {
        let (store, directory) = makeStore()
        store.setRawData(Data("garbage".utf8), for: .productivity)
        _ = store.read(Holder.self, from: .productivity)
        _ = store.read(Holder.self, from: .productivity)
        XCTAssertEqual(copies(in: directory).count, 1)
    }

    func testOnlyTheFiveLatestCopiesOfAFileAreKept() {
        let (store, directory) = makeStore()
        for index in 0..<6 {
            store.setRawData(Data("garbage \(index)".utf8), for: .productivity)
            _ = store.read(Holder.self, from: .productivity)
        }
        XCTAssertEqual(copies(in: directory).count, 5)
    }

    func testAHealthyStateReadModifiedAndSavedCreatesNoCopy() {
        let (store, directory) = makeStore()
        var holder = Holder()
        holder.entries = [Entry(id: 1, name: "a")]
        store.save(holder)
        XCTAssertEqual(store.state(Holder.self), holder)
        store.update(Holder.self) { $0.entries.append(Entry(id: 2, name: "b")) }
        XCTAssertEqual(store.state(Holder.self).entries.count, 2)
        XCTAssertTrue(copies(in: directory).isEmpty)
    }
}

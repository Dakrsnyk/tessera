import XCTest
@testable import Ardane

/// Two writers of the same file (the app and a widget button, or a double tap on the Lock Screen): each
/// read-modify-write of `SharedStore.update` starts from the state the other one saved, so no change is lost.
final class SharedStoreConcurrencyTests: XCTestCase {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    func testManyUpdatesAtTheSameTimeAllLandInTheSavedState() {
        let store = SharedStore(directory: temporaryDirectory())
        let count = 100
        DispatchQueue.concurrentPerform(iterations: count) { index in
            store.update(BudgetState.self) { $0.expenses.append(Expense(amount: Double(index + 1))) }
        }
        let saved = store.state(BudgetState.self)
        XCTAssertEqual(saved.expenses.count, count, "A change must never start from a state the other one has not saved yet")
        XCTAssertEqual(Set(saved.expenses.map(\.amount)).count, count, "Each of the hundred changes is there once")
        XCTAssertEqual(saved.expenses.reduce(0) { $0 + $1.amount }, Double(count * (count + 1) / 2))
    }

    func testAContentUpdateAndAMiniAppUpdateDoNotEraseEachOther() {
        let store = SharedStore(directory: temporaryDirectory())
        let count = 60
        DispatchQueue.concurrentPerform(iterations: count) { index in
            if index.isMultiple(of: 2) {
                store.update(NutritionState.self) { $0.goals.kcal = Double(1_000 + index) }
            } else {
                store.update(BudgetState.self) { $0.expenses.append(Expense(amount: 1)) }
            }
        }
        XCTAssertEqual(store.state(BudgetState.self).expenses.count, count / 2, "The budget keeps its thirty changes")
        let kcal = store.state(NutritionState.self).goals.kcal
        XCTAssertTrue(stride(from: 1_000, to: 1_000 + count, by: 2).contains(Int(kcal)), "The nutrition file holds one of the values written, not a mix")
    }

    func testTwoStoresOnTheSameFolderReadWhatTheOtherSaved() {
        let directory = temporaryDirectory()
        let app = SharedStore(directory: directory)
        let widget = SharedStore(directory: directory)
        app.save(BudgetState())
        XCTAssertTrue(widget.update(BudgetState.self) { $0.expenses.append(Expense(amount: 12)) })
        XCTAssertEqual(app.state(BudgetState.self).expenses.map(\.amount), [12], "The app sees the change of the widget on its next read")
    }

    func testAnUpdateNeverReplacesAFileItCannotReadAndTheOtherFilesStayUsable() throws {
        let directory = temporaryDirectory()
        let store = SharedStore(directory: directory)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("budget.json", isDirectory: true), withIntermediateDirectories: true)
        DispatchQueue.concurrentPerform(iterations: 20) { _ in
            XCTAssertFalse(store.update(BudgetState.self) { $0.expenses.append(Expense(amount: 1)) })
        }
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("budget.json").path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue, "Nothing replaced the unreadable file")
        XCTAssertTrue(store.update(CarState.self) { _ in })
    }

    /// `isUnreadable` is documented as « can't be read or decoded (protected while the iPhone is locked, or damaged) »:
    /// a damaged file (bytes that are not JSON) must be left as it is, not replaced by a default state with one change.
    func testAnUpdateLeavesADamagedFileAsItIs() throws {
        let directory = temporaryDirectory()
        let store = SharedStore(directory: directory)
        let file = directory.appendingPathComponent("budget.json")
        let damaged = Data("{ \"expenses\": [ {\"amount\": 12, ".utf8)
        try damaged.write(to: file)

        let changed = store.update(BudgetState.self) { $0.expenses.append(Expense(amount: 1)) }

        XCTAssertFalse(changed, "A file that cannot be decoded is refused, like one that cannot be read")
        XCTAssertEqual(try Data(contentsOf: file), damaged, "The damaged bytes are still there for a repair or a backup")
    }
}

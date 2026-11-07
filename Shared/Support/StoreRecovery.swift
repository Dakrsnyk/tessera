import Foundation
import CryptoKit

/// Counts the elements a tolerant decoding had to leave out (see `value(_:_:)` for arrays), so the store
/// can keep a copy of the file before anything overwrites it. The counter is global and guarded by a lock:
/// a loss noted by another decoding running at the same time only costs one extra backup copy.
enum LossyDecoding {
    private static let lock = NSLock()
    private static var losses = 0

    static func noteLoss() {
        lock.lock(); defer { lock.unlock() }
        losses += 1
    }

    /// The losses noted since the last call; the counter starts again from zero.
    static func takeLosses() -> Int {
        lock.lock(); defer { lock.unlock() }
        defer { losses = 0 }
        return losses
    }
}

/// Copies of data files that could not be read in full, kept in `<store folder>/Recovery`.
enum StoreRecovery {
    static let folderName = "Recovery"
    static let keptPerFile = 5

    /// Copies the exact bytes of a damaged file, once per distinct content (the name carries a short
    /// SHA-256 of the bytes, so the app and the widgets reading the same file add nothing), and keeps
    /// the most recent `keptPerFile` copies of each file. Best effort: a failure here never blocks a read.
    static func keepCopy(of data: Data, named name: String, in directory: URL) {
        let fileManager = FileManager.default
        let folder = directory.appendingPathComponent(folderName, isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true,
                                         attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined().prefix(12)
        let copy = folder.appendingPathComponent("\(name)-\(digest).json")
        guard !fileManager.fileExists(atPath: copy.path) else { return }
        do {
            try data.write(to: copy, options: SharedStore.writingOptions)
        } catch {
            return
        }
        prune(name: name, keeping: copy, in: folder)
    }

    /// Removes the oldest copies of one file beyond the limit; the copy just made always stays.
    private static func prune(name: String, keeping current: URL, in folder: URL) {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let all = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)) ?? []
        let others = all.filter {
            $0.lastPathComponent.hasPrefix("\(name)-") && $0.pathExtension == "json" && $0.lastPathComponent != current.lastPathComponent
        }
        guard others.count > keptPerFile - 1 else { return }
        func date(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
        }
        let oldestFirst = others.sorted { date($0) < date($1) }
        for url in oldestFirst.prefix(others.count - (keptPerFile - 1)) {
            try? fileManager.removeItem(at: url)
        }
    }
}

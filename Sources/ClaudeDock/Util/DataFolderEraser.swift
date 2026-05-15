import Foundation

enum DataFolderEraser {
    enum EraserError: Swift.Error, Equatable {
        case forbiddenPath(String)
    }

    /// Removes the target directory recursively. Refuses to delete anything
    /// whose path contains a `.claude` segment so we cannot, even by accident,
    /// destroy the user's Claude Code installation.
    static func erase(at url: URL) throws {
        let path = url.path
        let segments = url.pathComponents
        if segments.contains(".claude") {
            throw EraserError.forbiddenPath(path)
        }
        let fm = FileManager.default
        if fm.fileExists(atPath: path) {
            try fm.removeItem(at: url)
        }
        // missing → no-op
    }
}

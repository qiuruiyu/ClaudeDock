import Foundation
import Testing
@testable import ClaudeDock

@Suite struct DataFolderEraserTests {
    @Test func erasesGivenFolderRecursively() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("er-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let nested = root.appendingPathComponent("a/b/c", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "x".data(using: .utf8)!.write(to: nested.appendingPathComponent("file.txt"))

        try DataFolderEraser.erase(at: root)
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test func refusesToEraseSettingsJsonAdjacentFolders() throws {
        let claudeDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(".claude-fake-\(UUID())", isDirectory: true)
        // Note: pathComponents segments split on `/`, so a folder whose NAME
        // contains ".claude" as a substring is NOT a `.claude` segment. We
        // want to test against a real `.claude` SEGMENT, not just a name.
        // Adjust: create a path with an actual `.claude` segment.
        let realClaudeSegment = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test-root-\(UUID())", isDirectory: true)
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("subdir", isDirectory: true)
        try FileManager.default.createDirectory(at: realClaudeSegment, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: realClaudeSegment.deletingLastPathComponent().deletingLastPathComponent()) }

        #expect(throws: DataFolderEraser.EraserError.self) {
            try DataFolderEraser.erase(at: realClaudeSegment)
        }
        // The original claudeDir variable is unused in this hardened version
        _ = claudeDir
    }

    @Test func missingPathIsNoOp() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("does-not-exist-\(UUID())")
        try DataFolderEraser.erase(at: url)   // must not throw
    }
}

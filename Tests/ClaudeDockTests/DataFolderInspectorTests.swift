import Foundation
import Testing
@testable import ClaudeDock

@Suite struct DataFolderInspectorTests {
    private func makeTmp() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dfi-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func inspectorReportsFileAndDirSizes() throws {
        let root = try makeTmp()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data(repeating: 0x41, count: 10).write(to: root.appendingPathComponent("a.json"))
        let logs = root.appendingPathComponent("logs", isDirectory: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        try Data(repeating: 0x42, count: 10).write(to: logs.appendingPathComponent("a.log"))
        try Data(repeating: 0x42, count: 20).write(to: logs.appendingPathComponent("b.log"))

        let entries = try DataFolderInspector.inspect(at: root, maxDepth: 1)

        let byPath = Dictionary(uniqueKeysWithValues: entries.map { ($0.relativePath, $0) })
        #expect(byPath["a.json"]?.byteSize == 10)
        #expect(byPath["a.json"]?.kind == .file)
        #expect(byPath["logs"]?.byteSize == 30)
        #expect(byPath["logs"]?.kind == .directory)
    }

    @Test func emptyDirectoryReportsZeroSize() throws {
        let root = try makeTmp()
        defer { try? FileManager.default.removeItem(at: root) }
        let backups = root.appendingPathComponent("backups", isDirectory: true)
        try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)

        let entries = try DataFolderInspector.inspect(at: root, maxDepth: 1)
        #expect(entries.contains(where: { $0.relativePath == "backups" && $0.byteSize == 0 }))
    }

    @Test func missingRootReturnsEmptyArray() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("does-not-exist-\(UUID())")
        let entries = try DataFolderInspector.inspect(at: root, maxDepth: 1)
        #expect(entries.isEmpty)
    }
}

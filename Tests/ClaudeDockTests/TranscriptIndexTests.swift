import Foundation
import Testing
@testable import ClaudeDock

@Suite struct TranscriptIndexTests {
    private func makeTempRoot() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("transcript-idx-" + UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeTranscript(_ jsonl: String,
                                 to root: URL,
                                 subdir: String,
                                 sessionId: String,
                                 mtime: Date? = nil) -> URL {
        let dir = root.appendingPathComponent(subdir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(sessionId).jsonl")
        try? jsonl.write(to: file, atomically: true, encoding: .utf8)
        if let mtime {
            try? FileManager.default.setAttributes([.modificationDate: mtime],
                                                  ofItemAtPath: file.path)
        }
        return file
    }

    @Test func emptyRootReturnsEmptyIndex() {
        let root = makeTempRoot()
        let idx = TranscriptIndex.build(at: root)
        #expect(idx.entries.isEmpty)
    }

    @Test func missingRootReturnsEmptyIndex() {
        let nonexistent = URL(fileURLWithPath: "/tmp/definitely-does-not-exist-\(UUID().uuidString)")
        let idx = TranscriptIndex.build(at: nonexistent)
        #expect(idx.entries.isEmpty)
    }

    @Test func skipsUnparseableJsonl() {
        let root = makeTempRoot()
        _ = writeTranscript("not-valid-json\n", to: root, subdir: "x", sessionId: "bad")
        let idx = TranscriptIndex.build(at: root)
        #expect(idx.entries.isEmpty)
    }

    @Test func indexesValidJsonlByCwd() {
        let root = makeTempRoot()
        let cwd = "/Users/test/repo1"
        let line = #"{"type":"summary","cwd":"\#(cwd)","sessionId":"s-1"}"#
        _ = writeTranscript(line + "\n", to: root, subdir: "encoded-cwd", sessionId: "s-1")
        let idx = TranscriptIndex.build(at: root)
        #expect(idx.entries.count == 1)
        #expect(idx.entries[0].cwd == cwd)
        #expect(idx.entries[0].sessionId == "s-1")
    }

    @Test func transcriptForCwdPicksMostRecent() {
        let root = makeTempRoot()
        let cwd = "/Users/test/repo2"
        let line = #"{"cwd":"\#(cwd)"}"#
        _ = writeTranscript(line + "\n", to: root, subdir: "a", sessionId: "old",
                           mtime: Date(timeIntervalSince1970: 1000))
        _ = writeTranscript(line + "\n", to: root, subdir: "a", sessionId: "new",
                           mtime: Date(timeIntervalSince1970: 2000))
        let idx = TranscriptIndex.build(at: root)
        let pick = idx.transcript(forCwd: cwd)
        #expect(pick?.sessionId == "new")
    }

    @Test func transcriptForCwdReturnsNilForUnknownCwd() {
        let root = makeTempRoot()
        let line = #"{"cwd":"/x"}"#
        _ = writeTranscript(line + "\n", to: root, subdir: "x", sessionId: "s")
        let idx = TranscriptIndex.build(at: root)
        #expect(idx.transcript(forCwd: "/not/indexed") == nil)
    }
}

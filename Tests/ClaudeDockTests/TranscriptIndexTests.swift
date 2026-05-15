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

    // MARK: - encodeProjectsDirName

    @Test func encodingMirrorsClaudeCodeRules() {
        // ASCII letters/digits/hyphen passthrough; everything else → "-"
        #expect(TranscriptIndex.encodeProjectsDirName(for: "/Users/joe/repo")
                == "-Users-joe-repo")
        #expect(TranscriptIndex.encodeProjectsDirName(for: "/Users/joe/Claude_Chat/ClaudeDock")
                == "-Users-joe-Claude-Chat-ClaudeDock")
        // Consecutive non-ASCII → consecutive dashes (no collapsing).
        // Chinese characters in real user paths (zjuthesis case).
        // /a/个人/b → leading slash (1 dash), `a`, slash (1 dash), `个`
        // (1 dash), `人` (1 dash), slash (1 dash), `b` = 4 dashes between
        // `a` and `b`.
        #expect(TranscriptIndex.encodeProjectsDirName(for: "/a/个人/b")
                == "-a----b")
        // Existing hyphens are preserved
        #expect(TranscriptIndex.encodeProjectsDirName(for: "/a/b-c-d/e")
                == "-a-b-c-d-e")
    }

    // MARK: - transcript(forCwd:) — happy path (encoded-dir lookup)

    @Test func findsTranscriptInEncodedSubdir() {
        let root = makeTempRoot()
        let cwd = "/Users/test/repo1"
        let encoded = TranscriptIndex.encodeProjectsDirName(for: cwd)
        let line = #"{"type":"summary","cwd":"\#(cwd)","sessionId":"s-1"}"#
        _ = writeTranscript(line + "\n", to: root, subdir: encoded, sessionId: "s-1")
        let idx = TranscriptIndex.build(at: root)
        let ref = idx.transcript(forCwd: cwd)
        #expect(ref?.sessionId == "s-1")
        #expect(ref?.cwd == cwd)
    }

    @Test func returnsNilWhenSubdirMissing() {
        let root = makeTempRoot()
        let idx = TranscriptIndex.build(at: root)
        #expect(idx.transcript(forCwd: "/never/seen") == nil)
    }

    @Test func returnsNilForMalformedJsonl() {
        let root = makeTempRoot()
        let cwd = "/Users/test/bad"
        let encoded = TranscriptIndex.encodeProjectsDirName(for: cwd)
        _ = writeTranscript("not-valid-json\n", to: root, subdir: encoded, sessionId: "bad")
        let idx = TranscriptIndex.build(at: root)
        #expect(idx.transcript(forCwd: cwd) == nil)
    }

    @Test func picksMostRecentlyModifiedTranscript() {
        let root = makeTempRoot()
        let cwd = "/Users/test/repo2"
        let encoded = TranscriptIndex.encodeProjectsDirName(for: cwd)
        let line = #"{"cwd":"\#(cwd)"}"#
        _ = writeTranscript(line + "\n", to: root, subdir: encoded, sessionId: "old",
                           mtime: Date(timeIntervalSince1970: 1000))
        _ = writeTranscript(line + "\n", to: root, subdir: encoded, sessionId: "new",
                           mtime: Date(timeIntervalSince1970: 2000))
        let idx = TranscriptIndex.build(at: root)
        #expect(idx.transcript(forCwd: cwd)?.sessionId == "new")
    }

    @Test func ignoresTranscriptInWrongSubdirByCwdField() {
        // A transcript exists in some unrelated subdir but its stored
        // cwd matches what we're looking for. We should NOT find it via
        // the encoded-dir path (subdir name doesn't match), but the
        // fallback scan should pick it up.
        let root = makeTempRoot()
        let cwd = "/Users/test/wandering"
        let line = #"{"cwd":"\#(cwd)"}"#
        _ = writeTranscript(line + "\n", to: root,
                           subdir: "completely-unrelated-encoded-name",
                           sessionId: "wander")
        let idx = TranscriptIndex.build(at: root)
        #expect(idx.transcript(forCwd: cwd)?.sessionId == "wander",
                "Fallback scan should find it even when encoded-dir lookup misses")
    }

    // MARK: - real Claude Code transcript shape

    @Test func findsCwdEvenWhenMetadataEntriesComeFirst() {
        // Real Claude Code JSONLs lead with metadata entries that have
        // NO top-level cwd (last-prompt, permission-mode, file-history-
        // snapshot, etc.). The cwd appears later, in entries like
        // `attachment` or `user`. Reading only the first line returns
        // nil — which is the iter-069 follow-on bug that hid the user's
        // Ghostty/zjuthesis sessions.
        let root = makeTempRoot()
        let cwd = "/Users/test/realistic"
        let encoded = TranscriptIndex.encodeProjectsDirName(for: cwd)
        let lines = [
            #"{"type":"last-prompt","prompt":"hi"}"#,
            #"{"type":"permission-mode","permissionMode":"auto"}"#,
            #"{"type":"file-history-snapshot","messageId":"abc","snapshot":{"trackedFileBackups":{}}}"#,
            // First line with top-level cwd:
            #"{"type":"attachment","cwd":"\#(cwd)","userType":"external"}"#,
            // Later lines also have cwd:
            #"{"type":"user","cwd":"\#(cwd)","message":{"role":"user","content":"hi"}}"#,
        ]
        _ = writeTranscript(lines.joined(separator: "\n") + "\n",
                           to: root, subdir: encoded, sessionId: "real")
        let idx = TranscriptIndex.build(at: root)
        let ref = idx.transcript(forCwd: cwd)
        #expect(ref?.sessionId == "real")
        #expect(ref?.cwd == cwd)
    }

    // MARK: - scale: lots of unrelated transcripts

    @Test func unaffectedByManyUnrelatedTranscripts() {
        // Regression for the iter-062 cap bug: with 500+ unrelated
        // transcripts present, looking up a specific CWD still works
        // and is fast (encoded-dir path bypasses the others entirely).
        let root = makeTempRoot()
        let cwd = "/Users/test/needle"
        let encoded = TranscriptIndex.encodeProjectsDirName(for: cwd)
        let line = #"{"cwd":"\#(cwd)"}"#
        _ = writeTranscript(line + "\n", to: root, subdir: encoded, sessionId: "needle")
        // Pile of unrelated transcripts
        for i in 0..<300 {
            let dummy = #"{"cwd":"/x/\#(i)"}"#
            _ = writeTranscript(dummy + "\n",
                                to: root, subdir: "noise-\(i)", sessionId: "n-\(i)")
        }
        let idx = TranscriptIndex.build(at: root)
        #expect(idx.transcript(forCwd: cwd)?.sessionId == "needle",
                "Encoded-dir lookup should find the needle even among 300 unrelated transcripts")
    }
}

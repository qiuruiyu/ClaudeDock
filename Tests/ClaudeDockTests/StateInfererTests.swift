import Foundation
import Testing
@testable import ClaudeDock

@Suite struct StateInfererTests {
    private func writeJsonl(_ lines: [String]) -> URL {
        let file = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("inferer-" + UUID().uuidString + ".jsonl")
        try? lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test func emptyFileReturnsStarting() {
        let file = writeJsonl([])
        #expect(StateInferer.inferStatus(fromJsonlAt: file) == .starting)
    }

    @Test func missingFileReturnsStarting() {
        let bogus = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).jsonl")
        #expect(StateInferer.inferStatus(fromJsonlAt: bogus) == .starting)
    }

    @Test func lastLineIsAssistantReturnsIdle() {
        let file = writeJsonl([
            #"{"type":"user","message":{"role":"user","content":"hi"}}"#,
            #"{"type":"assistant","message":{"role":"assistant","content":"hello"}}"#,
        ])
        #expect(StateInferer.inferStatus(fromJsonlAt: file) == .idle)
    }

    @Test func lastLineIsUserReturnsThinking() {
        let file = writeJsonl([
            #"{"type":"assistant","message":{"role":"assistant","content":"yes"}}"#,
            #"{"type":"user","message":{"role":"user","content":"thanks"}}"#,
        ])
        #expect(StateInferer.inferStatus(fromJsonlAt: file) == .thinking)
    }

    @Test func unparseableLastLineReturnsStarting() {
        let file = writeJsonl([
            #"{"type":"assistant"}"#,
            "this-is-not-json",
        ])
        #expect(StateInferer.inferStatus(fromJsonlAt: file) == .starting)
    }

    @Test func nestedRoleInMessageStillWorks() {
        // Some Claude Code entries have `message.role` instead of top-level `type`.
        let file = writeJsonl([
            #"{"message":{"role":"assistant","content":"done"}}"#,
        ])
        #expect(StateInferer.inferStatus(fromJsonlAt: file) == .idle)
    }
}

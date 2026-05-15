import Foundation
import Testing
@testable import ClaudeDock

@Suite struct HookEventTests {
    @Test func decodeSessionStart() throws {
        let json = """
        {
          "session_id": "abc-123",
          "cwd": "/Users/joe/code/myproj",
          "hook_event_name": "SessionStart",
          "transcript_path": "/Users/joe/.claude/projects/myproj/abc-123.jsonl"
        }
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        #expect(event.sessionId == "abc-123")
        #expect(event.cwd == "/Users/joe/code/myproj")
        #expect(event.hookEventName == .sessionStart)
        #expect(event.transcriptPath == "/Users/joe/.claude/projects/myproj/abc-123.jsonl")
    }
}

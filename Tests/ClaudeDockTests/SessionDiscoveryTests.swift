import Foundation
import Testing
@testable import ClaudeDock

/// Returns a fixed list of ClaudeProcess records; ignores any system state.
struct StaticEnumerator: ProcessEnumerating {
    let procs: [ClaudeProcess]
    func enumerateClaudeProcesses() throws -> [ClaudeProcess] { procs }
}

@Suite struct SessionDiscoveryTests {
    private func makeProjectsRoot() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("discovery-" + UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeTranscript(in root: URL, subdir: String, sessionId: String,
                                 cwd: String, lines: [String] = []) -> URL {
        let dir = root.appendingPathComponent(subdir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(sessionId).jsonl")
        var body = [#"{"type":"summary","cwd":"\#(cwd)","sessionId":"\#(sessionId)"}"#]
        body.append(contentsOf: lines)
        try? body.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test func discoverEmptyWhenNoProcesses() throws {
        let root = makeProjectsRoot()
        let d = SessionDiscovery(enumerator: StaticEnumerator(procs: []), projectsRoot: root)
        #expect(try d.discover().isEmpty)
    }

    @Test func discoverSkipsProcessWithoutMatchingTranscript() throws {
        let root = makeProjectsRoot()
        // Transcript exists but for a different cwd.
        _ = writeTranscript(in: root, subdir: "elsewhere", sessionId: "other",
                           cwd: "/Users/test/other-repo")
        let p = ClaudeProcess(pid: 100, cwd: "/Users/test/missing", tty: "/dev/ttys001",
                              termProgram: nil, vscodePid: nil, iTermSessionId: nil, termSessionId: nil)
        let d = SessionDiscovery(enumerator: StaticEnumerator(procs: [p]), projectsRoot: root)
        #expect(try d.discover().isEmpty)
    }

    @Test func discoverSynthesizesIdentityWithClaudePidAsPpid() throws {
        let root = makeProjectsRoot()
        let cwd = "/Users/test/repo1"
        _ = writeTranscript(in: root, subdir: "repo1-encoded", sessionId: "session-abc",
                           cwd: cwd,
                           lines: [#"{"type":"assistant","message":{"role":"assistant","content":"ok"}}"#])
        let p = ClaudeProcess(pid: 555, cwd: cwd, tty: "/dev/ttys001",
                              termProgram: nil, vscodePid: nil, iTermSessionId: nil, termSessionId: nil)
        let d = SessionDiscovery(enumerator: StaticEnumerator(procs: [p]), projectsRoot: root)
        let results = try d.discover()
        #expect(results.count == 1)
        let expected = SessionIdentity.synthesize(sessionId: "session-abc",
                                                  cwd: cwd,
                                                  ppid: 555,
                                                  tty: "/dev/ttys001")
        #expect(results[0].identity.fingerprint == expected.fingerprint)
        #expect(results[0].identity.workKey == expected.workKey)
        #expect(results[0].status == .idle)
    }

    @Test func fingerprintMatchesEventualHookEventIdentity() throws {
        // The core merge guarantee: a discovered session's identity MUST
        // match the identity that SessionStore.ingest will synthesize from
        // the next hook event.
        let root = makeProjectsRoot()
        let cwd = "/Users/test/repo2"
        _ = writeTranscript(in: root, subdir: "repo2-encoded", sessionId: "s-42",
                           cwd: cwd)
        let p = ClaudeProcess(pid: 7777, cwd: cwd, tty: "/dev/ttys009",
                              termProgram: nil, vscodePid: nil, iTermSessionId: nil, termSessionId: nil)
        let d = SessionDiscovery(enumerator: StaticEnumerator(procs: [p]), projectsRoot: root)
        let discovered = try d.discover()
        #expect(discovered.count == 1)

        // Simulate the hook arriving later: HookServer parses session_id from
        // the body and ppid/tty from the URL query. SessionStore.ingest then
        // calls synthesize with those exact values:
        let hookIdentity = SessionIdentity.synthesize(
            sessionId: "s-42",
            cwd: cwd,
            ppid: 7777,     // hook.sh's $PPID == claude's PID
            tty: "/dev/ttys009"
        )
        #expect(discovered[0].identity.fingerprint == hookIdentity.fingerprint,
                "Discovery and hook paths must produce the same fingerprint, otherwise rows would duplicate")
    }

    // MARK: - iter-067 — env vars propagate into DiscoveredSession.hint

    @Test func envVarsPropagateIntoDiscoveredHint() throws {
        let root = makeProjectsRoot()
        let cwd = "/Users/test/vscode-project"
        _ = writeTranscript(in: root, subdir: "vscp", sessionId: "vs-1", cwd: cwd)
        let p = ClaudeProcess(
            pid: 4242,
            cwd: cwd,
            tty: "/dev/ttys003",
            termProgram: "vscode",
            vscodePid: 9999,
            iTermSessionId: nil,
            termSessionId: "abc-123"
        )
        let d = SessionDiscovery(enumerator: StaticEnumerator(procs: [p]), projectsRoot: root)
        let results = try d.discover()
        #expect(results.count == 1)
        let hint = results[0].hint
        #expect(hint.termProgram == "vscode")
        #expect(hint.vscodePid == 9999)
        #expect(hint.termSessionId == "abc-123")
        #expect(hint.ppid == 4242, "ppid in hint must be claude's PID for fingerprint stability")
        #expect(hint.tty == "/dev/ttys003")
    }
}

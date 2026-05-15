import Foundation
import Testing
@testable import ClaudeDock

@Suite struct StatusEngineTests {
    private func mkSession(status: SessionStatus) -> Session {
        let id = SessionIdentity.synthesize(sessionId: "s", cwd: "/x", ppid: 1, tty: nil)
        return Session(id: id.fingerprint, identity: id, status: status,
                       lastEventAt: Date(timeIntervalSinceReferenceDate: 0),
                       transcriptPath: "/tmp/x.jsonl", hint: TerminalHint())
    }

    @Test func sessionStartKeepsStarting() {
        var s = mkSession(status: .starting)
        StatusEngine().apply(.sessionStart, to: &s, at: Date())
        #expect(s.status == .starting)
    }

    @Test func userPromptSubmitGoesThinking() {
        var s = mkSession(status: .starting)
        StatusEngine().apply(.userPromptSubmit, to: &s, at: Date())
        #expect(s.status == .thinking)
    }

    @Test func notificationGoesWaitingInput() {
        var s = mkSession(status: .thinking)
        StatusEngine().apply(.notification, to: &s, at: Date())
        #expect(s.status == .waitingInput)
    }

    @Test func notificationFromIdleStaysIdle() {
        var s = mkSession(status: .idle)
        StatusEngine().apply(.notification, to: &s, at: Date())
        #expect(s.status == .idle, "Notification while idle is an idle reminder, not a real waitingInput.")
    }

    @Test func notificationFromStartingDoesNotEscalate() {
        var s = mkSession(status: .starting)
        StatusEngine().apply(.notification, to: &s, at: Date())
        #expect(s.status == .starting)
    }

    @Test func stopGoesIdle() {
        var s = mkSession(status: .thinking)
        StatusEngine().apply(.stop, to: &s, at: Date())
        #expect(s.status == .idle)
    }

    @Test func sessionEndGoesEnded() {
        var s = mkSession(status: .idle)
        StatusEngine().apply(.sessionEnd, to: &s, at: Date())
        #expect(s.status == .ended)
    }

    @Test func waitingInputThenUserPromptReturnsToThinking() {
        var s = mkSession(status: .waitingInput)
        StatusEngine().apply(.userPromptSubmit, to: &s, at: Date())
        #expect(s.status == .thinking)
    }

    @Test func heartbeatDeadProcessForcesEnded() {
        var s = mkSession(status: .idle)
        let now = Date()
        StatusEngine().applyHeartbeat(to: &s, processAlive: false,
                                      transcriptMTime: now,
                                      now: now)
        #expect(s.status == .ended)
    }

    @Test func heartbeatAliveButStaleMtimeForcesEnded() {
        var s = mkSession(status: .idle)
        let now = Date()
        StatusEngine().applyHeartbeat(to: &s, processAlive: true,
                                      transcriptMTime: now.addingTimeInterval(-6 * 60),
                                      now: now)
        #expect(s.status == .ended)
    }

    @Test func heartbeatDoesNotEscalateFromThinking() {
        var s = mkSession(status: .thinking)
        let now = Date()
        StatusEngine().applyHeartbeat(to: &s, processAlive: true,
                                      transcriptMTime: now.addingTimeInterval(-30 * 60),
                                      now: now)
        #expect(s.status == .thinking, "Mtime stale should NOT end a thinking session")
    }

    @Test func heartbeatDoesNotMoveActiveSession() {
        var s = mkSession(status: .idle)
        let now = Date()
        StatusEngine().applyHeartbeat(to: &s, processAlive: true,
                                      transcriptMTime: now.addingTimeInterval(-10),
                                      now: now)
        #expect(s.status == .idle)
    }
}

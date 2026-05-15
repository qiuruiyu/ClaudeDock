import Foundation
import Testing
@testable import ClaudeDock

@Suite struct MutePolicyTests {
    @Test func globalMuteSuppresses() {
        var prefs = Preferences()
        prefs.globalMuteUntil = Date().addingTimeInterval(60)
        let s = mkSession()
        #expect(MutePolicy.muted(s, in: prefs))
    }

    @Test func expiredMuteDoesNotSuppress() {
        var prefs = Preferences()
        prefs.globalMuteUntil = Date().addingTimeInterval(-60)
        let s = mkSession()
        #expect(!MutePolicy.muted(s, in: prefs))
    }

    private func mkSession() -> Session {
        let id = SessionIdentity.synthesize(sessionId: "s", cwd: "/x", ppid: 1, tty: nil)
        return Session(id: id.fingerprint, identity: id, status: .waitingInput,
                       lastEventAt: Date(), transcriptPath: "/tmp/x.jsonl", hint: TerminalHint())
    }
}

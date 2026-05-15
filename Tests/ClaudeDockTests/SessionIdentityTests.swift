import Foundation
import Testing
@testable import ClaudeDock

@Suite struct SessionIdentityTests {
    @Test func workKeyStableForSameCwd() {
        let a = SessionIdentity.synthesize(sessionId: "s1", cwd: "/Users/joe/x", ppid: 100, tty: "/dev/ttys001")
        let b = SessionIdentity.synthesize(sessionId: "s2", cwd: "/Users/joe/x", ppid: 200, tty: "/dev/ttys002")
        #expect(a.workKey == b.workKey, "Same cwd ⇒ same workKey")
        #expect(a.fingerprint != b.fingerprint, "Different sessionId ⇒ different fingerprint")
    }

    // MARK: - iter-071: identity is (cwd, sessionId)

    @Test func ppidAndTtyDoNotAffectFingerprint() {
        // The merge invariant after iter-071:
        //   Discovery → ppid=<claude pid> tty=/dev/ttysN
        //   Hook      → ppid=<intermediate shell pid> tty="" (piped stdin)
        // Different ppid AND different tty, but both observe the same
        // (cwd, sessionId). Must produce the same fingerprint.
        let discovery = SessionIdentity.synthesize(
            sessionId: "uuid-abc", cwd: "/x", ppid: 7777, tty: "/dev/ttys010"
        )
        let hook = SessionIdentity.synthesize(
            sessionId: "uuid-abc", cwd: "/x", ppid: 12345, tty: nil
        )
        let hookEmptyTty = SessionIdentity.synthesize(
            sessionId: "uuid-abc", cwd: "/x", ppid: 9876, tty: ""
        )
        #expect(discovery.fingerprint == hook.fingerprint,
                "Discovery and hook see different ppid/tty but same sessionId → must merge")
        #expect(discovery.fingerprint == hookEmptyTty.fingerprint)
    }

    @Test func differentSessionIdsInSameCwdAreDistinguishable() {
        // Two concurrent claude sessions in the same CWD must remain
        // distinguishable — they're legitimately different sessions
        // with different session_ids.
        let a = SessionIdentity.synthesize(sessionId: "session-A", cwd: "/x", ppid: 100, tty: nil)
        let b = SessionIdentity.synthesize(sessionId: "session-B", cwd: "/x", ppid: 100, tty: nil)
        #expect(a.fingerprint != b.fingerprint)
        #expect(a.workKey == b.workKey, "Both share the workspace; just different sessions")
    }

    @Test func workKeyDifferentForDifferentCwd() {
        let a = SessionIdentity.synthesize(sessionId: "s", cwd: "/a", ppid: 1, tty: nil)
        let b = SessionIdentity.synthesize(sessionId: "s", cwd: "/b", ppid: 1, tty: nil)
        #expect(a.workKey != b.workKey)
    }

    @Test func workKeyLength12() {
        let a = SessionIdentity.synthesize(sessionId: "s", cwd: "/x", ppid: 1, tty: nil)
        #expect(a.workKey.count == 12)
        #expect(a.fingerprint.count == 12)
    }
}

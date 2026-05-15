import Foundation
import Testing
@testable import ClaudeDock

@Suite struct SessionIdentityTests {
    @Test func workKeyStableForSameCwd() {
        let a = SessionIdentity.synthesize(sessionId: "s1", cwd: "/Users/joe/x", ppid: 100, tty: "/dev/ttys001")
        let b = SessionIdentity.synthesize(sessionId: "s2", cwd: "/Users/joe/x", ppid: 200, tty: "/dev/ttys002")
        #expect(a.workKey == b.workKey, "Same cwd ⇒ same workKey")
        #expect(a.fingerprint != b.fingerprint, "Different ppid ⇒ different fingerprint")
    }

    // MARK: - iter-070: TTY must not affect fingerprint

    @Test func samePpidAndCwdProduceSameFingerprintRegardlessOfTty() {
        // The merge invariant: discovery sees the real TTY (e.g.
        // "/dev/ttys010") while hook.sh sees its own piped stdin →
        // tty(1) returns "not a tty" → empty string. Both paths must
        // produce the SAME fingerprint so SessionStore.ingest finds
        // and merges into the existing discovered row.
        let discovery = SessionIdentity.synthesize(
            sessionId: "x", cwd: "/x", ppid: 7777, tty: "/dev/ttys010"
        )
        let hook = SessionIdentity.synthesize(
            sessionId: "x", cwd: "/x", ppid: 7777, tty: nil
        )
        let hookEmpty = SessionIdentity.synthesize(
            sessionId: "x", cwd: "/x", ppid: 7777, tty: ""
        )
        #expect(discovery.fingerprint == hook.fingerprint)
        #expect(discovery.fingerprint == hookEmpty.fingerprint)
    }

    @Test func differentPpidStillProducesDifferentFingerprintInSameCwd() {
        // Two distinct claude processes in the same CWD must still be
        // distinguishable — they're legitimately different sessions.
        let a = SessionIdentity.synthesize(sessionId: "x", cwd: "/x", ppid: 100, tty: nil)
        let b = SessionIdentity.synthesize(sessionId: "x", cwd: "/x", ppid: 200, tty: nil)
        #expect(a.fingerprint != b.fingerprint)
        #expect(a.workKey == b.workKey, "Both share the workspace; just different processes")
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

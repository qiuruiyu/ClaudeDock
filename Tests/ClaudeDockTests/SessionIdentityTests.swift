import Foundation
import Testing
@testable import ClaudeDock

@Suite struct SessionIdentityTests {
    @Test func workKeyStableForSameCwd() {
        let a = SessionIdentity.synthesize(sessionId: "s1", cwd: "/Users/joe/x", ppid: 100, tty: "/dev/ttys001")
        let b = SessionIdentity.synthesize(sessionId: "s2", cwd: "/Users/joe/x", ppid: 200, tty: "/dev/ttys002")
        #expect(a.workKey == b.workKey, "Same cwd ⇒ same workKey")
        #expect(a.fingerprint != b.fingerprint, "Different ppid/tty ⇒ different fingerprint")
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

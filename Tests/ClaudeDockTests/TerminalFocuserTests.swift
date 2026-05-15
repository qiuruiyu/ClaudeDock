import Foundation
import Testing
@testable import ClaudeDock

private struct MockGeneric: GenericFocusing {
    let recorded: (@Sendable (String) -> Void)?
    init(recorded: (@Sendable (String) -> Void)? = nil) { self.recorded = recorded }
    @MainActor
    func activate(app: String) async -> FocusResult {
        recorded?(app)
        return .activatedAppOnly(app: app)
    }
}

@MainActor
@Suite struct TerminalFocuserTests {
    private func mkSession(termProgram: String?, ttyOpt: String? = nil, iTermId: String? = nil) -> Session {
        var hint = TerminalHint()
        hint.termProgram = termProgram
        hint.tty = ttyOpt
        hint.iTermSessionId = iTermId
        let id = SessionIdentity.synthesize(sessionId: "s", cwd: "/x", ppid: 1, tty: ttyOpt)
        return Session(id: id.fingerprint, identity: id, status: .idle,
                       lastEventAt: Date(), transcriptPath: "/tmp/x.jsonl", hint: hint)
    }

    @Test func noHintReturnsNoTerminalHint() async {
        let f = TerminalFocuser(generic: MockGeneric())
        let r = await f.focus(mkSession(termProgram: nil))
        #expect(r == .noTerminalHint)
    }

    @Test func unknownTermFallsBackToGeneric() async {
        let f = TerminalFocuser(generic: MockGeneric())
        let r = await f.focus(mkSession(termProgram: "ghostty"))
        if case .activatedAppOnly(let app) = r { #expect(app == "ghostty") } else { Issue.record("expected activatedAppOnly, got \(r)") }
    }

    @Test func iTermWithNoSessionIdFallsBackToGeneric() async {
        let f = TerminalFocuser(generic: MockGeneric())
        let r = await f.focus(mkSession(termProgram: "iTerm.app"))
        if case .activatedAppOnly(let app) = r { #expect(app == "iTerm") } else { Issue.record("got \(r)") }
    }
}

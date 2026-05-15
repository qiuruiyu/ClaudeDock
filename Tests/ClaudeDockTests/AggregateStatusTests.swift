import Foundation
import Testing
@testable import ClaudeDock

@Suite struct AggregateStatusTests {
    private func mk(_ status: SessionStatus) -> Session {
        let id = SessionIdentity.synthesize(sessionId: UUID().uuidString,
                                            cwd: "/tmp/\(UUID().uuidString)",
                                            ppid: 1, tty: nil)
        return Session(id: id.fingerprint, identity: id, status: status,
                       lastEventAt: Date(), transcriptPath: "/tmp/x.jsonl", hint: TerminalHint())
    }

    @Test func emptyIsGray() { #expect(AggregateStatus.compute([]) == .gray) }
    @Test func allEndedIsGray() { #expect(AggregateStatus.compute([mk(.ended), mk(.ended)]) == .gray) }
    @Test func anyWaitingIsRed() { #expect(AggregateStatus.compute([mk(.idle), mk(.waitingInput)]) == .red) }
    @Test func thinkingNoWaitIsYellow() { #expect(AggregateStatus.compute([mk(.idle), mk(.thinking)]) == .yellow) }
    @Test func allIdleIsGreen() { #expect(AggregateStatus.compute([mk(.idle)]) == .green) }
}

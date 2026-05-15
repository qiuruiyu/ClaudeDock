import Foundation
import Testing
@testable import ClaudeDock

@Suite @MainActor struct NotchDockControllerTests {
    @Test func startsHidden() {
        let c = NotchDockController()
        #expect(c.state == .hidden)
    }

    @Test func sessionEnteringWaitingInputShowsBanner() {
        let c = NotchDockController()
        let s = makeSession(id: "a", status: .waitingInput, cwd: "/x")
        c.applySessionDiff(prev: ["a": .thinking], now: [s])
        if case .showing(let shown, _) = c.state {
            #expect(shown.id == "a")
        } else {
            Issue.record("expected .showing, got \(c.state)")
        }
    }

    @Test func thinkingToIdleShowsBanner() {
        let c = NotchDockController()
        let s = makeSession(id: "a", status: .idle, cwd: "/x")
        c.applySessionDiff(prev: ["a": .thinking], now: [s])
        if case .showing(let shown, _) = c.state {
            #expect(shown.id == "a")
        } else {
            Issue.record("expected .showing, got \(c.state)")
        }
    }

    @Test func waitingInputToIdleShowsBanner() {
        let c = NotchDockController()
        let s = makeSession(id: "a", status: .idle, cwd: "/x")
        c.applySessionDiff(prev: ["a": .waitingInput], now: [s])
        if case .showing(let shown, _) = c.state {
            #expect(shown.id == "a")
        } else {
            Issue.record("expected .showing on waitingInput→idle, got \(c.state)")
        }
    }

    @Test func bannerAutoHidesAfterTimeout() async {
        let c = NotchDockController(notificationTimeout: 0.05)
        let s = makeSession(id: "a", status: .waitingInput, cwd: "/x")
        c.applySessionDiff(prev: [:], now: [s])
        try? await Task.sleep(nanoseconds: 120_000_000)
        #expect(c.state == .hidden)
    }

    @Test func clickDismissesImmediately() {
        let c = NotchDockController()
        let s = makeSession(id: "a", status: .waitingInput, cwd: "/x")
        c.applySessionDiff(prev: [:], now: [s])
        c.userClickedBanner()
        #expect(c.state == .hidden)
    }

    private func makeSession(id: String, status: SessionStatus, cwd: String) -> Session {
        Session(
            id: id,
            identity: SessionIdentity(sessionId: id, workKey: cwd, fingerprint: id, cwd: cwd),
            status: status,
            lastEventAt: Date(),
            transcriptPath: "",
            hint: TerminalHint(),
            sameCwdIndex: nil)
    }
}

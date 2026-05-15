import Foundation
import Testing
@testable import ClaudeDock

@MainActor
@Suite struct VSCodeStrategyTests {

    @Test func schemeForVscode() {
        #expect(VSCodeStrategy.scheme(forTermProgram: "vscode") == "vscode")
        #expect(VSCodeStrategy.scheme(forTermProgram: "vscode-insiders") == "vscode-insiders")
        #expect(VSCodeStrategy.scheme(forTermProgram: "cursor") == "cursor")
    }

    @Test func schemeReturnsNilForUnknownTerminal() {
        #expect(VSCodeStrategy.scheme(forTermProgram: "iTerm.app") == nil)
        #expect(VSCodeStrategy.scheme(forTermProgram: "Apple_Terminal") == nil)
        #expect(VSCodeStrategy.scheme(forTermProgram: "ghostty") == nil)
        #expect(VSCodeStrategy.scheme(forTermProgram: "") == nil)
    }

    @Test func makeURLBuildsVscodeFileURL() {
        let url = VSCodeStrategy.makeURL(cwd: "/Users/joe/repo", scheme: "vscode")
        #expect(url?.absoluteString == "vscode://file/Users/joe/repo")
    }

    @Test func makeURLBuildsCursorURL() {
        let url = VSCodeStrategy.makeURL(cwd: "/Users/joe/repo", scheme: "cursor")
        #expect(url?.absoluteString == "cursor://file/Users/joe/repo")
    }

    @Test func makeURLPercentEncodesSpaces() {
        let url = VSCodeStrategy.makeURL(cwd: "/Users/joe/my project", scheme: "vscode")
        #expect(url?.absoluteString == "vscode://file/Users/joe/my%20project")
    }

    @Test func focusInvokesOpenerWithCorrectURL() async {
        actor Capture {
            var received: URL?
            func set(_ u: URL) { received = u }
            func get() -> URL? { received }
        }
        let cap = Capture()
        let strategy = VSCodeStrategy { url in
            Task { await cap.set(url) }
            return true
        }
        let result = await strategy.focus(cwd: "/Users/joe/work", scheme: "vscode")
        // Yield to let the Task above complete
        try? await Task.sleep(nanoseconds: 50_000_000)
        let captured = await cap.get()
        #expect(captured?.absoluteString == "vscode://file/Users/joe/work")
        if case .precise(let app, let window) = result {
            #expect(app == "vscode")
            #expect(window == "/Users/joe/work")
        } else {
            Issue.record("Expected .precise, got \(result)")
        }
    }

    @Test func focusReturnsFailedWhenOpenerSaysNo() async {
        let strategy = VSCodeStrategy { _ in false }
        let result = await strategy.focus(cwd: "/x", scheme: "vscode")
        if case .failed = result {
            // ok
        } else {
            Issue.record("Expected .failed, got \(result)")
        }
    }
}

@MainActor
@Suite struct TerminalFocuserVSCodeDispatchTests {

    /// Records the (cwd, scheme) the focuser dispatches; never opens anything.
    final class RecordingVSCode: VSCodeFocusing, @unchecked Sendable {
        var captured: (cwd: String, scheme: String)?
        var returnPrecise: Bool = true
        @MainActor
        func focus(cwd: String, scheme: String) async -> FocusResult {
            captured = (cwd, scheme)
            return returnPrecise ? .precise(app: scheme, window: cwd) : .failed(reason: "test")
        }
    }

    final class RecordingGeneric: GenericFocusing, @unchecked Sendable {
        var captured: String?
        @MainActor
        func activate(app: String) async -> FocusResult {
            captured = app
            return .activatedAppOnly(app: app)
        }
    }

    private func makeSession(termProgram: String, cwd: String = "/repo") -> Session {
        let identity = SessionIdentity.synthesize(sessionId: "s", cwd: cwd, ppid: 1, tty: nil)
        let hint = TerminalHint(ppid: 1, tty: nil, termProgram: termProgram,
                                iTermSessionId: nil, termSessionId: nil, vscodePid: nil)
        return Session(id: identity.fingerprint, identity: identity,
                       status: .idle, lastEventAt: Date(),
                       transcriptPath: "", hint: hint)
    }

    @Test func vscodeTermDispatchesToVSCodeStrategy() async {
        let vscode = RecordingVSCode()
        let generic = RecordingGeneric()
        let focuser = TerminalFocuser(vscode: vscode, generic: generic)
        let session = makeSession(termProgram: "vscode", cwd: "/Users/test/proj")
        let r = await focuser.focus(session)
        #expect(vscode.captured?.cwd == "/Users/test/proj")
        #expect(vscode.captured?.scheme == "vscode")
        #expect(generic.captured == nil, "Generic activate should not be called when VSCodeStrategy succeeds")
        if case .precise = r { /* ok */ } else { Issue.record("Expected .precise, got \(r)") }
    }

    @Test func cursorTermDispatchesToVSCodeStrategyWithCursorScheme() async {
        let vscode = RecordingVSCode()
        let generic = RecordingGeneric()
        let focuser = TerminalFocuser(vscode: vscode, generic: generic)
        let session = makeSession(termProgram: "cursor")
        _ = await focuser.focus(session)
        #expect(vscode.captured?.scheme == "cursor")
    }

    @Test func fallsBackToGenericWhenVSCodeStrategyFails() async {
        let vscode = RecordingVSCode()
        vscode.returnPrecise = false
        let generic = RecordingGeneric()
        let focuser = TerminalFocuser(vscode: vscode, generic: generic)
        let session = makeSession(termProgram: "vscode")
        _ = await focuser.focus(session)
        #expect(generic.captured == "vscode",
                "Fallback path must activate VS Code app at large when URL open fails")
    }

    @Test func nonVscodeTermBypassesVSCodeStrategy() async {
        let vscode = RecordingVSCode()
        let generic = RecordingGeneric()
        let focuser = TerminalFocuser(vscode: vscode, generic: generic)
        let session = makeSession(termProgram: "ghostty")
        _ = await focuser.focus(session)
        #expect(vscode.captured == nil)
        #expect(generic.captured == "ghostty")
    }
}

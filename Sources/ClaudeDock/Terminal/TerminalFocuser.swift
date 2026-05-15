import Foundation

protocol ITermFocusing: Sendable { @MainActor func focus(sessionId: String) async -> FocusResult }
protocol TerminalAppFocusing: Sendable { @MainActor func focus(tty: String) async -> FocusResult }
protocol GenericFocusing: Sendable { @MainActor func activate(app: String) async -> FocusResult }

@MainActor
struct TerminalFocuser {
    let iTerm: ITermFocusing?
    let terminalApp: TerminalAppFocusing?
    let generic: GenericFocusing

    init(iTerm: ITermFocusing? = nil, terminalApp: TerminalAppFocusing? = nil, generic: GenericFocusing) {
        self.iTerm = iTerm
        self.terminalApp = terminalApp
        self.generic = generic
    }

    func focus(_ session: Session) async -> FocusResult {
        guard let term = session.hint.termProgram, !term.isEmpty else {
            return .noTerminalHint
        }
        switch term {
        case "iTerm.app":
            if let sid = session.hint.iTermSessionId, let iTerm {
                let r = await iTerm.focus(sessionId: sid)
                if case .precise = r { return r }
            }
            return await generic.activate(app: "iTerm")
        case "Apple_Terminal":
            if let tty = session.hint.tty, let terminalApp {
                let r = await terminalApp.focus(tty: tty)
                if case .precise = r { return r }
            }
            return await generic.activate(app: "Terminal")
        default:
            return await generic.activate(app: term)
        }
    }
}

import Foundation
import Testing
@testable import ClaudeDock

@Suite struct TerminalHintTests {
    @Test func parseFromQueryItems() {
        let items = [
            URLQueryItem(name: "ppid", value: "2345"),
            URLQueryItem(name: "tty", value: "/dev/ttys001"),
            URLQueryItem(name: "term", value: "iTerm.app"),
            URLQueryItem(name: "iterm_id", value: "w0t1p0:UUID"),
            URLQueryItem(name: "term_session_id", value: ""),
            URLQueryItem(name: "vscode_pid", value: ""),
        ]
        let hint = TerminalHint.parse(queryItems: items)
        #expect(hint.ppid == 2345)
        #expect(hint.tty == "/dev/ttys001")
        #expect(hint.termProgram == "iTerm.app")
        #expect(hint.iTermSessionId == "w0t1p0:UUID")
        #expect(hint.termSessionId == nil)
        #expect(hint.vscodePid == nil)
    }

    @Test func parseEmptyReturnsAllNil() {
        let hint = TerminalHint.parse(queryItems: nil)
        #expect(hint.ppid == nil)
        #expect(hint.tty == nil)
    }
}

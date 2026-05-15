import Foundation

struct TerminalAppStrategy: TerminalAppFocusing {
    @MainActor
    func focus(tty: String) async -> FocusResult {
        let escaped = tty.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t is "\(escaped)" then
                        set selected of t to true
                        tell w to set frontmost to true
                        activate
                        return "ok"
                    end if
                end repeat
            end repeat
            return "notfound"
        end tell
        """
        switch await AppleScriptRunner.run(script) {
        case "ok":       return .precise(app: "Terminal", window: tty)
        case "notfound": return .failed(reason: "Terminal tab not found")
        default:         return .failed(reason: "AppleScript failed (permission?)")
        }
    }
}

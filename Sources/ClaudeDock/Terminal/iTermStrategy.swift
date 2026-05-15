import Foundation

struct iTermStrategy: ITermFocusing {
    @MainActor
    func focus(sessionId: String) async -> FocusResult {
        // Escape any double-quotes in sessionId for the script literal.
        let escaped = sessionId.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "iTerm2"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if unique id of s as string is "\(escaped)" then
                            tell s to select
                            tell w to select
                            activate
                            return "ok"
                        end if
                    end repeat
                end repeat
            end repeat
            return "notfound"
        end tell
        """
        switch await AppleScriptRunner.run(script) {
        case "ok":        return .precise(app: "iTerm2", window: sessionId)
        case "notfound":  return .failed(reason: "iTerm tab not found")
        case nil:         return .failed(reason: "AppleScript failed (permission?)")
        default:          return .failed(reason: "Unexpected AppleScript result")
        }
    }
}

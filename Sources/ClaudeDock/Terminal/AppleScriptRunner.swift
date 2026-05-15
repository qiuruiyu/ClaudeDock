import Foundation

enum AppleScriptRunner {
    /// Returns the string value of the AS result, or nil if compile/exec failed.
    static func run(_ src: String) async -> String? {
        await Task.detached(priority: .userInitiated) {
            var err: NSDictionary?
            guard let s = NSAppleScript(source: src) else { return nil }
            let out = s.executeAndReturnError(&err)
            if err != nil { return nil }
            return out.stringValue
        }.value
    }
}

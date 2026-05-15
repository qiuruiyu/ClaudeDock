// Sources/ClaudeDock/Terminal/VSCodeStrategy.swift
//
// Focus the right VS Code / Cursor window by opening
//   `vscode://file/<cwd>`  (or `cursor://file/<cwd>`)
// via NSWorkspace. VS Code's URL handler does the right thing: if a
// window for that workspace folder is already open, it's brought to
// front; otherwise a new window opens with the folder loaded. This is
// simpler and more reliable than walking the renderer-PID process tree
// and using AppleScript to target a specific NSWindow.

import AppKit

protocol VSCodeFocusing: Sendable {
    @MainActor
    func focus(cwd: String, scheme: String) async -> FocusResult
}

struct VSCodeStrategy: VSCodeFocusing {
    /// Injectable URL-open shim so tests can verify scheme dispatch without
    /// actually launching VS Code.
    var opener: @Sendable (URL) -> Bool

    init(opener: @Sendable @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }) {
        self.opener = opener
    }

    /// Map a hint.termProgram value to the corresponding URL scheme.
    /// Returns nil for terminals we don't deep-link into.
    static func scheme(forTermProgram term: String) -> String? {
        switch term {
        case "vscode":           return "vscode"
        case "vscode-insiders":  return "vscode-insiders"
        case "cursor":           return "cursor"
        default:                 return nil
        }
    }

    static func makeURL(cwd: String, scheme: String) -> URL? {
        // cwd is an absolute path starting with `/`, so the URL has the
        // form `vscode://file//Users/...`. The double slash is intentional
        // and accepted by VS Code's URL handler.
        let allowed = CharacterSet.urlPathAllowed
        let encoded = cwd.addingPercentEncoding(withAllowedCharacters: allowed) ?? cwd
        return URL(string: "\(scheme)://file\(encoded)")
    }

    @MainActor
    func focus(cwd: String, scheme: String) async -> FocusResult {
        guard let url = Self.makeURL(cwd: cwd, scheme: scheme) else {
            return .failed(reason: "Could not build URL for scheme=\(scheme), cwd=\(cwd)")
        }
        return opener(url)
            ? .precise(app: scheme, window: cwd)
            : .failed(reason: "Open URL failed: \(url.absoluteString)")
    }
}

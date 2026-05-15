import Foundation

struct TerminalHint: Codable, Equatable, Sendable {
    var ppid: Int32?
    var tty: String?
    var termProgram: String?
    var iTermSessionId: String?
    var termSessionId: String?
    var vscodePid: Int32?

    static func parse(queryItems: [URLQueryItem]?) -> TerminalHint {
        func nonEmpty(_ s: String?) -> String? {
            guard let s, !s.isEmpty else { return nil }
            return s
        }
        let dict = Dictionary(uniqueKeysWithValues: (queryItems ?? []).map { ($0.name, $0.value ?? "") })
        return TerminalHint(
            ppid: nonEmpty(dict["ppid"]).flatMap { Int32($0) },
            tty: nonEmpty(dict["tty"]),
            termProgram: nonEmpty(dict["term"]),
            iTermSessionId: nonEmpty(dict["iterm_id"]),
            termSessionId: nonEmpty(dict["term_session_id"]),
            vscodePid: nonEmpty(dict["vscode_pid"]).flatMap { Int32($0) }
        )
    }
}

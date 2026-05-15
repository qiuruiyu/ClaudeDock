import Foundation

struct SessionIdentity: Hashable, Codable, Sendable {
    let sessionId: String
    let workKey: String
    let fingerprint: String
    let cwd: String

    /// Fingerprint is `sha1(cwd|ppid)`. TTY is intentionally NOT part of
    /// the identity: hook.sh sees its own stdin (a pipe from claude →
    /// `tty(1)` returns "not a tty" → empty string), while discovery
    /// reports the controlling TTY of the claude process (e.g.
    /// `/dev/ttys010`). Including TTY in the fingerprint produced two
    /// rows for the same physical claude (one from each path) instead
    /// of merging. TTY still flows into `TerminalHint` for use by the
    /// focus strategies, just not as identity.
    static func synthesize(sessionId: String, cwd: String, ppid: Int32?, tty: String?) -> SessionIdentity {
        let resolvedCwd = (try? URL(fileURLWithPath: cwd).resolvingSymlinksInPath().path) ?? cwd
        let workKey = Crypto.sha1Prefix(resolvedCwd, length: 12)
        let ppidStr = ppid.map(String.init) ?? "0"
        let fingerprint = Crypto.sha1Prefix("\(resolvedCwd)|\(ppidStr)", length: 12)
        _ = tty   // intentionally unused — see doc comment above
        return SessionIdentity(sessionId: sessionId, workKey: workKey, fingerprint: fingerprint, cwd: resolvedCwd)
    }
}

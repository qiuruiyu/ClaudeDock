import Foundation

struct SessionIdentity: Hashable, Codable, Sendable {
    let sessionId: String
    let workKey: String
    let fingerprint: String
    let cwd: String

    /// Fingerprint is `sha1(cwd|sessionId)`. Neither PPID nor TTY are
    /// part of the identity:
    ///
    /// - PPID disagrees between paths. Claude Code invokes hooks via a
    ///   shell wrapper, so hook.sh's `$PPID` is the (short-lived)
    ///   intermediate shell, not the claude process. Discovery reads
    ///   claude's own PID via pgrep. The two values almost never match.
    /// - TTY disagrees the same way. hook.sh's stdin is a pipe from
    ///   claude → `tty(1)` returns "not a tty" → empty. Discovery sees
    ///   claude's controlling TTY (e.g. `/dev/ttys010`).
    ///
    /// `sessionId` (Claude's session UUID) is the only value both paths
    /// observe identically — claude embeds it in every hook payload
    /// and Discovery reads it from the transcript filename. Combined
    /// with `cwd` for defense against any hypothetical cross-workspace
    /// id reuse, it produces a stable fingerprint that lets a real
    /// hook event merge into the discovered row instead of creating a
    /// duplicate.
    ///
    /// PPID/TTY still flow into `TerminalHint` for the focus strategies;
    /// they're just not identity.
    static func synthesize(sessionId: String, cwd: String, ppid: Int32?, tty: String?) -> SessionIdentity {
        let resolvedCwd = (try? URL(fileURLWithPath: cwd).resolvingSymlinksInPath().path) ?? cwd
        let workKey = Crypto.sha1Prefix(resolvedCwd, length: 12)
        let fingerprint = Crypto.sha1Prefix("\(resolvedCwd)|\(sessionId)", length: 12)
        _ = ppid; _ = tty   // intentionally unused — see doc comment above
        return SessionIdentity(sessionId: sessionId, workKey: workKey, fingerprint: fingerprint, cwd: resolvedCwd)
    }
}

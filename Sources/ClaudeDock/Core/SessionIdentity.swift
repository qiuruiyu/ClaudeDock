import Foundation

struct SessionIdentity: Hashable, Codable, Sendable {
    let sessionId: String
    let workKey: String
    let fingerprint: String
    let cwd: String

    static func synthesize(sessionId: String, cwd: String, ppid: Int32?, tty: String?) -> SessionIdentity {
        let resolvedCwd = (try? URL(fileURLWithPath: cwd).resolvingSymlinksInPath().path) ?? cwd
        let workKey = Crypto.sha1Prefix(resolvedCwd, length: 12)
        let ppidStr = ppid.map(String.init) ?? "0"
        let ttyStr = tty ?? ""
        let fingerprint = Crypto.sha1Prefix("\(resolvedCwd)|\(ppidStr)|\(ttyStr)", length: 12)
        return SessionIdentity(sessionId: sessionId, workKey: workKey, fingerprint: fingerprint, cwd: resolvedCwd)
    }
}

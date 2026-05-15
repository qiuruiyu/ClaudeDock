import Foundation

struct Session: Identifiable, Equatable, Sendable {
    let id: String                  // = SessionIdentity.fingerprint
    var identity: SessionIdentity
    var status: SessionStatus
    var lastEventAt: Date
    var transcriptPath: String
    var hint: TerminalHint
    /// 1-based index among live sessions sharing this workKey, or nil if unique.
    var sameCwdIndex: Int? = nil
}

import Foundation

struct MutePolicy {
    /// Returns true if a notification for this session should be suppressed.
    static func muted(_ session: Session, in prefs: Preferences, now: Date = Date()) -> Bool {
        if let until = prefs.globalMuteUntil, until > now { return true }
        // per-workKey + per-fingerprint mute lives in AliasStore (v1.0.x). For
        // iter-029 the only mute scope is the global one above.
        return false
    }
}

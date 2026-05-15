import Foundation

struct StatusEngine: Sendable {
    static let staleMtimeThreshold: TimeInterval = 5 * 60

    func apply(_ kind: HookEvent.Kind, to session: inout Session, at now: Date) {
        switch kind {
        case .sessionStart:
            if session.status == .ended { session.status = .starting }
        case .userPromptSubmit:
            session.status = .thinking
        case .notification:
            // Claude Code fires Notification for both permission requests (mid-thinking)
            // AND idle reminders (after Stop). Only escalate to waitingInput when we're
            // currently thinking — that's a real "Claude is blocked" signal. An idle
            // reminder shouldn't paint the icon red.
            if session.status == .thinking {
                session.status = .waitingInput
            }
            // else: keep current status; Notification is an idle reminder or other noise.
        case .stop:
            session.status = .idle
        case .sessionEnd:
            session.status = .ended
        }
        session.lastEventAt = now
    }

    func applyHeartbeat(to session: inout Session,
                        processAlive: Bool,
                        transcriptMTime: Date,
                        now: Date) {
        if !processAlive {
            session.status = .ended
            session.lastEventAt = now
            return
        }
        // Stale mtime → only escalate if the session is *not* actively thinking
        let age = now.timeIntervalSince(transcriptMTime)
        if age > Self.staleMtimeThreshold && session.status != .thinking {
            session.status = .ended
            session.lastEventAt = now
        }
    }
}

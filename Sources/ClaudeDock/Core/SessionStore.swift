import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []
    private let aliases: AliasStore
    private let engine = StatusEngine()
    private let colors = ColorAssigner()
    private var forgottenIds: Set<String> = []

    init(aliases: AliasStore) {
        self.aliases = aliases
    }

    func ingest(event: HookEvent, hint: TerminalHint) {
        let identity = SessionIdentity.synthesize(sessionId: event.sessionId,
                                                  cwd: event.cwd,
                                                  ppid: hint.ppid,
                                                  tty: hint.tty)
        if forgottenIds.contains(identity.fingerprint) {
            return
        }
        // Assign a stable color (mutates aliases, saved below)
        _ = colors.color(forWorkKey: identity.workKey, in: aliases)
        aliases.touch(workKey: identity.workKey)

        if let idx = sessions.firstIndex(where: { $0.identity.fingerprint == identity.fingerprint }) {
            engine.apply(event.hookEventName, to: &sessions[idx], at: Date())
            if !hint.isEmpty { sessions[idx].hint = hint }
        } else {
            var s = Session(id: identity.fingerprint,
                            identity: identity,
                            status: .starting,
                            lastEventAt: Date(),
                            transcriptPath: event.transcriptPath,
                            hint: hint)
            engine.apply(event.hookEventName, to: &s, at: Date())
            sessions.append(s)
        }
        try? aliases.save()
        recomputeSameCwdIndices()
    }

    // MARK: - Mutation API (alias / color / pin)

    func rename(workKey: String, to newAlias: String?) {
        aliases.upsert(workKey: workKey, alias: newAlias)
        try? aliases.save()
        objectWillChange.send()
    }

    func setColor(workKey: String, to color: ColorTag) {
        aliases.upsert(workKey: workKey, color: color)
        try? aliases.save()
        objectWillChange.send()
    }

    func setPinned(workKey: String, _ pinned: Bool) {
        aliases.upsert(workKey: workKey, pinned: pinned)
        try? aliases.save()
        objectWillChange.send()
    }

    func forget(sessionId: String) {
        sessions.removeAll { $0.id == sessionId }
        forgottenIds.insert(sessionId)
        objectWillChange.send()
    }

    /// Mark a session as ended without going through StatusEngine. Used by
    /// ProcessExitWatcher when a claude process dies abruptly (terminal
    /// close, SIGKILL, crash) and never fires its own SessionEnd hook.
    /// Idempotent — no-ops if the session is already .ended or unknown.
    func markEnded(sessionId: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        if sessions[idx].status == .ended { return }
        sessions[idx].status = .ended
        sessions[idx].lastEventAt = Date()
        recomputeSameCwdIndices()
        objectWillChange.send()
    }

    /// Inject a session reconstructed from process enumeration + transcript
    /// inspection at launch time. Bypasses `StatusEngine` (which encodes
    /// hook-driven transitions) and writes the inferred status directly.
    /// Returns early if the fingerprint is already tracked or forgotten —
    /// when a real hook later fires for the same `(cwd, ppid, tty)` triple,
    /// the existing fingerprint-match logic in `ingest` merges it.
    /// The `hint` carries TERM_PROGRAM / VSCODE_PID / ITERM_SESSION_ID
    /// values read from the claude process's env (iter-067) so the focus
    /// strategy works identically for discovered and hook-tracked rows.
    func injectDiscovered(identity: SessionIdentity,
                          transcriptPath: String,
                          status: SessionStatus,
                          lastEventAt: Date,
                          hint: TerminalHint = TerminalHint()) {
        if forgottenIds.contains(identity.fingerprint) { return }
        if sessions.contains(where: { $0.identity.fingerprint == identity.fingerprint }) {
            return
        }
        _ = colors.color(forWorkKey: identity.workKey, in: aliases)
        aliases.touch(workKey: identity.workKey)
        let s = Session(id: identity.fingerprint,
                        identity: identity,
                        status: status,
                        lastEventAt: lastEventAt,
                        transcriptPath: transcriptPath,
                        hint: hint)
        sessions.append(s)
        try? aliases.save()
        recomputeSameCwdIndices()
    }

    // MARK: - #N auto-numbering

    private func recomputeSameCwdIndices() {
        let active = sessions.enumerated().filter { $0.element.status != .ended }
        var groups: [String: [(offset: Int, lastEventAt: Date)]] = [:]
        for (i, s) in active {
            groups[s.identity.workKey, default: []].append((i, s.lastEventAt))
        }
        // Reset all indices first
        for i in sessions.indices { sessions[i].sameCwdIndex = nil }
        for (_, members) in groups where members.count > 1 {
            let sorted = members.sorted { $0.lastEventAt < $1.lastEventAt }
            for (n, m) in sorted.enumerated() {
                sessions[m.offset].sameCwdIndex = n + 1
            }
        }
    }
}

private extension TerminalHint {
    var isEmpty: Bool {
        ppid == nil && tty == nil && termProgram == nil && iTermSessionId == nil
            && termSessionId == nil && vscodePid == nil
    }
}

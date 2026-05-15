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

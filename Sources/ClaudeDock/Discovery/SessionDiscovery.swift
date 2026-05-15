// Sources/ClaudeDock/Discovery/SessionDiscovery.swift
//
// Orchestrates a one-shot scan: enumerate running claude processes,
// match each one to its most recent transcript, infer its current
// status, and synthesize a SessionIdentity that will FINGERPRINT-MATCH
// any real hook event later fired by the same claude.
//
// The PPID semantics are subtle. When claude spawns hook.sh, hook.sh's
// $PPID is the claude process itself. So the hook POST carries
//   ppid=<claude PID>
// For our synthesized identity to match a later hook's identity, we
// must store **claude's own PID** in the ppid slot here. The variable
// name is misleading from the discovery side; the value semantics are
// what matter.

import Foundation
import Logging

struct DiscoveredSession: Equatable, Sendable {
    let identity: SessionIdentity
    let transcriptPath: String
    let status: SessionStatus
    let lastEventAt: Date
    let hint: TerminalHint    // iter-067 — env-derived; routes the focus strategy
}

final class SessionDiscovery: Sendable {
    let enumerator: ProcessEnumerating
    let projectsRoot: URL
    private let log = Logger(label: "claudedock.discovery")

    init(enumerator: ProcessEnumerating = ShellProcessEnumerator(),
         projectsRoot: URL = FileManager.default.homeDirectoryForCurrentUser
             .appendingPathComponent(".claude/projects")) {
        self.enumerator = enumerator
        self.projectsRoot = projectsRoot
    }

    func discover() throws -> [DiscoveredSession] {
        let procs = try enumerator.enumerateClaudeProcesses()
        guard !procs.isEmpty else {
            log.info("Discovery: no running claude processes")
            return []
        }
        let index = TranscriptIndex.build(at: projectsRoot)
        let results: [DiscoveredSession] = procs.compactMap { p in
            guard let ref = index.transcript(forCwd: p.cwd) else {
                log.debug("Discovery: no transcript for cwd=\(p.cwd); skipping pid=\(p.pid)")
                return nil
            }
            let status = StateInferer.inferStatus(fromJsonlAt: ref.path)
            let identity = SessionIdentity.synthesize(
                sessionId: ref.sessionId,
                cwd: p.cwd,
                ppid: p.pid,           // claude's own PID — matches hook.sh's $PPID
                tty: p.tty
            )
            // Reconstruct the same TerminalHint a hook would have produced,
            // so the focus strategy (TerminalFocuser dispatch) and any
            // .ppid-keyed reaper/watch work identically for discovered and
            // hook-tracked sessions.
            let hint = TerminalHint(
                ppid: p.pid,
                tty: p.tty,
                termProgram: p.termProgram,
                iTermSessionId: p.iTermSessionId,
                termSessionId: p.termSessionId,
                vscodePid: p.vscodePid
            )
            return DiscoveredSession(
                identity: identity,
                transcriptPath: ref.path.path,
                status: status,
                lastEventAt: ref.mtime,
                hint: hint
            )
        }
        log.info("Discovery: surfaced \(results.count)/\(procs.count) running session(s)")
        return results
    }
}

// Sources/ClaudeDock/Discovery/ProcessExitWatcher.swift
//
// Subscribes to kernel-level process-exit events via Dispatch's
// EVFILT_PROC + NOTE_EXIT wrapper (`DispatchSource.makeProcessSource`).
// One source per PID; the handler fires within microseconds of the
// process exiting, regardless of whether the exit was graceful
// (SessionEnd hook fired) or abrupt (terminal closed, SIGKILL, crash).
//
// This replaces the alternative — polling `kill -0 <pid>` every N
// seconds — with zero CPU overhead and instant detection.

import Foundation
import Darwin
import Logging

@MainActor
final class ProcessExitWatcher {
    private var sources: [String: DispatchSourceProcess] = [:]
    private let onExit: @MainActor (String) -> Void
    private let log = Logger(label: "claudedock.discovery.watcher")

    init(onExit: @escaping @MainActor (String) -> Void) {
        self.onExit = onExit
    }

    /// Begin watching the given PID. If the process is already dead at
    /// the moment of the call, `onExit` fires synchronously. Idempotent —
    /// re-watching an already-tracked sessionId is a no-op.
    func watch(sessionId: String, pid: Int32) {
        guard sources[sessionId] == nil else { return }

        // Liveness probe: signal 0 only checks for existence + permission.
        // ESRCH (3) means "no such process". Any other error code (e.g.
        // EPERM 1) means the process exists but we can't signal it; we
        // still want to watch in that case, so only treat ESRCH as dead.
        if kill(pid, 0) != 0 && errno == ESRCH {
            log.debug("Watch: pid=\(pid) already dead, firing immediately")
            onExit(sessionId)
            return
        }

        let source = DispatchSource.makeProcessSource(
            identifier: pid_t(pid),
            eventMask: .exit,
            queue: .global(qos: .userInitiated)
        )
        let id = sessionId
        source.setEventHandler { [weak self] in
            // Hop back to MainActor before touching state or invoking
            // the callback — DispatchSource handlers fire on the queue
            // we gave them, which is a background queue.
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.onExit(id)
                self.sources[id]?.cancel()
                self.sources.removeValue(forKey: id)
            }
        }
        source.resume()
        sources[sessionId] = source
        log.debug("Watching pid=\(pid) for session=\(sessionId)")
    }

    /// Stop watching a session. Idempotent.
    func unwatch(sessionId: String) {
        guard let source = sources.removeValue(forKey: sessionId) else { return }
        source.cancel()
    }

    /// Convenience for AppDelegate's reconciliation: cancel any watch
    /// whose sessionId isn't in `activeIds`.
    func reconcile(activeIds: Set<String>) {
        for id in Array(sources.keys) where !activeIds.contains(id) {
            unwatch(sessionId: id)
        }
    }

    /// Current number of active watches — for tests / diagnostics.
    var watchCount: Int { sources.count }
}

import Foundation
import Testing
@testable import ClaudeDock

@MainActor
@Suite(.serialized)
struct ProcessExitWatcherTests {

    /// Poll `condition()` every 50ms up to `timeoutSeconds`. Returns true
    /// if the condition became true; false on timeout.
    private func waitFor(_ condition: () -> Bool, timeoutSeconds: Double = 2.0) async -> Bool {
        let steps = Int(timeoutSeconds * 20)
        for _ in 0..<steps {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return condition()
    }

    @Test func firesOnExitForRealSubprocess() async throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sleep")
        proc.arguments = ["0.1"]
        try proc.run()
        let pid = proc.processIdentifier

        var captured: String?
        let watcher = ProcessExitWatcher { id in captured = id }
        watcher.watch(sessionId: "test-1", pid: pid)
        #expect(watcher.watchCount == 1)

        let ok = await waitFor({ captured != nil })
        #expect(ok)
        #expect(captured == "test-1")
        // The handler self-cancels after firing.
        #expect(watcher.watchCount == 0)
    }

    @Test func firesImmediatelyIfPidAlreadyDead() {
        // PID 1 is launchd, definitely alive — pick a clearly-bogus high PID
        // unlikely to be a real process. macOS PIDs are 32-bit but realistic
        // ranges stay well below 1M during a session.
        let dead = Int32(999_999)
        var captured: String?
        let watcher = ProcessExitWatcher { id in captured = id }
        watcher.watch(sessionId: "dead", pid: dead)
        #expect(captured == "dead", "Dead PID should fire onExit synchronously")
        #expect(watcher.watchCount == 0)
    }

    @Test func unwatchPreventsCallback() async throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sleep")
        proc.arguments = ["0.3"]
        try proc.run()
        let pid = proc.processIdentifier

        var captured: String?
        let watcher = ProcessExitWatcher { id in captured = id }
        watcher.watch(sessionId: "x", pid: pid)
        watcher.unwatch(sessionId: "x")
        #expect(watcher.watchCount == 0)

        proc.waitUntilExit()
        // Give any spurious handler 200ms to misbehave
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(captured == nil)
    }

    @Test func reWatchSameSessionIsIdempotent() async throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sleep")
        proc.arguments = ["0.3"]
        try proc.run()
        let pid = proc.processIdentifier

        var fireCount = 0
        let watcher = ProcessExitWatcher { _ in fireCount += 1 }
        watcher.watch(sessionId: "y", pid: pid)
        watcher.watch(sessionId: "y", pid: pid)  // duplicate; no-op
        watcher.watch(sessionId: "y", pid: pid)  // duplicate; no-op
        #expect(watcher.watchCount == 1)

        _ = await waitFor({ fireCount > 0 })
        #expect(fireCount == 1, "Despite three watch() calls, callback should fire exactly once")
    }

    @Test func reconcileCancelsOrphanedWatches() async throws {
        // Two subprocesses, watching both, then reconcile keeps only one.
        let p1 = Process()
        p1.executableURL = URL(fileURLWithPath: "/bin/sleep")
        p1.arguments = ["1"]
        try p1.run()
        let p2 = Process()
        p2.executableURL = URL(fileURLWithPath: "/bin/sleep")
        p2.arguments = ["1"]
        try p2.run()

        var fired: Set<String> = []
        let watcher = ProcessExitWatcher { id in fired.insert(id) }
        watcher.watch(sessionId: "keep", pid: p1.processIdentifier)
        watcher.watch(sessionId: "drop", pid: p2.processIdentifier)
        #expect(watcher.watchCount == 2)

        watcher.reconcile(activeIds: ["keep"])
        #expect(watcher.watchCount == 1)

        p1.terminate(); p1.waitUntilExit()
        p2.terminate(); p2.waitUntilExit()
        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(fired.contains("keep"))
        #expect(!fired.contains("drop"), "Dropped session should not have fired callback")
    }
}

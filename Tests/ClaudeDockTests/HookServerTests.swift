import Foundation
import Testing
@testable import ClaudeDock

@Suite(.serialized) struct HookServerTests {
    @Test func serverBindsToEphemeralPort() async throws {
        let server = HookServer()
        try await server.start()
        defer { Task { try? await server.stop() } }
        let port = await server.port
        #expect(port > 0, "Server should report a non-zero bound port")
    }

    @Test func postHookDeliversEvent() async throws {
        let server = HookServer()
        let received = ExpectingActor<HookEvent>()
        await server.setHandler { event, _ in await received.set(event) }
        try await server.start()
        defer { Task { try? await server.stop() } }

        let body = """
        {"session_id":"s1","cwd":"/tmp","hook_event_name":"SessionStart","transcript_path":"/tmp/t.jsonl"}
        """
        let port = await server.port
        let url = URL(string: "http://127.0.0.1:\(port)/hook")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = body.data(using: .utf8)
        let (_, resp) = try await URLSession.shared.data(for: req)
        #expect((resp as? HTTPURLResponse)?.statusCode == 200)

        let got = try await received.waitForValue(timeout: 1.0)
        #expect(got.sessionId == "s1")
    }

    @Test func serverWritesPortFile() async throws {
        // Tidy up from any previous run
        try? FileManager.default.removeItem(at: PathProvider.runtimePortFile)

        let server = HookServer()
        try await server.start()
        defer { Task { try? await server.stop() } }

        let written = try String(contentsOf: PathProvider.runtimePortFile, encoding: .utf8)
        let port = await server.port
        #expect(Int(written) == port)
    }
}

actor ExpectingActor<T: Sendable> {
    private var value: T?
    private var continuation: CheckedContinuation<T, Error>?

    func set(_ v: T) {
        if let c = continuation { continuation = nil; c.resume(returning: v); return }
        value = v
    }

    func waitForValue(timeout: TimeInterval) async throws -> T {
        if let v = value { value = nil; return v }
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { c in
                    Task { await self.setContinuation(c) }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError()
            }
            let v = try await group.next()!
            group.cancelAll()
            return v
        }
    }

    private func setContinuation(_ c: CheckedContinuation<T, Error>) {
        if let v = value { value = nil; c.resume(returning: v); return }
        continuation = c
    }
}

struct TimeoutError: Error {}

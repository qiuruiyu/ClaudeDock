import Foundation
import Testing
@testable import ClaudeDock

@MainActor
@Suite struct SessionStoreTests {
    private func tmp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    @Test func ingestSessionStartCreatesSession() {
        let store = SessionStore(aliases: AliasStore(fileURL: tmp()))
        let evt = HookEvent(sessionId: "s1", cwd: "/tmp",
                            hookEventName: .sessionStart,
                            transcriptPath: "/tmp/x.jsonl")
        store.ingest(event: evt, hint: TerminalHint())
        #expect(store.sessions.count == 1)
        #expect(store.sessions.first?.status == .starting)
    }

    @Test func ingestUserPromptThenStop() {
        let store = SessionStore(aliases: AliasStore(fileURL: tmp()))
        let base = HookEvent(sessionId: "s", cwd: "/tmp",
                             hookEventName: .sessionStart,
                             transcriptPath: "/tmp/x.jsonl")
        store.ingest(event: base, hint: TerminalHint())
        store.ingest(event: HookEvent(sessionId: "s", cwd: "/tmp",
                                      hookEventName: .userPromptSubmit,
                                      transcriptPath: "/tmp/x.jsonl"),
                     hint: TerminalHint())
        #expect(store.sessions.first?.status == .thinking)
        store.ingest(event: HookEvent(sessionId: "s", cwd: "/tmp",
                                      hookEventName: .stop,
                                      transcriptPath: "/tmp/x.jsonl"),
                     hint: TerminalHint())
        #expect(store.sessions.first?.status == .idle)
    }

    @Test func twoDifferentCwdsCreateTwoSessions() {
        let store = SessionStore(aliases: AliasStore(fileURL: tmp()))
        store.ingest(event: HookEvent(sessionId: "a", cwd: "/a",
                                      hookEventName: .sessionStart,
                                      transcriptPath: "/tmp/a.jsonl"),
                     hint: TerminalHint())
        store.ingest(event: HookEvent(sessionId: "b", cwd: "/b",
                                      hookEventName: .sessionStart,
                                      transcriptPath: "/tmp/b.jsonl"),
                     hint: TerminalHint())
        #expect(store.sessions.count == 2)
    }

    @Test func sameCwdGetsAutoNumber() {
        let store = SessionStore(aliases: AliasStore(fileURL: tmp()))
        let mk: (String) -> HookEvent = { sid in
            HookEvent(sessionId: sid, cwd: "/tmp/same",
                      hookEventName: .sessionStart,
                      transcriptPath: "/tmp/x.jsonl")
        }
        store.ingest(event: mk("a"), hint: TerminalHint(ppid: 1))
        store.ingest(event: mk("b"), hint: TerminalHint(ppid: 2))
        let nums = store.sessions.compactMap { $0.sameCwdIndex }
        #expect(nums.sorted() == [1, 2])
    }

    @Test func differentCwdsHaveNoNumber() {
        let store = SessionStore(aliases: AliasStore(fileURL: tmp()))
        store.ingest(event: HookEvent(sessionId: "a", cwd: "/a",
                                      hookEventName: .sessionStart,
                                      transcriptPath: ""),
                     hint: TerminalHint())
        store.ingest(event: HookEvent(sessionId: "b", cwd: "/b",
                                      hookEventName: .sessionStart,
                                      transcriptPath: ""),
                     hint: TerminalHint())
        #expect(store.sessions.allSatisfy { $0.sameCwdIndex == nil })
    }

    @Test func renameUpdatesAliasStore() throws {
        let url = tmp()
        let store = SessionStore(aliases: AliasStore(fileURL: url))
        store.ingest(event: HookEvent(sessionId: "a", cwd: "/x",
                                      hookEventName: .sessionStart,
                                      transcriptPath: ""),
                     hint: TerminalHint())
        let wk = store.sessions[0].identity.workKey
        store.rename(workKey: wk, to: "登录页重构")
        let reloaded = AliasStore(fileURL: url)
        #expect(reloaded.meta(forWorkKey: wk)?.alias == "登录页重构")
    }

    @Test func forgetRemovesSessionFromPublishedArray() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ss-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = SessionStore(aliases: AliasStore(fileURL: url))
        let event = HookEvent(sessionId: "abc",
                              cwd: "/tmp/x",
                              hookEventName: .sessionStart,
                              transcriptPath: "/tmp/x.jsonl")
        store.ingest(event: event, hint: TerminalHint(ppid: 1))
        let id = store.sessions[0].id
        #expect(store.sessions.count == 1)

        store.forget(sessionId: id)
        #expect(store.sessions.count == 0)
    }

    @Test func forgetFiltersFutureIngestForSameId() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ss-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = SessionStore(aliases: AliasStore(fileURL: url))

        let event = HookEvent(sessionId: "abc",
                              cwd: "/tmp/x",
                              hookEventName: .sessionStart,
                              transcriptPath: "/tmp/x.jsonl")
        store.ingest(event: event, hint: TerminalHint(ppid: 1))
        let id = store.sessions[0].id
        store.forget(sessionId: id)
        #expect(store.sessions.count == 0)

        // Re-ingest the same id — must be dropped silently.
        let followUp = HookEvent(sessionId: "abc",
                                 cwd: "/tmp/x",
                                 hookEventName: .userPromptSubmit,
                                 transcriptPath: "/tmp/x.jsonl")
        store.ingest(event: followUp, hint: TerminalHint(ppid: 1))
        #expect(store.sessions.count == 0, "forgotten ids stay filtered for the rest of the run")
    }

    @Test func forgetDoesNotAffectOtherSessions() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ss-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = SessionStore(aliases: AliasStore(fileURL: url))
        let eventA = HookEvent(sessionId: "aaa",
                               cwd: "/tmp/a",
                               hookEventName: .sessionStart,
                               transcriptPath: "/tmp/a.jsonl")
        let eventB = HookEvent(sessionId: "bbb",
                               cwd: "/tmp/b",
                               hookEventName: .sessionStart,
                               transcriptPath: "/tmp/b.jsonl")
        store.ingest(event: eventA, hint: TerminalHint(ppid: 1))
        store.ingest(event: eventB, hint: TerminalHint(ppid: 2))
        let idA = store.sessions.first { $0.identity.sessionId == "aaa" }!.id
        #expect(store.sessions.count == 2)

        store.forget(sessionId: idA)
        #expect(store.sessions.count == 1)
        #expect(store.sessions.first?.identity.sessionId == "bbb")

        // 'b' continues to receive events normally.
        let promptB = HookEvent(sessionId: "bbb",
                                cwd: "/tmp/b",
                                hookEventName: .userPromptSubmit,
                                transcriptPath: "/tmp/b.jsonl")
        store.ingest(event: promptB, hint: TerminalHint(ppid: 2))
        let bAfter = store.sessions.first { $0.identity.sessionId == "bbb" }!
        #expect(bAfter.status == .thinking)
    }

    // MARK: - injectDiscovered

    @Test func injectDiscoveredAddsNewSession() {
        let store = SessionStore(aliases: AliasStore(fileURL: tmp()))
        let identity = SessionIdentity.synthesize(sessionId: "s1", cwd: "/x",
                                                  ppid: 123, tty: "/dev/ttys001")
        store.injectDiscovered(identity: identity,
                               transcriptPath: "/x/.t.jsonl",
                               status: .idle,
                               lastEventAt: Date(timeIntervalSince1970: 1000))
        #expect(store.sessions.count == 1)
        #expect(store.sessions.first?.status == .idle)
        #expect(store.sessions.first?.transcriptPath == "/x/.t.jsonl")
    }

    @Test func injectDiscoveredSkipsIfAlreadyTracked() {
        let store = SessionStore(aliases: AliasStore(fileURL: tmp()))
        // Hook arrives first → creates session with status=.starting then engine
        // transitions to .idle on Stop.
        store.ingest(event: HookEvent(sessionId: "s1", cwd: "/x",
                                       hookEventName: .sessionStart,
                                       transcriptPath: "/x/.t.jsonl"),
                     hint: TerminalHint(ppid: 7777, tty: "/dev/ttys009"))
        store.ingest(event: HookEvent(sessionId: "s1", cwd: "/x",
                                       hookEventName: .stop,
                                       transcriptPath: "/x/.t.jsonl"),
                     hint: TerminalHint(ppid: 7777, tty: "/dev/ttys009"))
        let preStatus = store.sessions.first!.status
        #expect(preStatus == .idle)
        // Then discovery runs → same fingerprint → must be a no-op (not
        // overwriting the .idle from the hook flow).
        let identity = SessionIdentity.synthesize(sessionId: "s1", cwd: "/x",
                                                  ppid: 7777, tty: "/dev/ttys009")
        store.injectDiscovered(identity: identity,
                               transcriptPath: "/x/.t.jsonl",
                               status: .thinking,
                               lastEventAt: Date())
        #expect(store.sessions.count == 1)
        #expect(store.sessions.first?.status == .idle, "Discovery must not overwrite hook-tracked status")
    }

    @Test func hookEventAfterDiscoveryMergesNotDuplicates() {
        let store = SessionStore(aliases: AliasStore(fileURL: tmp()))
        // Discovery happens first.
        let identity = SessionIdentity.synthesize(sessionId: "s1", cwd: "/x",
                                                  ppid: 555, tty: "/dev/ttys001")
        store.injectDiscovered(identity: identity,
                               transcriptPath: "/x/.t.jsonl",
                               status: .idle,
                               lastEventAt: Date(timeIntervalSince1970: 1000))
        #expect(store.sessions.count == 1)
        // Then a real hook for the same session — must merge, not duplicate.
        store.ingest(event: HookEvent(sessionId: "s1", cwd: "/x",
                                       hookEventName: .userPromptSubmit,
                                       transcriptPath: "/x/.t.jsonl"),
                     hint: TerminalHint(ppid: 555, tty: "/dev/ttys001"))
        #expect(store.sessions.count == 1, "Hook must merge into discovered row, not duplicate")
        #expect(store.sessions.first?.status == .thinking)
    }

    @Test func injectDiscoveredRespectsForgottenIds() {
        let store = SessionStore(aliases: AliasStore(fileURL: tmp()))
        let identity = SessionIdentity.synthesize(sessionId: "s1", cwd: "/x",
                                                  ppid: 9, tty: nil)
        store.forget(sessionId: identity.fingerprint)
        store.injectDiscovered(identity: identity,
                               transcriptPath: "/x/.t.jsonl",
                               status: .idle,
                               lastEventAt: Date())
        #expect(store.sessions.isEmpty, "Forgotten sessions must stay forgotten through discovery")
    }

    // MARK: - markEnded (iter-066)

    @Test func markEndedTransitionsToEnded() {
        let store = SessionStore(aliases: AliasStore(fileURL: tmp()))
        store.ingest(event: HookEvent(sessionId: "s1", cwd: "/x",
                                       hookEventName: .sessionStart,
                                       transcriptPath: "/x/.t.jsonl"),
                     hint: TerminalHint(ppid: 100))
        let id = store.sessions[0].id
        #expect(store.sessions[0].status != .ended)
        store.markEnded(sessionId: id)
        #expect(store.sessions[0].status == .ended)
    }

    @Test func markEndedIsIdempotent() {
        let store = SessionStore(aliases: AliasStore(fileURL: tmp()))
        store.ingest(event: HookEvent(sessionId: "s1", cwd: "/x",
                                       hookEventName: .sessionStart,
                                       transcriptPath: "/x/.t.jsonl"),
                     hint: TerminalHint(ppid: 100))
        let id = store.sessions[0].id
        store.markEnded(sessionId: id)
        let firstTime = store.sessions[0].lastEventAt
        // Second call should be a no-op — status already .ended, no
        // bump to lastEventAt.
        store.markEnded(sessionId: id)
        #expect(store.sessions[0].lastEventAt == firstTime)
    }

    @Test func markEndedUnknownIdNoOps() {
        let store = SessionStore(aliases: AliasStore(fileURL: tmp()))
        store.ingest(event: HookEvent(sessionId: "s1", cwd: "/x",
                                       hookEventName: .sessionStart,
                                       transcriptPath: "/x/.t.jsonl"),
                     hint: TerminalHint(ppid: 100))
        let initialStatus = store.sessions[0].status
        store.markEnded(sessionId: "not-a-real-fingerprint")
        #expect(store.sessions.count == 1)
        #expect(store.sessions[0].status == initialStatus)
    }
}

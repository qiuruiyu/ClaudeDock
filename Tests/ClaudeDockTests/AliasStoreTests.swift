import Foundation
import Testing
@testable import ClaudeDock

@Suite struct AliasStoreTests {
    @Test func setAndGetAcrossInstances() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("aliases-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            let store = AliasStore(fileURL: url)
            store.upsert(workKey: "abc123", alias: "登录页重构", color: .orange, pinned: true)
            try store.save()
        }
        let reloaded = AliasStore(fileURL: url)
        #expect(reloaded.meta(forWorkKey: "abc123")?.alias == "登录页重构")
        #expect(reloaded.meta(forWorkKey: "abc123")?.color == .orange)
        #expect(reloaded.meta(forWorkKey: "abc123")?.pinned == true)
    }

    @Test func unknownKeyReturnsNil() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("aliases-\(UUID().uuidString).json")
        let store = AliasStore(fileURL: url)
        #expect(store.meta(forWorkKey: "ghost") == nil)
    }
}

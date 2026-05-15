import Foundation
import Testing
@testable import ClaudeDock

@Suite struct ColorAssignerTests {
    @Test func stableColorForSameWorkKey() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AliasStore(fileURL: url)
        let assigner = ColorAssigner()
        let c1 = assigner.color(forWorkKey: "abc", in: store)
        try store.save()
        let store2 = AliasStore(fileURL: url)
        let c2 = assigner.color(forWorkKey: "abc", in: store2)
        #expect(c1 == c2)
    }

    @Test func respectExistingColor() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = AliasStore(fileURL: url)
        store.upsert(workKey: "wk", color: .pink)
        #expect(ColorAssigner().color(forWorkKey: "wk", in: store) == .pink)
    }
}

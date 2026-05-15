import Foundation
import Testing
@testable import ClaudeDock

@Suite struct PersistenceTests {
    struct Box: Codable, Equatable { let n: Int; let s: String }

    @Test func roundTrip() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("box-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Persistence.write(Box(n: 7, s: "hello"), to: url)
        let got: Box? = Persistence.read(Box.self, from: url)
        #expect(got == Box(n: 7, s: "hello"))
    }

    @Test func missingFileReturnsNil() {
        let url = URL(fileURLWithPath: "/nonexistent/x.json")
        let got: Box? = Persistence.read(Box.self, from: url)
        #expect(got == nil)
    }
}

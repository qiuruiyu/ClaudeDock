import Foundation
import Testing
@testable import ClaudeDock

@Suite struct PreferencesTests {
    @Test func defaultsAreSensible() {
        let p = Preferences()
        #expect(p.notifyWaitingInput == true)
        #expect(p.notifyDone == false)
        #expect(p.aggregationWindowSeconds == 30)
        #expect(p.theme == .system)
    }

    @Test func roundTrip() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("prefs-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = Preferences()
        p.notifyDone = true
        p.aggregationWindowSeconds = 45
        try Persistence.write(p, to: url)
        let loaded = Persistence.read(Preferences.self, from: url)
        #expect(loaded == p)
    }
}

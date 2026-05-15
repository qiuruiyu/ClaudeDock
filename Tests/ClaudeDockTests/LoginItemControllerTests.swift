import Foundation
import Testing
@testable import ClaudeDock

@Suite struct LoginItemControllerTests {
    @Test func launchAtLoginDefaultsFalse() {
        let p = Preferences()
        #expect(p.launchAtLogin == false)
    }

    @Test func launchAtLoginRoundTripsThroughPersistence() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("prefs-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = Preferences()
        p.launchAtLogin = true
        try Persistence.write(p, to: url)
        let loaded = Persistence.read(Preferences.self, from: url)
        #expect(loaded?.launchAtLogin == true)
    }

    /// Smoke test the controller — actual register/unregister requires a bundled
    /// .app, so we only verify the API can be instantiated and reports a status.
    @Test @MainActor func controllerReportsAStatus() {
        let c = LoginItemController()
        let status = c.currentStatus
        // Any of the SMAppService.Status cases is acceptable; the call must not crash.
        #expect([.enabled, .notRegistered, .notFound, .requiresApproval].contains(status))
    }
}

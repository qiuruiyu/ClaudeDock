import Foundation
import Testing
@testable import ClaudeDock

@Suite struct InfoPlistTests {
    private func sourceInfoPlistURL() -> URL {
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<6 {
            let candidate = dir.appendingPathComponent("Sources/ClaudeDock/Resources/Info.plist")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            dir.deleteLastPathComponent()
        }
        fatalError("Could not locate Sources/ClaudeDock/Resources/Info.plist from \(FileManager.default.currentDirectoryPath)")
    }

    @Test func infoPlistHasMenuBarOnlyConfig() throws {
        let url = sourceInfoPlistURL()
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]
        #expect(plist["LSUIElement"] as? Bool == true, "LSUIElement must be true so the app does not show in Dock")
        #expect(plist["CFBundleIdentifier"] as? String == "com.claudedock.app")
        #expect(plist["CFBundleName"] as? String == "ClaudeDock")
        #expect(plist["CFBundleExecutable"] as? String == "ClaudeDock")
        #expect((plist["NSAppleEventsUsageDescription"] as? String)?.isEmpty == false,
                "AppleEvents usage description is required for iTerm/Terminal.app focus to ever prompt instead of fail silently")
        #expect((plist["NSUserNotificationsUsageDescription"] as? String)?.isEmpty == false)
        #expect(plist["LSMinimumSystemVersion"] as? String == "14.0")
    }
}

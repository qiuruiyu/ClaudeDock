import Foundation
import Testing
@testable import ClaudeDock

@Suite struct NameResolverTests {
    @Test func aliasOverridesEverything() {
        let store = AliasStore(fileURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
        store.upsert(workKey: "wk", alias: "登录页重构")
        #expect(NameResolver().resolve(cwd: "/foo/bar", workKey: "wk", aliasStore: store) == "登录页重构")
    }

    @Test func homeRendersAsHome() {
        let store = AliasStore(fileURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
        let home = NSHomeDirectory()
        #expect(NameResolver().resolve(cwd: home, workKey: "wk", aliasStore: store) == "Home")
    }

    @Test func rootRendersAsRoot() {
        let store = AliasStore(fileURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
        #expect(NameResolver().resolve(cwd: "/", workKey: "wk", aliasStore: store) == "Root")
    }

    @Test func basenameFallback() {
        let store = AliasStore(fileURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
        // Use /private/tmp which is unlikely to be a git repo
        #expect(NameResolver().resolve(cwd: "/private/tmp", workKey: "wk", aliasStore: store) == "tmp")
    }
}

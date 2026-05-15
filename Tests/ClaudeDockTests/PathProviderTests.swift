import Foundation
import Testing
@testable import ClaudeDock

@Suite struct PathProviderTests {
    @Test func applicationSupportPathContainsClaudeDock() {
        let url = PathProvider.applicationSupportRoot
        #expect(url.path.hasSuffix("/Library/Application Support/ClaudeDock"),
                "Got: \(url.path)")
    }

    @Test func runtimePortFileLocation() {
        let url = PathProvider.runtimePortFile
        #expect(url.path.hasSuffix("/Library/Application Support/ClaudeDock/runtime/port"))
    }

    @Test func marketplaceLayoutPaths() {
        #expect(PathProvider.marketplaceRoot.path
                    .hasSuffix("/ClaudeDock/marketplace"),
                "Got: \(PathProvider.marketplaceRoot.path)")
        #expect(PathProvider.marketplaceManifest.path
                    .hasSuffix("/ClaudeDock/marketplace/.claude-plugin/marketplace.json"),
                "Got: \(PathProvider.marketplaceManifest.path)")
        #expect(PathProvider.pluginManifest.path
                    .hasSuffix("/ClaudeDock/marketplace/claudedock/.claude-plugin/plugin.json"),
                "Got: \(PathProvider.pluginManifest.path)")
    }
}

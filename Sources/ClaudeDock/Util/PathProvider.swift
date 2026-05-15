import Foundation

enum PathProvider {
    static let applicationSupportRoot: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ClaudeDock", isDirectory: true)
    }()

    static var runtimeDirectory: URL { applicationSupportRoot.appendingPathComponent("runtime", isDirectory: true) }
    static var runtimePortFile: URL { runtimeDirectory.appendingPathComponent("port") }
    static var runtimePidFile:  URL { runtimeDirectory.appendingPathComponent("pid") }

    // Claude Code 2.x requires plugins to live inside a marketplace directory
    // (a `.claude-plugin/marketplace.json` catalog referencing one or more
    // plugins). See spec §3.2.
    static var marketplaceRoot: URL { applicationSupportRoot.appendingPathComponent("marketplace", isDirectory: true) }
    static var marketplaceManifest: URL { marketplaceRoot.appendingPathComponent(".claude-plugin/marketplace.json") }
    static var pluginRoot: URL { marketplaceRoot.appendingPathComponent("claudedock", isDirectory: true) }
    static var pluginManifest: URL { pluginRoot.appendingPathComponent(".claude-plugin/plugin.json") }
    static var pluginHookScript: URL { pluginRoot.appendingPathComponent("hook.sh") }

    static var stateFile: URL { applicationSupportRoot.appendingPathComponent("state.json") }
    static var aliasesFile: URL { applicationSupportRoot.appendingPathComponent("aliases.json") }
    static var preferencesFile: URL { applicationSupportRoot.appendingPathComponent("preferences.json") }
    static var logsDirectory: URL { applicationSupportRoot.appendingPathComponent("logs", isDirectory: true) }

    static func ensureDirectoriesExist() throws {
        for url in [applicationSupportRoot, runtimeDirectory, logsDirectory] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

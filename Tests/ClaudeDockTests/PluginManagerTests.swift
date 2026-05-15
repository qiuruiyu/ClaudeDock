import Foundation
import Testing
@testable import ClaudeDock

@Suite(.serialized) struct PluginManagerTests {
    @Test func regenerateWritesManifestAndHookScript() throws {
        try? FileManager.default.removeItem(at: PathProvider.marketplaceRoot)

        let mgr = PluginManager()
        try mgr.regenerate()

        // All three files materialized at the new marketplace-aware paths.
        #expect(FileManager.default.fileExists(atPath: PathProvider.marketplaceManifest.path))
        #expect(FileManager.default.fileExists(atPath: PathProvider.pluginManifest.path))
        #expect(FileManager.default.fileExists(atPath: PathProvider.pluginHookScript.path))

        // marketplace.json sanity
        let mjson = try Data(contentsOf: PathProvider.marketplaceManifest)
        let mobj = try JSONSerialization.jsonObject(with: mjson) as! [String: Any]
        #expect(mobj["name"] as? String == "claudedock")
        let plugins = mobj["plugins"] as! [[String: Any]]
        #expect(plugins.count == 1)
        #expect(plugins[0]["name"] as? String == "claudedock")
        #expect(plugins[0]["source"] as? String == "./claudedock")

        // plugin.json sanity (basic)
        let pjson = try Data(contentsOf: PathProvider.pluginManifest)
        let pobj = try JSONSerialization.jsonObject(with: pjson) as! [String: Any]
        #expect(pobj["name"] as? String == "claudedock")

        // hook.sh is executable
        let attrs = try FileManager.default.attributesOfItem(atPath: PathProvider.pluginHookScript.path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.intValue ?? 0
        #expect((perms & 0o111) == 0o111, "hook.sh must be executable; got \(String(perms, radix: 8))")
    }

    @Test func pluginManifestHasFiveHookKinds() throws {
        try? FileManager.default.removeItem(at: PathProvider.marketplaceRoot)
        try PluginManager().regenerate()

        let json = try Data(contentsOf: PathProvider.pluginManifest)
        let obj = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        let hooks = obj["hooks"] as! [String: Any]
        #expect(hooks["SessionStart"] != nil)
        #expect(hooks["UserPromptSubmit"] != nil)
        #expect(hooks["Notification"] != nil)
        #expect(hooks["Stop"] != nil)
        #expect(hooks["SessionEnd"] != nil)
    }

    @Test func hookCommandQuotedForPathsWithSpaces() throws {
        // Regression: Application Support contains a space, so the raw command
        // ${CLAUDE_PLUGIN_ROOT}/hook.sh would be word-split by /bin/sh -c at
        // execution time. We must wrap in escaped double quotes inside JSON.
        try? FileManager.default.removeItem(at: PathProvider.marketplaceRoot)
        try PluginManager().regenerate()
        let json = try Data(contentsOf: PathProvider.pluginManifest)
        let obj = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        let hooks = obj["hooks"] as! [String: [[String: Any]]]
        let firstCmd = ((hooks["SessionStart"]?.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String) ?? ""
        #expect(firstCmd.hasPrefix("\"") && firstCmd.hasSuffix("\""),
                "command must be wrapped in double quotes for spaces in path; got: \(firstCmd)")
    }

    @Test func installStateBeforeAndAfterRegenerate() throws {
        try? FileManager.default.removeItem(at: PathProvider.marketplaceRoot)
        #expect(PluginManager().installState == .filesMissing)

        try PluginManager().regenerate()
        #expect(PluginManager().installState == .filesPresent)
    }
}

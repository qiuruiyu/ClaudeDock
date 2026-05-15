import Foundation
import Logging

struct PluginManager {
    static let pluginVersion = "0.1.0"
    private let log = Logger(label: "claudedock.plugin")

    enum InstallState: Equatable { case filesMissing, filesPresent }

    var installState: InstallState {
        let mm = FileManager.default.fileExists(atPath: PathProvider.marketplaceManifest.path)
        let pm = FileManager.default.fileExists(atPath: PathProvider.pluginManifest.path)
        let h  = FileManager.default.fileExists(atPath: PathProvider.pluginHookScript.path)
        return (mm && pm && h) ? .filesPresent : .filesMissing
    }

    func regenerate() throws {
        try PathProvider.ensureDirectoriesExist()
        // marketplaceRoot/.claude-plugin/ — holds marketplace.json (catalog)
        try FileManager.default.createDirectory(
            at: PathProvider.marketplaceManifest.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        // marketplaceRoot/claudedock/.claude-plugin/ — holds plugin.json (manifest)
        try FileManager.default.createDirectory(
            at: PathProvider.pluginManifest.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try writeMarketplaceManifest()
        try writePluginManifest()
        try writeHookScript()
        log.info("Plugin files regenerated at \(PathProvider.marketplaceRoot.path)")
    }

    private func writeMarketplaceManifest() throws {
        let catalog: [String: Any] = [
            "name": "claudedock",
            "description": "Local marketplace wrapping the ClaudeDock plugin",
            "owner": ["name": "Joseph Qiu"],
            "plugins": [[
                "name": "claudedock",
                "source": "./claudedock",
                "description": "Floating dock for Claude Code session status",
                "version": Self.pluginVersion,
            ]],
        ]
        let data = try JSONSerialization.data(withJSONObject: catalog,
                                              options: [.prettyPrinted, .sortedKeys])
        try data.write(to: PathProvider.marketplaceManifest, options: .atomic)
    }

    private func writePluginManifest() throws {
        let event: [String: Any] = [
            "matcher": "*",
            "hooks": [[
                "type": "command",
                // Wrap in escaped double quotes so the resolved path survives
                // /bin/sh -c word-splitting at spaces (Application Support contains a space).
                "command": #""${CLAUDE_PLUGIN_ROOT}/hook.sh""#
            ]]
        ]
        let manifest: [String: Any] = [
            "name": "claudedock",
            "version": Self.pluginVersion,
            "description": "Floating dock for Claude Code session status",
            "hooks": [
                "SessionStart":     [event],
                "UserPromptSubmit": [event],
                "Notification":     [event],
                "Stop":             [event],
                "SessionEnd":       [event],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: manifest,
                                              options: [.prettyPrinted, .sortedKeys])
        try data.write(to: PathProvider.pluginManifest, options: .atomic)
    }

    private func writeHookScript() throws {
        let script = #"""
        #!/bin/bash
        # ClaudeDock hook wrapper (generated). Fast-return; never blocks Claude Code.
        set +e
        APP_SUPPORT="$HOME/Library/Application Support/ClaudeDock"
        [ -r "$APP_SUPPORT/runtime/port" ] || exit 0
        PORT=$(cat "$APP_SUPPORT/runtime/port" 2>/dev/null)
        [ -z "$PORT" ] && exit 0

        # URL-encode space & ampersand for safety in query string.
        enc() {
          local s="$1"
          s="${s// /%20}"
          s="${s//&/%26}"
          printf '%s' "$s"
        }

        TTY=$(/usr/bin/tty 2>/dev/null)
        # `tty` prints "not a tty" when stdin isn't a terminal — claude pipes
        # JSON to us on stdin, so this is the normal case. Squash to empty.
        [ "$TTY" = "not a tty" ] && TTY=""

        QS="ppid=$PPID"
        QS="${QS}&tty=$(enc "$TTY")"
        QS="${QS}&term=$(enc "${TERM_PROGRAM:-}")"
        QS="${QS}&iterm_id=$(enc "${ITERM_SESSION_ID:-}")"
        QS="${QS}&term_session_id=$(enc "${TERM_SESSION_ID:-}")"
        QS="${QS}&vscode_pid=$(enc "${VSCODE_PID:-}")"

        cat - | curl -sS -m 2 \
          -X POST "http://127.0.0.1:${PORT}/hook?${QS}" \
          -H 'Content-Type: application/json' \
          --data-binary @- >/dev/null 2>&1 &
        disown 2>/dev/null
        exit 0
        """#
        try script.data(using: .utf8)!.write(to: PathProvider.pluginHookScript, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o755)],
                                              ofItemAtPath: PathProvider.pluginHookScript.path)
    }
}

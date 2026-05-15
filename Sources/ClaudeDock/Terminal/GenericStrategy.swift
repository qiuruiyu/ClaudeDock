import AppKit

struct GenericStrategy: GenericFocusing {
    @MainActor
    func activate(app rawName: String) async -> FocusResult {
        let bundleId = bundleIdentifier(for: rawName)
        // Prefer activating an already-running instance — openApplication is a no-op
        // for already-running apps, so the user wouldn't see anything happen.
        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) {
            // macOS 14+: activateIgnoringOtherApps is deprecated and a no-op; pass no options.
            running.activate()
            return .activatedAppOnly(app: rawName)
        }
        // Not running — launch it
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return .failed(reason: "App not found: \(rawName) (\(bundleId))")
        }
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: .init())
            return .activatedAppOnly(app: rawName)
        } catch {
            return .failed(reason: "Open failed: \(error.localizedDescription)")
        }
    }

    private func bundleIdentifier(for raw: String) -> String {
        switch raw {
        case "Apple_Terminal", "Terminal":  return "com.apple.Terminal"
        case "iTerm.app", "iTerm":          return "com.googlecode.iterm2"
        case "ghostty":                     return "com.mitchellh.ghostty"
        case "WarpTerminal":                return "dev.warp.Warp"
        case "vscode":                      return "com.microsoft.VSCode"
        case "cursor":                      return "com.todesktop.230313mzl4w4u92"
        default:                            return raw
        }
    }
}

import SwiftUI
import AppKit

struct PluginSettingsView: View {
    @State private var pluginManager = PluginManager()
    @State private var lastReinstallStatus: String?
    @State private var showUninstallSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plugin & Hooks").font(.system(size: 12, weight: .semibold))

            GroupBox("Status") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: pluginManager.installState == .filesPresent
                              ? "checkmark.circle.fill"
                              : "xmark.circle.fill")
                            .foregroundStyle(pluginManager.installState == .filesPresent ? .green : .red)
                        Text(pluginManager.installState == .filesPresent
                             ? "Plugin files present at the marketplace path."
                             : "Plugin files missing.")
                            .font(.system(size: 11))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Marketplace path:")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.top, 2)
                    Text(PathProvider.marketplaceRoot.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 2)
            }

            GroupBox("Install commands") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Run these once in any terminal to wire ClaudeDock into Claude Code:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("claude plugin marketplace add \"\(PathProvider.marketplaceRoot.path)\"")
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    Text("claude plugin install claudedock@claudedock")
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    HStack {
                        Button("Copy install commands") { copyInstallCommands() }
                            .controlSize(.small)
                        Button("Reinstall plugin files") { reinstall() }
                            .controlSize(.small)
                    }
                    if let s = lastReinstallStatus {
                        Text(s).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }

            GroupBox("Uninstall") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Three-step explicit uninstall. ClaudeDock never modifies ~/.claude/settings.json — there's nothing to restore.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Uninstall…") { showUninstallSheet = true }
                        .controlSize(.small)
                }
                .padding(.vertical, 2)
            }
            .sheet(isPresented: $showUninstallSheet) {
                UninstallSheet(isPresented: $showUninstallSheet)
            }
        }
    }

    private func copyInstallCommands() {
        let cmds = """
        claude plugin marketplace add "\(PathProvider.marketplaceRoot.path)"
        claude plugin install claudedock@claudedock
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmds, forType: .string)
    }

    private func reinstall() {
        do {
            try pluginManager.regenerate()
            lastReinstallStatus = "✓ Plugin files regenerated."
        } catch {
            lastReinstallStatus = "✗ Regenerate failed: \(error.localizedDescription)"
        }
    }
}

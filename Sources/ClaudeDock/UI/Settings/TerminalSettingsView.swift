import SwiftUI
import AppKit

struct TerminalSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Terminal").font(.system(size: 12, weight: .semibold))

            GroupBox("Click-to-focus support") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("iTerm2 — precise tab focus", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                    Label("Terminal.app — precise tab focus", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                    Label("Ghostty / Warp / Alacritty — activate app only", systemImage: "minus.circle")
                        .foregroundStyle(.secondary)
                    Label("VS Code / Cursor — activate app only (precise focus in v1.1 via ClaudeDock Bridge extension)",
                          systemImage: "minus.circle")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 11))
                .padding(.vertical, 2)
            }

            GroupBox("AppleScript / Automation permission") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ClaudeDock needs Automation permission to control iTerm2 and Terminal.app for precise tab focus.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open System Settings → Privacy → Automation") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

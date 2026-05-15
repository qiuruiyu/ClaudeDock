import SwiftUI
import AppKit

struct UninstallSheet: View {
    @Binding var isPresented: Bool
    @State private var dataErased = false
    @State private var lastError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Uninstall ClaudeDock").font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Done") { isPresented = false }.controlSize(.small)
            }

            stepHeader(1, "Uninstall plugin + remove marketplace")
            VStack(alignment: .leading, spacing: 4) {
                Text("Paste this into any terminal where Claude Code is available:")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Text(uninstallCommands)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(6)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .textSelection(.enabled)
                Button("Copy commands") { copyCommands() }.controlSize(.small)
            }

            stepHeader(2, "Delete ClaudeDock data folder")
            VStack(alignment: .leading, spacing: 4) {
                Text(PathProvider.applicationSupportRoot.path)
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                HStack {
                    Button(dataErased ? "Deleted ✓" : "Delete data folder") { eraseData() }
                        .disabled(dataErased)
                        .controlSize(.small)
                    if let e = lastError {
                        Text(e).font(.system(size: 10)).foregroundStyle(.orange)
                    }
                }
            }

            stepHeader(3, "Trash the app")
            Text("Drag `ClaudeDock.app` from /Applications to the Trash, or right-click → Move to Trash.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Divider()
            Text("We never modified `~/.claude/settings.json`, so there's nothing to restore.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.green)
        }
        .padding(20)
        .frame(width: 420)
    }

    private func stepHeader(_ n: Int, _ title: String) -> some View {
        HStack(spacing: 6) {
            Text("\(n).").font(.system(size: 12, weight: .bold))
            Text(title).font(.system(size: 12, weight: .semibold))
        }
    }

    private var uninstallCommands: String {
        """
        claude plugin uninstall claudedock@claudedock
        claude plugin marketplace remove claudedock
        """
    }

    private func copyCommands() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(uninstallCommands, forType: .string)
    }

    private func eraseData() {
        do {
            try DataFolderEraser.erase(at: PathProvider.applicationSupportRoot)
            dataErased = true
        } catch {
            lastError = "Erase failed: \(error.localizedDescription)"
        }
    }
}

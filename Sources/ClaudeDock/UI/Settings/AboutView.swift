import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About").font(.system(size: 12, weight: .semibold))

            GroupBox("ClaudeDock") {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version 0.1.0 (Plan B in progress)")
                        .font(.system(size: 11))
                    Text("Status indicator + popover manager for Claude Code sessions on macOS.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }

            GroupBox("Privacy") {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Fully local — no telemetry, no outbound network beyond 127.0.0.1.", systemImage: "lock.shield")
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Never reads Claude Code transcript content (only the file's mtime as a heartbeat fallback).", systemImage: "doc.text")
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Never modifies ~/.claude/settings.json directly. All hook registration flows through `claude plugin install` (your CLI runs the change visibly).", systemImage: "checkmark.seal")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 11))
                .padding(.vertical, 2)
            }

            GroupBox("Open source") {
                Text("Source, spec, and progress log live in this repo. See docs/superpowers/specs/ and docs/superpowers/plans/ for the design.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 2)
            }
        }
    }
}

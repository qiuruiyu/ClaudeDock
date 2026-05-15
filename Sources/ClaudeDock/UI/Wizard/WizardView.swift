import SwiftUI
import AppKit

struct WizardView: View {
    @ObservedObject var state: WizardState
    @ObservedObject var prefs: PreferencesStore
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 4) {
                ForEach(Array(WizardState.Step.allCases.dropLast().enumerated()), id: \.offset) { i, _ in
                    Circle()
                        .fill(i <= state.current.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 8)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                Button("Back") { state.back() }
                    .disabled(state.current == .welcome)
                Spacer()
                Button("Skip setup") { state.skip() }
                Spacer()
                Button(state.current == .hotkey ? "Finish" : "Next") {
                    state.next()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520, height: 360)
        .onChange(of: state.current) { _, newValue in
            if newValue == .done { onComplete() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.current {
        case .welcome:
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to ClaudeDock").font(.title2.weight(.semibold))
                Text("A menu-bar app that aggregates the status of every running Claude Code session, with one-click jump-back to the right terminal.")
                Text("ClaudeDock never modifies your `~/.claude/settings.json`. All integration goes through the official Claude Code plugin system.")
                    .foregroundStyle(.secondary)
            }
        case .plugin:
            VStack(alignment: .leading, spacing: 8) {
                Text("Install the plugin").font(.title3.weight(.semibold))
                Text("Run these two commands in any terminal:")
                Text("claude plugin marketplace add \"\(PathProvider.marketplaceRoot.path)\"\nclaude plugin install claudedock@claudedock")
                    .font(.system(size: 11, design: .monospaced))
                    .padding(8)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .textSelection(.enabled)
                Button("Copy commands") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        "claude plugin marketplace add \"\(PathProvider.marketplaceRoot.path)\"\nclaude plugin install claudedock@claudedock",
                        forType: .string)
                }
                .controlSize(.small)
                Text("Once installed, the next session you start with `claude` will show up in ClaudeDock automatically.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        case .notchDock:
            VStack(alignment: .leading, spacing: 8) {
                Text("Optional: Notch Dock").font(.title3.weight(.semibold))
                Text("ClaudeDock can show a small floating panel under the notch (or top-center on notch-less Macs). It expands on hover to show your sessions.")
                Toggle("Enable Notch Dock", isOn: $prefs.prefs.enableNotchDock)
                Text("You can change this later in Settings → Appearance.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        case .hotkey:
            VStack(alignment: .leading, spacing: 8) {
                Text("Optional: Global hotkey").font(.title3.weight(.semibold))
                Text("Default is ⌥ Space. You can change it later in Settings → Hotkey.")
                Toggle("Disable hotkey", isOn: $prefs.prefs.hotkeyDisabled)
                Text("That's all — click Finish and the menu-bar icon will be your home base.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        case .done:
            Color.clear
        }
    }
}

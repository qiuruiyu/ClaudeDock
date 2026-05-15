import SwiftUI
import AppKit

struct HotkeySettingsView: View {
    @ObservedObject var prefs: PreferencesStore
    let onChange: () -> Void
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var lastError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hotkey").font(.system(size: 12, weight: .semibold))

            GroupBox("Global toggle") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Current:")
                            .font(.system(size: 11))
                        Text(currentDisplay)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    HStack {
                        Button(isRecording ? "Press any combo…" : "Record new") {
                            toggleRecording()
                        }
                        .controlSize(.small)
                        Button("Reset to ⌥ Space") {
                            prefs.prefs.hotkeyKeyCode = 49
                            prefs.prefs.hotkeyModifiers = 0x0800
                            prefs.prefs.hotkeyDisabled = false
                            onChange()
                        }
                        .controlSize(.small)
                    }
                    Toggle("Disable hotkey", isOn: $prefs.prefs.hotkeyDisabled)
                        .font(.system(size: 11))
                        .onChange(of: prefs.prefs.hotkeyDisabled) { _, _ in onChange() }
                    if let e = lastError {
                        Text(e).font(.system(size: 10)).foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .onDisappear { stopRecording() }
    }

    private var currentDisplay: String {
        if prefs.prefs.hotkeyDisabled { return "Disabled" }
        let code = prefs.prefs.hotkeyKeyCode ?? 49
        let mods = UInt(prefs.prefs.hotkeyModifiers ?? 0x0800)
        return HotkeyRecorder.displayString(keyCode: code, modifiers: mods)
    }

    private func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        isRecording = true
        lastError = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            let mods = event.modifierFlags
                       .intersection([.command, .option, .control, .shift])
                       .rawValue
            let code = event.keyCode
            switch HotkeyRecorder.validate(keyCode: code, modifiers: mods) {
            case .ok:
                prefs.prefs.hotkeyKeyCode = code
                prefs.prefs.hotkeyModifiers = UInt32(mods)
                prefs.prefs.hotkeyDisabled = false
                onChange()
                stopRecording()
                return nil
            case .rejectedTooLoose:
                lastError = "Need at least one of ⌘ / ⌥ / ⌃ / ⇧."
                return nil
            case .rejectedFunctionOnly:
                lastError = "Function-only combos are reserved."
                return nil
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

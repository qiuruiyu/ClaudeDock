import SwiftUI
import AppKit

@MainActor
final class PopoverMode: ObservableObject {
    enum Mode { case list, settings }
    @Published var mode: Mode = .list
}

struct PopoverRootView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var prefs: PreferencesStore
    @ObservedObject var popoverMode: PopoverMode
    let aliases: AliasStore
    let focuser: TerminalFocuser
    let loginItem: LoginItemController
    let latency: LatencyTracker
    let onHotkeyChange: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Constant ink backdrop so the cross-fade between list and settings
            // never reveals the OS popover's default light surface. Without
            // this, the .opacity portion of the transition flashes white in
            // the gap between the old view fading out and the new view fading in.
            Theme.ink
                .frame(width: Theme.popoverWidth, height: Theme.popoverHeight)

            if popoverMode.mode == .list {
                SessionListView(
                    store: store,
                    aliases: aliases,
                    focuser: focuser,
                    onGearTap: {
                        withAnimation(.easeInOut(duration: 0.22)) { popoverMode.mode = .settings }
                    },
                    onDismiss: onDismiss
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                SettingsView(prefs: prefs, aliases: aliases, loginItem: loginItem, latency: latency, onHotkeyChange: onHotkeyChange, onBack: {
                    withAnimation(.easeInOut(duration: 0.22)) { popoverMode.mode = .list }
                })
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}

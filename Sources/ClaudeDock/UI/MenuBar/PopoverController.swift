import AppKit
import SwiftUI

@MainActor
final class PopoverController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private let popoverMode = PopoverMode()
    private let store: SessionStore
    private let aliases: AliasStore
    private let prefs: PreferencesStore
    private let focuser: TerminalFocuser
    private let loginItem: LoginItemController
    private let latency: LatencyTracker
    private let onHotkeyChange: () -> Void
    private let onRefresh: () -> Void
    private var clickMonitor: Any?

    init(store: SessionStore, aliases: AliasStore, prefs: PreferencesStore, focuser: TerminalFocuser, loginItem: LoginItemController, latency: LatencyTracker, onHotkeyChange: @escaping () -> Void, onRefresh: @escaping () -> Void) {
        self.store = store
        self.aliases = aliases
        self.prefs = prefs
        self.focuser = focuser
        self.loginItem = loginItem
        self.latency = latency
        self.onHotkeyChange = onHotkeyChange
        self.onRefresh = onRefresh
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.delegate = self

        let root = PopoverRootView(
            store: store,
            prefs: prefs,
            popoverMode: popoverMode,
            aliases: aliases,
            focuser: focuser,
            loginItem: loginItem,
            latency: latency,
            onHotkeyChange: onHotkeyChange,
            onRefresh: onRefresh,
            onDismiss: { [weak self] in self?.popover.performClose(nil) }
        )
        popover.contentViewController = NSHostingController(rootView: root)

        installClickMonitor()
    }

    /// NSPopover's `.transient` behavior is unreliable under `LSUIElement` apps —
    /// the app never receives a key-window-loss event, so outside-clicks don't
    /// dismiss. A global NSEvent monitor only fires for events in OTHER apps,
    /// which is exactly the "outside the popover" semantics we want; clicks
    /// inside our popover content remain local and don't trigger the monitor.
    private func installClickMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.popover.isShown {
                    self.popover.performClose(nil)
                }
            }
        }
    }

    func toggle(relativeTo view: NSView) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // LSUIElement (menu-bar-only) apps don't automatically become
            // the active app when the user clicks the status item. Without
            // activating, the popover opens but the FIRST click inside it
            // just promotes the app to active — the click action itself
            // requires a second tap. Force activation here so the first
            // intra-popover click works on the first try.
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
    }

    // MARK: NSPopoverDelegate

    nonisolated func popoverWillClose(_ notification: Notification) {
        // Reset to list view so next open is back to sessions.
        Task { @MainActor in
            self.popoverMode.mode = .list
        }
    }
}

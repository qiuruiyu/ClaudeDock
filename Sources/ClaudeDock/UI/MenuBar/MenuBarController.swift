import AppKit
import Combine

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()
    private let store: SessionStore
    private let aliases: AliasStore
    private let prefs: PreferencesStore
    private let focuser: TerminalFocuser
    private let loginItem: LoginItemController
    private let latency: LatencyTracker
    private let onHotkeyChange: () -> Void
    private let popoverController: PopoverController

    init(store: SessionStore, aliases: AliasStore, prefs: PreferencesStore, focuser: TerminalFocuser, loginItem: LoginItemController, latency: LatencyTracker, onHotkeyChange: @escaping () -> Void) {
        self.store = store
        self.aliases = aliases
        self.prefs = prefs
        self.focuser = focuser
        self.loginItem = loginItem
        self.latency = latency
        self.onHotkeyChange = onHotkeyChange
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.popoverController = PopoverController(store: store, aliases: aliases, prefs: prefs, focuser: focuser, loginItem: loginItem, latency: latency, onHotkeyChange: onHotkeyChange)

        statusItem.button?.image = StatusIconRenderer.image(for: .gray)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleStatusItemClick(_:))
        // Right-click delivers a context menu with Quit; left-click toggles
        // the popover as before. We can't use statusItem.menu directly —
        // assigning it would override left-click and hide the popover entry.
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Re-render icon whenever sessions change
        store.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] sessions in
                let status = AggregateStatus.compute(sessions)
                self?.statusItem.button?.image = StatusIconRenderer.image(for: status)
            }
            .store(in: &cancellables)
    }

    func toggle() {
        guard let button = statusItem.button else { return }
        popoverController.toggle(relativeTo: button)
    }

    @objc private func handleStatusItemClick(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggle()
        }
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit ClaudeDock",
                              action: #selector(quitApp),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        // Pop up just below the status bar button. Setting positioning to
        // nil + an anchor point in the button's coordinate space gives the
        // same visual placement as the popover.
        let anchor = NSPoint(x: 0, y: button.frame.height + 4)
        menu.popUp(positioning: nil, at: anchor, in: button)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

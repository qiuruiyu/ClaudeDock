import AppKit
import SwiftUI

@MainActor
final class WizardController {
    private let prefs: PreferencesStore
    private let state = WizardState()
    private var window: NSWindow?

    init(prefs: PreferencesStore) { self.prefs = prefs }

    func showIfNeeded() {
        guard !prefs.prefs.hasSeenWizard else { return }
        show()
    }

    func show() {
        if window != nil { window?.makeKeyAndOrderFront(nil); return }
        let view = WizardView(state: state, prefs: prefs) { [weak self] in
            self?.complete()
        }
        let hosting = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: hosting)
        w.title = "ClaudeDock Setup"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = w
    }

    private func complete() {
        prefs.prefs.hasSeenWizard = true
        window?.close()
        window = nil
    }
}

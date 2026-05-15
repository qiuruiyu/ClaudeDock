import AppKit
import Combine
import Logging

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let log = Logger(label: "claudedock.app")
    let hookServer = HookServer()
    let latency = LatencyTracker()
    let aliases = AliasStore()
    lazy var sessionStore: SessionStore = SessionStore(aliases: aliases)
    let terminalFocuser: TerminalFocuser
    let preferencesStore: PreferencesStore
    let loginItem = LoginItemController()
    private var notifications: ClaudeDockNotifications?
    var menuBar: MenuBarController?
    let hotkeyService = HotkeyService()
    let notchController = NotchDockController()
    var notchPanel: NotchDockPanel?
    private var notchCancellables = Set<AnyCancellable>()
    private var sessionBinding: AnyCancellable?
    var wizard: WizardController?

    override init() {
        self.terminalFocuser = TerminalFocuser(
            iTerm: iTermStrategy(),
            terminalApp: TerminalAppStrategy(),
            generic: GenericStrategy()
        )
        self.preferencesStore = PreferencesStore()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("ClaudeDock launching…")

        do {
            try PluginManager().regenerate()
        } catch {
            log.error("PluginManager.regenerate failed: \(error)")
        }

        Task { [weak self] in
            guard let self else { return }
            await self.hookServer.setHandler { [weak self] event, hint in
                guard let self else { return }
                await MainActor.run {
                    self.sessionStore.ingest(event: event, hint: hint)
                    self.log.info("Hook: \(event.hookEventName.rawValue) sid=\(event.sessionId) cwd=\(event.cwd) ppid=\(hint.ppid ?? -1)")
                }
            }
            await self.hookServer.setLatencyTracker(self.latency)
            do {
                try await self.hookServer.start()
            } catch {
                self.log.error("HookServer failed to start: \(error)")
            }
        }

        // Construct notifications subsystem after sessionStore is materialized so the
        // Combine subscription attaches to the same instance MenuBarController will use.
        _ = self.sessionStore
        self.notifications = ClaudeDockNotifications(store: self.sessionStore,
                                                     aliases: self.aliases,
                                                     prefs: self.preferencesStore)

        self.loginItem.syncWith(self.preferencesStore.prefs.launchAtLogin)

        self.menuBar = MenuBarController(store: self.sessionStore,
                                         aliases: self.aliases,
                                         prefs: self.preferencesStore,
                                         focuser: self.terminalFocuser,
                                         loginItem: self.loginItem,
                                         latency: self.latency,
                                         onHotkeyChange: { [weak self] in self?.reapplyHotkey() })

        // Notch Dock panel: hosts the SwiftUI view in a floating NSPanel and
        // toggles visibility based on `preferencesStore.prefs.enableNotchDock`.
        let panel = NotchDockPanel(controller: notchController,
                                   store: sessionStore,
                                   aliases: aliases,
                                   focuser: terminalFocuser)
        self.notchPanel = panel

        // Lifecycle-managed binding: the controller only subscribes to
        // SessionStore changes while enableNotchDock is true. On disable, we
        // cancel the subscription (so the bind closure's previousStatuses
        // state stops drifting) and force the controller hidden so the panel
        // state-sink orders it offscreen.
        preferencesStore.$prefs
            .map(\.enableNotchDock)
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    self.sessionBinding = self.notchController.bind(to: self.sessionStore)
                } else {
                    self.sessionBinding?.cancel()
                    self.sessionBinding = nil
                    self.notchController.forceHidden()
                }
            }
            .store(in: &notchCancellables)

        reapplyHotkey()

        let w = WizardController(prefs: preferencesStore)
        self.wizard = w
        w.showIfNeeded()
    }

    @MainActor
    func reapplyHotkey() {
        hotkeyService.unregister()
        if preferencesStore.prefs.hotkeyDisabled {
            log.info("Hotkey disabled by user preference")
            return
        }
        let key = preferencesStore.prefs.hotkeyKeyCode ?? HotkeyService.defaultKeyCode
        let mods = preferencesStore.prefs.hotkeyModifiers ?? HotkeyService.defaultModifiers
        hotkeyService.register(keyCode: key, modifiers: mods) { [weak self] in
            self?.menuBar?.toggle()
        }
        log.info("Hotkey reapplied: keyCode=\(key) modifiers=\(String(mods, radix: 16))")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyService.unregister()
        Task { try? await hookServer.stop() }
    }
}

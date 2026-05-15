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
    let discovery = SessionDiscovery()
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

    // ProcessExitWatcher tracks per-session kqueue exit subscriptions so
    // we mark sessions .ended within microseconds of the claude process
    // dying, even when claude can't fire its own SessionEnd hook (e.g.
    // terminal closed abruptly, SIGKILL).
    private var exitWatcher: ProcessExitWatcher!
    private var watcherCancellable: AnyCancellable?
    private var watchedSessionIds: Set<String> = []

    override init() {
        self.terminalFocuser = TerminalFocuser(
            iTerm: iTermStrategy(),
            terminalApp: TerminalAppStrategy(),
            vscode: VSCodeStrategy(),
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
                                         onHotkeyChange: { [weak self] in self?.reapplyHotkey() },
                                         onRefresh: { [weak self] in self?.runDiscovery() })

        // One-shot launch-time discovery — surface any `claude` sessions that
        // were already running before ClaudeDock started. Backgrounded so the
        // menu-bar icon appears immediately; results merge into the store as
        // they arrive. Re-runs on demand via the popover's refresh button.
        runDiscovery()

        // ProcessExitWatcher: reconcile per-session kqueue subscriptions
        // against the live session set on every change. Fires markEnded
        // microseconds after a claude process exits, even for ungraceful
        // exits (terminal close, SIGKILL, crash) that never reach the
        // SessionEnd hook flow.
        self.exitWatcher = ProcessExitWatcher { [weak self] sessionId in
            self?.sessionStore.markEnded(sessionId: sessionId)
        }
        self.watcherCancellable = self.sessionStore.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] sessions in
                self?.reconcileWatcher(against: sessions)
            }

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

    /// Run SessionDiscovery off the main thread and merge results into the
    /// SessionStore on the main thread. Idempotent — `injectDiscovered`
    /// no-ops when the fingerprint is already tracked.
    @MainActor
    func runDiscovery() {
        let discovery = self.discovery
        let log = self.log
        Task.detached(priority: .userInitiated) { [weak self] in
            let results: [DiscoveredSession]
            do {
                results = try discovery.discover()
            } catch {
                log.error("Discovery failed: \(error)")
                return
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                for r in results {
                    self.sessionStore.injectDiscovered(identity: r.identity,
                                                       transcriptPath: r.transcriptPath,
                                                       status: r.status,
                                                       lastEventAt: r.lastEventAt,
                                                       hint: r.hint)
                }
            }
        }
    }

    /// Bring the ProcessExitWatcher's tracked-PID set into sync with the
    /// SessionStore's live (non-ended) sessions. Idempotent: re-watching
    /// an already-tracked session is a no-op inside the watcher; sessions
    /// that disappeared or transitioned to .ended get unwatched.
    @MainActor
    private func reconcileWatcher(against sessions: [Session]) {
        let liveIds: Set<String> = Set(sessions
            .filter { $0.status != .ended }
            .filter { $0.hint.ppid != nil }
            .map(\.id))

        // Start watching any newly-live session with a known PID
        for s in sessions where s.status != .ended {
            guard let pid = s.hint.ppid else { continue }
            if !watchedSessionIds.contains(s.id) {
                exitWatcher.watch(sessionId: s.id, pid: pid)
                watchedSessionIds.insert(s.id)
            }
        }
        // Drop watches for sessions that are no longer live
        for id in watchedSessionIds where !liveIds.contains(id) {
            exitWatcher.unwatch(sessionId: id)
            watchedSessionIds.remove(id)
        }
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

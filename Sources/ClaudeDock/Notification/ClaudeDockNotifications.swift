import AppKit
import Combine
import UserNotifications
import Logging

@MainActor
final class ClaudeDockNotifications {
    private let store: SessionStore
    private let prefs: PreferencesStore
    private let resolver = NameResolver()
    private let aliasStore: AliasStore  // shared with SessionStore & SessionListView
    private var cancellables = Set<AnyCancellable>()
    private var previousStatuses: [String: SessionStatus] = [:]
    private let log = Logger(label: "claudedock.notify")

    /// True when the process is a properly bundled .app with a bundle identifier
    /// known to CoreServices. UNUserNotificationCenter raises NSInternalInconsistency
    /// when this isn't the case (e.g. `swift run` builds). Plan C `.app` packaging fixes this.
    private let isBundled: Bool

    init(store: SessionStore, aliases: AliasStore, prefs: PreferencesStore) {
        self.store = store
        self.aliasStore = aliases
        self.prefs = prefs
        // Bundle.main.bundleIdentifier returns nil for unbundled `swift run` binaries.
        // We additionally require the URL extension to be ".app" — the Xcode-style
        // unbundled build dir has a bundleIdentifier-less mainBundle pointing at a
        // .build/ directory that still crashes UN.
        let url = Bundle.main.bundleURL
        self.isBundled = (Bundle.main.bundleIdentifier != nil)
                      && url.pathExtension == "app"

        if isBundled {
            // Request permission once. Result is best-effort; system shows the prompt at first call.
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
                if let error { self?.log.warning("Notification auth error: \(error)") }
                else        { self?.log.info("Notification auth granted=\(granted)") }
            }
        } else {
            log.info("Notification auth skipped — process is not a bundled .app (Plan C packaging needed). bundleURL=\(url.path)")
        }

        store.$sessions
            .sink { [weak self] sessions in
                Task { @MainActor in self?.diff(sessions) }
            }
            .store(in: &cancellables)
    }

    private func diff(_ sessions: [Session]) {
        for s in sessions {
            let prev = previousStatuses[s.id]
            previousStatuses[s.id] = s.status
            guard prev != s.status else { continue }

            let cur = prefs.prefs
            // Enter emit if EITHER banner or sound is wanted for this level.
            // Banner-vs-sound decision is then made inside emit independently.
            // Critical: waitingInput
            if s.status == .waitingInput,
               (cur.notifyWaitingInput || cur.soundOnWaitingInput),
               !MutePolicy.muted(s, in: cur) {
                emit(s, level: .critical)
            }
            // Medium: any "still-working" state (thinking OR waitingInput) → idle.
            // Including waitingInput covers the common path where Claude was
            // blocked on a tool permission, the user approved, then Claude
            // finished — that flow ends at idle but prev is waitingInput, not
            // thinking, so we'd miss it if we only checked .thinking.
            else if (prev == .thinking || prev == .waitingInput), s.status == .idle,
                    (cur.notifyDone || cur.soundOnDone),
                    !MutePolicy.muted(s, in: cur) {
                emit(s, level: .medium)
            }
        }
        // Garbage-collect tracking for ended sessions so memory doesn't grow.
        let liveIds = Set(sessions.map(\.id))
        previousStatuses = previousStatuses.filter { liveIds.contains($0.key) }
    }

    private enum Level { case critical, medium }

    private func emit(_ s: Session, level: Level) {
        // Fullscreen exemption: downgrade critical → don't send banner
        if level == .critical, prefs.prefs.downgradeOnFullscreen, isFullscreenActive() {
            log.info("Notification downgraded due to fullscreen: \(s.identity.cwd)")
            return
        }
        let name = resolver.resolve(cwd: s.identity.cwd,
                                    workKey: s.identity.workKey,
                                    aliasStore: aliasStore)
        let wantsSound = (level == .critical && prefs.prefs.soundOnWaitingInput)
                      || (level == .medium && prefs.prefs.soundOnDone)
        let wantsBanner = (level == .critical && prefs.prefs.notifyWaitingInput)
                       || (level == .medium && prefs.prefs.notifyDone)

        // Sound always plays direct via NSSound — never delegated to UN. UN's
        // `content.sound` is silenced under DnD / Focus / no-permission and we
        // want the audible cue to be the user's source of truth: if the toggle
        // is on, the sound rings, period.
        if wantsSound {
            log.info("Notify sound: \(name) level=\(level)")
            playSystemSound()
        }

        // Banner only fires when bundled (UN crashes without a bundle id) AND
        // the user wants it AND the notch dock isn't enabled (the notch dock
        // will show its own banner for the same event — no double-notify).
        // Sound still fires above regardless: NSSound is the authoritative cue.
        if wantsBanner, isBundled, !prefs.prefs.enableNotchDock {
            log.info("Notify banner: \(name) level=\(level)")
            let content = UNMutableNotificationContent()
            content.title = "ClaudeDock — \(name)"
            content.body = level == .critical ? "Claude is waiting for input." : "Session complete."
            // intentionally no content.sound — NSSound above is authoritative.
            let req = UNNotificationRequest(identifier: "\(s.id)-\(level)-\(Int(Date().timeIntervalSince1970))",
                                            content: content, trigger: nil)
            UNUserNotificationCenter.current().add(req) { [weak self] err in
                if let err { self?.log.warning("Failed to post notification: \(err)") }
                else        { self?.log.info("Notification posted: \(name) \(level)") }
            }
        }
    }

    /// Three-step fallback: NSSound(named:) is unreliable across macOS configurations
    /// (sometimes returns nil silently, sometimes .play() fails without error). We fall
    /// back to loading the .aiff directly, then to NSSound.beep() so the user always
    /// gets *something* audible when a sound toggle is on.
    private func playSystemSound() {
        if let s = NSSound(named: NSSound.Name("Glass")) {
            let played = s.play()
            log.info("Sound: NSSound(\"Glass\") played=\(played)")
            if played { return }
        }
        let url = URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff")
        if let s = NSSound(contentsOf: url, byReference: true) {
            let played = s.play()
            log.info("Sound: NSSound(contentsOf:) played=\(played)")
            if played { return }
        }
        NSSound.beep()
        log.info("Sound: fell back to NSSound.beep()")
    }

    private func isFullscreenActive() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        let pid: pid_t = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)
        var window: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &window)
        guard let win = window else { return false }
        var fs: CFTypeRef?
        AXUIElementCopyAttributeValue(win as! AXUIElement, "AXFullScreen" as CFString, &fs)
        return (fs as? Bool) ?? false
    }
}

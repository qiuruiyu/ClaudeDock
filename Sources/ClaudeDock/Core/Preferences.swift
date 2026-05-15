import Foundation
import Combine
import Logging

struct Preferences: Codable, Equatable, Sendable {
    // General
    var launchAtLogin: Bool = false
    var hasSeenWizard: Bool = false

    // Notifications
    var notifyWaitingInput: Bool = true
    var notifyDone: Bool = false
    var soundOnWaitingInput: Bool = false
    var soundOnDone: Bool = false
    var followFocusMode: Bool = true
    var downgradeOnFullscreen: Bool = true
    var aggregationWindowSeconds: Int = 30

    // Mute
    var globalMuteUntil: Date? = nil

    // Appearance
    var theme: Theme = .system
    var showBadgeDigit: Bool = false
    var enableNotchDock: Bool = false

    // Hotkey (defaults: ⌥ + Space)
    var hotkeyKeyCode: UInt16? = 49      // kVK_Space
    var hotkeyModifiers: UInt32? = 0x0800   // optionKey
    var hotkeyDisabled: Bool = false

    enum Theme: String, Codable, Sendable { case system, light, dark }
}

@MainActor
final class PreferencesStore: ObservableObject {
    @Published var prefs: Preferences
    private let fileURL: URL
    private let log = Logger(label: "claudedock.prefs")
    private var cancellables = Set<AnyCancellable>()

    init(fileURL: URL = PathProvider.preferencesFile) {
        self.fileURL = fileURL
        self.prefs = Persistence.read(Preferences.self, from: fileURL) ?? Preferences()

        // Combine sink: fires on EVERY mutation of `prefs`, including SwiftUI
        // binding writes via $prefs.prefs.<field>. The `dropFirst()` skips the
        // initial value emitted on subscription so we don't overwrite the file
        // on launch.
        $prefs
            .dropFirst()
            .sink { [weak self] newValue in
                guard let self else { return }
                try? Persistence.write(newValue, to: self.fileURL)
                self.log.info("Preferences saved: notifyWaitingInput=\(newValue.notifyWaitingInput) notifyDone=\(newValue.notifyDone) soundOnWaitingInput=\(newValue.soundOnWaitingInput) soundOnDone=\(newValue.soundOnDone)")
            }
            .store(in: &cancellables)
    }

    /// Manual save (still useful for forced flushes; not normally needed)
    func save() {
        try? Persistence.write(prefs, to: fileURL)
    }
}

import Foundation
import Combine

@MainActor
final class NotchDockController: ObservableObject {
    @Published private(set) var state: NotchDockState = .hidden
    private let notificationTimeout: TimeInterval
    private var timeoutTask: Task<Void, Never>?

    init(notificationTimeout: TimeInterval = 5.0) {
        self.notificationTimeout = notificationTimeout
    }

    func bind(to store: SessionStore) -> AnyCancellable {
        var previousStatuses: [String: SessionStatus] = [:]
        return store.$sessions.sink { [weak self] sessions in
            guard let self else { return }
            Task { @MainActor in
                self.applySessionDiff(prev: previousStatuses, now: sessions)
                previousStatuses = Dictionary(uniqueKeysWithValues:
                    sessions.map { ($0.id, $0.status) })
            }
        }
    }

    /// Same triggers as ClaudeDockNotifications: waitingInput entry OR
    /// (thinking | waitingInput) → idle.
    func applySessionDiff(prev: [String: SessionStatus], now: [Session]) {
        for s in now {
            let prevStatus = prev[s.id]
            if s.status == .waitingInput && prevStatus != .waitingInput {
                showBanner(for: s)
                return
            }
            if s.status == .idle && (prevStatus == .thinking || prevStatus == .waitingInput) {
                showBanner(for: s)
                return
            }
        }
    }

    func userClickedBanner() {
        timeoutTask?.cancel()
        state = .hidden
    }

    /// Called by AppDelegate when the user disables enableNotchDock at runtime.
    func forceHidden() {
        timeoutTask?.cancel()
        state = .hidden
    }

    private func showBanner(for s: Session) {
        let until = Date().addingTimeInterval(notificationTimeout)
        state = .showing(s, until: until)
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self, notificationTimeout] in
            try? await Task.sleep(nanoseconds: UInt64(notificationTimeout * 1_000_000_000))
            guard let self else { return }
            await MainActor.run {
                if case .showing = self.state { self.state = .hidden }
            }
        }
    }
}

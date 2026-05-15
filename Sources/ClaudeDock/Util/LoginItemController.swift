import Foundation
import ServiceManagement
import Logging

@MainActor
final class LoginItemController {
    private let service = SMAppService.mainApp
    private let log = Logger(label: "claudedock.loginitem")

    var currentStatus: SMAppService.Status { service.status }

    /// Sets the registration state, returning true on success. Failures are logged.
    /// Common reason for failure: the binary is not running inside a real `.app`
    /// bundle (i.e. unbundled `swift run` development). In that case the toggle
    /// is a no-op until the user launches ClaudeDock.app from /Applications.
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try service.register()
                log.info("LoginItem registered; status=\(service.status.rawValue)")
            } else {
                try service.unregister()
                log.info("LoginItem unregistered; status=\(service.status.rawValue)")
            }
            return true
        } catch {
            log.warning("LoginItem \(enabled ? "register" : "unregister") failed: \(error)")
            return false
        }
    }

    /// Reconciles the OS state with the stored preference. Called once at launch.
    /// If the preference disagrees with reality, the preference wins.
    func syncWith(_ pref: Bool) {
        let isEnabled = (service.status == .enabled)
        guard isEnabled != pref else { return }
        setEnabled(pref)
    }
}

import SwiftUI

struct NotificationsSettingsView: View {
    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications").font(.system(size: 12, weight: .semibold))

            GroupBox("Show notifications for") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("🔴 Waiting for input", isOn: $prefs.prefs.notifyWaitingInput)
                    Toggle("🟡 Session completed", isOn: $prefs.prefs.notifyDone)
                }
                .font(.system(size: 11))
                .padding(.vertical, 2)
            }

            GroupBox("Sounds") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Waiting for input", isOn: $prefs.prefs.soundOnWaitingInput)
                    Toggle("Session completed", isOn: $prefs.prefs.soundOnDone)
                }
                .font(.system(size: 11))
                .padding(.vertical, 2)
            }

            GroupBox("Behavior") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Follow macOS Focus Mode", isOn: $prefs.prefs.followFocusMode)
                    Toggle("Downgrade when any app is fullscreen", isOn: $prefs.prefs.downgradeOnFullscreen)
                    Stepper("Aggregate burst events: \(prefs.prefs.aggregationWindowSeconds)s",
                            value: $prefs.prefs.aggregationWindowSeconds,
                            in: 5...300, step: 5)
                }
                .font(.system(size: 11))
                .padding(.vertical, 2)
            }
        }
    }
}

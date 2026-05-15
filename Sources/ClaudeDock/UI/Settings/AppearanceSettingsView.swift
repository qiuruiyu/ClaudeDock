import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance").font(.system(size: 12, weight: .semibold))

            GroupBox("Theme") {
                Picker("", selection: $prefs.prefs.theme) {
                    Text("Follow system").tag(Preferences.Theme.system)
                    Text("Light").tag(Preferences.Theme.light)
                    Text("Dark").tag(Preferences.Theme.dark)
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: 11))
                .padding(.vertical, 2)
            }

            GroupBox("Status icon") {
                Toggle("Show active session count as badge", isOn: $prefs.prefs.showBadgeDigit)
                    .font(.system(size: 11))
                    .padding(.vertical, 2)
            }

            GroupBox("Notch Dock") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Show flash banner under menu bar", isOn: $prefs.prefs.enableNotchDock)
                        .font(.system(size: 11))
                    Text("A 5-second banner appears below the menu bar (or under the notch) when a session needs input or finishes. Off by default.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var prefs: PreferencesStore
    let loginItem: LoginItemController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General").font(.system(size: 12, weight: .semibold))

            GroupBox("Startup") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Launch at login", isOn: $prefs.prefs.launchAtLogin)
                        .font(.system(size: 11))
                    Text("Requires ClaudeDock.app installed to /Applications. The toggle is a no-op when running from `swift run`.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
            .onChange(of: prefs.prefs.launchAtLogin) { _, newValue in
                loginItem.setEnabled(newValue)
            }

            Toggle("Show numeric badge on status icon", isOn: $prefs.prefs.showBadgeDigit)
                .font(.system(size: 11))
        }
    }
}

import SwiftUI

struct SettingsView: View {
    @ObservedObject var prefs: PreferencesStore
    let aliases: AliasStore
    let loginItem: LoginItemController
    let latency: LatencyTracker
    let onHotkeyChange: () -> Void
    let onBack: () -> Void

    @StateObject private var dataAliasesObserver: DataSettingsView.AliasesObserver

    @State private var selection: SettingsTab = .general

    init(prefs: PreferencesStore,
         aliases: AliasStore,
         loginItem: LoginItemController,
         latency: LatencyTracker,
         onHotkeyChange: @escaping () -> Void,
         onBack: @escaping () -> Void) {
        self.prefs = prefs
        self.aliases = aliases
        self.loginItem = loginItem
        self.latency = latency
        self.onHotkeyChange = onHotkeyChange
        self.onBack = onBack
        self._dataAliasesObserver = StateObject(wrappedValue: DataSettingsView.AliasesObserver(store: aliases))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                sidebar
                Divider()
                ScrollView { detailView.padding(.horizontal, 12).padding(.vertical, 10) }
            }
        }
        .frame(width: 360, height: 520)
        // Match the popover's dark console aesthetic so transition into
        // Settings doesn't flash a light surface against the dark list.
        // .preferredColorScheme(.dark) flips system colors (GroupBox bg,
        // Toggle bg, etc) to their dark variants.
        .preferredColorScheme(.dark)
        .background(Theme.ink)
    }

    private var header: some View {
        ZStack {
            Text("Settings")
                .font(.system(size: 12, weight: .semibold))
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 28)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(SettingsTab.allCases) { tab in
                Button(action: { selection = tab }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.iconName).frame(width: 12, height: 12)
                        Text(tab.displayName)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(selection == tab ? Color.accentColor.opacity(0.18) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .frame(width: 100)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .general:        GeneralSettingsView(prefs: prefs, loginItem: loginItem)
        case .notifications:  NotificationsSettingsView(prefs: prefs)
        case .appearance:     AppearanceSettingsView(prefs: prefs)
        case .hotkey:         HotkeySettingsView(prefs: prefs, onChange: onHotkeyChange)
        case .terminal:       TerminalSettingsView()
        case .plugin:         PluginSettingsView()
        case .data:           DataSettingsView(aliasesObserver: dataAliasesObserver)
        case .diagnostics:    DiagnosticsSettingsView(latency: latency)
        case .about:          AboutView()
        }
    }
}

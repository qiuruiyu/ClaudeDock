import Foundation

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, notifications, appearance, hotkey, terminal, plugin, data, diagnostics, about
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .notifications: return "bell"
        case .appearance: return "paintbrush"
        case .hotkey: return "keyboard"
        case .terminal: return "terminal"
        case .plugin: return "puzzlepiece.extension"
        case .data: return "folder"
        case .diagnostics: return "stethoscope"
        case .about: return "info.circle"
        }
    }
}

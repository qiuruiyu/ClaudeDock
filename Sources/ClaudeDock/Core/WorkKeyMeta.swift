import Foundation

enum ColorTag: String, Codable, CaseIterable, Equatable, Sendable {
    case blue, green, orange, red, purple, pink, yellow, teal
}

struct WorkKeyMeta: Codable, Equatable, Sendable {
    var alias: String?
    var color: ColorTag
    var pinned: Bool
    var lastSeen: Date
}

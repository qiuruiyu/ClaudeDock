import Foundation

struct HookEvent: Decodable, Equatable, Sendable {
    enum Kind: String, Decodable, Sendable {
        case sessionStart       = "SessionStart"
        case userPromptSubmit   = "UserPromptSubmit"
        case notification       = "Notification"
        case stop               = "Stop"
        case sessionEnd         = "SessionEnd"
    }

    let sessionId: String
    let cwd: String
    let hookEventName: Kind
    let transcriptPath: String

    private enum CodingKeys: String, CodingKey {
        case sessionId       = "session_id"
        case cwd
        case hookEventName   = "hook_event_name"
        case transcriptPath  = "transcript_path"
    }
}

enum SessionStatus: String, Codable, Equatable, Sendable {
    case starting
    case thinking
    case waitingInput
    case idle
    case ended
}

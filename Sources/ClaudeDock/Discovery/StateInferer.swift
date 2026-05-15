// Sources/ClaudeDock/Discovery/StateInferer.swift
//
// Reads the tail of a JSONL transcript and infers a SessionStatus from
// the last entry. Conservative — `.waitingInput` (the red "needs input"
// state) is never inferred; that state is only produced by the
// Notification hook firing in real time.

import Foundation

enum StateInferer {
    /// Reads up to 32 KB from the end of `path`, parses the last non-empty
    /// JSON line, returns `.idle` if it's an assistant message, `.thinking`
    /// if it's a user message, `.starting` otherwise.
    static func inferStatus(fromJsonlAt path: URL) -> SessionStatus {
        guard let fh = try? FileHandle(forReadingFrom: path) else { return .starting }
        defer { try? fh.close() }
        let size: UInt64
        do {
            size = try fh.seekToEnd()
        } catch {
            return .starting
        }
        let tailSize: UInt64 = min(32 * 1024, size)
        guard tailSize > 0 else { return .starting }
        do {
            try fh.seek(toOffset: size - tailSize)
        } catch {
            return .starting
        }
        guard let data = try? fh.read(upToCount: Int(tailSize)),
              let s = String(data: data, encoding: .utf8) else {
            return .starting
        }
        let lines = s.split(whereSeparator: \.isNewline).map(String.init)
        guard let last = lines.reversed().first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return .starting
        }
        guard let lineData = last.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
            return .starting
        }
        // Two shapes seen in Claude Code transcripts:
        //   { "type": "user",      "message": {...}, ... }
        //   { "type": "assistant", "message": {...}, ... }
        let role = (json["type"] as? String)
            ?? ((json["message"] as? [String: Any])?["role"] as? String)
        switch role {
        case "assistant": return .idle
        case "user":      return .thinking
        default:          return .starting
        }
    }
}

// Sources/ClaudeDock/Discovery/ProcessEnvReader.swift
//
// Read another process's environment variables on macOS via the
// KERN_PROCARGS2 sysctl. Used by ProcessEnumerator to populate
// TERM_PROGRAM / VSCODE_PID / ITERM_SESSION_ID / TERM_SESSION_ID on
// discovered claude sessions — without these, a session started inside
// VS Code's integrated terminal looks indistinguishable from one
// started in a plain shell, so the TerminalFocuser can't pick the
// right strategy.
//
// The KERN_PROCARGS2 buffer layout (per <sys/sysctl.h> + Darwin sources):
//
//   [4 bytes ] argc as host-endian int32
//   [N bytes ] exec_path  (null-terminated)
//   [pad     ] zero bytes until next non-zero
//   [argv    ] argc null-terminated strings
//   [env     ] null-terminated KEY=VALUE strings until end or empty
//
// Best-effort: any parse failure / permission denial returns an empty
// dict; we never crash on a malformed buffer.

import Foundation
import Darwin

protocol ProcessEnvReading: Sendable {
    func readEnv(pid: Int32) -> [String: String]
}

struct DarwinProcessEnvReader: ProcessEnvReading {
    func readEnv(pid: Int32) -> [String: String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0 else { return [:] }
        guard size > 0 else { return [:] }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &size, nil, 0) == 0 else { return [:] }
        // size may have shrunk on the second call
        if buffer.count > size { buffer.removeSubrange(size..<buffer.count) }
        return Self.parse(buffer)
    }

    /// Exposed for unit tests with hand-crafted buffers.
    static func parse(_ buffer: [UInt8]) -> [String: String] {
        guard buffer.count >= 4 else { return [:] }
        // argc is host-byte-order int32 in the first 4 bytes
        var argc: Int32 = 0
        withUnsafeMutableBytes(of: &argc) { dst in
            buffer.withUnsafeBytes { src in
                dst.copyBytes(from: src.prefix(4))
            }
        }
        guard argc >= 0 else { return [:] }

        var i = 4

        // Skip exec_path: read until null
        while i < buffer.count && buffer[i] != 0 { i += 1 }
        // Skip alignment-padding zero bytes
        while i < buffer.count && buffer[i] == 0 { i += 1 }

        // Skip argc null-terminated argv strings
        for _ in 0..<Int(argc) {
            while i < buffer.count && buffer[i] != 0 { i += 1 }
            i += 1   // step past the null
            if i >= buffer.count { return [:] }
        }

        // Read env strings until end-of-buffer or empty string
        var env: [String: String] = [:]
        while i < buffer.count {
            let start = i
            while i < buffer.count && buffer[i] != 0 { i += 1 }
            if i == start { break }   // empty string sentinel
            let slice = Array(buffer[start..<i])
            if let s = String(bytes: slice, encoding: .utf8),
               let eq = s.firstIndex(of: "=") {
                let key = String(s[..<eq])
                let value = String(s[s.index(after: eq)...])
                env[key] = value
            }
            i += 1   // step past the null
        }
        return env
    }
}

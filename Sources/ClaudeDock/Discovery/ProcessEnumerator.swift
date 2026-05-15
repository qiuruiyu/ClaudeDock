// Sources/ClaudeDock/Discovery/ProcessEnumerator.swift
//
// Lists running `claude` processes on this Mac with each one's working
// directory and controlling terminal. Used by SessionDiscovery to surface
// sessions that existed before ClaudeDock launched.
//
// Shells out to /usr/bin/pgrep + /usr/sbin/lsof + /bin/ps. The actual
// shell invocation is behind a ShellRunning protocol so tests can inject
// a fake without touching the system process table.

import Foundation
import Logging

struct ClaudeProcess: Equatable, Sendable {
    let pid: Int32
    let cwd: String
    let tty: String?   // e.g. "/dev/ttys001"; nil if not a tty
}

protocol ShellRunning: Sendable {
    func run(_ tool: String, _ args: [String]) throws -> String
}

struct ProcessShellRunner: ShellRunning {
    func run(_ tool: String, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

protocol ProcessEnumerating: Sendable {
    func enumerateClaudeProcesses() throws -> [ClaudeProcess]
}

struct ShellProcessEnumerator: ProcessEnumerating {
    let runner: ShellRunning
    let limit: Int
    private let log = Logger(label: "claudedock.discovery.proc")

    init(runner: ShellRunning = ProcessShellRunner(), limit: Int = 32) {
        self.runner = runner
        self.limit = limit
    }

    func enumerateClaudeProcesses() throws -> [ClaudeProcess] {
        let pgrep = (try? runner.run("/usr/bin/pgrep", ["-x", "claude"])) ?? ""
        let candidatePids = pgrep.split(whereSeparator: \.isNewline)
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
            .prefix(limit)
        if candidatePids.count > limit {
            log.warning("pgrep returned more than \(limit) claude PIDs; truncating")
        }
        // macOS `pgrep -x claude` matches the leading-prefix of the process
        // name and unexpectedly catches `claude.exe` (Claude Desktop's
        // Electron subprocess). Filter by the exact `comm` field via ps.
        let pids = candidatePids.filter { isExactlyClaude(pid: $0) }
        return pids.compactMap { pid in
            guard let cwd = readCWD(pid: pid) else { return nil }
            let tty = readTTY(pid: pid)
            return ClaudeProcess(pid: pid, cwd: cwd, tty: tty)
        }
    }

    private func isExactlyClaude(pid: Int32) -> Bool {
        let out = (try? runner.run("/bin/ps", ["-p", "\(pid)", "-o", "comm="])) ?? ""
        let comm = out.trimmingCharacters(in: .whitespacesAndNewlines)
        // ps -o comm= sometimes prints the full executable path; we want
        // the basename comparison.
        let name = (comm as NSString).lastPathComponent
        return name == "claude"
    }

    private func readCWD(pid: Int32) -> String? {
        // `-a` ANDs the -p and -d filters; without it lsof ORs them and
        // returns the cwd of *every* process, which is catastrophically
        // wrong (the first match is some unrelated pid). The FakeShellRunner
        // in tests indexes by pid alone so it never exhibited this; only
        // live runs against /usr/sbin/lsof revealed it.
        let out = (try? runner.run("/usr/sbin/lsof", ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"])) ?? ""
        for line in out.split(whereSeparator: \.isNewline) where line.hasPrefix("n") {
            let path = String(line.dropFirst())
            if !path.isEmpty { return path }
        }
        return nil
    }

    private func readTTY(pid: Int32) -> String? {
        let out = (try? runner.run("/bin/ps", ["-p", "\(pid)", "-o", "tty="])) ?? ""
        let raw = out.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw == "??" || raw == "?" { return nil }
        return raw.hasPrefix("/dev/") ? raw : "/dev/\(raw)"
    }
}

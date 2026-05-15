import Foundation
import Testing
@testable import ClaudeDock

/// Captures `(tool, args)` call signatures so tests can verify the shell layer.
final class FakeShellRunner: ShellRunning, @unchecked Sendable {
    /// Map of "key" → canned output. Keys:
    ///   "pgrep"            — for any pgrep invocation
    ///   "lsof:<pid>"       — for lsof against pid
    ///   "ps_tty:<pid>"     — for ps -p <pid> -o tty=
    ///   "ps_comm:<pid>"    — for ps -p <pid> -o comm=  (defaults to "claude")
    var outputs: [String: String]
    private(set) var calls: [(String, [String])] = []
    private let lock = NSLock()

    init(outputs: [String: String]) {
        self.outputs = outputs
    }

    func run(_ tool: String, _ args: [String]) throws -> String {
        lock.lock(); defer { lock.unlock() }
        calls.append((tool, args))
        if tool.hasSuffix("/pgrep") {
            return outputs["pgrep"] ?? ""
        }
        if tool.hasSuffix("/lsof"), let pidIdx = args.firstIndex(of: "-p"),
           pidIdx + 1 < args.count {
            return outputs["lsof:\(args[pidIdx + 1])"] ?? ""
        }
        if tool.hasSuffix("/ps"), let pidIdx = args.firstIndex(of: "-p"),
           pidIdx + 1 < args.count {
            let pid = args[pidIdx + 1]
            // Differentiate ps queries by their -o field
            if args.contains("comm=") {
                // Default to a passing value so older tests don't have to
                // declare it for every pid; explicit override wins.
                return outputs["ps_comm:\(pid)"] ?? "claude\n"
            }
            if args.contains("tty=") {
                return outputs["ps_tty:\(pid)"] ?? outputs["ps:\(pid)"] ?? ""
            }
            return outputs["ps:\(pid)"] ?? ""
        }
        return ""
    }
}

@Suite struct ProcessEnumeratorTests {
    @Test func emptyWhenNoClaudeProcesses() throws {
        let runner = FakeShellRunner(outputs: ["pgrep": ""])
        let e = ShellProcessEnumerator(runner: runner)
        #expect(try e.enumerateClaudeProcesses().isEmpty)
    }

    @Test func parsesThreeProcessesWithCwdAndTty() throws {
        let runner = FakeShellRunner(outputs: [
            "pgrep":      "12345\n12346\n12347\n",
            "lsof:12345": "p12345\nfcwd\nn/Users/joe/projects/foo\n",
            "lsof:12346": "p12346\nfcwd\nn/Users/joe/projects/bar\n",
            "lsof:12347": "p12347\nfcwd\nn/Users/joe/projects/baz\n",
            "ps:12345":   "ttys001\n",
            "ps:12346":   "ttys002\n",
            "ps:12347":   "ttys003\n",
        ])
        let procs = try ShellProcessEnumerator(runner: runner).enumerateClaudeProcesses()
        #expect(procs.count == 3)
        #expect(procs[0].pid == 12345)
        #expect(procs[0].cwd == "/Users/joe/projects/foo")
        #expect(procs[0].tty == "/dev/ttys001")
        #expect(procs[2].tty == "/dev/ttys003")
    }

    @Test func handlesMissingTtyByNullingIt() throws {
        let runner = FakeShellRunner(outputs: [
            "pgrep":    "999\n",
            "lsof:999": "p999\nfcwd\nn/tmp\n",
            "ps:999":   "??\n",
        ])
        let procs = try ShellProcessEnumerator(runner: runner).enumerateClaudeProcesses()
        #expect(procs.count == 1)
        #expect(procs[0].tty == nil)
    }

    @Test func dropsProcessesWithUnreadableCwd() throws {
        let runner = FakeShellRunner(outputs: [
            "pgrep":     "111\n222\n",
            "lsof:111":  "p111\nfcwd\nn/ok\n",
            "lsof:222":  "",  // no cwd line at all
            "ps:111":    "ttys001\n",
            "ps:222":    "ttys002\n",
        ])
        let procs = try ShellProcessEnumerator(runner: runner).enumerateClaudeProcesses()
        #expect(procs.count == 1)
        #expect(procs[0].pid == 111)
    }

    // MARK: - iter-065 regression coverage

    @Test func excludesClaudeExeByCommNameCheck() throws {
        // pgrep on macOS catches `claude.exe` (Claude Desktop Electron
        // subprocess) when querying for `claude`. We must filter by the
        // exact `comm` value from ps.
        let runner = FakeShellRunner(outputs: [
            "pgrep":       "100\n200\n300\n",
            "ps_comm:100": "claude\n",
            "ps_comm:200": "claude.exe\n",          // should be filtered
            "ps_comm:300": "claude-research\n",     // should be filtered
            "lsof:100":    "p100\nfcwd\nn/repo/a\n",
            "lsof:200":    "p200\nfcwd\nn/repo/b\n",
            "lsof:300":    "p300\nfcwd\nn/repo/c\n",
            "ps:100":      "ttys001\n",
            "ps:200":      "ttys002\n",
            "ps:300":      "ttys003\n",
        ])
        let procs = try ShellProcessEnumerator(runner: runner).enumerateClaudeProcesses()
        #expect(procs.count == 1)
        #expect(procs[0].pid == 100)
    }

    @Test func lsofIsCalledWithDashAFlag() throws {
        // Without `-a`, lsof ORs `-p` and `-d cwd` and returns the cwd of
        // every process. This is the iter-062 bug that crept into prod.
        let runner = FakeShellRunner(outputs: [
            "pgrep":    "555\n",
            "lsof:555": "p555\nfcwd\nn/some/path\n",
            "ps:555":   "ttys004\n",
        ])
        _ = try ShellProcessEnumerator(runner: runner).enumerateClaudeProcesses()
        let lsofCall = runner.calls.first { $0.0.hasSuffix("/lsof") }
        #expect(lsofCall != nil, "lsof should have been invoked")
        #expect(lsofCall!.1.contains("-a"),
                "lsof MUST be called with -a to AND the -p and -d filters")
    }

    @Test func excludesClaudeExeEvenIfFirstInList() throws {
        // Order-independent: filter applies regardless of pgrep ordering.
        let runner = FakeShellRunner(outputs: [
            "pgrep":       "200\n100\n",
            "ps_comm:100": "claude\n",
            "ps_comm:200": "claude.exe\n",
            "lsof:100":    "p100\nfcwd\nn/x\n",
            "lsof:200":    "p200\nfcwd\nn/y\n",
            "ps:100":      "ttys001\n",
            "ps:200":      "ttys002\n",
        ])
        let procs = try ShellProcessEnumerator(runner: runner).enumerateClaudeProcesses()
        #expect(procs.count == 1)
        #expect(procs[0].pid == 100)
    }
}

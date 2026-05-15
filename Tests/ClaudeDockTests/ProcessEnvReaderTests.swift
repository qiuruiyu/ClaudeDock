import Foundation
import Testing
@testable import ClaudeDock

@Suite struct ProcessEnvReaderTests {

    // MARK: - parse() unit tests with hand-crafted buffers

    /// Encode the KERN_PROCARGS2 buffer layout from primitive parts so
    /// tests don't have to depend on any real process.
    private func makeBuffer(execPath: String,
                            argv: [String],
                            env: [String: String]) -> [UInt8] {
        var out: [UInt8] = []
        // argc
        var argc = Int32(argv.count)
        withUnsafeBytes(of: &argc) { out.append(contentsOf: $0) }
        // exec_path + null
        out.append(contentsOf: Array(execPath.utf8))
        out.append(0)
        // Align with extra null padding (Darwin pads to pointer alignment)
        out.append(0); out.append(0); out.append(0)
        // argv strings
        for a in argv {
            out.append(contentsOf: Array(a.utf8))
            out.append(0)
        }
        // env strings (key=value)
        for (k, v) in env {
            out.append(contentsOf: Array("\(k)=\(v)".utf8))
            out.append(0)
        }
        return out
    }

    @Test func parsesSingleEnvVar() {
        let buf = makeBuffer(execPath: "/usr/bin/claude",
                             argv: ["claude"],
                             env: ["TERM_PROGRAM": "vscode"])
        let env = DarwinProcessEnvReader.parse(buf)
        #expect(env["TERM_PROGRAM"] == "vscode")
    }

    @Test func parsesAllRelevantTermEnvVars() {
        let buf = makeBuffer(execPath: "/path/claude",
                             argv: ["claude", "--version"],
                             env: [
                                "TERM_PROGRAM": "vscode",
                                "VSCODE_PID": "98765",
                                "ITERM_SESSION_ID": "w0t0p0:ABCDEF",
                                "TERM_SESSION_ID": "ABC-DEF",
                                "HOME": "/Users/test",
                             ])
        let env = DarwinProcessEnvReader.parse(buf)
        #expect(env["TERM_PROGRAM"] == "vscode")
        #expect(env["VSCODE_PID"] == "98765")
        #expect(env["ITERM_SESSION_ID"] == "w0t0p0:ABCDEF")
        #expect(env["TERM_SESSION_ID"] == "ABC-DEF")
        #expect(env["HOME"] == "/Users/test")
    }

    @Test func emptyBufferReturnsEmpty() {
        #expect(DarwinProcessEnvReader.parse([]) == [:])
        #expect(DarwinProcessEnvReader.parse([0, 0, 0]) == [:])
    }

    @Test func skipsMultipleArgvStrings() {
        let buf = makeBuffer(execPath: "/bin/sh",
                             argv: ["sh", "-c", "echo hi"],
                             env: ["FOO": "bar"])
        let env = DarwinProcessEnvReader.parse(buf)
        #expect(env["FOO"] == "bar")
    }

    @Test func tolerantOfEnvWithEmbeddedEquals() {
        // VS Code stores some env vars with `=` in the value
        let buf = makeBuffer(execPath: "/x",
                             argv: ["x"],
                             env: ["FOO": "key=val=more"])
        let env = DarwinProcessEnvReader.parse(buf)
        #expect(env["FOO"] == "key=val=more")
    }

    // MARK: - Live readEnv (best-effort against current process)

    @Test func readsOurOwnEnvVars() {
        // Spawn `/bin/sleep` with a known env var, read it back.
        // Skip if we can't spawn (CI sandboxes, etc.).
        let key = "CLAUDEDOCK_TEST_MARKER_\(UUID().uuidString.prefix(8))"
        let value = "marker-\(UUID().uuidString.prefix(8))"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sleep")
        p.arguments = ["0.5"]
        var environment = ProcessInfo.processInfo.environment
        environment[key] = String(value)
        p.environment = environment
        do {
            try p.run()
        } catch {
            return  // can't spawn → skip
        }
        defer { p.terminate(); p.waitUntilExit() }
        // Give the kernel a moment to populate its argv/env
        Thread.sleep(forTimeInterval: 0.05)
        let env = DarwinProcessEnvReader().readEnv(pid: p.processIdentifier)
        #expect(env[key] == String(value), "Reader should see our injected env var")
    }
}

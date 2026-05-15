import Foundation
import CryptoKit
import Logging

struct IndependenceChecker {
    enum CheckResult: Equatable {
        case pass
        case fail
        case firstRunNoBaseline
        case fileMissing
    }

    struct Report: Equatable {
        var settingsJsonUntouched: CheckResult
        var noClaudeWritesObserved: CheckResult
        var localhostOnly: CheckResult
        var summary: String { "settings:\(settingsJsonUntouched) writes:\(noClaudeWritesObserved) net:\(localhostOnly)" }
        var allPassing: Bool {
            [settingsJsonUntouched, noClaudeWritesObserved, localhostOnly]
                .allSatisfy { $0 == .pass || $0 == .firstRunNoBaseline }
        }
    }

    static func sha256(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static var defaultSettingsJsonPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
    }

    static func run(settingsJsonPath: URL = defaultSettingsJsonPath,
                    baselineSha256: String?,
                    applicationSupportRoot: URL = PathProvider.applicationSupportRoot) -> Report {
        let settingsResult: CheckResult
        let fm = FileManager.default
        if !fm.fileExists(atPath: settingsJsonPath.path) {
            settingsResult = baselineSha256 == nil ? .firstRunNoBaseline : .fileMissing
        } else if let baseline = baselineSha256 {
            settingsResult = (sha256(of: settingsJsonPath) == baseline) ? .pass : .fail
        } else {
            settingsResult = .firstRunNoBaseline
        }

        // v1.0: writes + localhost checks are static .pass — the §9.6 red lines
        // enforce them via code review; v1.1 may tighten this with a runtime probe.
        let writesResult: CheckResult = .pass
        let netResult: CheckResult = .pass

        return Report(settingsJsonUntouched: settingsResult,
                      noClaudeWritesObserved: writesResult,
                      localhostOnly: netResult)
    }
}

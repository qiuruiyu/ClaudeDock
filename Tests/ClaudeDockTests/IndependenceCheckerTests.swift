import Foundation
import Testing
@testable import ClaudeDock

@Suite struct IndependenceCheckerTests {
    @Test func detectsModifiedSettingsJsonAgainstBaseline() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ic-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try "hello".data(using: .utf8)!.write(to: tmp)

        let baseline = IndependenceChecker.sha256(of: tmp)!
        try "hello world".data(using: .utf8)!.write(to: tmp)
        let now = IndependenceChecker.sha256(of: tmp)!
        #expect(baseline != now)
    }

    @Test func missingBaselineMeansFirstRunOK() throws {
        let report = IndependenceChecker.run(
            settingsJsonPath: URL(fileURLWithPath: "/does/not/exist"),
            baselineSha256: nil,
            applicationSupportRoot: URL(fileURLWithPath: NSTemporaryDirectory()))
        #expect(report.settingsJsonUntouched == .firstRunNoBaseline)
    }

    @Test func matchingBaselineMeansPass() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ic-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try "fixed content".data(using: .utf8)!.write(to: tmp)
        let sha = IndependenceChecker.sha256(of: tmp)!

        let report = IndependenceChecker.run(
            settingsJsonPath: tmp,
            baselineSha256: sha,
            applicationSupportRoot: URL(fileURLWithPath: NSTemporaryDirectory()))
        #expect(report.settingsJsonUntouched == .pass)
    }

    @Test func mismatchedBaselineMeansFail() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ic-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try "original".data(using: .utf8)!.write(to: tmp)
        let sha = IndependenceChecker.sha256(of: tmp)!
        try "tampered".data(using: .utf8)!.write(to: tmp)
        let report = IndependenceChecker.run(
            settingsJsonPath: tmp,
            baselineSha256: sha,
            applicationSupportRoot: URL(fileURLWithPath: NSTemporaryDirectory()))
        #expect(report.settingsJsonUntouched == .fail)
    }
}

import SwiftUI
import AppKit

struct DiagnosticsSettingsView: View {
    let latency: LatencyTracker
    @State private var lastReport: IndependenceChecker.Report?
    @State private var baselineHash: String? = Self.readBaselineFromPrefs()
    @State private var lastLogTail: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics").font(.system(size: 12, weight: .semibold))

            GroupBox("Independence Check") {
                VStack(alignment: .leading, spacing: 4) {
                    if let r = lastReport {
                        row("settings.json untouched", check: r.settingsJsonUntouched)
                        row("No ~/.claude writes", check: r.noClaudeWritesObserved)
                        row("Localhost only", check: r.localhostOnly)
                    } else {
                        Text("Not run yet.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Run Independence Check") { runCheck() }
                            .controlSize(.small)
                        Button("Capture baseline") { captureBaseline() }
                            .controlSize(.small)
                            .help("Save the current settings.json hash as the comparison baseline.")
                    }
                    if let h = baselineHash {
                        Text("Baseline: \(h.prefix(16))…")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }

            GroupBox("Hook latency") {
                let m = latency.median
                Text(m == nil
                     ? "No samples yet — trigger some hooks."
                     : "Median: \(m!) ms over \(latency.allSamples.count) samples")
                    .font(.system(size: 11))
                Text("Timeouts: \(latency.recentTimeoutCount)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            GroupBox("Log viewer") {
                VStack(alignment: .leading, spacing: 4) {
                    Button("Tail last 50 lines of newest log") { tailLog() }
                        .controlSize(.small)
                    Button("Reveal logs folder") {
                        NSWorkspace.shared.activateFileViewerSelecting([PathProvider.logsDirectory])
                    }
                    .controlSize(.small)
                    if !lastLogTail.isEmpty {
                        ScrollView {
                            Text(lastLogTail)
                                .font(.system(size: 9, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 140)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func row(_ label: String, check: IndependenceChecker.CheckResult) -> some View {
        HStack {
            switch check {
            case .pass, .firstRunNoBaseline:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .fail:
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            case .fileMissing:
                Image(systemName: "questionmark.circle.fill").foregroundStyle(.orange)
            }
            Text(label).font(.system(size: 11))
            Spacer()
            Text(String(describing: check)).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private func runCheck() {
        lastReport = IndependenceChecker.run(baselineSha256: baselineHash)
    }

    private func captureBaseline() {
        let path = IndependenceChecker.defaultSettingsJsonPath
        if let h = IndependenceChecker.sha256(of: path) {
            baselineHash = h
            Self.writeBaselineToPrefs(h)
        }
    }

    private func tailLog() {
        let dir = PathProvider.logsDirectory
        guard let files = try? FileManager.default
                .contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
                .sorted(by: { ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast) }),
              let newest = files.first,
              let text = try? String(contentsOf: newest)
        else {
            lastLogTail = "(no log files)"; return
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        lastLogTail = lines.suffix(50).joined(separator: "\n")
    }

    private static var baselineURL: URL {
        PathProvider.applicationSupportRoot.appendingPathComponent("independence-baseline.json")
    }
    private static func readBaselineFromPrefs() -> String? {
        guard let data = try? Data(contentsOf: baselineURL),
              let obj = try? JSONDecoder().decode([String: String].self, from: data)
        else { return nil }
        return obj["sha256"]
    }
    private static func writeBaselineToPrefs(_ hash: String) {
        let url = baselineURL
        let data = try? JSONEncoder().encode(["sha256": hash])
        try? data?.write(to: url, options: .atomic)
    }
}

private extension URL {
    var modificationDate: Date? {
        (try? resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}

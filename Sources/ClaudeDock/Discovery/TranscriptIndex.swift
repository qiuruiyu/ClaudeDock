// Sources/ClaudeDock/Discovery/TranscriptIndex.swift
//
// Walks ~/.claude/projects/ and indexes every JSONL transcript by the
// `cwd` value stored inside its first entry. Used by SessionDiscovery
// to map a discovered claude process's CWD to its session_id without
// having to depend on Claude Code's directory-name encoding scheme
// (which can change silently between Claude Code versions).

import Foundation
import Logging

struct TranscriptRef: Equatable, Sendable {
    let path: URL
    let cwd: String
    let sessionId: String   // derived from filename
    let mtime: Date
}

struct TranscriptIndex: Sendable {
    let entries: [TranscriptRef]

    /// Pick the most-recently-modified transcript whose stored cwd matches.
    func transcript(forCwd cwd: String) -> TranscriptRef? {
        entries
            .filter { $0.cwd == cwd }
            .max(by: { $0.mtime < $1.mtime })
    }

    static func build(at projectsRoot: URL, limit: Int = 256) -> TranscriptIndex {
        let log = Logger(label: "claudedock.discovery.index")
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: projectsRoot.path, isDirectory: &isDir), isDir.boolValue else {
            return TranscriptIndex(entries: [])
        }
        guard let subdirs = try? fm.contentsOfDirectory(at: projectsRoot,
                                                       includingPropertiesForKeys: nil,
                                                       options: [.skipsHiddenFiles]) else {
            return TranscriptIndex(entries: [])
        }
        var out: [TranscriptRef] = []
        out.reserveCapacity(min(limit, 64))
        outer: for sub in subdirs {
            guard let files = try? fm.contentsOfDirectory(at: sub,
                                                         includingPropertiesForKeys: [.contentModificationDateKey],
                                                         options: [.skipsHiddenFiles]) else {
                continue
            }
            for f in files where f.pathExtension == "jsonl" {
                if out.count >= limit {
                    log.warning("TranscriptIndex capped at \(limit) entries")
                    break outer
                }
                if let ref = makeRef(jsonlURL: f) {
                    out.append(ref)
                }
            }
        }
        return TranscriptIndex(entries: out)
    }

    private static func makeRef(jsonlURL: URL) -> TranscriptRef? {
        guard let fh = try? FileHandle(forReadingFrom: jsonlURL) else { return nil }
        defer { try? fh.close() }
        let chunk = try? fh.read(upToCount: 8192)
        guard let data = chunk, let s = String(data: data, encoding: .utf8) else { return nil }
        guard let firstLine = s.split(whereSeparator: \.isNewline).first(where: { !$0.isEmpty }),
              let lineData = String(firstLine).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
              let cwd = json["cwd"] as? String, !cwd.isEmpty else {
            return nil
        }
        let mtime = (try? jsonlURL.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? Date(timeIntervalSince1970: 0)
        let sessionId = jsonlURL.deletingPathExtension().lastPathComponent
        return TranscriptRef(path: jsonlURL, cwd: cwd, sessionId: sessionId, mtime: mtime)
    }
}

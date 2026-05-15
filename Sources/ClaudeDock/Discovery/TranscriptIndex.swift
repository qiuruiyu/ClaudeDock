// Sources/ClaudeDock/Discovery/TranscriptIndex.swift
//
// Look up the most-recently-modified transcript for a given CWD without
// walking the entire `~/.claude/projects/` tree. Claude Code stores
// transcripts at:
//
//   ~/.claude/projects/<encoded-cwd>/<session-id>.jsonl
//
// where the encoding replaces every character in CWD that isn't an
// ASCII letter, digit, or hyphen with `-`. We mirror that rule to
// resolve the subdir directly. Falls back to a bounded full scan only
// if the encoded subdir doesn't exist (e.g. Claude Code changes the
// encoding in a future version) — never reads more than necessary.
//
// History: an earlier iter-062 implementation walked the whole tree
// with a 256-transcript cap. Power users with hundreds of transcripts
// hit the cap before their actual running claudes' subdirs were
// indexed, so discovery silently missed those sessions.

import Foundation
import Logging

struct TranscriptRef: Equatable, Sendable {
    let path: URL
    let cwd: String
    let sessionId: String   // derived from filename
    let mtime: Date
}

struct TranscriptIndex: Sendable {
    let projectsRoot: URL
    private let log = Logger(label: "claudedock.discovery.index")

    /// API-compatible with the old `build(at:)` factory — but the
    /// resulting struct holds no eager state; lookups happen on-demand
    /// in `transcript(forCwd:)`.
    static func build(at projectsRoot: URL) -> TranscriptIndex {
        TranscriptIndex(projectsRoot: projectsRoot)
    }

    /// Resolve the most-recently-modified `.jsonl` whose stored `cwd`
    /// matches `cwd`. Tries the encoded-name subdir first; if missing,
    /// falls back to a bounded scan so the discovery flow still works
    /// even if Claude Code's encoding rule changes.
    func transcript(forCwd cwd: String) -> TranscriptRef? {
        let fm = FileManager.default
        let encoded = Self.encodeProjectsDirName(for: cwd)
        let primary = projectsRoot.appendingPathComponent(encoded)
        if let ref = bestMatch(in: primary, matchingCwd: cwd, fm: fm) {
            return ref
        }
        // Fallback: encoded path either doesn't exist or didn't contain
        // a transcript matching `cwd`. Scan known subdirs as a safety
        // net — capped, but capped so high a real user shouldn't hit it.
        return fallbackScan(matchingCwd: cwd, fm: fm)
    }

    /// Encode a CWD path to the subdirectory name Claude Code uses.
    /// Every character that isn't an ASCII letter, digit, or hyphen
    /// becomes a single `-`. Consecutive non-alphanumerics produce
    /// consecutive dashes (no collapsing).
    static func encodeProjectsDirName(for cwd: String) -> String {
        var out = ""
        out.reserveCapacity(cwd.count)
        for scalar in cwd.unicodeScalars {
            let isAsciiLetter = (0x41...0x5A).contains(Int(scalar.value))
                || (0x61...0x7A).contains(Int(scalar.value))
            let isAsciiDigit = (0x30...0x39).contains(Int(scalar.value))
            let isHyphen = scalar.value == 0x2D
            if isAsciiLetter || isAsciiDigit || isHyphen {
                out.unicodeScalars.append(scalar)
            } else {
                out.append("-")
            }
        }
        return out
    }

    private func bestMatch(in dir: URL, matchingCwd cwd: String, fm: FileManager) -> TranscriptRef? {
        guard let files = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        var best: TranscriptRef?
        for f in files where f.pathExtension == "jsonl" {
            guard let ref = Self.makeRef(jsonlURL: f), ref.cwd == cwd else { continue }
            if best == nil || ref.mtime > best!.mtime { best = ref }
        }
        return best
    }

    private func fallbackScan(matchingCwd cwd: String, fm: FileManager) -> TranscriptRef? {
        // High cap (16k files) — far beyond any realistic personal usage
        // but bounded enough to avoid an OS-level meltdown if something
        // weird is happening with ~/.claude/projects/.
        let limit = 16_384
        guard let subdirs = try? fm.contentsOfDirectory(
            at: projectsRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }
        var best: TranscriptRef?
        var seen = 0
        outer: for sub in subdirs {
            guard let files = try? fm.contentsOfDirectory(
                at: sub,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for f in files where f.pathExtension == "jsonl" {
                seen += 1
                if seen > limit {
                    log.warning("Fallback transcript scan exceeded \(limit) files; stopping")
                    break outer
                }
                guard let ref = Self.makeRef(jsonlURL: f), ref.cwd == cwd else { continue }
                if best == nil || ref.mtime > best!.mtime { best = ref }
            }
        }
        return best
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

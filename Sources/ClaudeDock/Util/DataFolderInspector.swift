import Foundation

struct DataFolderInspector {
    enum Kind: Equatable { case file, directory }
    struct Entry: Identifiable, Equatable {
        let relativePath: String
        let byteSize: Int64
        let kind: Kind
        var id: String { relativePath }
    }

    /// Lists top-level entries under `root`, computing total byte size for
    /// directories via a recursive walk. `maxDepth` limits the *listing* depth
    /// (so we don't bullet-list every log file) but directory sizes are still
    /// summed across the full subtree.
    static func inspect(at root: URL, maxDepth: Int = 1) throws -> [Entry] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            return []
        }
        let contents = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey])
        var result: [Entry] = []
        for url in contents {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = values.isDirectory ?? false
            let size: Int64
            if isDirectory {
                size = recursiveSize(of: url)
            } else {
                size = (try? Int64(url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)) ?? 0
            }
            result.append(Entry(relativePath: url.lastPathComponent,
                                byteSize: size,
                                kind: isDirectory ? .directory : .file))
        }
        return result.sorted { $0.relativePath < $1.relativePath }
    }

    private static func recursiveSize(of url: URL) -> Int64 {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let u as URL in en {
            let values = try? u.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }

    static func formattedSize(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}

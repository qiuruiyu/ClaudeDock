import Foundation

struct NameResolver: Sendable {
    func resolve(cwd: String, workKey: String, aliasStore: AliasStore) -> String {
        if let alias = aliasStore.meta(forWorkKey: workKey)?.alias, !alias.isEmpty {
            return alias
        }
        if cwd == "/" { return "Root" }
        if cwd == NSHomeDirectory() { return "Home" }
        if let repo = findGitRepoRoot(startingAt: cwd) {
            return (repo as NSString).lastPathComponent
        }
        return (cwd as NSString).lastPathComponent
    }

    private func findGitRepoRoot(startingAt cwd: String) -> String? {
        var url = URL(fileURLWithPath: cwd)
        for _ in 0..<32 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path) {
                return url.path
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return nil
    }
}

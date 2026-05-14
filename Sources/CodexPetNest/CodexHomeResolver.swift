import Foundation

enum CodexHomeResolver {
    static func resolve(environment: [String: String] = ProcessInfo.processInfo.environment,
                        fileManager: FileManager = .default) -> URL {
        let fallback = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex")

        guard let rawValue = environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return fallback
        }

        let candidate = URL(fileURLWithPath: NSString(string: rawValue).expandingTildeInPath).standardizedFileURL
        guard isUserWritable(candidate, fileManager: fileManager) else {
            return fallback
        }

        return candidate
    }

    private static func isUserWritable(_ url: URL, fileManager: FileManager) -> Bool {
        let path = url.path
        let protectedPrefixes = ["/Applications", "/Library", "/System", "/usr", "/bin", "/sbin"]
        if protectedPrefixes.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            return false
        }

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            return isDirectory.boolValue && fileManager.isWritableFile(atPath: path)
        }

        var parent = url.deletingLastPathComponent()
        while parent.path != "/" {
            if fileManager.fileExists(atPath: parent.path, isDirectory: &isDirectory) {
                return isDirectory.boolValue && fileManager.isWritableFile(atPath: parent.path)
            }
            parent.deleteLastPathComponent()
        }

        return false
    }
}

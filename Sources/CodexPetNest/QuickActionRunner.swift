import AppKit

enum QuickActionRunnerError: Error, LocalizedError {
    case appNotFound(String)
    case shortcutFailed(String)
    case terminalFailed(String)
    case terminalRejected

    var errorDescription: String? {
        switch self {
        case .appNotFound(let path): return "Application not found: \(path)"
        case .shortcutFailed(let msg): return "Shortcut failed: \(msg)"
        case .terminalFailed(let msg): return "Terminal action failed: \(msg)"
        case .terminalRejected: return "Terminal command was cancelled"
        }
    }
}

final class QuickActionRunner {
    static let shared = QuickActionRunner()

    private init() {}

    func run(_ action: QuickActionConfig) async {
        do {
            switch action.kind {
            case .app:
                try await runApp(target: action.target)
            case .shortcut:
                try await runShortcut(target: action.target)
            case .terminal:
                try await runTerminalCommand(target: action.target, action: action)
            case .url:
                try await runURL(target: action.target)
            }
        } catch {
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = "Action Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    // MARK: - App

    private func runApp(target: String) async throws {
        if target.hasPrefix("/") || target.hasPrefix("~") {
            let expanded = NSString(string: target).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw QuickActionRunnerError.appNotFound(target)
            }
            let config = NSWorkspace.OpenConfiguration()
            try await NSWorkspace.shared.openApplication(at: url, configuration: config)
        } else {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target) ??
                            NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: "/Applications/\(target).app")) else {
                throw QuickActionRunnerError.appNotFound(target)
            }
            let config = NSWorkspace.OpenConfiguration()
            try await NSWorkspace.shared.openApplication(at: url, configuration: config)
        }
    }

    // MARK: - Shortcut

    private func runShortcut(target: String) async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", target]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: QuickActionRunnerError.shortcutFailed(
                        "exit code \(process.terminationStatus)"
                    ))
                }
            }
            do {
                try task.run()
            } catch {
                continuation.resume(throwing: QuickActionRunnerError.shortcutFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Terminal Command

    private func runTerminalCommand(target: String, action: QuickActionConfig) async throws {
        let confirmed: Bool = await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "Run Terminal Command?"
            alert.informativeText = action.name + "\n\nCommand:\n\(target)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Run")
            alert.addButton(withTitle: "Cancel")

            let cancelButton = alert.buttons[1]
            cancelButton.keyEquivalent = "\u{1b}"

            return alert.runModal() == .alertFirstButtonReturn
        }

        guard confirmed else {
            throw QuickActionRunnerError.terminalRejected
        }

        // Open command in a visible Terminal window via AppleScript
        let escaped = target.replacingOccurrences(of: "\\", with: "\\\\")
                             .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\"\n    activate\n    do script \"\(escaped)\"\nend tell"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
            if let error = error {
                let message = (error[NSAppleScript.errorMessage] as? String) ?? "Unknown error"
                continuation.resume(throwing: QuickActionRunnerError.terminalFailed(message))
            } else {
                continuation.resume()
            }
        }
    }

    // MARK: - URL

    @MainActor
    private func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private func runURL(target: String) async throws {
        var urlString = target.trimmingCharacters(in: .whitespaces)
        if !urlString.hasPrefix("http://"), !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        guard let url = URL(string: urlString) else {
            throw QuickActionRunnerError.shortcutFailed("Invalid URL: \(target)")
        }
        await openURL(url)
    }
}

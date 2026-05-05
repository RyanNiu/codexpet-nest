import Foundation

struct PomodoroSettings: Codable, Equatable {
    var focusMinutes: Int = 25
    var breakMinutes: Int = 5
}

struct Settings: Codable, Equatable {
    var showNest: Bool = true
    var launchAtLogin: Bool = false
    var nestPosition: String = "bottom"
    var theme: String = "default"
    var enabledWidgets: [String] = ["clock", "countdown", "pomodoro"]
    var countdownTarget: String?
    var pomodoro: PomodoroSettings = PomodoroSettings()
}

final class SettingsStore {
    static let shared = SettingsStore()

    var settings = Settings()

    private let supportDir: URL
    private let fileURL: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        supportDir = home.appendingPathComponent("Library/Application Support/CodexPet Nest")
        fileURL = supportDir.appendingPathComponent("settings.json")
        settings = Settings()

        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(Settings.self, from: data)
        else { return }
        settings = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func widgetEnabled(_ id: String) -> Bool {
        settings.enabledWidgets.contains(id)
    }
}

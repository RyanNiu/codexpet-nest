import Foundation

struct PomodoroSettings: Codable, Equatable {
    var focusMinutes: Int = 25
    var breakMinutes: Int = 5
}

enum PetRuntimeMode: String, Codable, Equatable {
    case codexFollow
    case standalone
}

struct SavedRect: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct Settings: Codable, Equatable {
    var showNest: Bool = true
    var launchAtLogin: Bool = false
    var nestPosition: String = "bottom"
    var theme: String = "default"
    var enabledWidgets: [String] = ["clock", "countdown", "pomodoro", "usage"]
    var countdownTarget: String?
    var pomodoro: PomodoroSettings = PomodoroSettings()
    var managedPetIds: [String] = []
    var activeNestId: String = "capacity-orbit-nest"
    var hoverOnlyNestIds: Set<String> = []

    // Pet runtime mode
    var preferredPetRuntimeMode: PetRuntimeMode? = nil
    var activeStandalonePetId: String?
    var standalonePetFrame: SavedRect?
    var freeRoamEnabled: Bool = false
    var petAlwaysOnTop: Bool = false
    var petClickThrough: Bool = false
    var randomBehaviorEnabled: Bool = true
    var randomBehaviorIntensity: String = "medium"
    var showStandalonePet: Bool = true

    // Whether standalone mode was entered via auto-degradation (Codex unavailable)
    var standaloneWasAutoDegraded: Bool = false

    // Analytics
    var sentAppInstall: Bool = false
    var lastLaunchEventDate: String? // YYYY-MM-DD
    var lastSeenVersion: String?

    var activePetRuntimeMode: PetRuntimeMode {
        guard let preferred = preferredPetRuntimeMode else {
            return .codexFollow
        }
        return preferred
    }
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
        #if DEBUG
        print("[SettingsStore] fileURL: \(fileURL.path)")
        #endif
        load()
    }

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(Settings.self, from: data)
            settings = decoded
            #if DEBUG
            print("[SettingsStore] loaded activeNestId=\(settings.activeNestId)")
            #endif
        } catch {
            #if DEBUG
            print("[SettingsStore] load failed: \(error)")
            #endif
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            #if DEBUG
            print("[SettingsStore] saved activeNestId=\(settings.activeNestId)")
            #endif
        } catch {
            #if DEBUG
            print("[SettingsStore] save failed: \(error)")
            #endif
        }
    }

    func widgetEnabled(_ id: String) -> Bool {
        settings.enabledWidgets.contains(id)
    }
}

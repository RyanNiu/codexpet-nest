import Foundation

final class BuiltInPetInstaller {
    static let shared = BuiltInPetInstaller()

    private let petsDir: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let supportDir = home.appendingPathComponent("Library/Application Support/CodexPet Nest")
        petsDir = supportDir.appendingPathComponent("pets")
    }

    func installIfNeeded() {
        guard let bundledPetsURL = Bundle.main.url(forResource: "BundledPets", withExtension: nil) else {
            print("[BuiltInPetInstaller] BundledPets directory not found in app bundle.")
            return
        }

        let fileManager = FileManager.default
        let builtInPetId = "builtin-default"
        let bundledURL = bundledPetsURL.appendingPathComponent(builtInPetId)
        let installedURL = petsDir.appendingPathComponent(builtInPetId)

        guard fileManager.fileExists(atPath: bundledURL.path) else {
            print("[BuiltInPetInstaller] Bundled pet not found: \(builtInPetId)")
            return
        }

        if !fileManager.fileExists(atPath: installedURL.path) {
            print("[BuiltInPetInstaller] Installing \(builtInPetId) for the first time...")
            try? fileManager.createDirectory(at: petsDir, withIntermediateDirectories: true)
            try? fileManager.copyItem(at: bundledURL, to: installedURL)
            LocalPetManager.shared.refresh()
        }
    }
}

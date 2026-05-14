import Foundation
import AppKit

struct PetManifest: Codable {
    let id: String
    let displayName: String
    let description: String
    let spritesheetPath: String
    let preview: String?
    
    // Advanced rendering meta
    let frameWidth: Int?
    let frameHeight: Int?
    let frameSize: Int?
    let columns: Int?
    let rows: Int?
    let animations: [String: PetAnimationConfig]?
}


struct LocalPet: Identifiable {
    let id: String
    let displayName: String
    let description: String
    let spritesheetPath: String
    let preview: String?
    let path: String
    var isCurrent: Bool = false
    var isAppManaged: Bool = false
    let manifest: PetManifest?
}


final class LocalPetManager: ObservableObject {
    static let shared = LocalPetManager()

    @Published var pets: [LocalPet] = []
    @Published var currentPetId: String?

    private let fileManager = FileManager.default
    private let codexHome: URL
    private let petsDir: URL
    private let globalStateURL: URL
    private let appSupportDir: URL

    private init() {
        codexHome = CodexHomeResolver.resolve(fileManager: fileManager)
        petsDir = codexHome.appendingPathComponent("pets")
        globalStateURL = codexHome.appendingPathComponent(".codex-global-state.json")

        appSupportDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexPet Nest")
        
        refresh()
    }

    func refresh() {
        updateCurrentPetId()
        scanLocalPets()
    }

    private func updateCurrentPetId() {
        guard let data = try? Data(contentsOf: globalStateURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let atomState = json["electron-persisted-atom-state"] as? [String: Any],
              let selectedId = atomState["selected-avatar-id"] as? String else {
            currentPetId = nil
            return
        }

        if selectedId.hasPrefix("custom:") {
            currentPetId = String(selectedId.dropFirst(7))
        } else {
            currentPetId = "codex-managed:\(selectedId)"
        }
    }

    private func scanLocalPets() {
        var foundPets: [LocalPet] = []
        
        guard let contents = try? fileManager.contentsOfDirectory(at: petsDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            self.pets = []
            return
        }

        for folderURL in contents {
            let petJsonURL = folderURL.appendingPathComponent("pet.json")
            guard fileManager.fileExists(atPath: petJsonURL.path) else { continue }

            do {
                let data = try Data(contentsOf: petJsonURL)
                let manifest = try JSONDecoder().decode(PetManifest.self, from: data)
                
                let petObj = LocalPet(
                    id: manifest.id,
                    displayName: manifest.displayName,
                    description: manifest.description,
                    spritesheetPath: manifest.spritesheetPath,
                    preview: manifest.preview,
                    path: folderURL.path,
                    isCurrent: manifest.id == currentPetId,
                    isAppManaged: SettingsStore.shared.settings.managedPetIds.contains(manifest.id),
                    manifest: manifest
                )

                
                foundPets.append(petObj)
            } catch {
                print("Failed to parse pet.json at \(petJsonURL.path): \(error)")
            }
        }
        
        self.pets = foundPets.sorted { $0.displayName < $1.displayName }
    }

    func openInFinder(pet: LocalPet) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: pet.path)
    }

    func uninstallPet(_ pet: LocalPet) throws {
        try fileManager.removeItem(atPath: pet.path)
        
        if let index = SettingsStore.shared.settings.managedPetIds.firstIndex(of: pet.id) {
            SettingsStore.shared.settings.managedPetIds.remove(at: index)
            SettingsStore.shared.save()
        }
        
        refresh()
    }
}

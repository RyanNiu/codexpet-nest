import Foundation
import AppKit

struct InstalledNest: Identifiable {
    let id: String
    let manifest: PackageManifest
    let layout: NestLayout
    let rootURL: URL
    let previewURL: URL?
    
    var name: String { manifest.name }
    var author: String { manifest.author }
    var version: String { manifest.version }
    var description: String { manifest.description }
}

final class LocalNestManager {
    static let shared = LocalNestManager()
    
    private let nestsDir: URL
    private(set) var installedNests: [InstalledNest] = []
    
    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let supportDir = home.appendingPathComponent("Library/Application Support/CodexPet Nest")
        nestsDir = supportDir.appendingPathComponent("nests")
        try? FileManager.default.createDirectory(at: nestsDir, withIntermediateDirectories: true)
        refresh()
    }
    
    func refresh() {
        var nests: [InstalledNest] = []
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(at: nestsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            self.installedNests = []
            return
        }
        
        for folderURL in contents {
            let manifestURL = folderURL.appendingPathComponent("codexpet-package.json")
            guard fileManager.fileExists(atPath: manifestURL.path),
                  let manifestData = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONDecoder().decode(PackageManifest.self, from: manifestData),
                  manifest.type == PackageType.nest.rawValue else {
                continue
            }
            
            let layoutFile = manifest.layout ?? "nest.json"
            let layoutURL = folderURL.appendingPathComponent(layoutFile)
            guard fileManager.fileExists(atPath: layoutURL.path),
                  let layoutData = try? Data(contentsOf: layoutURL),
                  let layout = try? JSONDecoder().decode(NestLayout.self, from: layoutData) else {
                continue
            }
            
            var previewURL: URL?
            if let preview = manifest.preview {
                let pURL = folderURL.appendingPathComponent(preview)
                if fileManager.fileExists(atPath: pURL.path) {
                    previewURL = pURL
                }
            }
            
            nests.append(InstalledNest(
                id: manifest.id,
                manifest: manifest,
                layout: layout,
                rootURL: folderURL,
                previewURL: previewURL
            ))
        }
        
        self.installedNests = nests
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .installedNestsChanged, object: nil)
        }
    }
    
    func applyNest(id: String) {
        let isBuiltIn = (id == "default" || id == NestRenderer.orbitNestId)
        if isBuiltIn || installedNests.contains(where: { $0.id == id }) {
            SettingsStore.shared.settings.activeNestId = id
            SettingsStore.shared.save()
            
            NotificationCenter.default.post(name: .activeNestChanged, object: nil)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
            NotificationCenter.default.post(name: .nestSizeChanged, object: nil)
        }
    }
    
    func uninstallNest(id: String) throws {
        if id == "default" { return }
        if SettingsStore.shared.settings.activeNestId == id {
            throw NSError(domain: "LocalNestManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot uninstall the active nest skin. Switch to default first."])
        }
        
        let folderURL = nestsDir.appendingPathComponent(id)
        if FileManager.default.fileExists(atPath: folderURL.path) {
            try FileManager.default.removeItem(at: folderURL)
        }
        refresh()
    }
    
    func openNestFolder(id: String) {
        let folderURL = nestsDir.appendingPathComponent(id)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folderURL.path)
    }
    
    func getActiveNest() -> InstalledNest? {
        let activeId = SettingsStore.shared.settings.activeNestId
        if activeId == "default" || activeId == NestRenderer.orbitNestId {
            return nil
        }
        
        if let nest = installedNests.first(where: { $0.id == activeId }) {
            return nest
        }
        
        // Fallback: If active ID is not found, set to default and return nil
        SettingsStore.shared.settings.activeNestId = "default"
        SettingsStore.shared.save()
        return nil
    }
}

extension Notification.Name {
    static let installedNestsChanged = Notification.Name("installedNestsChanged")
    static let activeNestChanged = Notification.Name("activeNestChanged")
}

import Foundation
import AppKit

struct InstalledNest: Identifiable {
    let id: String
    let manifest: PackageManifest
    let layout: NestLayout
    let rootURL: URL
    let previewURL: URL?
    let installedVersion: String

    var name: String { manifest.name }
    var author: String { manifest.author }
    var version: String { installedVersion }
    var description: String { manifest.description }

    var isBuiltIn: Bool {
        LocalNestManager.isBuiltIn(id: id)
    }

    var isPlatformNest: Bool {
        FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("manifest.json").path)
    }
}

final class LocalNestManager {
    static let shared = LocalNestManager()

    private let nestsDir: URL
    private(set) var installedNests: [InstalledNest] = []

    static let builtInNestIds: Set<String> = [
        "capacity-orbit-nest",
        "basket-pomodoro-nest",
        "legend-status-nest",
        "window-desk-nest"
    ]

    static func isBuiltIn(id: String) -> Bool {
        return builtInNestIds.contains(id)
    }

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
            // Scan versioned platform nests: nests/<id>/<version>/
            if let versionDirs = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                for versionDir in versionDirs {
                    let manifestURL = versionDir.appendingPathComponent("manifest.json")
                    guard fileManager.fileExists(atPath: manifestURL.path) else { continue }

                    if let nest = loadPlatformNest(id: folderURL.lastPathComponent, version: versionDir.lastPathComponent, rootURL: versionDir) {
                        nests.append(nest)
                    }
                }
            }

            // Legacy flat nests: nests/<id>/codexpet-package.json
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

            let nestId = manifest.id
            if nests.contains(where: { $0.id == nestId && $0.isPlatformNest }) { continue }

            nests.append(InstalledNest(
                id: nestId,
                manifest: manifest,
                layout: layout,
                rootURL: folderURL,
                previewURL: previewURL,
                installedVersion: manifest.version
            ))
        }

        // Dedup: keep only the latest version per nest ID
        var latestByID: [String: InstalledNest] = [:]
        for nest in nests {
            if let existing = latestByID[nest.id] {
                if nest.installedVersion.compare(existing.installedVersion, options: .numeric) == .orderedDescending {
                    latestByID[nest.id] = nest
                }
            } else {
                latestByID[nest.id] = nest
            }
        }
        self.installedNests = Array(latestByID.values)

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .installedNestsChanged, object: nil)
        }
    }

    private func loadPlatformNest(id: String, version: String, rootURL: URL) -> InstalledNest? {
        let fileManager = FileManager.default

        let layoutURL = rootURL.appendingPathComponent("nest.json")
        guard fileManager.fileExists(atPath: layoutURL.path),
              let layoutData = try? Data(contentsOf: layoutURL),
              let layout = try? JSONDecoder().decode(NestLayout.self, from: layoutData) else {
            return nil
        }

        let manifestURL = rootURL.appendingPathComponent("manifest.json")
        let runtimeManifest: RuntimeManifest?
        if let data = try? Data(contentsOf: manifestURL) {
            runtimeManifest = try? JSONDecoder().decode(RuntimeManifest.self, from: data)
        } else {
            runtimeManifest = nil
        }

        let packageManifest = PackageManifest(
            type: PackageType.nest.rawValue,
            schemaVersion: layout.schemaVersion,
            id: id,
            name: runtimeManifest?.title ?? id,
            version: version,
            author: "CodexPet Platform",
            description: "",
            manifest: nil,
            spritesheet: nil,
            preview: nil,
            license: "MIT",
            tags: nil,
            layout: "nest.json",
            theme: nil,
            widgets: nil
        )

        return InstalledNest(
            id: id,
            manifest: packageManifest,
            layout: layout,
            rootURL: rootURL,
            previewURL: nil,
            installedVersion: version
        )
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
        if id == "default" || LocalNestManager.isBuiltIn(id: id) {
            throw NSError(domain: "LocalNestManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot uninstall built-in nest skins."])
        }
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

        let candidates = installedNests.filter { $0.id == activeId }
        if let nest = candidates.sorted(by: { $0.installedVersion.compare($1.installedVersion, options: .numeric) == .orderedDescending }).first {
            return nest
        }

        SettingsStore.shared.settings.activeNestId = "default"
        SettingsStore.shared.save()
        return nil
    }
}

extension Notification.Name {
    static let installedNestsChanged = Notification.Name("installedNestsChanged")
    static let activeNestChanged = Notification.Name("activeNestChanged")
}

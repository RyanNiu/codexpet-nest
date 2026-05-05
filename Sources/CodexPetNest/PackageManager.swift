import Foundation
import CryptoKit

// MARK: - Package Types

enum PackageType: String {
    case pet = "codexpet.pet"
    case nest = "codexpet.nest"
}

struct PackageManifest: Codable {
    let type: String
    let schemaVersion: String
    let id: String
    let name: String
    let version: String
    let author: String
    let description: String
    let manifest: String?
    let spritesheet: String?
    let preview: String?
    let license: String
    let tags: [String]?

    // Nest-specific
    let layout: String?
    let theme: String?
    let widgets: [String]?
}

enum PackageManagerError: Error, LocalizedError {
    case downloadFailed(String)
    case sha256Mismatch(expected: String, actual: String)
    case unzipFailed(String)
    case missingManifest
    case invalidManifest(String)
    case missingRequiredFile(String)
    case pathTraversal(String)
    case unexpectedFileType(String)
    case unsafeContent(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let msg): return "Download failed: \(msg)"
        case .sha256Mismatch(let exp, let act): return "SHA256 mismatch. Expected \(exp.prefix(16))..., got \(act.prefix(16))..."
        case .unzipFailed(let msg): return "Unzip failed: \(msg)"
        case .missingManifest: return "Missing codexpet-package.json"
        case .invalidManifest(let msg): return "Invalid package manifest: \(msg)"
        case .missingRequiredFile(let f): return "Missing required file: \(f)"
        case .pathTraversal(let p): return "Unsafe path detected: \(p)"
        case .unexpectedFileType(let t): return "Unexpected package type: \(t)"
        case .unsafeContent(let msg): return "Unsafe content detected: \(msg)"
        }
    }
}

// MARK: - Package Manager

final class PackageManager {
    static let shared = PackageManager()

    private let api = CodexPetAPI.shared
    private let supportDir: URL
    private let internalPetsDir: URL
    private let nestsDir: URL
    private let tempDir: URL
    private let codexPetsDir: URL

    private init() {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        supportDir = home.appendingPathComponent("Library/Application Support/CodexPet Nest")
        internalPetsDir = supportDir.appendingPathComponent("pets")
        nestsDir = supportDir.appendingPathComponent("nests")
        tempDir = supportDir.appendingPathComponent("tmp")

        let codexHomeEnv = ProcessInfo.processInfo.environment["CODEX_HOME"]
            ?? home.appendingPathComponent(".codex").path
        codexPetsDir = URL(fileURLWithPath: codexHomeEnv).appendingPathComponent("pets")

        try? fileManager.createDirectory(at: internalPetsDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: nestsDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: codexPetsDir, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    func isPetInstalled(id: String) -> Bool {
        FileManager.default.fileExists(atPath: codexPetsDir.appendingPathComponent(id).path)
    }

    func isNestInstalled(id: String) -> Bool {
        FileManager.default.fileExists(atPath: nestsDir.appendingPathComponent("\(id)/codexpet-package.json").path)
    }

    func installPet(id: String) async throws {
        let meta = try await api.getPetDownload(id: id)
        try await downloadAndInstall(downloadURL: meta.url, expectedSHA256: meta.sha256, type: .pet)
    }

    func installLocalPet(zipURL: URL) async throws {
        let data = try Data(contentsOf: zipURL)
        try await processInstall(data: data, expectedSHA256: nil, type: .pet)
    }

    func installLocalNest(zipURL: URL) async throws {
        let data = try Data(contentsOf: zipURL)
        try await processInstall(data: data, expectedSHA256: nil, type: .nest)
    }

    func installNest(id: String) async throws {
        let meta = try await api.getNestDownload(id: id)
        try await downloadAndInstall(downloadURL: meta.url, expectedSHA256: meta.sha256, type: .nest)
    }

    // MARK: - Core Flow

    private func downloadAndInstall(downloadURL: String, expectedSHA256: String?, type: PackageType) async throws {
        let (data, _) = try await api.downloadFile(url: downloadURL)
        
        guard let expected = expectedSHA256 else {
            throw PackageManagerError.invalidManifest("Missing SHA256 for online integrity check")
        }

        try await processInstall(data: data, expectedSHA256: expected, type: type)
    }

    private func processInstall(data: Data, expectedSHA256: String?, type: PackageType) async throws {
        if let expected = expectedSHA256 {
            let actual = sha256Hex(data)
            guard actual == expected else {
                throw PackageManagerError.sha256Mismatch(expected: expected, actual: actual)
            }
        }

        let workDir = tempDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        let zipPath = workDir.appendingPathComponent("package.zip")
        try data.write(to: zipPath, options: .atomic)

        try await safeUnzip(zipPath, to: workDir, type: type)
        try? FileManager.default.removeItem(at: zipPath)

        let (manifest, packageRoot) = try resolvePackageRoot(in: workDir)
        try validateManifest(manifest, type: type, packageRoot: packageRoot)

        let installDir = (type == .pet ? codexPetsDir : nestsDir).appendingPathComponent(manifest.id)
        try? FileManager.default.removeItem(at: installDir)
        try FileManager.default.createDirectory(at: installDir, withIntermediateDirectories: true)

        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: packageRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        
        for src in contents {
            let dst = installDir.appendingPathComponent(src.lastPathComponent)
            try fileManager.copyItem(at: src, to: dst)
        }
        
        if type == .pet {
            if !SettingsStore.shared.settings.managedPetIds.contains(manifest.id) {
                SettingsStore.shared.settings.managedPetIds.append(manifest.id)
                SettingsStore.shared.save()
            }
            LocalPetManager.shared.refresh()
        } else if type == .nest {
            LocalNestManager.shared.refresh()
        }
    }

    // MARK: - Validation

    private func resolvePackageRoot(in workDir: URL) throws -> (PackageManifest, URL) {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: workDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        var manifests: [(manifest: PackageManifest, url: URL)] = []

        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.lastPathComponent == "codexpet-package.json" {
                let data = try Data(contentsOf: fileURL)
                do {
                    let manifest = try JSONDecoder().decode(PackageManifest.self, from: data)
                    manifests.append((manifest, fileURL))
                } catch {
                    throw PackageManagerError.invalidManifest("Could not parse codexpet-package.json: \(error.localizedDescription)")
                }
            }
        }

        if manifests.isEmpty {
            throw PackageManagerError.missingManifest
        }
        if manifests.count > 1 {
            throw PackageManagerError.invalidManifest("Multiple codexpet-package.json found")
        }

        let entry = manifests[0]
        let packageRoot = entry.url.deletingLastPathComponent()
        
        let normalizedWorkDir = workDir.standardizedFileURL
        let normalizedPackageRoot = packageRoot.standardizedFileURL
        
        if normalizedPackageRoot != normalizedWorkDir {
            let parent = normalizedPackageRoot.deletingLastPathComponent()
            if parent != normalizedWorkDir {
                throw PackageManagerError.invalidManifest("Package root must be ZIP root or a single top-level folder")
            }
        }

        return (entry.manifest, packageRoot)
    }

    private func validateManifest(_ manifest: PackageManifest, type: PackageType, packageRoot: URL) throws {
        guard manifest.type == type.rawValue else {
            throw PackageManagerError.unexpectedFileType(manifest.type)
        }

        let idPattern = try NSRegularExpression(pattern: "^[a-z0-9][a-z0-9-]{1,50}$")
        guard idPattern.firstMatch(in: manifest.id, range: NSRange(manifest.id.startIndex..., in: manifest.id)) != nil else {
            throw PackageManagerError.invalidManifest("Invalid package id format")
        }

        try validateFileExists(in: packageRoot, path: "codexpet-package.json", label: "Manifest")
        if let preview = manifest.preview {
            try validateFileExists(in: packageRoot, path: preview, label: "Preview")
        }

        if type == .pet {
            guard let spritesheet = manifest.spritesheet,
                  let petManifest = manifest.manifest else {
                throw PackageManagerError.missingRequiredFile("Pet manifest or spritesheet")
            }
            try validateFileExists(in: packageRoot, path: spritesheet, label: "Spritesheet")
            try validateFileExists(in: packageRoot, path: petManifest, label: "Pet metadata (pet.json)")
            
            let petJsonURL = packageRoot.appendingPathComponent(petManifest)
            let petData = try Data(contentsOf: petJsonURL)
            let petJson = try JSONSerialization.jsonObject(with: petData) as? [String: Any]
            if let spritesheetPath = petJson?["spritesheetPath"] as? String {
                try validateFileExists(in: packageRoot, path: spritesheetPath, label: "Pet spritesheet (internal)")
            } else {
                throw PackageManagerError.missingRequiredFile("pet.json spritesheetPath")
            }
        } else if type == .nest {
            let layoutFile = manifest.layout ?? "nest.json"
            try validateFileExists(in: packageRoot, path: layoutFile, label: "Nest Layout (nest.json)")
            
            let layoutURL = packageRoot.appendingPathComponent(layoutFile)
            let layoutData = try Data(contentsOf: layoutURL)
            let layout = try JSONDecoder().decode(NestLayout.self, from: layoutData)
            
            guard layout.canvas.width > 0 && layout.canvas.height > 0 else {
                throw PackageManagerError.invalidManifest("Canvas width/height must be > 0")
            }
            if layout.canvas.width > 2048 || layout.canvas.height > 2048 {
                throw PackageManagerError.invalidManifest("Canvas size exceeds limit (2048)")
            }
            
            for layer in layout.layers {
                guard layer.type == "image" else {
                    throw PackageManagerError.unsafeContent("Unsupported layer type: \(layer.type)")
                }
                try validateFileExists(in: packageRoot, path: layer.src, label: "Layer asset (\(layer.id))")
                guard layer.frame.width > 0 && layer.frame.height > 0 else {
                    throw PackageManagerError.invalidManifest("Layer frame width/height must be > 0")
                }
            }
        }
    }

    private func validateFileExists(in root: URL, path: String, label: String) throws {
        if path.contains("..") || path.hasPrefix("/") {
            throw PackageManagerError.pathTraversal("\(label): \(path)")
        }
        
        let fileURL = root.appendingPathComponent(path).standardizedFileURL
        if !fileURL.path.hasPrefix(root.standardizedFileURL.path) {
            throw PackageManagerError.pathTraversal("\(label): \(path)")
        }
        
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            throw PackageManagerError.missingRequiredFile("\(label) (\(path))")
        }
    }

    // MARK: - Safe ZIP (Manual using SafeZipReader)

    private func safeUnzip(_ zipPath: URL, to destDir: URL, type: PackageType) async throws {
        let data = try Data(contentsOf: zipPath)
        let reader = try SafeZipReader(data: data)
        
        let forbiddenExtensions = ["sh", "js", "py", "rb", "exe", "bin", "com", "bat", "cmd", "swift", "php", "pl", "vbs"]

        for entry in reader.entries {
            // 1. Extension check
            let ext = URL(fileURLWithPath: entry.path).pathExtension.lowercased()
            if forbiddenExtensions.contains(ext) {
                throw PackageManagerError.unsafeContent("Forbidden file type: \(entry.path)")
            }
            
            // 2. Extract (SafeZipReader handles path traversal and symlinks internally)
            try reader.extract(entry: entry, to: destDir)
        }
    }

    private func sha256Hex(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

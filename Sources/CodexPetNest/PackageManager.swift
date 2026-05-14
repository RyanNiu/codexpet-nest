import Foundation
import CryptoKit
import AppKit

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
    case missingManifest(PackageType)
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
        case .missingManifest(let type):
            if type == .pet {
                return "ZIP must contain codexpet-package.json, or pet.json plus its spritesheet at the package root or inside one top-level folder."
            } else {
                return "This package is missing codexpet-package.json. Please use a CodexPet package zip."
            }
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

        codexPetsDir = CodexHomeResolver.resolve(fileManager: fileManager).appendingPathComponent("pets")

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
        do {
            let meta = try await api.getPetDownload(id: id)
            try await downloadAndInstall(downloadURL: meta.url, expectedSHA256: meta.sha256, type: .pet)
        } catch {
            await AppAnalytics.shared.report(eventName: "pet_install_failed", metadata: ["id": id, "error": error.localizedDescription])
            throw error
        }
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
        do {
            let meta = try await api.getNestDownload(id: id)
            try await downloadAndInstall(downloadURL: meta.url, expectedSHA256: meta.sha256, type: .nest)
        } catch {
            await AppAnalytics.shared.report(eventName: "nest_install_failed", metadata: ["id": id, "error": error.localizedDescription])
            throw error
        }
    }

    /// Download and validate a pet from the platform API without installing it yet.
    func preparePetInstall(id: String) async throws -> PreparedPackageInstall {
        let meta = try await api.getPetDownload(id: id)
        let data = try await downloadAndValidate(downloadURL: meta.url, expectedSHA256: meta.sha256)
        let manifest = try await inspectPackage(data: data, type: .pet)
        guard manifest.id == id else {
            throw PackageManagerError.invalidManifest("Downloaded pet id (\(manifest.id)) does not match requested pet id (\(id))")
        }
        return PreparedPackageInstall(data: data, manifest: manifest)
    }

    func installPreparedPet(_ prepared: PreparedPackageInstall) async throws {
        try await processInstall(data: prepared.data, expectedSHA256: nil, type: .pet)
    }

    // MARK: - Core Flow

    private func downloadAndInstall(downloadURL: String, expectedSHA256: String?, type: PackageType) async throws {
        let data = try await downloadAndValidate(downloadURL: downloadURL, expectedSHA256: expectedSHA256)
        try await processInstall(data: data, expectedSHA256: nil, type: type)
    }

    private func downloadAndValidate(downloadURL: String, expectedSHA256: String?) async throws -> Data {
        let (data, _) = try await api.downloadFile(url: downloadURL)

        guard let expected = expectedSHA256 else {
            throw PackageManagerError.invalidManifest("Missing SHA256 for online integrity check")
        }

        let actual = sha256Hex(data)
        guard actual == expected else {
            throw PackageManagerError.sha256Mismatch(expected: expected, actual: actual)
        }

        return data
    }

    private func inspectPackage(data: Data, type: PackageType) async throws -> PackageManifest {
        let workDir = tempDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        let zipPath = workDir.appendingPathComponent("package.zip")
        try data.write(to: zipPath, options: .atomic)

        try await safeUnzip(zipPath, to: workDir, type: type)
        try? FileManager.default.removeItem(at: zipPath)

        let (manifest, packageRoot) = try resolvePackageRoot(in: workDir, type: type)
        try validateManifest(manifest, type: type, packageRoot: packageRoot)
        return manifest
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

        let (manifest, packageRoot) = try resolvePackageRoot(in: workDir, type: type)
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
            await AppAnalytics.shared.report(eventName: "pet_install_success", metadata: ["id": manifest.id])
        } else if type == .nest {
            LocalNestManager.shared.refresh()
            await AppAnalytics.shared.report(eventName: "nest_install_success", metadata: ["id": manifest.id])
        }
    }

    // MARK: - Validation

    private func resolvePackageRoot(in workDir: URL, type: PackageType) throws -> (PackageManifest, URL) {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: workDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        var manifests: [(manifest: PackageManifest, url: URL)] = []

        while let fileURL = enumerator?.nextObject() as? URL {
            // Skip __MACOSX metadata folders
            if fileURL.path.contains("__MACOSX") { continue }
            
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

        if !manifests.isEmpty {
            // If multiple manifests found (e.g. nested packages), pick the shallowest one that isn't in __MACOSX
            manifests.sort { a, b in
                a.url.path.count < b.url.path.count
            }

            let entry = manifests[0]
            let packageRoot = entry.url.deletingLastPathComponent()
            
            let normalizedWorkDir = workDir.standardizedFileURL
            let normalizedPackageRoot = packageRoot.standardizedFileURL
            
            // Check if packageRoot is workDir or a direct child of workDir
            if normalizedPackageRoot != normalizedWorkDir {
                let parent = normalizedPackageRoot.deletingLastPathComponent()
                if parent != normalizedWorkDir {
                    let relativePath = normalizedPackageRoot.path.replacingOccurrences(of: normalizedWorkDir.path, with: "")
                    let components = relativePath.components(separatedBy: "/").filter { !$0.isEmpty }
                    if components.count > 1 {
                        throw PackageManagerError.invalidManifest("Package root must be ZIP root or a single top-level folder. Found at: \(relativePath)")
                    }
                }
            }

            return (entry.manifest, packageRoot)
        }

        // Fallback for .pet type: search for pet.json in root or unique top-level folder
        if type == .pet {
            let rootContents = try fileManager.contentsOfDirectory(at: workDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            
            // 1. Try ZIP root
            let rootPetJson = workDir.appendingPathComponent("pet.json")
            if fileManager.fileExists(atPath: rootPetJson.path) {
                return try resolveLegacyPetPackage(at: workDir, petJsonURL: rootPetJson)
            }
            
            // 2. Try unique top-level directory
            let dirs = rootContents.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            if dirs.count == 1 {
                let subDir = dirs[0]
                let subPetJson = subDir.appendingPathComponent("pet.json")
                if fileManager.fileExists(atPath: subPetJson.path) {
                    return try resolveLegacyPetPackage(at: subDir, petJsonURL: subPetJson)
                }
            }
        }

        throw PackageManagerError.missingManifest(type)
    }

    private func resolveLegacyPetPackage(at packageRoot: URL, petJsonURL: URL) throws -> (PackageManifest, URL) {
        let petData = try Data(contentsOf: petJsonURL)
        let petManifest: PetManifest
        do {
            petManifest = try JSONDecoder().decode(PetManifest.self, from: petData)
        } catch {
            throw PackageManagerError.invalidManifest("Could not parse pet.json: \(error.localizedDescription)")
        }

        // Validate ID format
        let idPattern = try NSRegularExpression(pattern: "^[a-z0-9][a-z0-9-]{1,50}$")
        guard idPattern.firstMatch(in: petManifest.id, range: NSRange(petManifest.id.startIndex..., in: petManifest.id)) != nil else {
            throw PackageManagerError.invalidManifest("Invalid pet id format in pet.json: \(petManifest.id)")
        }

        // Validate spritesheet existence and safety
        try validateFileExists(in: packageRoot, path: petManifest.spritesheetPath, label: "Spritesheet")

        // Validate preview existence and safety if present
        if let preview = petManifest.preview {
            try validateFileExists(in: packageRoot, path: preview, label: "Preview")
        }

        // Construct memory PackageManifest
        let manifest = PackageManifest(
            type: "codexpet.pet",
            schemaVersion: "1.0.0",
            id: petManifest.id,
            name: petManifest.displayName,
            version: "1.0.0",
            author: "Local",
            description: petManifest.description,
            manifest: "pet.json",
            spritesheet: petManifest.spritesheetPath,
            preview: petManifest.preview,
            license: "Unknown",
            tags: nil,
            layout: nil,
            theme: nil,
            widgets: nil
        )

        return (manifest, packageRoot)
    }

    private func validateManifest(_ manifest: PackageManifest, type: PackageType, packageRoot: URL) throws {
        guard manifest.type == type.rawValue else {
            throw PackageManagerError.unexpectedFileType(manifest.type)
        }

        let idPattern = try NSRegularExpression(pattern: "^[a-z0-9][a-z0-9-]{1,50}$")
        guard idPattern.firstMatch(in: manifest.id, range: NSRange(manifest.id.startIndex..., in: manifest.id)) != nil else {
            throw PackageManagerError.invalidManifest("Invalid package id format")
        }

        if FileManager.default.fileExists(atPath: packageRoot.appendingPathComponent("codexpet-package.json").path) {
            try validateFileExists(in: packageRoot, path: "codexpet-package.json", label: "Manifest")
        }
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
            guard let layoutFile = manifest.layout else {
                 throw PackageManagerError.invalidManifest("Missing 'layout' field in codexpet-package.json")
            }
            guard layoutFile == "nest.json" else {
                 throw PackageManagerError.invalidManifest("Layout field must be 'nest.json'")
            }
            try validateFileExists(in: packageRoot, path: "nest.json", label: "Nest Layout (nest.json)")
            
            let layoutURL = packageRoot.appendingPathComponent("nest.json")
            let layoutData = try Data(contentsOf: layoutURL)
            let layout: NestLayout
            do {
                layout = try JSONDecoder().decode(NestLayout.self, from: layoutData)
            } catch {
                throw PackageManagerError.invalidManifest("Failed to parse nest.json: \(error.localizedDescription)")
            }
            
            try validateNestLayout(layout, packageRoot: packageRoot)
        }
    }

    private func validateNestLayout(_ layout: NestLayout, packageRoot: URL) throws {
        // 1. schemaVersion
        guard layout.schemaVersion == "1.0.0" || layout.schemaVersion == "1.1.0" else {
            throw PackageManagerError.invalidManifest("Unsupported schema version: \(layout.schemaVersion)")
        }

        // 2. canvas
        guard layout.canvas.width > 0 && layout.canvas.height > 0 &&
              layout.canvas.width.isFinite && layout.canvas.height.isFinite else {
            throw PackageManagerError.invalidManifest("Canvas dimensions must be positive finite numbers")
        }
        if layout.canvas.width > 1024 || layout.canvas.height > 1024 {
            throw PackageManagerError.invalidManifest("Canvas size exceeds limit (1024x1024)")
        }

        // Layers validation
        for layer in layout.layers {
            guard layer.type == "image" else {
                throw PackageManagerError.unsafeContent("Unsupported layer type: \(layer.type). V1 only supports 'image'.")
            }
            try validateThemeAssetPath(layer.src, packageRoot: packageRoot, label: "Layer asset (\(layer.id))")
            try validateNestFrame(layer.frame, canvas: layout.canvas, id: layer.id)
        }

        // Widget slots validation
        let allowedWidgets = ["usage", "clock", "countdown", "pomodoro"]
        if let slots = layout.widgetSlots {
            for (id, rect) in slots {
                guard allowedWidgets.contains(id) else {
                    throw PackageManagerError.invalidManifest("Unauthorized widget slot: \(id). Allowed: \(allowedWidgets.joined(separator: ", "))")
                }
                try validateNestFrame(rect, canvas: layout.canvas, id: id)
            }
        }

        // v1.1 validation
        if layout.schemaVersion == "1.1.0" {
            // 3. elements
            if let elements = layout.elements {
                var elementIds = Set<String>()
                for element in elements {
                    guard !element.id.isEmpty else {
                        throw PackageManagerError.invalidManifest("Element ID cannot be empty")
                    }
                    guard !elementIds.contains(element.id) else {
                        throw PackageManagerError.invalidManifest("Duplicate element ID: \(element.id)")
                    }
                    elementIds.insert(element.id)
                    try validateNestElement(element, layout: layout, packageRoot: packageRoot)
                }
            }

            // 10. metricBands
            if let metricBands = layout.metricBands {
                try validateMetricBands(metricBands)
            }
        }
    }

    private func validateNestElement(_ element: NestThemeElement, layout: NestLayout, packageRoot: URL) throws {
        // frame width/height > 0 且 finite. 允许最多 8px overflow
        try validateNestFrame(element.frame, canvas: layout.canvas, id: element.id)
        
        // metric validation
        if let metricId = element.metric {
            guard MetricCatalog.shared.contains(metricId) else {
                throw PackageManagerError.invalidManifest("Unknown metric: \(metricId) in element \(element.id)")
            }
        }
        
        switch element {
        case .staticImage(let e):
            try validateThemeAssetPath(e.src, packageRoot: packageRoot, label: "Element \(e.id) src")
            
        case .variantImage(let e):
            guard !e.variants.isEmpty else {
                throw PackageManagerError.invalidManifest("Element \(e.id) variants cannot be empty")
            }
            for (key, val) in e.variants {
                guard !key.isEmpty else {
                    throw PackageManagerError.invalidManifest("Element \(e.id) variant key cannot be empty")
                }
                try validateThemeAssetPath(val, packageRoot: packageRoot, label: "Element \(e.id) variant \(key)")
            }
            if let fallback = e.fallback {
                try validateThemeAssetPath(fallback, packageRoot: packageRoot, label: "Element \(e.id) fallback")
            }
            
        case .metricText(let e):
            if let style = e.style {
                if let weight = style.fontWeight {
                    let allowedWeights = ["regular", "medium", "semibold", "bold"]
                    guard allowedWeights.contains(weight) else {
                        throw PackageManagerError.invalidManifest("Invalid fontWeight: \(weight) in element \(e.id)")
                    }
                }
                if let align = style.alignment {
                    let allowedAligns = ["left", "center", "right"]
                    guard allowedAligns.contains(align) else {
                        throw PackageManagerError.invalidManifest("Invalid alignment: \(align) in element \(e.id)")
                    }
                }
                if let color = style.color {
                    try validateHexColor(color, elementId: e.id)
                }
                if let fontSize = style.fontSize {
                    guard fontSize >= 1 && fontSize <= 128 else {
                        throw PackageManagerError.invalidManifest("fontSize must be between 1 and 128 in element \(e.id)")
                    }
                }
            }
            
        case .metricGauge(let e):
            // metricGauge.renderer validation
            let allowedRenderers = ["ringStroke", "linearBar", "circleFill"]
            guard allowedRenderers.contains(e.renderer) else {
                throw PackageManagerError.invalidManifest("Unknown renderer: \(e.renderer) in element \(e.id)")
            }
            
            if let style = e.style {
                if let color = style.fillColor { try validateHexColor(color, elementId: e.id) }
                if let color = style.trackColor { try validateHexColor(color, elementId: e.id) }
                if let opacity = style.opacity {
                    guard opacity >= 0 && opacity <= 1 else {
                        throw PackageManagerError.invalidManifest("opacity must be between 0 and 1 in element \(e.id)")
                    }
                }
                if let lineWidth = style.lineWidth {
                    guard lineWidth > 0 && lineWidth <= 64 else {
                        throw PackageManagerError.invalidManifest("lineWidth must be between 0 and 64 in element \(e.id)")
                    }
                }
                if let direction = style.direction {
                    let allowedDirections = ["leftToRight", "rightToLeft", "bottomToTop", "topToBottom"]
                    guard allowedDirections.contains(direction) else {
                        throw PackageManagerError.invalidManifest("Invalid direction: \(direction) in element \(e.id)")
                    }
                }
                if let lineCap = style.lineCap {
                    let allowedCaps = ["butt", "round", "square"]
                    guard allowedCaps.contains(lineCap) else {
                        throw PackageManagerError.invalidManifest("Invalid lineCap: \(lineCap) in element \(e.id)")
                    }
                }
                if let clipShape = style.clipShape {
                    guard clipShape == "circle" else {
                        throw PackageManagerError.invalidManifest("Invalid clipShape: \(clipShape) in element \(e.id)")
                    }
                }
                if let cornerRadius = style.cornerRadius {
                    guard cornerRadius >= 0 else {
                        throw PackageManagerError.invalidManifest("cornerRadius must be >= 0 in element \(e.id)")
                    }
                }
                if let startAngle = style.startAngle {
                    guard startAngle.isFinite else {
                        throw PackageManagerError.invalidManifest("startAngle must be finite in element \(e.id)")
                    }
                }
            }
        }
    }

    private func validateNestFrame(_ rect: NestRect, canvas: NestCanvas, id: String) throws {
        guard rect.width > 0 && rect.height > 0 &&
              rect.x.isFinite && rect.y.isFinite &&
              rect.width.isFinite && rect.height.isFinite else {
            throw PackageManagerError.invalidManifest("Frame (\(id)) must have positive finite dimensions")
        }
        
        // frame 允许最多 8px overflow
        let margin: Double = 8.0
        if rect.x < -margin || rect.y < -margin || 
           (rect.x + rect.width) > (canvas.width + margin) || 
           (rect.y + rect.height) > (canvas.height + margin) {
            throw PackageManagerError.invalidManifest("Frame (\(id)) exceeds allowed canvas overflow (8px)")
        }
    }

    private func validateMetricBands(_ metricBands: [String: [MetricBand]]) throws {
        for (metricId, bands) in metricBands {
            guard MetricCatalog.shared.isPercentMetric(metricId) else {
                throw PackageManagerError.invalidManifest("Metric bands can only be applied to percent metrics. Invalid: \(metricId)")
            }
            guard !bands.isEmpty else {
                throw PackageManagerError.invalidManifest("Metric bands for \(metricId) cannot be empty")
            }
            
            var lastMax: Double = -Double.infinity
            let idRegex = try NSRegularExpression(pattern: "^[a-z0-9_-]+$")
            
            for band in bands {
                guard !band.id.isEmpty else {
                    throw PackageManagerError.invalidManifest("Band ID cannot be empty in \(metricId)")
                }
                guard idRegex.firstMatch(in: band.id, range: NSRange(band.id.startIndex..., in: band.id)) != nil else {
                    throw PackageManagerError.invalidManifest("Invalid band ID format: \(band.id) in \(metricId). Only lowercase letters, numbers, underscores and hyphens allowed.")
                }
                guard band.max.isFinite else {
                    throw PackageManagerError.invalidManifest("Band max must be finite in \(metricId)")
                }
                guard band.max > lastMax else {
                    throw PackageManagerError.invalidManifest("Band max must be strictly increasing in \(metricId)")
                }
                guard band.max <= 100 else {
                    throw PackageManagerError.invalidManifest("Band max must be <= 100 in \(metricId)")
                }
                lastMax = band.max
            }
            
            // TODO: Optional recommendation - last max should be 100
        }
    }

    private func validateThemeAssetPath(_ path: String, packageRoot: URL, label: String) throws {
        // Relative path, no traversal, no remote URL
        if path.contains("..") || path.hasPrefix("/") || path.contains("://") {
            throw PackageManagerError.pathTraversal("\(label): \(path)")
        }
        
        let fileURL = packageRoot.appendingPathComponent(path).standardizedFileURL
        if !fileURL.path.hasPrefix(packageRoot.standardizedFileURL.path) {
            throw PackageManagerError.pathTraversal("\(label): \(path)")
        }
        
        // Extension must be png or webp
        let ext = fileURL.pathExtension.lowercased()
        guard ext == "png" || ext == "webp" else {
            throw PackageManagerError.invalidManifest("\(label) has unsupported extension: \(ext). Only png/webp allowed.")
        }
        
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            throw PackageManagerError.missingRequiredFile("\(label) (\(path))")
        }
    }

    private func validateHexColor(_ color: String, elementId: String) throws {
        let pattern = "^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$"
        let regex = try NSRegularExpression(pattern: pattern)
        guard regex.firstMatch(in: color, range: NSRange(color.startIndex..., in: color)) != nil else {
            throw PackageManagerError.invalidManifest("Invalid hex color: \(color) in element \(elementId)")
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

struct PreparedPackageInstall {
    let data: Data
    let manifest: PackageManifest
}

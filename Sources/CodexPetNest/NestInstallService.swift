import Foundation
import CryptoKit
import AppKit

enum NestInstallError: Error, LocalizedError {
    case invalidURL
    case missingToken
    case intentResolveFailed(String)
    case manifestDownloadFailed(String)
    case layoutDownloadFailed(String)
    case assetDownloadFailed(String)
    case sha256Mismatch(file: String, expected: String, actual: String)
    case saveFailed(String)
    case completeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid install URL"
        case .missingToken: return "Missing install token in URL"
        case .intentResolveFailed(let msg): return "Failed to resolve install intent: \(msg)"
        case .manifestDownloadFailed(let msg): return "Failed to download runtime manifest: \(msg)"
        case .layoutDownloadFailed(let msg): return "Failed to download layout: \(msg)"
        case .assetDownloadFailed(let msg): return "Failed to download asset: \(msg)"
        case .sha256Mismatch(let file, let exp, let act):
            return "SHA256 mismatch for \(file). Expected \(exp.prefix(16))..., got \(act.prefix(16))..."
        case .saveFailed(let msg): return "Failed to save files: \(msg)"
        case .completeFailed(let msg): return "Failed to complete install: \(msg)"
        }
    }
}

final class NestInstallService {
    static let shared = NestInstallService()

    private let api = CodexPetAPI.shared
    private let fileManager = FileManager.default
    private let nestsDir: URL

    private init() {
        let home = fileManager.homeDirectoryForCurrentUser
        let supportDir = home.appendingPathComponent("Library/Application Support/CodexPet Nest")
        nestsDir = supportDir.appendingPathComponent("nests")
        try? fileManager.createDirectory(at: nestsDir, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    func handleInstallURL(_ url: URL) async {
        guard let token = extractToken(from: url) else {
            await showError(.missingToken)
            return
        }

        do {
            try await installFromToken(token)
        } catch let error as NestInstallError {
            await AppAnalytics.shared.report(eventName: "nest_install_failed", metadata: ["error": error.localizedDescription])
            await showError(error)
        } catch {
            await AppAnalytics.shared.report(eventName: "nest_install_failed", metadata: ["error": error.localizedDescription])
            await showError(.intentResolveFailed(error.localizedDescription))
        }
    }

    // MARK: - Core Flow

    private func installFromToken(_ intentToken: String) async throws {
        // Step 1: Resolve install intent
        let intent = try await api.resolveInstallIntent(token: intentToken)
        let runtimeToken = intent.runtimeToken

        // Step 2: Download runtime manifest
        let manifest = try await api.getRuntimeManifest(url: intent.runtimeManifestUrl)

        // Step 3: Download layout (nest.json), verify sha256
        let layoutData = try await api.downloadLayout(url: manifest.layout.url)
        let layoutHash = sha256Hex(layoutData)
        guard layoutHash == manifest.layout.sha256 else {
            throw NestInstallError.sha256Mismatch(
                file: "nest.json",
                expected: manifest.layout.sha256,
                actual: layoutHash
            )
        }

        // Validate layout is parseable
        do {
            _ = try JSONDecoder().decode(NestLayout.self, from: layoutData)
        } catch {
            throw NestInstallError.layoutDownloadFailed("Invalid nest.json: \(error.localizedDescription)")
        }

        // Step 4: Download assets, verify sha256
        var assetDataMap: [String: Data] = [:]
        for asset in manifest.assets {
            let data = try await api.downloadAsset(url: asset.url)
            let hash = sha256Hex(data)
            guard hash == asset.sha256 else {
                throw NestInstallError.sha256Mismatch(
                    file: asset.path,
                    expected: asset.sha256,
                    actual: hash
                )
            }
            assetDataMap[asset.path] = data
        }

        // Step 5: Save to versioned cache directory
        let nestDir = nestsDir.appendingPathComponent("\(manifest.id)/\(manifest.version)")
        if fileManager.fileExists(atPath: nestDir.path) {
            try? fileManager.removeItem(at: nestDir)
        }
        try fileManager.createDirectory(at: nestDir, withIntermediateDirectories: true)

        // Save runtime manifest
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: nestDir.appendingPathComponent("manifest.json"), options: .atomic)

        // Save layout
        try layoutData.write(to: nestDir.appendingPathComponent("nest.json"), options: .atomic)

        // Save assets
        let assetsDir = nestDir.appendingPathComponent("assets")
        try fileManager.createDirectory(at: assetsDir, withIntermediateDirectories: true)

        for (path, data) in assetDataMap {
            let relativePath: String
            if path.hasPrefix("assets/") {
                relativePath = String(path.dropFirst("assets/".count))
            } else {
                relativePath = path
            }

            let fileURL = assetsDir.appendingPathComponent(relativePath)
            let parentDir = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDir.path) {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
            try data.write(to: fileURL, options: .atomic)
        }

        // Step 6: Complete install (server must confirm before local activation)
        do {
            try await api.completeInstall(nestId: manifest.id, runtimeToken: runtimeToken)
        } catch {
            throw NestInstallError.completeFailed(error.localizedDescription)
        }

        // Step 7: Set as active nest (only after server confirms)
        await MainActor.run {
            LocalNestManager.shared.refresh()
            LocalNestManager.shared.applyNest(id: manifest.id)
        }
        await AppAnalytics.shared.report(eventName: "nest_install_success", metadata: ["id": manifest.id])
    }

    // MARK: - Helpers

    private func extractToken(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return components.queryItems?.first(where: { $0.name == "token" })?.value
    }

    private func sha256Hex(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    @MainActor
    private func showError(_ error: NestInstallError) {
        let alert = NSAlert()
        alert.messageText = "Nest Install Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

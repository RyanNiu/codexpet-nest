import Foundation

// MARK: - Install Intent

struct InstallIntentResponse: Codable {
    let runtimeToken: String
    let runtimeManifestUrl: String
    let nestId: String?
    let version: String?
}

// MARK: - Runtime Manifest

struct RuntimeManifest: Codable {
    let type: String
    let id: String
    let version: String
    let title: String
    let schemaVersion: String
    let layout: RuntimeLayoutRef
    let assets: [RuntimeAsset]
    let metricCatalog: RuntimeRegistryRef?
    let componentRegistry: RuntimeRegistryRef?
    let componentRegistryVersion: String?
    let expiresAt: String?
}

struct RuntimeLayoutRef: Codable {
    let url: String
    let sha256: String
    let size: Int
}

struct RuntimeAsset: Codable {
    let path: String
    let url: String
    let sha256: String
    let contentType: String
    let size: Int
}

struct RuntimeRegistryRef: Codable {
    let version: String
    let url: String
    let sha256: String
}

// MARK: - Install Complete

struct InstallCompleteRequest: Codable {
    let runtimeToken: String
}

struct InstallCompleteResponse: Codable {
    let ok: Bool
}

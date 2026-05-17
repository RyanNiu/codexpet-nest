import Foundation
import CryptoKit

final class AppAnalytics {
    static let shared = AppAnalytics()
    
    private let appId = "codexpet-nest"
    private let baseURL: String
    private let session: URLSession
    
    private var installId: String {
        let key = "analytics_install_id"
        if let id = UserDefaults.standard.string(forKey: key) {
            return id
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }
    
    private var installIdHash: String {
        let data = Data(installId.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private let sessionId = UUID().uuidString
    
    private init() {
        self.baseURL = ProcessInfo.processInfo.environment["CODEXPET_API_BASE_URL"] ?? "https://codexpet.xyz"
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }
    
    struct EventRequest: Codable {
        let appId: String
        let eventName: String
        let appVersion: String
        let buildNumber: String
        let platform: String
        let osVersion: String
        let installIdHash: String
        let sessionId: String
        let channel: String
        let locale: String
        let metadata: [String: String]
    }
    
    @discardableResult
    func report(eventName: String, metadata: [String: String] = [:]) async -> Bool {
        return await doReport(eventName: eventName, metadata: metadata)
    }
    
    private func doReport(eventName: String, metadata: [String: String]) async -> Bool {
        let channel = getChannel()
        let request = EventRequest(
            appId: appId,
            eventName: eventName,
            appVersion: getAppVersion(),
            buildNumber: getBuildNumber(),
            platform: "macos",
            osVersion: getOSVersion(),
            installIdHash: installIdHash,
            sessionId: sessionId,
            channel: channel,
            locale: Locale.current.identifier,
            metadata: metadata
        )
        
        guard let url = URL(string: "\(baseURL)/api/app/events") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            req.httpBody = try JSONEncoder().encode(request)
            let (_, response) = try await session.data(for: req)
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                return true
            }
            return false
        } catch {
            #if DEBUG
            print("[AppAnalytics] Failed to report \(eventName): \(error)")
            #endif
            return false
        }
    }
    
    private func getChannel() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let channelFile = home.appendingPathComponent("Library/Application Support/CodexPet Nest/install_channel.json")
        if let data = try? Data(contentsOf: channelFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let channel = json["channel"] as? String {
            return channel
        }
        return "unknown"
    }
    
    func getAppVersion() -> String {
        AppVersion.currentMarketingVersion
    }
    
    private func getBuildNumber() -> String {
        AppVersion.currentBuildVersion
    }
    
    private func getOSVersion() -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    }
    
    // MARK: - Lifecycle Events
    
    func trackLaunch() {
        Task {
            let today = ISO8601DateFormatter().string(from: Date()).prefix(10) // YYYY-MM-DD
            let currentVersion = getAppVersion()
            
            // 1. Install
            if !SettingsStore.shared.settings.sentAppInstall {
                if await report(eventName: "app_install") {
                    SettingsStore.shared.settings.sentAppInstall = true
                    SettingsStore.shared.save()
                }
            }
            
            // 2. Launch (once per day)
            if SettingsStore.shared.settings.lastLaunchEventDate != String(today) {
                if await report(eventName: "app_launch") {
                    SettingsStore.shared.settings.lastLaunchEventDate = String(today)
                    SettingsStore.shared.save()
                }
            }
            
            // 3. Update
            if let lastVersion = SettingsStore.shared.settings.lastSeenVersion, lastVersion != currentVersion {
                if await report(eventName: "app_update", metadata: [
                    "fromVersion": lastVersion,
                    "toVersion": currentVersion
                ]) {
                    SettingsStore.shared.settings.lastSeenVersion = currentVersion
                    SettingsStore.shared.save()
                }
            } else if SettingsStore.shared.settings.lastSeenVersion == nil {
                // First time tracking version
                SettingsStore.shared.settings.lastSeenVersion = currentVersion
                SettingsStore.shared.save()
            }
        }
    }
}

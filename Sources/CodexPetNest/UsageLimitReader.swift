import Foundation

struct UsageBucket: Codable, Equatable {
    let usedPercent: Int
    let windowMinutes: Int
    let resetAfterSeconds: Int?
    let resetAt: Double?
    
    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
        case resetAfterSeconds = "reset_after_seconds"
        case resetAt = "reset_at"
    }
    
    var remainingPercent: Int {
        max(0, 100 - usedPercent)
    }
    
    var resetDate: Date? {
        if let resetAt = resetAt {
            return Date(timeIntervalSince1970: resetAt)
        }
        return nil
    }
}

struct RawUsageLimitEvent: Codable {
    let type: String
    let planType: String?
    let rateLimits: RateLimits?
    let additionalRateLimits: [String: UsageBucket]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case planType = "plan_type"
        case rateLimits = "rate_limits"
        case additionalRateLimits = "additional_rate_limits"
    }
    
    struct RateLimits: Codable {
        let allowed: Bool
        let limitReached: Bool
        let primary: UsageBucket?
        let secondary: UsageBucket?
        
        enum CodingKeys: String, CodingKey {
            case allowed
            case limitReached = "limit_reached"
            case primary
            case secondary
        }
    }
}

enum UsageSource: String {
    case cached = "Cached"
    case live = "Live"
    case unavailable = "Unavailable"
}

struct UsageLimitInfo {
    let planType: String
    let source: UsageSource
    let allowed: Bool
    let limitReached: Bool
    let primary: UsageBucket?
    let secondary: UsageBucket?
    let additionalBuckets: [String: UsageBucket]
    let observedAt: Date
}

final class UsageLimitReader {
    private let codexHome: String
    
    init() {
        self.codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"]
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex").path
    }
    
    func readLatest() -> UsageLimitInfo? {
        let logFiles = ["logs_2.sqlite", "logs_1.sqlite"]
        
        for fileName in logFiles {
            let dbPath = (codexHome as NSString).appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: dbPath) {
                if let info = readFromDB(path: dbPath) {
                    return info
                }
            }
        }
        
        return nil
    }
    
    private func readFromDB(path: String) -> UsageLimitInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        
        // Query newest row containing the type
        let query = "SELECT feedback_log_body FROM logs WHERE feedback_log_body LIKE '%\"type\":\"codex.rate_limits\"%' ORDER BY id DESC LIMIT 1;"
        process.arguments = [path, query]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard let data = try outputPipe.fileHandleForReading.readToEnd(),
                  let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty
            else {
                return nil
            }
            
            // Extract JSON from the output (it might have prefix like "websocket event: ")
            guard let jsonRange = output.range(of: "\\{.*\\}", options: .regularExpression) else {
                return nil
            }
            
            let jsonString = String(output[jsonRange])
            guard let jsonData = jsonString.data(using: .utf8) else { return nil }
            
            let decoder = JSONDecoder()
            let rawEvent = try decoder.decode(RawUsageLimitEvent.self, from: jsonData)
            
            return UsageLimitInfo(
                planType: rawEvent.planType ?? "Unknown",
                source: .cached,
                allowed: rawEvent.rateLimits?.allowed ?? true,
                limitReached: rawEvent.rateLimits?.limitReached ?? false,
                primary: rawEvent.rateLimits?.primary,
                secondary: rawEvent.rateLimits?.secondary,
                additionalBuckets: rawEvent.additionalRateLimits ?? [:],
                observedAt: Date() // Could ideally parse ts from sqlite but this is fine for cached state
            )
        } catch {
            #if DEBUG
            print("UsageLimitReader error: \(error)")
            #endif
            return nil
        }
    }
}

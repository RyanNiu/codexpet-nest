import Foundation

struct UsageBucket: Codable, Equatable {
    let usedPercent: Double
    let windowMinutes: Int?
    let resetAfterSeconds: Int?
    let resetAt: Double?
    
    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
        case resetAfterSeconds = "reset_after_seconds"
        case resetAt = "reset_at"
    }
    
    var remainingPercent: Int {
        return Int(max(0, 100.0 - usedPercent))
    }
    
    var resetDate: Date? {
        if let resetAt = resetAt {
            return Date(timeIntervalSince1970: resetAt)
        }
        return nil
    }
}

// Live API Response Structure
struct LiveUsageResponse: Codable {
    let rateLimit: LiveRateLimits?
    
    enum CodingKeys: String, CodingKey {
        case rateLimit = "rate_limit"
    }
    
    struct LiveRateLimits: Codable {
        let primaryWindow: UsageBucket?
        let secondaryWindow: UsageBucket?
        
        enum CodingKeys: String, CodingKey {
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }
    }
}

// SQLite Event Structure
struct RawUsageLimitEvent: Codable {
    let type: String
    let planType: String?
    let rateLimits: RateLimits?
    
    enum CodingKeys: String, CodingKey {
        case type
        case planType = "plan_type"
        case rateLimits = "rate_limits"
    }
    
    struct RateLimits: Codable {
        let allowed: Bool?
        let limitReached: Bool?
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
    let observedAt: Date
}

final class UsageLimitReader {
    private let codexHome: String
    private let authPath: String
    
    init() {
        self.codexHome = CodexHomeResolver.resolve().path
        self.authPath = (codexHome as NSString).appendingPathComponent("auth.json")
    }
    
    func readLatest() -> UsageLimitInfo? {
        // Try live first
        if let live = fetchLiveUsage() {
            return live
        }
        
        // Fallback to cached
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
    
    private func fetchLiveUsage() -> UsageLimitInfo? {
        guard let token = getAccessToken() else { return nil }
        
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5.0
        
        let semaphore = DispatchSemaphore(value: 0)
        var result: UsageLimitInfo?
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("[UsageLimitReader] Live fetch error: \(error)")
                return
            }
            
            guard let data = data else { return }
            
            do {
                let decoder = JSONDecoder()
                let resp = try decoder.decode(LiveUsageResponse.self, from: data)
                if let limits = resp.rateLimit {
                    result = UsageLimitInfo(
                        planType: "Live", // Or "Unknown" if not in JSON
                        source: .live,
                        allowed: true,
                        limitReached: (limits.primaryWindow?.usedPercent ?? 0) >= 100,
                        primary: limits.primaryWindow,
                        secondary: limits.secondaryWindow,
                        observedAt: Date()
                    )
                }
            } catch {
                print("[UsageLimitReader] Live decode error: \(error)")
            }
        }
        
        task.resume()
        _ = semaphore.wait(timeout: .now() + 6.0)
        
        return result
    }
    
    private func getAccessToken() -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: authPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String else {
            return nil
        }
        return accessToken
    }
    
    private func readFromDB(path: String) -> UsageLimitInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        
        // Improved query with better sorting
        let query = "SELECT feedback_log_body FROM logs WHERE feedback_log_body LIKE '%\"type\":\"codex.rate_limits\"%' ORDER BY ts DESC, ts_nanos DESC, id DESC LIMIT 1;"
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
            
            // Balanced brace extraction
            guard let jsonString = extractBalancedJSON(from: output) else {
                return nil
            }
            
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
                observedAt: Date()
            )
        } catch {
            print("[UsageLimitReader] DB read error: \(error)")
            return nil
        }
    }
    
    private func extractBalancedJSON(from text: String) -> String? {
        var braceCount = 0
        var startIndex: String.Index?
        
        for (index, char) in text.enumerated() {
            let stringIndex = text.index(text.startIndex, offsetBy: index)
            if char == "{" {
                if braceCount == 0 { startIndex = stringIndex }
                braceCount += 1
            } else if char == "}" {
                braceCount -= 1
                if braceCount == 0, let start = startIndex {
                    return String(text[start...stringIndex])
                }
            }
        }
        return nil
    }
}

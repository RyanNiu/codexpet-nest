import Foundation

enum MetricKind: String, Codable {
    case number
    case ratio
    case percent
    case text
    case boolean
    case enumeration
}

enum MetricStatus: String, Codable {
    case stable
    case beta
    case requiresPermission
    case future
    case privateDoNotExpose
}

enum MetricPrivacy: String, Codable {
    case low
    case medium
    case high
    case blocked
}

struct MetricDefinition: Equatable, Codable {
    let id: String
    let kind: MetricKind
    let description: String
    let domain: String?
    let source: String?
    let status: MetricStatus?
    let permission: String?
    let privacy: MetricPrivacy?
    let refreshIntervalSeconds: Int?
    let allowedRenderers: [String]?

    init(id: String,
         kind: MetricKind,
         description: String,
         domain: String? = nil,
         source: String? = nil,
         status: MetricStatus? = nil,
         permission: String? = nil,
         privacy: MetricPrivacy? = nil,
         refreshIntervalSeconds: Int? = nil,
         allowedRenderers: [String]? = nil) {
        self.id = id
        self.kind = kind
        self.description = description
        self.domain = domain
        self.source = source
        self.status = status
        self.permission = permission
        self.privacy = privacy
        self.refreshIntervalSeconds = refreshIntervalSeconds
        self.allowedRenderers = allowedRenderers
    }

    var isPermissionGated: Bool {
        status == .requiresPermission
    }

    var isPubliclyExposable: Bool {
        guard let p = privacy else { return true }
        return p != .blocked && p != .high
    }
}

// MARK: - Catalog

final class MetricCatalog {
    static let shared = MetricCatalog()

    private var definitions: [String: MetricDefinition] = [:]

    private init() {
        registerBuiltInMetrics()
    }

    // MARK: - Query

    func definition(for id: String) -> MetricDefinition? {
        return definitions[id]
    }

    func contains(_ id: String) -> Bool {
        return definitions.keys.contains(id)
    }

    func isPercentMetric(_ id: String) -> Bool {
        return definitions[id]?.kind == .percent
    }

    var all: [MetricDefinition] {
        return Array(definitions.values).sorted { $0.id < $1.id }
    }

    // MARK: - Registration

    func register(_ def: MetricDefinition) {
        definitions[def.id] = def
    }

    /// Reset to built-in definitions only, discarding any registry-loaded entries.
    func resetToBuiltIns() {
        definitions.removeAll()
        registerBuiltInMetrics()
    }

    /// Load metric definitions from a downloaded metric-catalog.json file.
    /// Resets to built-ins first so metrics from one nest do not leak into another.
    func load(from url: URL) {
        resetToBuiltIns()
        guard let data = try? Data(contentsOf: url) else { return }
        guard let catalog = try? JSONDecoder().decode(MetricCatalogJSON.self, from: data) else { return }
        for def in catalog.metrics {
            definitions[def.id] = def
        }
    }

    // MARK: - Validation

    func isMetricAllowedForRenderer(_ metricId: String, renderer: String) -> Bool {
        guard let def = definition(for: metricId) else { return false }
        if let allowed = def.allowedRenderers {
            return allowed.contains(renderer)
        }
        return defaultRenderer(for: def.kind) == renderer
    }

    func defaultRenderer(for kind: MetricKind) -> String {
        switch kind {
        case .text:       return "metricText"
        case .number:     return "metricText"
        case .ratio:      return "linearBar"
        case .percent:    return "metricText"
        case .boolean:    return "metricText"
        case .enumeration: return "variantIcon"
        }
    }

    // MARK: - Built-in

    private func registerBuiltInMetrics() {
        // Usage Metrics - Primary
        register(MetricDefinition(id: "usage.primary.used_percent", kind: .percent, description: "Percentage of primary quota used", domain: "codex", status: .stable, privacy: .low))
        register(MetricDefinition(id: "usage.primary.remaining_percent", kind: .percent, description: "Percentage of primary quota remaining", domain: "codex", status: .stable, privacy: .low))
        register(MetricDefinition(id: "usage.primary.remaining_ratio", kind: .ratio, description: "Ratio of primary quota remaining (0.0 to 1.0)", domain: "codex", status: .stable, privacy: .low, allowedRenderers: ["linearBar", "ringStroke", "circleFill", "metricText"]))
        register(MetricDefinition(id: "usage.primary.remaining_band", kind: .enumeration, description: "Status band for primary remaining quota (empty, low, medium, high, full)", domain: "codex", status: .stable, privacy: .low))
        register(MetricDefinition(id: "usage.primary.reset_after_seconds", kind: .number, description: "Seconds until primary quota resets", domain: "codex", status: .stable, privacy: .low))
        register(MetricDefinition(id: "usage.primary.reset_label", kind: .text, description: "Human readable reset time for primary quota", domain: "codex", status: .stable, privacy: .low))

        // Usage Metrics - Secondary
        register(MetricDefinition(id: "usage.secondary.used_percent", kind: .percent, description: "Percentage of secondary quota used", domain: "codex", status: .stable, privacy: .low))
        register(MetricDefinition(id: "usage.secondary.remaining_percent", kind: .percent, description: "Percentage of secondary quota remaining", domain: "codex", status: .stable, privacy: .low))
        register(MetricDefinition(id: "usage.secondary.remaining_ratio", kind: .ratio, description: "Ratio of secondary quota remaining (0.0 to 1.0)", domain: "codex", status: .stable, privacy: .low, allowedRenderers: ["linearBar", "ringStroke", "circleFill", "metricText"]))
        register(MetricDefinition(id: "usage.secondary.remaining_band", kind: .enumeration, description: "Status band for secondary remaining quota (empty, low, medium, high, full)", domain: "codex", status: .stable, privacy: .low))
        register(MetricDefinition(id: "usage.secondary.reset_after_seconds", kind: .number, description: "Seconds until secondary quota resets", domain: "codex", status: .stable, privacy: .low))
        register(MetricDefinition(id: "usage.secondary.reset_label", kind: .text, description: "Human readable reset time for secondary quota", domain: "codex", status: .stable, privacy: .low))

        // Usage General
        register(MetricDefinition(id: "usage.allowed", kind: .boolean, description: "Whether usage is currently allowed", domain: "codex", status: .stable, privacy: .low))
        register(MetricDefinition(id: "usage.limit_reached", kind: .boolean, description: "Whether any usage limit has been reached", domain: "codex", status: .stable, privacy: .low))
        register(MetricDefinition(id: "usage.source", kind: .enumeration, description: "Source of the usage data (Live, Cached)", domain: "codex", status: .stable, privacy: .low))
        register(MetricDefinition(id: "usage.plan_type", kind: .text, description: "User plan type", domain: "codex", status: .stable, privacy: .medium))

        // System Time Metrics
        register(MetricDefinition(id: "system.time.hour", kind: .number, description: "Current hour (0-23)", domain: "macos", status: .stable, privacy: .low))
        register(MetricDefinition(id: "system.time.minute", kind: .number, description: "Current minute (0-59)", domain: "macos", status: .stable, privacy: .low))
        register(MetricDefinition(id: "system.time.day_period", kind: .enumeration, description: "Current time of day (day, night)", domain: "macos", status: .stable, privacy: .low))
        register(MetricDefinition(id: "system.time.weekday", kind: .enumeration, description: "Day of the week (mon, tue, wed, thu, fri, sat, sun)", domain: "macos", status: .stable, privacy: .low))
        register(MetricDefinition(id: "system.time.is_weekend", kind: .boolean, description: "Whether today is a weekend", domain: "macos", status: .stable, privacy: .low))
        register(MetricDefinition(id: "system.time.hhmm", kind: .text, description: "Current time in HH:mm format", domain: "macos", status: .stable, privacy: .low))
        register(MetricDefinition(id: "system.date.short", kind: .text, description: "Current date in MM/dd format", domain: "macos", status: .stable, privacy: .low))

        // Pet Metrics
        register(MetricDefinition(id: "pet.name", kind: .text, description: "Display name of the currently active pet", domain: "codex", status: .stable, privacy: .low))

        // Local Metrics
        register(MetricDefinition(id: "local.pomodoro.state", kind: .enumeration, description: "Pomodoro state (idle, focus, break, paused)", domain: "local", status: .stable, privacy: .low))
        register(MetricDefinition(id: "local.pomodoro.remaining_ratio", kind: .ratio, description: "Current pomodoro session progress", domain: "local", status: .stable, privacy: .low, allowedRenderers: ["linearBar", "ringStroke", "circleFill", "metricText"]))
        register(MetricDefinition(id: "local.pomodoro.remaining_label", kind: .text, description: "Pomodoro timer label (mm:ss)", domain: "local", status: .stable, privacy: .low))
        register(MetricDefinition(id: "local.quick_actions.count", kind: .number, description: "Number of configured quick actions", domain: "local", status: .stable, privacy: .medium))
        register(MetricDefinition(id: "local.quick_actions.has_actions", kind: .boolean, description: "Whether quick actions are configured", domain: "local", status: .stable, privacy: .medium))
    }
}

// MARK: - JSON Decoding

struct MetricCatalogJSON: Codable {
    let schemaVersion: String
    let catalogVersion: String
    let metrics: [MetricDefinition]
}

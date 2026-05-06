import Foundation

enum MetricKind: String {
    case number
    case ratio
    case percent
    case text
    case boolean
    case enumeration
}

struct MetricDefinition: Equatable {
    let id: String
    let kind: MetricKind
    let description: String
}

final class MetricCatalog {
    static let shared = MetricCatalog()
    
    private var definitions: [String: MetricDefinition] = [:]
    
    private init() {
        registerBuiltInMetrics()
    }
    
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
    
    private func register(_ def: MetricDefinition) {
        definitions[def.id] = def
    }
    
    private func registerBuiltInMetrics() {
        // Usage Metrics - Primary
        register(MetricDefinition(id: "usage.primary.used_percent", kind: .percent, description: "Percentage of primary quota used"))
        register(MetricDefinition(id: "usage.primary.remaining_percent", kind: .percent, description: "Percentage of primary quota remaining"))
        register(MetricDefinition(id: "usage.primary.remaining_ratio", kind: .ratio, description: "Ratio of primary quota remaining (0.0 to 1.0)"))
        register(MetricDefinition(id: "usage.primary.remaining_band", kind: .enumeration, description: "Status band for primary remaining quota (empty, low, medium, high, full)"))
        register(MetricDefinition(id: "usage.primary.reset_after_seconds", kind: .number, description: "Seconds until primary quota resets"))
        register(MetricDefinition(id: "usage.primary.reset_label", kind: .text, description: "Human readable reset time for primary quota"))
        
        // Usage Metrics - Secondary
        register(MetricDefinition(id: "usage.secondary.used_percent", kind: .percent, description: "Percentage of secondary quota used"))
        register(MetricDefinition(id: "usage.secondary.remaining_percent", kind: .percent, description: "Percentage of secondary quota remaining"))
        register(MetricDefinition(id: "usage.secondary.remaining_ratio", kind: .ratio, description: "Ratio of secondary quota remaining (0.0 to 1.0)"))
        register(MetricDefinition(id: "usage.secondary.remaining_band", kind: .enumeration, description: "Status band for secondary remaining quota (empty, low, medium, high, full)"))
        register(MetricDefinition(id: "usage.secondary.reset_after_seconds", kind: .number, description: "Seconds until secondary quota resets"))
        register(MetricDefinition(id: "usage.secondary.reset_label", kind: .text, description: "Human readable reset time for secondary quota"))
        
        // Usage General
        register(MetricDefinition(id: "usage.allowed", kind: .boolean, description: "Whether usage is currently allowed"))
        register(MetricDefinition(id: "usage.limit_reached", kind: .boolean, description: "Whether any usage limit has been reached"))
        register(MetricDefinition(id: "usage.source", kind: .enumeration, description: "Source of the usage data (Live, Cached)"))
        register(MetricDefinition(id: "usage.plan_type", kind: .text, description: "User plan type"))
        
        // System Time Metrics
        register(MetricDefinition(id: "system.time.hour", kind: .number, description: "Current hour (0-23)"))
        register(MetricDefinition(id: "system.time.minute", kind: .number, description: "Current minute (0-59)"))
        register(MetricDefinition(id: "system.time.day_period", kind: .enumeration, description: "Current time of day (day, night)"))
        register(MetricDefinition(id: "system.time.weekday", kind: .enumeration, description: "Day of the week (mon, tue, wed, thu, fri, sat, sun)"))
        register(MetricDefinition(id: "system.time.is_weekend", kind: .boolean, description: "Whether today is a weekend"))
        register(MetricDefinition(id: "system.time.hhmm", kind: .text, description: "Current time in HH:mm format"))
        register(MetricDefinition(id: "system.date.short", kind: .text, description: "Current date in MM/dd format"))
    }
}

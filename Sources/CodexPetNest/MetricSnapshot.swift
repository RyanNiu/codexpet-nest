import Foundation

struct MetricSnapshot {
    private(set) var values: [String: MetricValue]
    let observedAt: Date

    init(values: [String: MetricValue] = [:], observedAt: Date = Date()) {
        self.values = values
        self.observedAt = observedAt
    }
    
    func value(for id: String) -> MetricValue {
        return values[id] ?? .unavailable
    }
    
    func merging(_ other: MetricSnapshot) -> MetricSnapshot {
        var newValues = self.values
        for (key, value) in other.values {
            newValues[key] = value
        }
        
        let newDate = max(self.observedAt, other.observedAt)
        return MetricSnapshot(values: newValues, observedAt: newDate)
    }
}

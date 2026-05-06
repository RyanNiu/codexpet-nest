import Foundation

final class UsageMetricProvider: MetricProvider {
    private let reader: UsageLimitReader

    init(reader: UsageLimitReader = UsageLimitReader()) {
        self.reader = reader
    }

    var refreshInterval: TimeInterval { 60 }

    func snapshot() -> MetricSnapshot {
        var values: [String: MetricValue] = [:]
        
        guard let info = reader.readLatest() else {
            return createUnavailableSnapshot()
        }

        // General
        values["usage.allowed"] = .boolean(info.allowed)
        values["usage.limit_reached"] = .boolean(info.limitReached)
        values["usage.source"] = .enumeration(info.source.rawValue)
        values["usage.plan_type"] = .text(info.planType)

        // Primary
        if let primary = info.primary {
            mapBucket(primary, prefix: "usage.primary", into: &values)
        } else {
            markBucketUnavailable(prefix: "usage.primary", into: &values)
        }

        // Secondary
        if let secondary = info.secondary {
            mapBucket(secondary, prefix: "usage.secondary", into: &values)
        } else {
            markBucketUnavailable(prefix: "usage.secondary", into: &values)
        }

        return MetricSnapshot(values: values, observedAt: info.observedAt)
    }

    private func mapBucket(_ bucket: UsageBucket, prefix: String, into values: inout [String: MetricValue]) {
        let used = bucket.usedPercent
        let remaining = max(0, min(100, 100 - used))
        
        values["\(prefix).used_percent"] = .percent(used)
        values["\(prefix).remaining_percent"] = .percent(remaining)
        values["\(prefix).remaining_ratio"] = .ratio(remaining / 100.0)
        values["\(prefix).remaining_band"] = .enumeration(getBand(remaining))
        
        if let seconds = bucket.resetAfterSeconds {
            values["\(prefix).reset_after_seconds"] = .number(Double(seconds))
        } else {
            values["\(prefix).reset_after_seconds"] = .unavailable
        }
        
        values["\(prefix).reset_label"] = .text(formatReset(bucket))
    }

    private func markBucketUnavailable(prefix: String, into values: inout [String: MetricValue]) {
        values["\(prefix).used_percent"] = .unavailable
        values["\(prefix).remaining_percent"] = .unavailable
        values["\(prefix).remaining_ratio"] = .unavailable
        values["\(prefix).remaining_band"] = .unavailable
        values["\(prefix).reset_after_seconds"] = .unavailable
        values["\(prefix).reset_label"] = .unavailable
    }

    private func createUnavailableSnapshot() -> MetricSnapshot {
        var values: [String: MetricValue] = [:]
        
        values["usage.allowed"] = .unavailable
        values["usage.limit_reached"] = .unavailable
        values["usage.source"] = .unavailable
        values["usage.plan_type"] = .unavailable
        
        markBucketUnavailable(prefix: "usage.primary", into: &values)
        markBucketUnavailable(prefix: "usage.secondary", into: &values)
        
        return MetricSnapshot(values: values)
    }

    private func getBand(_ remaining: Double) -> String {
        if remaining <= 0 { return "empty" }
        if remaining <= 25 { return "low" }
        if remaining <= 50 { return "medium" }
        if remaining <= 75 { return "high" }
        return "full"
    }

    private func formatReset(_ bucket: UsageBucket) -> String {
        if let secs = bucket.resetAfterSeconds {
            let h = secs / 3600
            let m = (secs % 3600) / 60
            if h > 24 {
                return "resets in \(h/24)d \(h%24)h"
            }
            if h > 0 {
                return "resets in \(h)h \(m)m"
            }
            return "resets in \(m)m"
        } else if let date = bucket.resetDate {
            let df = DateFormatter()
            df.timeStyle = .short
            df.dateStyle = .none
            return "resets at \(df.string(from: date))"
        }
        return "resets soon"
    }
}

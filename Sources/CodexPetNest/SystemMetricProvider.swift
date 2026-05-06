import Foundation

final class SystemMetricProvider: MetricProvider {
    private let dateProvider: () -> Date
    
    init(dateProvider: @escaping () -> Date = Date.init) {
        self.dateProvider = dateProvider
    }

    var refreshInterval: TimeInterval { 60 }

    func snapshot() -> MetricSnapshot {
        let now = dateProvider()
        let calendar = Calendar.current
        var values: [String: MetricValue] = [:]

        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        values["system.time.hour"] = .number(Double(hour))
        values["system.time.minute"] = .number(Double(minute))
        
        // Day period: 06:00 <= time < 18:00 is day
        let isDay = hour >= 6 && hour < 18
        values["system.time.day_period"] = .enumeration(isDay ? "day" : "night")
        
        // Weekday
        // weekday in Calendar is 1 (Sun) to 7 (Sat)
        let weekdayIndex = calendar.component(.weekday, from: now)
        let weekdays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        let weekdayStr = weekdays[weekdayIndex - 1]
        values["system.time.weekday"] = .enumeration(weekdayStr)
        
        let isWeekend = weekdayIndex == 1 || weekdayIndex == 7
        values["system.time.is_weekend"] = .boolean(isWeekend)
        
        // Formatted strings
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        values["system.time.hhmm"] = .text(timeFormatter.string(from: now))
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd"
        values["system.date.short"] = .text(dateFormatter.string(from: now))

        return MetricSnapshot(values: values, observedAt: now)
    }
}

import Foundation

enum MetricValue: Equatable {
    case number(Double)
    case ratio(Double)       // 0...1
    case percent(Double)     // 0...100
    case text(String)
    case boolean(Bool)
    case enumeration(String)
    case unavailable

    var stringValue: String? {
        switch self {
        case .text(let s), .enumeration(let s):
            return s
        case .number(let d):
            return String(format: "%.0f", d)
        case .ratio(let d):
            return String(format: "%.2f", d)
        case .percent(let d):
            return String(format: "%.0f%%", d)
        case .boolean(let b):
            return b ? "true" : "false"
        case .unavailable:
            return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let d), .ratio(let d), .percent(let d):
            return d
        default:
            return nil
        }
    }

    var ratioValue: Double? {
        switch self {
        case .ratio(let d):
            return d
        case .percent(let d):
            return d / 100.0
        default:
            return nil
        }
    }

    var percentValue: Double? {
        switch self {
        case .percent(let d):
            return d
        case .ratio(let d):
            return d * 100.0
        default:
            return nil
        }
    }

    var enumValue: String? {
        if case .enumeration(let s) = self {
            return s
        }
        return nil
    }
}

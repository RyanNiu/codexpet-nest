import Foundation

enum NestThemeElement: Codable, Equatable {
    case staticImage(StaticImageElement)
    case variantImage(VariantImageElement)
    case metricText(MetricTextElement)
    case metricGauge(MetricGaugeElement)
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "staticImage":
            self = .staticImage(try StaticImageElement(from: decoder))
        case "variantImage":
            self = .variantImage(try VariantImageElement(from: decoder))
        case "metricText":
            self = .metricText(try MetricTextElement(from: decoder))
        case "metricGauge":
            self = .metricGauge(try MetricGaugeElement(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown element type: \(type)"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .staticImage(let element):
            try element.encode(to: encoder)
        case .variantImage(let element):
            try element.encode(to: encoder)
        case .metricText(let element):
            try element.encode(to: encoder)
        case .metricGauge(let element):
            try element.encode(to: encoder)
        }
    }
    
    // Computed properties for convenience
    var id: String {
        switch self {
        case .staticImage(let e): return e.id
        case .variantImage(let e): return e.id
        case .metricText(let e): return e.id
        case .metricGauge(let e): return e.id
        }
    }
    
    var type: String {
        switch self {
        case .staticImage(let e): return e.type
        case .variantImage(let e): return e.type
        case .metricText(let e): return e.type
        case .metricGauge(let e): return e.type
        }
    }
    
    var frame: NestRect {
        switch self {
        case .staticImage(let e): return e.frame
        case .variantImage(let e): return e.frame
        case .metricText(let e): return e.frame
        case .metricGauge(let e): return e.frame
        }
    }
    
    var metric: String? {
        switch self {
        case .staticImage: return nil
        case .variantImage(let e): return e.metric
        case .metricText(let e): return e.metric
        case .metricGauge(let e): return e.metric
        }
    }
    
    var renderer: String? {
        switch self {
        case .metricGauge(let e): return e.renderer
        default: return nil
        }
    }
}

struct StaticImageElement: Codable, Equatable {
    let id: String
    let type: String
    let src: String
    let frame: NestRect
}

struct VariantImageElement: Codable, Equatable {
    let id: String
    let type: String
    let metric: String
    let frame: NestRect
    let variants: [String: String]
    let fallback: String?
}

struct MetricTextElement: Codable, Equatable {
    let id: String
    let type: String
    let metric: String
    let frame: NestRect
    let style: MetricTextStyle?
}

struct MetricGaugeElement: Codable, Equatable {
    let id: String
    let type: String
    let metric: String
    let renderer: String
    let frame: NestRect
    let style: MetricGaugeStyle?
}

struct MetricTextStyle: Codable, Equatable {
    let fontSize: Double?
    let fontWeight: String?
    let color: String?
    let alignment: String?
    let prefix: String?
    let suffix: String?
    let fallbackText: String?
}

struct MetricGaugeStyle: Codable, Equatable {
    let fillColor: String?
    let trackColor: String?
    let opacity: Double?
    let lineWidth: Double?
    let startAngle: Double?
    let clockwise: Bool?
    let lineCap: String?
    let cornerRadius: Double?
    let direction: String?
    let clipShape: String?
}

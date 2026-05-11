import Foundation

struct PetSlot: Codable, Equatable {
    let id: String
    let frame: NestRect
    let anchor: String?
    let defaultAction: String?
    let zIndex: Int?
}

struct NestComponent: Codable, Equatable {
    let id: String
    let component: String
    let frame: NestRect
    let props: [String: NestPropValue]?
    let zIndex: Int?
}

enum NestPropValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported prop value type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }

    var stringValue: String? { if case .string(let v) = self { return v } else { return nil } }
    var numberValue: Double? { if case .number(let v) = self { return v } else { return nil } }
    var boolValue: Bool? { if case .bool(let v) = self { return v } else { return nil } }
}

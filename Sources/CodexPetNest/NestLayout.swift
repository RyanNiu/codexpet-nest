import Foundation
import CoreGraphics

struct NestLayout: Codable, Equatable {
    let schemaVersion: String
    let canvas: NestCanvas
    let layers: [NestLayer]
    let widgetSlots: [String: NestRect]?
    let metricBands: [String: [MetricBand]]?
    let elements: [NestThemeElement]?
    let petSlot: PetSlot?
    let components: [NestComponent]?
}

struct NestCanvas: Codable, Equatable {
    let width: Double
    let height: Double
    let petSlot: NestRect?
    let background: String?
}

struct NestLayer: Codable, Equatable {
    let id: String
    let type: String // only "image" supported in V1
    let src: String
    let frame: NestRect
    let opacity: Double?
    let zIndex: Int?
}

struct NestRect: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    
    var cgRect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

struct MetricBand: Codable, Equatable {
    let id: String
    let max: Double
}


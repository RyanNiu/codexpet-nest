import Foundation

struct NestLayout: Codable {
    let schemaVersion: String
    let canvas: NestCanvas
    let layers: [NestLayer]
    let widgetSlots: [String: NestRect]?
}

struct NestCanvas: Codable {
    let width: Double
    let height: Double
}

struct NestLayer: Codable {
    let id: String
    let type: String // only "image" supported in V1
    let src: String
    let frame: NestRect
}

struct NestRect: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    
    var cgRect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

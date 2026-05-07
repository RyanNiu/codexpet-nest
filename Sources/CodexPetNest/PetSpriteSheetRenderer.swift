import Foundation
import AppKit
import CoreGraphics

struct PetAnimationConfig: Codable {
    let row: Int
    let frames: Int
    let fps: Double?
}

struct SpriteSheetDescriptor: Codable {
    let frameWidth: Int
    let frameHeight: Int
    let columns: Int
    let rows: Int
    let animations: [String: PetAnimationConfig]?
}

final class PetSpriteSheetRenderer {
    
    static let shared = PetSpriteSheetRenderer()
    
    private init() {}
    
    /// Heuristic to detect frame size based on CGImage pixel dimensions.
    /// Prioritizes standard 8x9 atlas if divisible.
    func detectDescriptor(cgImage: CGImage, manifest: [String: Any]? = nil) -> SpriteSheetDescriptor {
        let pixelWidth = cgImage.width
        let pixelHeight = cgImage.height
        
        // 1. Try to read from manifest if provided
        if let manifest = manifest {
            let fw = manifest["frameWidth"] as? Int ?? (manifest["frameSize"] as? Int)
            let fh = manifest["frameHeight"] as? Int ?? (manifest["frameSize"] as? Int)
            
            if let fw = fw, let fh = fh {
                let cols = manifest["columns"] as? Int ?? (pixelWidth / fw)
                let rows = manifest["rows"] as? Int ?? (pixelHeight / fh)
                return SpriteSheetDescriptor(
                    frameWidth: fw,
                    frameHeight: fh,
                    columns: cols,
                    rows: rows,
                    animations: nil
                )
            }
        }
        
        // 2. Default Codex Pet Atlas: Priority 8x9
        // Requirement: "如果 pixelWidth 能被 8 整除，pixelHeight 能被 9 整除，直接用 8x9"
        if pixelWidth >= 8 && pixelHeight >= 9 && pixelWidth % 8 == 0 && pixelHeight % 9 == 0 {
            return SpriteSheetDescriptor(
                frameWidth: pixelWidth / 8,
                frameHeight: pixelHeight / 9,
                columns: 8,
                rows: 9,
                animations: nil
            )
        }
        
        // 3. Fallback to common square heuristics
        let commonSizes = [80, 128, 64, 96, 48, 32]
        for size in commonSizes {
            if pixelWidth % size == 0 && pixelHeight % size == 0 {
                return SpriteSheetDescriptor(
                    frameWidth: size,
                    frameHeight: size,
                    columns: pixelWidth / size,
                    rows: pixelHeight / size,
                    animations: nil
                )
            }
        }
        
        // 4. Final fallback: single frame
        return SpriteSheetDescriptor(
            frameWidth: pixelWidth,
            frameHeight: pixelHeight,
            columns: 1,
            rows: 1,
            animations: nil
        )
    }
    
    func extractFirstFrame(from image: NSImage, petId: String? = nil) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let desc = detectDescriptor(cgImage: cgImage)
        
        // Mandatory debug export if petId is provided
        if let petId = petId {
            debugExportContactSheet(cgImage: cgImage, desc: desc, petId: petId)
        }
        
        // Find first non-empty frame starting from row 0 col 0
        for col in 0..<desc.columns {
            let x = col * desc.frameWidth
            let y = 0
            let cropRect = CGRect(x: x, y: y, width: desc.frameWidth, height: desc.frameHeight)
            if let cropped = cgImage.cropping(to: cropRect) {
                if !isCGImageEmpty(cropped) {
                    return NSImage(cgImage: cropped, size: NSSize(width: desc.frameWidth, height: desc.frameHeight))
                }
            }
        }
        
        // Fallback to absolute first frame
        return extractFrame(cgImage: cgImage, row: 0, col: 0, desc: desc)
    }
    
    func extractFrame(cgImage: CGImage, row: Int, col: Int, desc: SpriteSheetDescriptor) -> NSImage? {
        if row >= desc.rows || col >= desc.columns { return nil }
        
        let fw = desc.frameWidth
        let fh = desc.frameHeight
        
        let x = col * fw
        let y = row * fh
        
        let cropRect = CGRect(x: x, y: y, width: fw, height: fh)
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        
        return NSImage(cgImage: cropped, size: NSSize(width: fw, height: fh))
    }
    
    func extractAnimationFrames(from image: NSImage, action: String, desc: SpriteSheetDescriptor) -> [NSImage] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        
        let row = rowForAction(action)
        if row >= desc.rows { return [] }
        
        var frames: [NSImage] = []
        let maxFramesPerRow = min(desc.columns, 8)
        
        for col in 0..<maxFramesPerRow {
            let x = col * desc.frameWidth
            let y = row * desc.frameHeight
            let cropRect = CGRect(x: x, y: y, width: desc.frameWidth, height: desc.frameHeight)
            
            if let cropped = cgImage.cropping(to: cropRect) {
                if isCGImageEmpty(cropped) { continue }
                let nsFrame = NSImage(cgImage: cropped, size: NSSize(width: desc.frameWidth, height: desc.frameHeight))
                frames.append(nsFrame)
            }
        }
        return frames
    }
    
    private func rowForAction(_ action: String) -> Int {
        switch action.lowercased() {
        case "idle": return 0
        case "walk": return 1
        case "sleep": return 2
        case "action": return 3
        default: return 0
        }
    }
    
    /// Checks if a CGImage is effectively empty (all transparent)
    private func isCGImageEmpty(_ cgImage: CGImage) -> Bool {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(data: &rawData,
                                    width: width,
                                    height: height,
                                    bitsPerComponent: 8,
                                    bytesPerRow: bytesPerRow,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return true }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Scan for any pixel with alpha > 0.05
        for i in 0..<(width * height) {
            let alpha = rawData[i * bytesPerPixel + 3]
            if alpha > 12 { // approx 0.05 * 255
                return false
            }
        }
        return true
    }
    
    func debugExportContactSheet(cgImage: CGImage, desc: SpriteSheetDescriptor, petId: String) {
        let gridCols = 8
        let gridRows = 4
        let fw = desc.frameWidth
        let fh = desc.frameHeight
        
        let totalW = fw * gridCols
        let totalH = fh * gridRows
        
        guard let context = CGContext(data: nil,
                                    width: totalW,
                                    height: totalH,
                                    bitsPerComponent: 8,
                                    bytesPerRow: 0,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        
        // Fill background with light grey to see frame boundaries
        context.setFillColor(NSColor.lightGray.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: totalW, height: totalH))
        
        for row in 0..<min(desc.rows, gridRows) {
            for col in 0..<min(desc.columns, gridCols) {
                let x = col * fw
                let y = row * fh
                let cropRect = CGRect(x: x, y: y, width: fw, height: fh)
                if let cropped = cgImage.cropping(to: cropRect) {
                    // Draw in contact sheet (Flip Y for CGContext)
                    let drawRect = CGRect(x: col * fw,
                                        y: totalH - (row + 1) * fh,
                                        width: fw,
                                        height: fh)
                    context.draw(cropped, in: drawRect)
                }
            }
        }
        
        if let outputImage = context.makeImage() {
            let url = URL(fileURLWithPath: "/tmp/codexpet-frames-\(petId).png")
            let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil)
            if let dest = destination {
                CGImageDestinationAddImage(dest, outputImage, nil)
                CGImageDestinationFinalize(dest)
                print("[PetSpriteSheetRenderer] DEBUG: Exported contact sheet to \(url.path)")
            }
        }
    }
}


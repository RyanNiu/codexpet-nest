import Foundation
import AppKit

struct PetSpriteConfig: Codable {
    struct FrameSize: Codable {
        let width: Int
        let height: Int
    }
    
    struct Animation: Codable {
        let row: Int
        let frames: Int
        let fps: Double?
    }
    
    let frameSize: FrameSize
    let animations: [String: Animation]
}

final class PetSpriteSheetRenderer {
    
    static let shared = PetSpriteSheetRenderer()
    
    private init() {}
    
    /// Heuristic to detect frame size if not provided
    func detectFrameSize(imageSize: NSSize) -> NSSize {
        let w = imageSize.width
        let h = imageSize.height
        
        if w == 0 || h == 0 { return .zero }
        
        // Common frame sizes for Codex pets
        let commonSizes: [CGFloat] = [80, 128, 64, 48, 160, 32]
        
        for size in commonSizes {
            if Int(w) % Int(size) == 0 && Int(h) % Int(size) == 0 {
                return NSSize(width: size, height: size)
            }
        }
        
        // Fallback: assume it's a square or a strip of squares
        let minDim = min(w, h)
        return NSSize(width: minDim, height: minDim)
    }
    
    func extractFirstFrame(from image: NSImage, config: PetSpriteConfig? = nil) -> NSImage? {
        let frameSize = config?.frameSize != nil 
            ? NSSize(width: config!.frameSize.width, height: config!.frameSize.height)
            : detectFrameSize(imageSize: image.size)
        
        return extractFrame(from: image, row: 0, col: 0, frameSize: frameSize)
    }
    
    func extractFrame(from image: NSImage, row: Int, col: Int, frameSize: NSSize) -> NSImage? {
        if frameSize.width <= 0 || frameSize.height <= 0 { return nil }
        
        let x = CGFloat(col) * frameSize.width
        // AppKit uses bottom-left origin, but spritesheets are usually top-down.
        let y = image.size.height - CGFloat(row + 1) * frameSize.height
        
        let rect = NSRect(x: x, y: y, width: frameSize.width, height: frameSize.height)
        if x + frameSize.width > image.size.width || y < 0 {
            return nil
        }
        
        let target = NSImage(size: frameSize)
        target.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: frameSize), from: rect, operation: .copy, fraction: 1.0)
        target.unlockFocus()
        target.isTemplate = false
        return target
    }
    
    func extractAnimationFrames(from image: NSImage, action: String, config: PetSpriteConfig) -> [NSImage] {
        guard let anim = config.animations[action] else { return [] }
        
        var frames: [NSImage] = []
        let frameSize = NSSize(width: config.frameSize.width, height: config.frameSize.height)
        
        for col in 0..<anim.frames {
            if let frame = extractFrame(from: image, row: anim.row, col: col, frameSize: frameSize) {
                frames.append(frame)
            }
        }
        
        return frames
    }
    
    /// Fallback for when we don't have a config but want to show *something*
    func extractFallbackAnimation(from image: NSImage, row: Int) -> [NSImage] {
        let frameSize = detectFrameSize(imageSize: image.size)
        if frameSize.width <= 0 { return [] }
        
        let cols = Int(image.size.width / frameSize.width)
        var frames: [NSImage] = []
        
        // Take at most 8 frames to be safe
        for col in 0..<min(cols, 8) {
            if let frame = extractFrame(from: image, row: row, col: col, frameSize: frameSize) {
                frames.append(frame)
            }
        }
        return frames
    }
}

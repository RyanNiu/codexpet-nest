import Foundation
import AppKit

final class AnimatedSpritePreviewView: NSView {
    
    private var frames: [NSImage] = []
    private var currentFrameIndex: Int = 0
    private var timer: Timer?
    private var fps: Double = 8.0
    
    private let imageView = NSImageView()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.05).cgColor
        layer?.cornerRadius = 8
        
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        // Use Nearest Neighbor for pixel art clarity
        imageView.layer?.magnificationFilter = .nearest
        addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.8),
            imageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.8)
        ])
        
        // We'll just use a solid dark background for now as requested "柔和暗色面板"
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 1.0).cgColor

    }
    
    func setFrames(_ newFrames: [NSImage], fps: Double = 8.0) {
        stop()
        self.frames = newFrames
        self.fps = fps
        self.currentFrameIndex = 0
        
        if !frames.isEmpty {
            imageView.image = frames[0]
            if frames.count > 1 {
                start()
            }
        } else {
            imageView.image = nil
        }
    }
    
    func start() {
        stop()
        guard frames.count > 1 else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentFrameIndex = (self.currentFrameIndex + 1) % self.frames.count
            self.imageView.image = self.frames[self.currentFrameIndex]
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    deinit {
        stop()
    }
}

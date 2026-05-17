import AppKit
import ImageIO
import ObjectiveC

enum AnimatedImageSupport {
    static func configure(_ imageView: NSImageView) {
        imageView.animates = true
    }

    @discardableResult
    static func load(contentsOf url: URL, into imageView: NSImageView) -> Bool {
        stopAnimation(on: imageView)

        if url.pathExtension.lowercased() == "gif",
           let animation = GIFAnimation(url: url, imageView: imageView) {
            objc_setAssociatedObject(
                imageView,
                &animationAssociationKey,
                animation,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            animation.start()
            return true
        }

        guard let image = NSImage(contentsOf: url) else {
            imageView.image = nil
            return false
        }
        imageView.image = image
        return true
    }

    static func stopAnimation(on imageView: NSImageView) {
        if let animation = objc_getAssociatedObject(imageView, &animationAssociationKey) as? GIFAnimation {
            animation.stop()
        }
        objc_setAssociatedObject(imageView, &animationAssociationKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

private var animationAssociationKey: UInt8 = 0

private final class GIFAnimation {
    private weak var imageView: NSImageView?
    private let frames: [NSImage]
    private let delays: [TimeInterval]
    private var index = 0
    private var timer: Timer?

    init?(url: URL, imageView: NSImageView) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else { return nil }

        var loadedFrames: [NSImage] = []
        var loadedDelays: [TimeInterval] = []

        for i in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let size = NSSize(width: cgImage.width, height: cgImage.height)
            loadedFrames.append(NSImage(cgImage: cgImage, size: size))
            loadedDelays.append(Self.frameDelay(source: source, index: i))
        }

        guard !loadedFrames.isEmpty else { return nil }
        self.imageView = imageView
        self.frames = loadedFrames
        self.delays = loadedDelays
    }

    func start() {
        imageView?.image = frames[0]
        scheduleNextFrame()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleNextFrame() {
        guard frames.count > 1 else { return }
        timer?.invalidate()
        let delay = delays.indices.contains(index) ? delays[index] : 0.1
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.advance()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func advance() {
        index = (index + 1) % frames.count
        imageView?.image = frames[index]
        scheduleNextFrame()
    }

    private static func frameDelay(source: CGImageSource, index: Int) -> TimeInterval {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return 0.1
        }

        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? TimeInterval
        let delay = unclamped ?? clamped ?? 0.1
        return delay < 0.02 ? 0.1 : delay
    }
}

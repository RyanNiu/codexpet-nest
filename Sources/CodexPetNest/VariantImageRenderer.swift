import AppKit

final class VariantImageRenderer: NSView, NestElementRenderer {
    private let imageView = NSImageView()
    private let element: VariantImageElement
    private let rootURL: URL
    private var imageCache: [String: NSImage] = [:]
    
    override var isFlipped: Bool { true }
    
    init(element: VariantImageElement, rootURL: URL) {
        self.element = element
        self.rootURL = rootURL
        super.init(frame: .zero)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        imageView.imageScaling = .scaleAxesIndependently
        AnimatedImageSupport.configure(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func update(snapshot: MetricSnapshot) {
        let value = snapshot.value(for: element.metric)
        
        let key: String
        switch value {
        case .enumeration(let s), .text(let s):
            key = s
        case .boolean(let b):
            key = b ? "true" : "false"
        default:
            key = ""
        }
        
        if let assetPath = element.variants[key] ?? element.fallback {
            if loadImage(assetPath) {
                isHidden = false
            } else {
                isHidden = true
            }
        } else {
            isHidden = true
        }
    }
    
    private func loadImage(_ path: String) -> Bool {
        if let cached = imageCache[path] {
            AnimatedImageSupport.stopAnimation(on: imageView)
            imageView.image = cached
            return true
        }
        
        let url = rootURL.appendingPathComponent(path)
        if url.pathExtension.lowercased() == "gif" {
            return AnimatedImageSupport.load(contentsOf: url, into: imageView)
        }

        if let image = NSImage(contentsOf: url) {
            imageCache[path] = image
            imageView.image = image
            return true
        }
        
        return false
    }
}

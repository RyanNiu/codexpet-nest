import AppKit
import CoreGraphics

// MARK: - Protocol

protocol RendererPrimitive: AnyObject {
    func update(snapshot: MetricSnapshot)
}

// MARK: - Factory

enum PrimitiveFactory {
    static func create(
        node: RuntimeNode,
        resolvedProps: ResolvedRuntimeProps,
        frame: CGRect,
        snapshot: MetricSnapshot,
        rootURL: URL?,
        nestId: String,
        effectiveProps: [String: RegistryPropValue] = [:]
    ) -> NSView? {
        let view: NSView?

        switch node.renderer {
        case "metricText":
            view = MetricTextPrimitive(metric: node.metric, props: resolvedProps, frame: frame, snapshot: snapshot)
        case "linearBar":
            view = LinearBarPrimitive(metric: node.metric, props: resolvedProps, frame: frame, snapshot: snapshot)
        case "circleFill":
            view = CircleFillPrimitive(metric: node.metric, props: resolvedProps, frame: frame, snapshot: snapshot)
        case "ringStroke":
            view = RingStrokePrimitive(metric: node.metric, props: resolvedProps, frame: frame, snapshot: snapshot)
        case "variantIcon":
            view = VariantIconPrimitive(metric: node.metric, props: resolvedProps, frame: frame, snapshot: snapshot, rootURL: rootURL)
        case "analogClock":
            view = AnalogClockPrimitive(props: resolvedProps, frame: frame, snapshot: snapshot)
        case "timerText":
            view = TimerTextPrimitive(metric: node.metric, props: resolvedProps, frame: frame, snapshot: snapshot)
        case "actionButtons":
            view = ActionButtonsPrimitive(props: resolvedProps, nestId: nestId)
        case "group":
            return GroupPrimitive(node: node, resolvedProps: resolvedProps, frame: frame, snapshot: snapshot, rootURL: rootURL, nestId: nestId, effectiveProps: effectiveProps)
        default:
            view = nil
        }

        if let v = view {
            v.frame = frame
        }
        return view
    }
}

// MARK: - Metric Text

final class MetricTextPrimitive: NSView, RendererPrimitive {
    private let metric: String?
    private let label = NSTextField(labelWithString: "")
    private let prefix: String
    private let suffix: String
    private let fallbackText: String

    init(metric: String?, props: ResolvedRuntimeProps, frame: CGRect, snapshot: MetricSnapshot) {
        self.metric = metric
        self.prefix = props.string("prefix") ?? ""
        self.suffix = props.string("suffix") ?? ""
        self.fallbackText = props.string("fallbackText") ?? ""
        super.init(frame: frame)

        let fontSize = props.cgFloat("fontSize", default: 14)
        let fontWeight = props.string("fontWeight") ?? "regular"
        let colorHex = props.string("color") ?? "#FFFFFF"
        let alignment = props.string("alignment") ?? "center"

        label.font = NSFont.systemFont(ofSize: fontSize, weight: parseWeight(fontWeight))
        label.textColor = NSColor.fromHex(colorHex) ?? .white
        label.alignment = parseAlignment(alignment)
        label.drawsBackground = false
        label.frame = NSRect(x: 0, y: 0, width: frame.width, height: frame.height)
        addSubview(label)

        render(snapshot: snapshot, prefix: prefix, suffix: suffix, fallbackText: fallbackText)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(snapshot: MetricSnapshot) {
        render(snapshot: snapshot, prefix: prefix, suffix: suffix, fallbackText: fallbackText)
    }

    private func render(snapshot: MetricSnapshot, prefix: String, suffix: String, fallbackText: String) {
        guard let metricId = metric else {
            label.stringValue = fallbackText
            return
        }
        let value = snapshot.value(for: metricId)
        var text: String
        switch value {
        case .text(let s), .enumeration(let s):
            text = s
        case .ratio(let d):
            text = String(format: "%.0f", d * 100)
        case .percent(let d):
            text = String(format: "%.0f", d)
        case .number(let d):
            text = String(format: "%.0f", d)
        case .boolean(let b):
            text = b ? "true" : "false"
        case .unavailable:
            text = fallbackText
        }
        label.stringValue = "\(prefix)\(text)\(suffix)"
    }
}

// MARK: - Linear Bar

final class LinearBarPrimitive: NSView, RendererPrimitive {
    private let metric: String?
    private let barLayer = CALayer()
    private let trackLayer = CALayer()
    private let props: ResolvedRuntimeProps

    init(metric: String?, props: ResolvedRuntimeProps, frame: CGRect, snapshot: MetricSnapshot) {
        self.metric = metric
        self.props = props
        super.init(frame: frame)
        wantsLayer = true

        let fillColor = NSColor.fromHex(props.string("fillColor") ?? "#34C759") ?? .systemGreen
        let trackColor = NSColor.fromHex(props.string("trackColor") ?? "#FFFFFF26") ?? NSColor.white.withAlphaComponent(0.15)
        let cornerRadius = props.cgFloat("cornerRadius", default: 3)

        trackLayer.backgroundColor = trackColor.cgColor
        trackLayer.cornerRadius = cornerRadius
        layer?.addSublayer(trackLayer)

        barLayer.backgroundColor = fillColor.cgColor
        barLayer.cornerRadius = cornerRadius
        layer?.addSublayer(barLayer)

        layoutBar(frame: frame)
        render(snapshot: snapshot)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        layoutBar(frame: bounds)
    }

    private func layoutBar(frame: CGRect) {
        let barHeight = props.cgFloat("barHeight", default: min(frame.height, 12))
        let y = (frame.height - barHeight) / 2
        trackLayer.frame = CGRect(x: 0, y: y, width: frame.width, height: barHeight)
    }

    func update(snapshot: MetricSnapshot) {
        render(snapshot: snapshot)
    }

    private func render(snapshot: MetricSnapshot) {
        let ratio = resolveRatio(snapshot: snapshot)
        var direction = props.string("direction") ?? "leftToRight"
        
        // Map web registry enums
        if direction == "horizontal" { direction = "leftToRight" }
        if direction == "vertical" { direction = "bottomToTop" }

        switch direction {
        case "leftToRight":
            barLayer.frame = CGRect(x: 0, y: trackLayer.frame.minY, width: bounds.width * ratio, height: trackLayer.frame.height)
        case "rightToLeft":
            barLayer.frame = CGRect(x: bounds.width * (1 - ratio), y: trackLayer.frame.minY, width: bounds.width * ratio, height: trackLayer.frame.height)
        case "topToBottom":
            barLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height * ratio)
        case "bottomToTop":
            barLayer.frame = CGRect(x: 0, y: bounds.height * (1 - ratio), width: bounds.width, height: bounds.height * ratio)
        default:
            barLayer.frame = CGRect(x: 0, y: trackLayer.frame.minY, width: bounds.width * ratio, height: trackLayer.frame.height)
        }

        // Color warning thresholds
        if ratio < 0.1 {
            barLayer.backgroundColor = NSColor.systemRed.cgColor
        } else if ratio < 0.3 {
            barLayer.backgroundColor = NSColor.systemOrange.cgColor
        } else {
            barLayer.backgroundColor = (NSColor.fromHex(props.string("fillColor") ?? "#34C759") ?? .systemGreen).cgColor
        }
    }

    private func resolveRatio(snapshot: MetricSnapshot) -> CGFloat {
        guard let metricId = metric else { return 0 }
        let value = snapshot.value(for: metricId)
        switch value {
        case .ratio(let d): return CGFloat(max(0, min(1, d)))
        case .percent(let d): return CGFloat(max(0, min(1, d / 100)))
        case .number(let d) where d >= 0 && d <= 1: return CGFloat(d)
        default: return 0
        }
    }
}

// MARK: - Circle Fill

final class CircleFillPrimitive: NSView, RendererPrimitive {
    private let metric: String?
    private let props: ResolvedRuntimeProps
    private let trackPath: NSBezierPath
    private var currentRatio: CGFloat = 0

    init(metric: String?, props: ResolvedRuntimeProps, frame: CGRect, snapshot: MetricSnapshot) {
        self.metric = metric
        self.props = props
        let center = CGPoint(x: frame.width / 2, y: frame.height / 2)
        let radius = min(frame.width, frame.height) / 2
        self.trackPath = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        super.init(frame: frame)
        render(snapshot: snapshot)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(snapshot: MetricSnapshot) {
        render(snapshot: snapshot)
        setNeedsDisplay(bounds)
    }

    private func render(snapshot: MetricSnapshot) {
        guard let metricId = metric else { currentRatio = 0; return }
        let value = snapshot.value(for: metricId)
        switch value {
        case .ratio(let d): currentRatio = CGFloat(max(0, min(1, d)))
        case .percent(let d): currentRatio = CGFloat(max(0, min(1, d / 100)))
        case .number(let d) where d >= 0 && d <= 1: currentRatio = CGFloat(d)
        default: currentRatio = 0
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let fillColor = NSColor.fromHex(props.string("fillColor") ?? "#2E7BFF") ?? .systemBlue
        let trackColor = NSColor.fromHex(props.string("trackColor") ?? "#071B38") ?? NSColor.black.withAlphaComponent(0.3)

        trackColor.setFill()
        trackPath.fill()

        if currentRatio > 0 {
            ctx.saveGState()
            trackPath.addClip()

            var direction = props.string("direction") ?? "bottomToTop"
            if direction == "horizontal" { direction = "leftToRight" }
            if direction == "vertical" { direction = "bottomToTop" }
            
            var fillRect = bounds
            switch direction {
            case "bottomToTop":
                fillRect.origin.y = bounds.height * (1 - currentRatio)
                fillRect.size.height *= currentRatio
            case "topToBottom":
                fillRect.size.height *= currentRatio
            case "leftToRight":
                fillRect.size.width *= currentRatio
            case "rightToLeft":
                fillRect.origin.x = bounds.width * (1 - currentRatio)
                fillRect.size.width *= currentRatio
            default:
                fillRect.origin.y = bounds.height * (1 - currentRatio)
                fillRect.size.height *= currentRatio
            }

            fillColor.setFill()
            fillRect.fill()
            ctx.restoreGState()
        }
    }
}

// MARK: - Ring Stroke

final class RingStrokePrimitive: NSView, RendererPrimitive {
    private let metric: String?
    private let props: ResolvedRuntimeProps
    private var currentRatio: CGFloat = 0

    init(metric: String?, props: ResolvedRuntimeProps, frame: CGRect, snapshot: MetricSnapshot) {
        self.metric = metric
        self.props = props
        super.init(frame: frame)
        render(snapshot: snapshot)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(snapshot: MetricSnapshot) {
        render(snapshot: snapshot)
        setNeedsDisplay(bounds)
    }

    private func render(snapshot: MetricSnapshot) {
        guard let metricId = metric else { currentRatio = 0; return }
        let value = snapshot.value(for: metricId)
        switch value {
        case .ratio(let d): currentRatio = CGFloat(max(0, min(1, d)))
        case .percent(let d): currentRatio = CGFloat(max(0, min(1, d / 100)))
        case .number(let d) where d >= 0 && d <= 1: currentRatio = CGFloat(d)
        default: currentRatio = 0
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let lineWidth = props.cgFloat("lineWidth", default: 4)
        let fillColor = NSColor.fromHex(props.string("fillColor") ?? "#34C759") ?? .systemGreen
        let trackColor = NSColor.fromHex(props.string("trackColor") ?? "#FFFFFF26") ?? NSColor.white.withAlphaComponent(0.15)
        let startAngleDeg = props.cgFloat("startAngle", default: -90)
        let clockwise = props.bool("clockwise") ?? false
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2

        // Track
        ctx.setStrokeColor(trackColor.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        ctx.strokePath()

        // Fill
        if currentRatio > 0 {
            ctx.setStrokeColor(fillColor.cgColor)
            let lineCap = props.string("lineCap") ?? "round"
            switch lineCap {
            case "butt": ctx.setLineCap(.butt)
            case "square": ctx.setLineCap(.square)
            default: ctx.setLineCap(.round)
            }

            let startAngle = startAngleDeg * .pi / 180
            let sweep = currentRatio * 2 * .pi
            let endAngle = clockwise ? (startAngle - sweep) : (startAngle + sweep)
            ctx.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
            ctx.strokePath()
        }
    }
}

// MARK: - Variant Icon

final class VariantIconPrimitive: NSView, RendererPrimitive {
    private let metric: String?
    private let imageView = NSImageView()
    private let variants: [String: String]
    private let fallback: String?
    private let rootURL: URL?

    init(metric: String?, props: ResolvedRuntimeProps, frame: CGRect, snapshot: MetricSnapshot, rootURL: URL?) {
        self.metric = metric
        self.rootURL = rootURL

        var variantsMap: [String: String] = [:]
        // Parse props like "variant.day", "variant.night"
        for (key, val) in props.values {
            if key.hasPrefix("variant.") {
                let variantKey = String(key.dropFirst("variant.".count))
                if let path = val.stringValue { variantsMap[variantKey] = path }
            }
        }
        self.variants = variantsMap
        self.fallback = props.string("fallback")

        super.init(frame: frame)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        AnimatedImageSupport.configure(imageView)
        imageView.frame = NSRect(x: 0, y: 0, width: frame.width, height: frame.height)
        addSubview(imageView)

        render(snapshot: snapshot)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(snapshot: MetricSnapshot) {
        render(snapshot: snapshot)
    }

    private func render(snapshot: MetricSnapshot) {
        guard let metricId = metric else { return }
        let value = snapshot.value(for: metricId)
        let key: String
        switch value {
        case .enumeration(let s), .text(let s): key = s
        case .boolean(let b): key = b ? "true" : "false"
        default: key = ""
        }

        if let assetPath = variants[key] ?? fallback, let root = rootURL {
            let url = root.appendingPathComponent(assetPath)
            if AnimatedImageSupport.load(contentsOf: url, into: imageView) {
                imageView.isHidden = false
                return
            }
        }

        // Fallback: draw a simple colored circle with the key letter
        AnimatedImageSupport.stopAnimation(on: imageView)
        imageView.image = placeholderIcon(for: key)
        imageView.isHidden = false
    }

    private func placeholderIcon(for key: String) -> NSImage {
        let size = NSSize(width: 32, height: 32)
        return NSImage(size: size, flipped: true) { rect in
            let hue: CGFloat = key == "day" ? 0.14 : (key == "night" ? 0.65 : 0.5)
            NSColor(hue: hue, saturation: 0.5, brightness: 0.8, alpha: 1).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2)).fill()
            return true
        }
    }
}

// MARK: - Analog Clock

final class AnalogClockPrimitive: NSView, RendererPrimitive {
    private let props: ResolvedRuntimeProps
    private var hourValue: Double = 0
    private var minuteValue: Double = 0
    private var timer: Timer?

    init(props: ResolvedRuntimeProps, frame: CGRect, snapshot: MetricSnapshot) {
        self.props = props
        super.init(frame: frame)
        render(snapshot: snapshot)

        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.setNeedsDisplay(self?.bounds ?? .zero)
        }
    }

    required init?(coder: NSCoder) { fatalError() }
    deinit { timer?.invalidate() }

    func update(snapshot: MetricSnapshot) {
        render(snapshot: snapshot)
        setNeedsDisplay(bounds)
    }

    private func render(snapshot: MetricSnapshot) {
        hourValue = snapshot.value(for: "system.time.hour").doubleValue ?? 0
        minuteValue = snapshot.value(for: "system.time.minute").doubleValue ?? 0
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard NSGraphicsContext.current?.cgContext != nil else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 2

        let faceColor = NSColor.fromHex(props.string("faceColor") ?? "#1A1A2E") ?? .black
        let handColor = NSColor.fromHex(props.string("handColor") ?? "#FFFFFF") ?? .white
        let tickColor = NSColor.fromHex(props.string("tickColor") ?? "#FFFFFF44") ?? NSColor.white.withAlphaComponent(0.27)
        let showTicks = props.bool("showTicks") ?? true

        // Face
        faceColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()

        // Ticks
        if showTicks {
            tickColor.setStroke()
            for i in 0..<12 {
                let angle = CGFloat(i) * .pi / 6 - .pi / 2
                let inner = radius * 0.82
                let outer = radius * 0.93
                let path = NSBezierPath()
                path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                path.line(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                path.lineWidth = 1
                path.stroke()
            }
        }

        // Hour hand
        let hourAngle = -(.pi / 2) + (hourValue / 12) * 2 * .pi + (minuteValue / 60) * (.pi / 6)
        handColor.setStroke()
        let hourPath = NSBezierPath()
        hourPath.move(to: center)
        hourPath.line(to: CGPoint(x: center.x + cos(hourAngle) * radius * 0.5, y: center.y + sin(hourAngle) * radius * 0.5))
        hourPath.lineWidth = 2.5
        hourPath.stroke()

        // Minute hand
        let minuteAngle = -(.pi / 2) + (minuteValue / 60) * 2 * .pi
        let minutePath = NSBezierPath()
        minutePath.move(to: center)
        minutePath.line(to: CGPoint(x: center.x + cos(minuteAngle) * radius * 0.75, y: center.y + sin(minuteAngle) * radius * 0.75))
        minutePath.lineWidth = 1.5
        minutePath.stroke()

        // Center dot
        handColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)).fill()
    }
}

// MARK: - Timer Text

final class TimerTextPrimitive: NSView, RendererPrimitive {
    private let metric: String?
    private let label = NSTextField(labelWithString: "")
    private var timer: Timer?

    init(metric: String?, props: ResolvedRuntimeProps, frame: CGRect, snapshot: MetricSnapshot) {
        self.metric = metric
        super.init(frame: frame)

        let fontSize = props.cgFloat("fontSize", default: 16)
        let color = NSColor.fromHex(props.string("color") ?? "#FFFFFF") ?? .white

        label.font = .monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
        label.textColor = color
        label.alignment = .center
        label.drawsBackground = false
        label.frame = NSRect(x: 0, y: 0, width: frame.width, height: frame.height)
        addSubview(label)

        render(snapshot: snapshot)
    }

    required init?(coder: NSCoder) { fatalError() }
    deinit { timer?.invalidate() }

    func update(snapshot: MetricSnapshot) {
        render(snapshot: snapshot)
    }

    private func render(snapshot: MetricSnapshot) {
        guard let metricId = metric else { label.stringValue = "--:--"; return }
        let value = snapshot.value(for: metricId)
        switch value {
        case .text(let s): label.stringValue = s
        case .number(let d): label.stringValue = formatSeconds(Int(d))
        default: label.stringValue = "--:--"
        }
    }

    private func formatTimer(from value: MetricValue) -> String {
        switch value {
        case .text(let s): return s
        case .number(let d): return formatSeconds(Int(d))
        default: return "--:--"
        }
    }

    private func formatSeconds(_ total: Int) -> String {
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Action Buttons

final class ActionButtonsPrimitive: NSView, RendererPrimitive {
    private let label = NSTextField(labelWithString: "")
    private let nestId: String

    init(props: ResolvedRuntimeProps, nestId: String) {
        self.nestId = nestId
        super.init(frame: .zero)
        wantsLayer = true

        let buttonCount = Int(props.number("maxItems") ?? 3)
        label.stringValue = "⚡ \(buttonCount) actions"
        label.font = .systemFont(ofSize: CGFloat(props.number("fontSize") ?? 11), weight: .medium)
        label.textColor = NSColor.fromHex(props.string("color") ?? "#FFFFFF") ?? .white
        label.alignment = .center
        label.drawsBackground = false
        label.frame = NSRect(x: 0, y: 0, width: CGFloat(props.number("maxWidth") ?? 160), height: 36)
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(snapshot: MetricSnapshot) {
        // Action buttons are static; metric updates not applicable
    }
}

// MARK: - Group

final class GroupPrimitive: NSView, RendererPrimitive {
    private var childPrimitives: [RendererPrimitive] = []

    init(node: RuntimeNode, resolvedProps: ResolvedRuntimeProps, frame: CGRect, snapshot: MetricSnapshot, rootURL: URL?, nestId: String, effectiveProps: [String: RegistryPropValue] = [:]) {
        super.init(frame: frame)
        wantsLayer = true

        guard let children = node.children else { return }

        let direction = resolvedProps.string("direction") ?? "horizontal"
        let spacing = resolvedProps.cgFloat("spacing", default: 4)
        var offset: CGFloat = 0

        for childNode in children {
            let childProps = childNode.resolvedProps(effectiveProps: effectiveProps, frame: frame)

            // Layout logic: Stack children
            let childWidth = (direction == "horizontal") ? frame.width / CGFloat(children.count) - spacing : frame.width
            let childHeight = (direction == "vertical") ? frame.height / CGFloat(children.count) - spacing : frame.height

            let childFrame: CGRect
            if direction == "horizontal" {
                childFrame = CGRect(x: offset, y: 0, width: childWidth, height: frame.height)
                offset += childWidth + spacing
            } else {
                childFrame = CGRect(x: 0, y: offset, width: frame.width, height: childHeight)
                offset += childHeight + spacing
            }

            if let view = PrimitiveFactory.create(
                node: childNode,
                resolvedProps: childProps,
                frame: childFrame,
                snapshot: snapshot,
                rootURL: rootURL,
                nestId: nestId,
                effectiveProps: effectiveProps
            ) {
                if let primitive = view as? RendererPrimitive {
                    childPrimitives.append(primitive)
                }
                addSubview(view)
            }
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(snapshot: MetricSnapshot) {
        for primitive in childPrimitives {
            primitive.update(snapshot: snapshot)
        }
    }
}

// MARK: - Helpers

private func parseWeight(_ s: String) -> NSFont.Weight {
    switch s {
    case "medium": return .medium
    case "semibold": return .semibold
    case "bold": return .bold
    default: return .regular
    }
}

private func parseAlignment(_ s: String) -> NSTextAlignment {
    switch s {
    case "left": return .left
    case "right": return .right
    default: return .center
    }
}

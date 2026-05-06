import AppKit

final class MetricGaugeRenderer: NSView, NestElementRenderer {
    private let element: MetricGaugeElement
    private var currentRatio: CGFloat?
    
    override var isFlipped: Bool { true }
    
    init(element: MetricGaugeElement) {
        self.element = element
        super.init(frame: .zero)
        wantsLayer = true
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func update(snapshot: MetricSnapshot) {
        let value = snapshot.value(for: element.metric)
        
        switch value {
        case .ratio(let d):
            currentRatio = CGFloat(max(0, min(1, d)))
        case .percent(let d):
            currentRatio = CGFloat(max(0, min(1, d / 100.0)))
        case .number(let d):
            // Only use if 0...1 as ratio, otherwise unavailable
            if d >= 0 && d <= 1 {
                currentRatio = CGFloat(d)
            } else {
                currentRatio = nil
            }
        default:
            currentRatio = nil
        }
        
        setNeedsDisplay(bounds)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        let style = element.style
        let fillColor = NSColor.fromHex(style?.fillColor ?? "#34C759") ?? .systemGreen
        let trackColor = NSColor.fromHex(style?.trackColor ?? "#FFFFFF26") ?? NSColor.white.withAlphaComponent(0.15)
        let overallOpacity = CGFloat(style?.opacity ?? 1.0)
        
        ctx.setAlpha(overallOpacity)
        
        switch element.renderer {
        case "ringStroke":
            drawRingStroke(ctx: ctx, fillColor: fillColor, trackColor: trackColor)
        case "linearBar":
            drawLinearBar(ctx: ctx, fillColor: fillColor, trackColor: trackColor)
        case "circleFill":
            drawCircleFill(ctx: ctx, fillColor: fillColor, trackColor: trackColor)
        default:
            break
        }
    }
    
    private func drawRingStroke(ctx: CGContext, fillColor: NSColor, trackColor: NSColor) {
        let style = element.style
        let lineWidth = CGFloat(style?.lineWidth ?? 4)
        let startAngleDeg = CGFloat(style?.startAngle ?? -90)
        let clockwise = style?.clockwise ?? false
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
        
        // Draw track
        ctx.setStrokeColor(trackColor.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        ctx.strokePath()
        
        // Draw fill
        if let ratio = currentRatio, ratio > 0 {
            ctx.setStrokeColor(fillColor.cgColor)
            ctx.setLineCap(parseLineCap(style?.lineCap))
            
            let startAngle = startAngleDeg * .pi / 180
            let sweep = ratio * 2 * .pi
            let endAngle = clockwise ? (startAngle - sweep) : (startAngle + sweep)
            
            ctx.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
            ctx.strokePath()
        }
    }
    
    private func drawLinearBar(ctx: CGContext, fillColor: NSColor, trackColor: NSColor) {
        let style = element.style
        let cornerRadius = CGFloat(style?.cornerRadius ?? Double(bounds.height / 2))
        let clampedCornerRadius = min(cornerRadius, min(bounds.width, bounds.height) / 2)
        
        let path = NSBezierPath(roundedRect: bounds, xRadius: clampedCornerRadius, yRadius: clampedCornerRadius)
        
        // Draw track
        trackColor.setFill()
        path.fill()
        
        // Draw fill
        if let ratio = currentRatio, ratio > 0 {
            ctx.saveGState()
            path.addClip()
            
            let direction = style?.direction ?? "leftToRight"
            var fillRect = bounds
            
            switch direction {
            case "leftToRight":
                fillRect.size.width *= ratio
            case "rightToLeft":
                fillRect.origin.x = bounds.width * (1 - ratio)
                fillRect.size.width *= ratio
            case "topToBottom":
                fillRect.size.height *= ratio
            case "bottomToTop":
                fillRect.origin.y = bounds.height * (1 - ratio)
                fillRect.size.height *= ratio
            default:
                fillRect.size.width *= ratio
            }
            
            fillColor.setFill()
            fillRect.fill()
            
            ctx.restoreGState()
        }
    }
    
    private func drawCircleFill(ctx: CGContext, fillColor: NSColor, trackColor: NSColor) {
        let style = element.style
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2
        
        let path = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        
        // Draw track
        trackColor.setFill()
        path.fill()
        
        // Draw fill
        if let ratio = currentRatio, ratio > 0 {
            ctx.saveGState()
            path.addClip()
            
            let direction = style?.direction ?? "bottomToTop"
            var fillRect = bounds
            
            switch direction {
            case "topToBottom":
                fillRect.size.height *= ratio
            case "bottomToTop":
                fillRect.origin.y = bounds.height * (1 - ratio)
                fillRect.size.height *= ratio
            case "leftToRight":
                fillRect.size.width *= ratio
            case "rightToLeft":
                fillRect.origin.x = bounds.width * (1 - ratio)
                fillRect.size.width *= ratio
            default:
                fillRect.origin.y = bounds.height * (1 - ratio)
                fillRect.size.height *= ratio
            }
            
            fillColor.setFill()
            fillRect.fill()
            
            ctx.restoreGState()
        }
    }
    
    private func parseLineCap(_ cap: String?) -> CGLineCap {
        switch cap {
        case "butt": return .butt
        case "round": return .round
        case "square": return .square
        default: return .round
        }
    }
}

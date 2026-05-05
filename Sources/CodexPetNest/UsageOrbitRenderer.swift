import AppKit

final class UsageOrbitRenderer: NSView {
    private let reader = UsageLimitReader()
    private var timer: Timer?
    private var info: UsageLimitInfo?
    
    var isHovering: Bool = false {
        didSet { if oldValue != isHovering { needsDisplay = true } }
    }
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshData()
        }
        refreshData()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func refreshData() {
        self.info = reader.readLatest()
        needsDisplay = true
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let dist = sqrt(pow(point.x - center.x, 2) + pow(point.y - center.y, 2))
        
        // Inner area (pet body) should pass through to allow clicking the pet
        if dist < 40 {
            return nil
        }
        
        // Rings and outer area should capture right-click
        return super.hitTest(point)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        // Scaled down for tighter fit around pet (pet is ~80x80)
        let outerRadius: CGFloat = 64
        let innerRadius: CGFloat = 52
        let lineWidth: CGFloat = 6
        
        // Background tracks
        drawRing(context: context, center: center, radius: outerRadius, percent: 100, color: NSColor.white.withAlphaComponent(0.08), lineWidth: lineWidth)
        drawRing(context: context, center: center, radius: innerRadius, percent: 100, color: NSColor.white.withAlphaComponent(0.08), lineWidth: lineWidth)
        
        // Ticks
        drawTicks(context: context, center: center, radius: outerRadius, count: 12)
        
        if let info = info {
            if let primary = info.primary {
                let color = colorForPercent(primary.remainingPercent)
                drawRing(context: context, center: center, radius: outerRadius, percent: CGFloat(primary.remainingPercent), color: color, lineWidth: lineWidth, glow: true)
            } else {
                drawRing(context: context, center: center, radius: outerRadius, percent: 100, color: NSColor.gray.withAlphaComponent(0.3), lineWidth: lineWidth)
            }
            
            if let secondary = info.secondary {
                let color = colorForPercent(secondary.remainingPercent)
                drawRing(context: context, center: center, radius: innerRadius, percent: CGFloat(secondary.remainingPercent), color: color, lineWidth: lineWidth, glow: true)
            } else {
                drawRing(context: context, center: center, radius: innerRadius, percent: 100, color: NSColor.gray.withAlphaComponent(0.3), lineWidth: lineWidth)
            }
            
            drawReadouts(info: info)
        } else {
            let gray = NSColor.gray.withAlphaComponent(0.3)
            drawRing(context: context, center: center, radius: outerRadius, percent: 100, color: gray, lineWidth: lineWidth)
            drawRing(context: context, center: center, radius: innerRadius, percent: 100, color: gray, lineWidth: lineWidth)
        }
    }
    
    private func drawRing(context: CGContext, center: CGPoint, radius: CGFloat, percent: CGFloat, color: NSColor, lineWidth: CGFloat, glow: Bool = false) {
        context.saveGState()
        
        let startAngle: CGFloat = -CGFloat.pi / 2
        let endAngle = startAngle + (percent / 100.0) * (2.0 * .pi)
        
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        
        if glow {
            context.setShadow(offset: .zero, blur: 5, color: color.withAlphaComponent(0.8).cgColor)
        }
        
        context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        context.strokePath()
        
        context.restoreGState()
    }
    
    private func drawTicks(context: CGContext, center: CGPoint, radius: CGFloat, count: Int) {
        context.saveGState()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.15).cgColor)
        context.setLineWidth(1.2)
        
        for i in 0..<count {
            let angle = CGFloat(i) * (2.0 * .pi / CGFloat(count)) - .pi/2
            // Smaller ticks for smaller rings
            let p1 = CGPoint(x: center.x + (radius + 5) * cos(angle), y: center.y + (radius + 5) * sin(angle))
            let p2 = CGPoint(x: center.x + (radius + 10) * cos(angle), y: center.y + (radius + 10) * sin(angle))
            context.move(to: p1)
            context.addLine(to: p2)
        }
        context.strokePath()
        context.restoreGState()
    }
    
    private func colorForPercent(_ percent: Int) -> NSColor {
        if percent < 12 { return .systemRed }
        if percent < 30 { return .systemOrange }
        return .systemCyan
    }
    
    private func drawReadouts(info: UsageLimitInfo) {
        if let primary = info.primary {
            if isHovering || primary.remainingPercent < 12 {
                drawPill(percent: primary.remainingPercent, radius: 64, color: colorForPercent(primary.remainingPercent))
            }
        }
        if let secondary = info.secondary {
            if isHovering || secondary.remainingPercent < 12 {
                drawPill(percent: secondary.remainingPercent, radius: 52, color: colorForPercent(secondary.remainingPercent))
            }
        }
    }
    
    private func drawPill(percent: Int, radius: CGFloat, color: NSColor) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let angle = CGFloat(percent) * (2.0 * .pi / 100.0) - .pi/2
        let pillCenter = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        
        let text = "\(percent)%"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attributes)
        
        // Pill background
        let pillWidth = textSize.width + 12
        let pillHeight = textSize.height + 4
        let pillRect = CGRect(x: pillCenter.x - pillWidth/2, y: pillCenter.y - pillHeight/2, width: pillWidth, height: pillHeight)
        
        let path = NSBezierPath(roundedRect: pillRect, xRadius: pillHeight/2, yRadius: pillHeight/2)
        NSColor.black.withAlphaComponent(0.8).setFill()
        path.fill()
        
        // Border
        color.withAlphaComponent(0.6).setStroke()
        path.lineWidth = 1.5
        path.stroke()
        
        text.draw(at: CGPoint(x: pillRect.midX - textSize.width/2, y: pillRect.midY - textSize.height/2), withAttributes: attributes)
    }
    
    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

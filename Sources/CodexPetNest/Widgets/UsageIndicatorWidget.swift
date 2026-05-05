import AppKit

final class UsageIndicatorWidget: NSView {
    private let reader = UsageLimitReader()
    private var info: UsageLimitInfo?
    private var timer: Timer?
    
    private let primaryRing = RingView()
    private let secondaryRing = RingView()
    private let label = NSTextField(labelWithString: "")
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        
        primaryRing.color = .systemGreen
        primaryRing.thickness = 3
        addSubview(primaryRing)
        
        secondaryRing.color = .systemBlue
        secondaryRing.thickness = 2
        addSubview(secondaryRing)
        
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.alignment = .center
        label.textColor = .white
        addSubview(label)
        
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.update()
        }
        
        addTrackingRect(bounds, owner: self, userData: nil, assumeInside: false)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layout() {
        super.layout()
        let size = min(bounds.width, bounds.height)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        
        primaryRing.frame = NSRect(x: center.x - size/2, y: center.y - size/2, width: size, height: size)
        secondaryRing.frame = NSRect(x: center.x - size/2 + 4, y: center.y - size/2 + 4, width: size - 8, height: size - 8)
        label.frame = NSRect(x: 0, y: center.y - 6, width: bounds.width, height: 14)
    }
    
    func update() {
        #if DEBUG
        print("[UsageIndicator] update")
        #endif
        guard let newInfo = reader.readLatest() else {
            isHidden = true
            return
        }
        
        self.info = newInfo
        isHidden = false
        
        if let primary = newInfo.primary {
            primaryRing.percentage = CGFloat(primary.remainingPercent) / 100.0
            label.stringValue = "\(primary.remainingPercent)%"
            
            // Color feedback
            if primary.remainingPercent < 10 {
                primaryRing.color = .systemRed
            } else if primary.remainingPercent < 30 {
                primaryRing.color = .systemOrange
            } else {
                primaryRing.color = .systemGreen
            }
        }
        
        if let secondary = newInfo.secondary {
            secondaryRing.percentage = CGFloat(secondary.remainingPercent) / 100.0
        } else {
            secondaryRing.percentage = 0
        }
        
        if newInfo.limitReached || !newInfo.allowed {
            primaryRing.color = .systemRed
            label.stringValue = "!"
            label.textColor = .white
        } else {
            label.textColor = .white
        }
        
        updateTooltip()
    }
    
    private func updateTooltip() {
        guard let info = info else {
            toolTip = nil
            return
        }
        
        var lines = [
            "Plan: \(info.planType)",
            "Source: \(info.source.rawValue)"
        ]
        
        if let p = info.primary {
            let resetStr = formatReset(p)
            lines.append("5h window: \(p.remainingPercent)% left, \(resetStr)")
        }
        
        if let s = info.secondary {
            let resetStr = formatReset(s)
            lines.append("7d window: \(s.remainingPercent)% left, \(resetStr)")
        }
        
        if info.limitReached {
            lines.append("CRITICAL: Limit Reached")
        }
        
        toolTip = lines.joined(separator: "\n")
    }
    
    private func formatReset(_ bucket: UsageBucket) -> String {
        if let secs = bucket.resetAfterSeconds {
            let h = secs / 3600
            let m = (secs % 3600) / 60
            if h > 24 {
                return "resets in \(h/24)d \(h%24)h"
            }
            return "resets in \(h)h \(m)m"
        } else if let date = bucket.resetDate {
            let df = DateFormatter()
            df.timeStyle = .short
            df.dateStyle = .none
            return "resets at \(df.string(from: date))"
        }
        return "resets soon"
    }
}

private final class RingView: NSView {
    var percentage: CGFloat = 1.0 { didSet { setNeedsDisplay(bounds) } }
    var color: NSColor = .systemGreen { didSet { setNeedsDisplay(bounds) } }
    var thickness: CGFloat = 3 { didSet { setNeedsDisplay(bounds) } }
    
    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - thickness) / 2
        
        // Background track
        let bgPath = NSBezierPath()
        bgPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        color.withAlphaComponent(0.2).setStroke()
        bgPath.lineWidth = thickness
        bgPath.stroke()
        
        // Active ring
        let startAngle: CGFloat = 90
        let endAngle = startAngle - (360 * percentage)
        
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        color.setStroke()
        path.lineWidth = thickness
        path.lineCapStyle = .round
        path.stroke()
    }
}

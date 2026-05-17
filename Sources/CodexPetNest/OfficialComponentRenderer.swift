import AppKit

// MARK: - Factory

enum OfficialComponentFactory {

    /// Create a view for a nest component instance.
    /// - Parameters:
    ///   - component: The component instance from the layout.
    ///   - registry: The loaded component registry (from cache), if available.
    ///   - snapshot: Current metric snapshot.
    ///   - rootURL: Nest root for asset resolution.
    ///   - nestId: Nest identifier.
    /// - Returns: A rendered view, or nil if the component cannot be rendered.
    static func createView(
        for component: NestComponent,
        registry: ComponentRegistry?,
        snapshot: MetricSnapshot,
        rootURL: URL?,
        nestId: String
    ) -> NSView? {
        // Primary path: resolve from registry
        if let reg = registry, let def = reg.component(id: component.component) {
            return createFromRegistry(def: def, component: component, snapshot: snapshot, rootURL: rootURL, nestId: nestId)
        }

        // Fallback: legacy hard-coded switch
        return createLegacyView(for: component, rootURL: rootURL, nestId: nestId)
    }

    /// Resolve a component definition from the registry into a native view.
    static func createFromRegistry(
        def: ComponentDefinition,
        component: NestComponent,
        snapshot: MetricSnapshot,
        rootURL: URL?,
        nestId: String
    ) -> NSView? {
        if component.component == "official.actions.quickActions" {
            return QuickActionsComponent(component: component, nestId: nestId)
        }

        let instanceFrame = component.frame
        let frame = def.effectiveFrame(instanceFrame: instanceFrame)
        let effectiveProps = def.effectiveProps(instanceProps: component.props)
        let resolvedProps = def.runtime.resolvedProps(effectiveProps: effectiveProps, frame: frame)

        return PrimitiveFactory.create(
            node: def.runtime,
            resolvedProps: resolvedProps,
            frame: frame,
            snapshot: snapshot,
            rootURL: rootURL,
            nestId: nestId,
            effectiveProps: effectiveProps
        )
    }

    // MARK: - Legacy Fallback

    private static func createLegacyView(for component: NestComponent, rootURL: URL?, nestId: String) -> NSView? {
        let props = component.props ?? [:]

        func fontSize(_ defaultSize: Double = 14) -> CGFloat {
            if let v = props["fontSize"]?.numberValue { return CGFloat(v) }
            return CGFloat(defaultSize)
        }

        func color(_ defaultHex: String = "#FFFFFF") -> NSColor {
            if let hex = props["color"]?.stringValue {
                return NSColor.fromHex(hex) ?? NSColor.fromHex(defaultHex) ?? .white
            }
            return NSColor.fromHex(defaultHex) ?? .white
        }

        func showLabel() -> Bool {
            props["showLabel"]?.boolValue ?? false
        }

        switch component.component {
        case "official.time.clockText":
            return ClockTextComponent(fontSize: fontSize(16), color: color(), showLabel: showLabel())

        case "official.time.analogClock":
            return AnalogClockLegacyComponent(props: props)

        case "official.time.dayNightIcon":
            let size = props["size"]?.numberValue ?? 24
            return DayNightIconComponent(iconSize: CGFloat(size), showLabel: showLabel())

        case "official.usage.fiveHourBar":
            return UsageBarComponent(
                metricPrefix: "usage.primary",
                barColor: color("#00FF88"),
                showLabel: showLabel()
            )

        case "official.usage.sevenDayBar":
            return UsageBarComponent(
                metricPrefix: "usage.secondary",
                barColor: color("#4488FF"),
                showLabel: showLabel()
            )

        case "official.usage.fiveHourRing":
            return UsageRingComponent(metricPrefix: "usage.primary", props: props)

        case "official.usage.sevenDayRing":
            return UsageRingComponent(metricPrefix: "usage.secondary", props: props)

        case "official.usage.hpMpOrbs":
            return HpMpOrbsComponent(props: props)

        case "official.usage.quotaText":
            return QuotaTextComponent(fontSize: fontSize(14), color: color(), showLabel: showLabel())

        case "official.focus.pomodoroTimer":
            return PomodoroTimerComponent(fontSize: fontSize(18), color: color(), showLabel: showLabel())

        case "official.actions.quickActions":
            return QuickActionsComponent(component: component, nestId: nestId)

        default:
            #if DEBUG
            print("[OfficialComponentFactory] Unknown component: \(component.component)")
            #endif
            return nil
        }
    }
}

// MARK: - Component Renderers (Legacy)

protocol OfficialComponentRenderer: AnyObject {
    func update(snapshot: MetricSnapshot)
}

// MARK: Clock Text

final class ClockTextComponent: NSView, OfficialComponentRenderer {
    private let timeLabel = NSTextField(labelWithString: "")
    private let phaseLabel = NSTextField(labelWithString: "")
    private var timer: Timer?

    init(fontSize: CGFloat, color: NSColor, showLabel: Bool) {
        super.init(frame: .zero)

        timeLabel.font = .monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
        timeLabel.alignment = .center
        timeLabel.textColor = color
        timeLabel.drawsBackground = false
        addSubview(timeLabel)

        phaseLabel.font = .systemFont(ofSize: max(8, fontSize * 0.45), weight: .regular)
        phaseLabel.alignment = .center
        phaseLabel.textColor = color.withAlphaComponent(0.6)
        phaseLabel.drawsBackground = false
        phaseLabel.isHidden = !showLabel
        addSubview(phaseLabel)

        update()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    required init?(coder: NSCoder) { fatalError() }
    deinit { timer?.invalidate() }

    override func layout() {
        super.layout()
        timeLabel.frame = NSRect(x: 0, y: bounds.height * 0.15, width: bounds.width, height: bounds.height * 0.55)
        phaseLabel.frame = NSRect(x: 0, y: 2, width: bounds.width, height: bounds.height * 0.25)
    }

    private func update() {
        let now = Date()
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"
        timeLabel.stringValue = tf.string(from: now)
        let hour = Calendar.current.component(.hour, from: now)
        phaseLabel.stringValue = (hour >= 6 && hour < 18) ? "day" : "night"
    }

    func update(snapshot: MetricSnapshot) {}
}

// MARK: Analog Clock (Legacy wrapper)

final class AnalogClockLegacyComponent: NSView, OfficialComponentRenderer {
    private let clockView: AnalogClockPrimitive
    private var timer: Timer?

    init(props: [String: NestPropValue]) {
        var p: [String: RegistryPropValue] = [:]
        for (k, v) in props { p[k] = RegistryPropValue.from(nestProp: v) }
        let resolved = ResolvedRuntimeProps(values: p)
        let size = CGFloat(props["size"]?.numberValue ?? 80)
        let frame = CGRect(x: 0, y: 0, width: size, height: size)
        self.clockView = AnalogClockPrimitive(props: resolved, frame: frame, snapshot: MetricSnapshot())
        super.init(frame: .zero)
        addSubview(clockView)

        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.clockView.setNeedsDisplay(self?.bounds ?? .zero)
        }
    }

    required init?(coder: NSCoder) { fatalError() }
    deinit { timer?.invalidate() }

    override func layout() {
        super.layout()
        clockView.frame = bounds
    }

    func update(snapshot: MetricSnapshot) {
        clockView.update(snapshot: snapshot)
    }
}

// MARK: Day/Night Icon

final class DayNightIconComponent: NSView, OfficialComponentRenderer {
    private let iconView = NSImageView()
    private let phaseLabel = NSTextField(labelWithString: "")
    private var currentPeriod: String = "day"

    init(iconSize: CGFloat, showLabel: Bool) {
        super.init(frame: .zero)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        phaseLabel.font = .systemFont(ofSize: 9, weight: .regular)
        phaseLabel.alignment = .center
        phaseLabel.textColor = .white.withAlphaComponent(0.6)
        phaseLabel.drawsBackground = false
        phaseLabel.isHidden = !showLabel
        addSubview(phaseLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let iconSize = min(bounds.width, bounds.height) * 0.7
        let x = (bounds.width - iconSize) / 2
        let y = (bounds.height - iconSize) / 2
        iconView.frame = NSRect(x: x, y: y, width: iconSize, height: iconSize)
        phaseLabel.frame = NSRect(x: 0, y: 2, width: bounds.width, height: 12)
    }

    func update(snapshot: MetricSnapshot) {
        let period = snapshot.value(for: "system.time.day_period")
        let periodStr: String
        if case .enumeration(let s) = period { periodStr = s }
        else { periodStr = "day" }

        guard periodStr != currentPeriod else { return }
        currentPeriod = periodStr

        if periodStr == "night" {
            iconView.image = moonIcon()
        } else {
            iconView.image = sunIcon()
        }
        phaseLabel.stringValue = periodStr
    }

    private func sunIcon() -> NSImage {
        let size = NSSize(width: 32, height: 32)
        let image = NSImage(size: size, flipped: true) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 8
            NSColor(red: 1, green: 0.84, blue: 0.2, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
            for i in 0..<8 {
                let angle = CGFloat(i) * .pi / 4
                let inner = radius + 3
                let outer = radius + 7
                let line = NSBezierPath()
                line.move(to: NSPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                line.line(to: NSPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                line.lineWidth = 2
                line.lineCapStyle = .round
                NSColor(red: 1, green: 0.84, blue: 0.2, alpha: 1).setStroke()
                line.stroke()
            }
            return true
        }
        return image
    }

    private func moonIcon() -> NSImage {
        let size = NSSize(width: 32, height: 32)
        let image = NSImage(size: size, flipped: true) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 9
            NSColor(red: 0.75, green: 0.8, blue: 0.9, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x + 2, y: center.y - 4, width: radius * 2, height: radius * 2)).fill()
            return true
        }
        return image
    }
}

// MARK: Usage Bar

final class UsageBarComponent: NSView, OfficialComponentRenderer {
    private let barLayer = CALayer()
    private let trackLayer = CALayer()
    private let label = NSTextField(labelWithString: "")
    private let metricPrefix: String
    private let barColor: NSColor
    private let showLabel: Bool

    init(metricPrefix: String, barColor: NSColor, showLabel: Bool) {
        self.metricPrefix = metricPrefix
        self.barColor = barColor
        self.showLabel = showLabel
        super.init(frame: .zero)
        wantsLayer = true

        trackLayer.backgroundColor = barColor.withAlphaComponent(0.15).cgColor
        trackLayer.cornerRadius = 3
        layer?.addSublayer(trackLayer)

        barLayer.backgroundColor = barColor.cgColor
        barLayer.cornerRadius = 3
        layer?.addSublayer(barLayer)

        label.font = .systemFont(ofSize: 9, weight: .medium)
        label.alignment = .right
        label.textColor = .white.withAlphaComponent(0.8)
        label.drawsBackground = false
        label.isHidden = !showLabel
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let barHeight: CGFloat = 6
        let y = (bounds.height - barHeight) / 2
        trackLayer.frame = NSRect(x: 0, y: y, width: bounds.width, height: barHeight)
        label.frame = NSRect(x: 0, y: y + barHeight + 2, width: bounds.width, height: 12)
    }

    func update(snapshot: MetricSnapshot) {
        let ratio = snapshot.value(for: "\(metricPrefix).remaining_ratio")
        let remaining: CGFloat
        if case .ratio(let r) = ratio { remaining = CGFloat(r) }
        else { remaining = 0 }

        barLayer.frame = NSRect(x: 0, y: trackLayer.frame.minY, width: bounds.width * remaining, height: trackLayer.frame.height)

        if remaining < 0.1 {
            barLayer.backgroundColor = NSColor.systemRed.cgColor
        } else if remaining < 0.3 {
            barLayer.backgroundColor = NSColor.systemOrange.cgColor
        } else {
            barLayer.backgroundColor = barColor.cgColor
        }

        if showLabel {
            let percent = snapshot.value(for: "\(metricPrefix).remaining_percent")
            if case .percent(let p) = percent { label.stringValue = "\(Int(p))%" }
        }
    }
}

// MARK: Usage Ring (new legacy fallback for ringStroke components)

final class UsageRingComponent: NSView, OfficialComponentRenderer {
    private let metricPrefix: String
    private let fillColor: NSColor
    private let trackColor: NSColor
    private let lineWidth: CGFloat
    private var currentRatio: CGFloat = 0

    init(metricPrefix: String, props: [String: NestPropValue]) {
        self.metricPrefix = metricPrefix
        self.fillColor = NSColor.fromHex(props["fillColor"]?.stringValue ?? "#34C759") ?? .systemGreen
        self.trackColor = NSColor.fromHex(props["trackColor"]?.stringValue ?? "#FFFFFF26") ?? NSColor.white.withAlphaComponent(0.15)
        self.lineWidth = CGFloat(props["lineWidth"]?.numberValue ?? 4)
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(snapshot: MetricSnapshot) {
        let ratio = snapshot.value(for: "\(metricPrefix).remaining_ratio")
        if case .ratio(let r) = ratio { currentRatio = CGFloat(r) }
        else { currentRatio = 0 }
        setNeedsDisplay(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2

        ctx.setStrokeColor(trackColor.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        ctx.strokePath()

        if currentRatio > 0 {
            ctx.setStrokeColor(fillColor.cgColor)
            ctx.setLineCap(.round)
            ctx.addArc(center: center, radius: radius, startAngle: -.pi / 2, endAngle: -.pi / 2 + currentRatio * 2 * .pi, clockwise: false)
            ctx.strokePath()
        }
    }
}

// MARK: HP/MP Orbs (new legacy fallback for circleFill group)

final class HpMpOrbsComponent: NSView, OfficialComponentRenderer {
    private let hpOrb = CALayer()
    private let mpOrb = CALayer()
    private let hpTrack = CALayer()
    private let mpTrack = CALayer()
    private var hpRatio: CGFloat = 0
    private var mpRatio: CGFloat = 0

    init(props: [String: NestPropValue]) {
        let hpColor = NSColor.fromHex(props["hpColor"]?.stringValue ?? "#D92A2A") ?? .systemRed
        let mpColor = NSColor.fromHex(props["mpColor"]?.stringValue ?? "#2E7BFF") ?? .systemBlue
        let trackColor = NSColor.fromHex(props["trackColor"]?.stringValue ?? "#FFFFFF26") ?? NSColor.white.withAlphaComponent(0.15)

        super.init(frame: .zero)
        wantsLayer = true

        hpTrack.backgroundColor = trackColor.cgColor
        hpTrack.cornerRadius = 0
        layer?.addSublayer(hpTrack)
        hpOrb.backgroundColor = hpColor.cgColor
        hpOrb.cornerRadius = 0
        layer?.addSublayer(hpOrb)

        mpTrack.backgroundColor = trackColor.cgColor
        mpTrack.cornerRadius = 0
        layer?.addSublayer(mpTrack)
        mpOrb.backgroundColor = mpColor.cgColor
        mpOrb.cornerRadius = 0
        layer?.addSublayer(mpOrb)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let orbWidth = bounds.width / 2
        hpTrack.frame = CGRect(x: 0, y: 0, width: orbWidth, height: bounds.height)
        mpTrack.frame = CGRect(x: orbWidth, y: 0, width: orbWidth, height: bounds.height)
        hpOrb.frame = CGRect(x: 0, y: bounds.height * (1 - hpRatio), width: orbWidth, height: bounds.height * hpRatio)
        mpOrb.frame = CGRect(x: orbWidth, y: bounds.height * (1 - mpRatio), width: orbWidth, height: bounds.height * mpRatio)

        // Clip to circle
        for layer in [hpTrack, hpOrb, mpTrack, mpOrb] {
            let mask = CAShapeLayer()
            mask.path = CGPath(ellipseIn: layer.bounds, transform: nil)
            layer.mask = mask
        }
    }

    func update(snapshot: MetricSnapshot) {
        if case .ratio(let r) = snapshot.value(for: "usage.secondary.remaining_ratio") { hpRatio = CGFloat(r) }
        if case .ratio(let r) = snapshot.value(for: "usage.primary.remaining_ratio") { mpRatio = CGFloat(r) }
        layout()
    }
}

// MARK: Quota Text

final class QuotaTextComponent: NSView, OfficialComponentRenderer {
    private let textLabel = NSTextField(labelWithString: "")
    private let showLabel: Bool

    init(fontSize: CGFloat, color: NSColor, showLabel: Bool) {
        self.showLabel = showLabel
        super.init(frame: .zero)

        textLabel.font = .monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
        textLabel.alignment = .center
        textLabel.textColor = color
        textLabel.drawsBackground = false
        addSubview(textLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        textLabel.frame = bounds
    }

    func update(snapshot: MetricSnapshot) {
        let primaryPct = snapshot.value(for: "usage.primary.remaining_percent")
        let primaryStr: String
        if case .percent(let p) = primaryPct { primaryStr = "\(Int(p))%" }
        else { primaryStr = "--" }

        let secondaryPct = snapshot.value(for: "usage.secondary.remaining_percent")
        let secondaryStr: String
        if case .percent(let p) = secondaryPct { secondaryStr = "\(Int(p))%" }
        else { secondaryStr = "--" }

        let isLimited: Bool
        if case .boolean(let b) = snapshot.value(for: "usage.limit_reached") { isLimited = b }
        else { isLimited = false }

        if isLimited {
            textLabel.stringValue = "Limit!"
            textLabel.textColor = .systemRed
        } else if showLabel {
            textLabel.stringValue = "5h:\(primaryStr) 7d:\(secondaryStr)"
        } else {
            textLabel.stringValue = primaryStr
        }
    }
}

// MARK: Pomodoro Timer

final class PomodoroTimerComponent: NSView, OfficialComponentRenderer {
    private let timeLabel = NSTextField(labelWithString: "")
    private let phaseLabel = NSTextField(labelWithString: "")
    private var timer: Timer?
    private var phase: PomodoroPhase = .idle
    private var secondsRemaining: Int = 0
    private let showLabel: Bool

    init(fontSize: CGFloat, color: NSColor, showLabel: Bool) {
        self.showLabel = showLabel
        super.init(frame: .zero)

        timeLabel.font = .monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
        timeLabel.alignment = .center
        timeLabel.textColor = color
        timeLabel.drawsBackground = false
        addSubview(timeLabel)

        phaseLabel.font = .systemFont(ofSize: max(8, fontSize * 0.45), weight: .regular)
        phaseLabel.alignment = .center
        phaseLabel.textColor = color.withAlphaComponent(0.6)
        phaseLabel.drawsBackground = false
        phaseLabel.isHidden = !showLabel
        addSubview(phaseLabel)

        secondsRemaining = SettingsStore.shared.settings.pomodoro.focusMinutes * 60
        updateDisplay()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    required init?(coder: NSCoder) { fatalError() }
    deinit { timer?.invalidate() }

    override func layout() {
        super.layout()
        timeLabel.frame = NSRect(x: 0, y: bounds.height * 0.15, width: bounds.width, height: bounds.height * 0.55)
        phaseLabel.frame = NSRect(x: 0, y: 2, width: bounds.width, height: bounds.height * 0.25)
    }

    func update(snapshot: MetricSnapshot) {}

    private func tick() {
        guard phase == .focus || phase == .rest else { return }
        secondsRemaining -= 1
        if secondsRemaining <= 0 {
            if phase == .focus {
                phase = .rest
                secondsRemaining = SettingsStore.shared.settings.pomodoro.breakMinutes * 60
            } else {
                phase = .idle
                secondsRemaining = SettingsStore.shared.settings.pomodoro.focusMinutes * 60
                timer?.invalidate()
                timer = nil
            }
        }
        updateDisplay()
    }

    private func updateDisplay() {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        timeLabel.stringValue = String(format: "%02d:%02d", m, s)

        guard showLabel else { return }
        switch phase {
        case .idle: phaseLabel.stringValue = "Ready"
        case .focus: phaseLabel.stringValue = "Focus"
        case .rest: phaseLabel.stringValue = "Break"
        case .paused: phaseLabel.stringValue = "Paused"
        }
    }
}

import AppKit

// MARK: - Factory

enum OfficialComponentFactory {
    static func createView(for component: NestComponent, rootURL: URL?, nestId: String) -> NSView? {
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

        case "official.usage.quotaText":
            return QuotaTextComponent(fontSize: fontSize(14), color: color(), showLabel: showLabel())

        case "official.focus.pomodoroTimer":
            return PomodoroTimerComponent(fontSize: fontSize(18), color: color(), showLabel: showLabel())

        case "official.actions.quickActions":
            return QuickActionsComponent(component: component, nestId: nestId)

        default:
            return nil
        }
    }
}

// MARK: - Component Renderers

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
            let circle = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                                       width: radius * 2, height: radius * 2))
            circle.fill()

            for i in 0..<8 {
                let angle = CGFloat(i) * .pi / 4
                let inner = radius + 3
                let outer = radius + 7
                let x1 = center.x + cos(angle) * inner
                let y1 = center.y + sin(angle) * inner
                let x2 = center.x + cos(angle) * outer
                let y2 = center.y + sin(angle) * outer

                let line = NSBezierPath()
                line.move(to: NSPoint(x: x1, y: y1))
                line.line(to: NSPoint(x: x2, y: y2))
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
            let circle = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                                       width: radius * 2, height: radius * 2))
            circle.fill()

            NSColor.black.setFill()
            let shadow = NSBezierPath(ovalIn: NSRect(x: center.x + 2, y: center.y - 4,
                                                       width: radius * 2, height: radius * 2))
            shadow.fill()
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

        barLayer.frame = NSRect(x: 0, y: trackLayer.frame.minY,
                                 width: bounds.width * remaining,
                                 height: trackLayer.frame.height)

        if remaining < 0.1 {
            barLayer.backgroundColor = NSColor.systemRed.cgColor
        } else if remaining < 0.3 {
            barLayer.backgroundColor = NSColor.systemOrange.cgColor
        } else {
            barLayer.backgroundColor = barColor.cgColor
        }

        if showLabel {
            let percent = snapshot.value(for: "\(metricPrefix).remaining_percent")
            if case .percent(let p) = percent {
                label.stringValue = "\(Int(p))%"
            }
        }
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
        let primaryRemaining = snapshot.value(for: "usage.primary.remaining_percent")
        let primaryPct: String
        if case .percent(let p) = primaryRemaining { primaryPct = "\(Int(p))%" }
        else { primaryPct = "--" }

        let secondaryRemaining = snapshot.value(for: "usage.secondary.remaining_percent")
        let secondaryPct: String
        if case .percent(let p) = secondaryRemaining { secondaryPct = "\(Int(p))%" }
        else { secondaryPct = "--" }

        let limitReached = snapshot.value(for: "usage.limit_reached")
        let isLimited: Bool
        if case .boolean(let b) = limitReached { isLimited = b }
        else { isLimited = false }

        if isLimited {
            textLabel.stringValue = "Limit!"
            textLabel.textColor = .systemRed
        } else if showLabel {
            textLabel.stringValue = "5h:\(primaryPct) 7d:\(secondaryPct)"
        } else {
            textLabel.stringValue = primaryPct
        }
    }
}

// MARK: Pomodoro Timer

final class PomodoroTimerComponent: NSView, OfficialComponentRenderer {
    private let timeLabel = NSTextField(labelWithString: "")
    private let phaseLabel = NSTextField(labelWithString: "")
    private var timer: Timer?

    private var phase: PomodoroPhase = .idle
    private var lastPhase: PomodoroPhase = .idle
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

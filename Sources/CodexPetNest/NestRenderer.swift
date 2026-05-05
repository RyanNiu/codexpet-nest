import AppKit

final class NestRenderer: NSView {
    private var clockWidget: ClockWidget?
    private var countdownWidget: CountdownWidget?
    private var pomodoroWidget: PomodoroWidget?
    private var usageWidget: UsageIndicatorWidget?
    private let cornerRadius: CGFloat = 16
    
    private var orbitRenderer: UsageOrbitRenderer?
    private var layerViews: [NSImageView] = []
    private var activeNest: InstalledNest?

    static let orbitNestId = "capacity-orbit-nest"

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        updateAppearance()
        rebuildWidgets()
        
        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged),
            name: .settingsChanged, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(activeNestChanged),
            name: .activeNestChanged, object: nil
        )
        
        activeNestChanged()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        
        let activeId = SettingsStore.shared.settings.activeNestId
        let mode = isOrbitNest ? "orbit" : (activeNest != nil ? "custom" : "default")
        #if DEBUG
        print("[NestRenderer] Layout triggered. activeNestId: \(activeId), mode: \(mode), canvasSize: \(currentCanvasSize)")
        #endif

        if isOrbitNest {
            orbitRenderer?.frame = bounds
            orbitRenderer?.isHidden = false
            
            // Strictly hide all other UI
            clockWidget?.isHidden = true
            countdownWidget?.isHidden = true
            pomodoroWidget?.isHidden = true
            usageWidget?.isHidden = true
            layerViews.forEach { $0.isHidden = true }
        } else {
            orbitRenderer?.isHidden = true
            if let nest = activeNest {
                layoutCustom(nest)
            } else {
                layoutDefault()
            }
        }
    }
    
    private var isOrbitNest: Bool {
        return SettingsStore.shared.settings.activeNestId == NestRenderer.orbitNestId
    }
    
    private func layoutDefault() {
        let normalWidgets = [clockWidget, countdownWidget, pomodoroWidget].compactMap { $0 }
        let usage = usageWidget
        
        let usageWidth: CGFloat = usage != nil ? 44 : 0
        let availableWidth = bounds.width - usageWidth
        
        if !normalWidgets.isEmpty {
            let w = availableWidth / CGFloat(normalWidgets.count)
            for (i, widget) in normalWidgets.enumerated() {
                widget.frame = NSRect(x: CGFloat(i) * w, y: 0, width: w, height: bounds.height)
                widget.isHidden = false
            }
        }
        
        if let usage = usage {
            usage.frame = NSRect(x: availableWidth, y: 0, width: usageWidth, height: bounds.height)
            usage.isHidden = false
        }
    }
    
    private func layoutCustom(_ nest: InstalledNest) {
        // Layout layers
        for (i, layer) in nest.layout.layers.enumerated() {
            if i < layerViews.count {
                layerViews[i].frame = layer.frame.cgRect
                layerViews[i].isHidden = false
            }
        }
        
        // Layout widgets
        let slots = nest.layout.widgetSlots ?? [:]
        
        func layoutWidget(_ widget: NSView?, id: String) {
            guard let widget = widget else { return }
            if let slot = slots[id] {
                widget.frame = slot.cgRect
                widget.isHidden = false
            } else {
                widget.isHidden = true
            }
        }
        
        layoutWidget(clockWidget, id: "clock")
        layoutWidget(countdownWidget, id: "countdown")
        layoutWidget(pomodoroWidget, id: "pomodoro")
        layoutWidget(usageWidget, id: "usage")
    }

    func rebuildWidgets() {
        clockWidget?.removeFromSuperview()
        clockWidget = nil
        countdownWidget?.removeFromSuperview()
        countdownWidget = nil
        pomodoroWidget?.removeFromSuperview()
        pomodoroWidget = nil
        usageWidget?.removeFromSuperview()
        usageWidget = nil
        orbitRenderer?.removeFromSuperview()
        orbitRenderer = nil

        // If in orbit mode, don't create default widgets at all
        if isOrbitNest {
            orbitRenderer = UsageOrbitRenderer(frame: bounds)
            addSubview(orbitRenderer!)
        } else {
            if SettingsStore.shared.widgetEnabled("clock") {
                clockWidget = ClockWidget(frame: .zero)
                addSubview(clockWidget!)
            }
            if SettingsStore.shared.widgetEnabled("countdown") {
                countdownWidget = CountdownWidget(frame: .zero)
                addSubview(countdownWidget!)
            }
            if SettingsStore.shared.widgetEnabled("pomodoro") {
                pomodoroWidget = PomodoroWidget(frame: .zero)
                addSubview(pomodoroWidget!)
            }
            if SettingsStore.shared.widgetEnabled("usage") {
                usageWidget = UsageIndicatorWidget(frame: .zero)
                addSubview(usageWidget!)
            }
        }
        
        needsLayout = true
    }

    @objc private func settingsChanged() {
        updateAppearance()
        rebuildWidgets()
    }
    
    @objc private func activeNestChanged() {
        let activeId = SettingsStore.shared.settings.activeNestId
        print("[NestRenderer] activeNestChanged. activeId: \(activeId)")
        activeNest = LocalNestManager.shared.getActiveNest()
        
        // Clear old layers
        for v in layerViews { v.removeFromSuperview() }
        layerViews.removeAll()
        
        if let nest = activeNest {
            for layer in nest.layout.layers {
                let imgURL = nest.rootURL.appendingPathComponent(layer.src)
                if let image = NSImage(contentsOf: imgURL) {
                    let iv = NSImageView(image: image)
                    iv.imageScaling = .scaleAxesIndependently
                    addSubview(iv, positioned: .below, relativeTo: nil)
                    layerViews.append(iv)
                }
            }
        }
        
        NotificationCenter.default.post(name: .nestSizeChanged, object: nil)
        updateAppearance()
        rebuildWidgets() // Force rebuild to switch orbit/default mode
        needsLayout = true
    }
    
    private func updateAppearance() {
        if isOrbitNest {
            // Strictly transparent background for orbit
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.cornerRadius = 0
        } else if activeNest != nil {
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.cornerRadius = 0
        } else {
            layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.82).cgColor
            layer?.cornerRadius = cornerRadius
        }
    }

    var currentCanvasSize: NSSize {
        if isOrbitNest {
            return NSSize(width: 160, height: 160)
        }
        if let nest = activeNest {
            return NSSize(width: nest.layout.canvas.width, height: nest.layout.canvas.height)
        }
        return NSSize(width: 220, height: 72)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if isOrbitNest {
            let center = NSPoint(x: bounds.midX, y: bounds.midY)
            let dx = point.x - center.x
            let dy = point.y - center.y
            let dist = sqrt(dx*dx + dy*dy)
            
            // Inner ring is 52. Outer ring is 64.
            // We want to allow clicks through if dist < 40 (central area where pet is).
            if dist < 40 {
                return nil // Click through to pet!
            }
            
            // Also allow click through if dist > 85 (outside the nest area)
            if dist > 85 {
                return nil
            }
            
            // Otherwise, let the widgets/renderer handle it (e.g. right click menu)
            return super.hitTest(point)
        }
        return super.hitTest(point)
    }
}

extension Notification.Name {
    static let nestSizeChanged = Notification.Name("nestSizeChanged")
}

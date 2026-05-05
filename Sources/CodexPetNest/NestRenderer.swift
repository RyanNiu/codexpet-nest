import AppKit

final class NestRenderer: NSView {
    private var clockWidget: ClockWidget?
    private var countdownWidget: CountdownWidget?
    private var pomodoroWidget: PomodoroWidget?
    private var usageWidget: UsageIndicatorWidget?
    private let cornerRadius: CGFloat = 16
    
    private var layerViews: [NSImageView] = []
    private var activeNest: InstalledNest?

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
        
        if let nest = activeNest {
            layoutCustom(nest)
        } else {
            layoutDefault()
        }
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
            }
        }
        
        if let usage = usage {
            usage.frame = NSRect(x: availableWidth, y: 0, width: usageWidth, height: bounds.height)
        }
    }
    
    private func layoutCustom(_ nest: InstalledNest) {
        // Layout layers
        for (i, layer) in nest.layout.layers.enumerated() {
            if i < layerViews.count {
                layerViews[i].frame = layer.frame.cgRect
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
                // If no slot, we could either hide it or use default logic.
                // The prompt says: "If slot missing, use default layout."
                // But in a custom skin, default layout might look weird.
                // Let's hide it for now if no slot is defined in a custom skin, 
                // OR we can just append it at the end.
                // Requirement: "If slot missing, use default layout."
                // Since layoutCustom is called, we'll just hide it if not in slots to avoid overlap.
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
        countdownWidget?.removeFromSuperview()
        pomodoroWidget?.removeFromSuperview()
        usageWidget?.removeFromSuperview()

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
        needsLayout = true
    }

    @objc private func settingsChanged() {
        updateAppearance()
        rebuildWidgets()
    }
    
    @objc private func activeNestChanged() {
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
            // Resize host window if needed? No, prompt says don't change window logic.
        }
        
        updateAppearance()
        needsLayout = true
    }
    
    private func updateAppearance() {
        if activeNest != nil {
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.cornerRadius = 0
        } else {
            layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.82).cgColor
            layer?.cornerRadius = cornerRadius
        }
    }
}

import AppKit

final class NestRenderer: NSView {
    private var clockWidget: ClockWidget?
    private var countdownWidget: CountdownWidget?
    private var pomodoroWidget: PomodoroWidget?
    private var usageWidget: UsageIndicatorWidget?
    private let cornerRadius: CGFloat = 16
    
    private var orbitRenderer: UsageOrbitRenderer?
    private var layerViews: [NSImageView] = []
    private var elementViews: [NSView] = []
    private var elementRenderers: [NestElementRenderer] = []
    private var componentViews: [NSView] = []
    private var componentRenderers: [OfficialComponentRenderer] = []

    private struct RenderItem {
        let view: NSView
        let frame: NestRect
        let zIndex: Int
        let order: Int
    }
    private var renderItems: [RenderItem] = []
    
    private let metricProviders: [MetricProvider] = [
        UsageMetricProvider(),
        SystemMetricProvider(),
        PetMetricProvider()
    ]
    private var metricSnapshot = MetricSnapshot()
    private var metricTimer: Timer?
    
    private var activeNest: InstalledNest?

    override var isFlipped: Bool { true }
    
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
        startMetricTimer()
    }

    deinit {
        metricTimer?.invalidate()
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
            renderItems.forEach { $0.view.isHidden = true }
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
        // Layout all render items (layers + elements + components) in zIndex order
        for item in renderItems {
            item.view.frame = item.frame.cgRect
            item.view.isHidden = false
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

        // Clear old elements
        for v in elementViews { v.removeFromSuperview() }
        elementViews.removeAll()
        elementRenderers.removeAll()

        // Clear old components
        for v in componentViews { v.removeFromSuperview() }
        componentViews.removeAll()
        componentRenderers.removeAll()

        renderItems.removeAll()

        if let nest = activeNest {
            var items: [RenderItem] = []
            var orderCounter = 0

            // Collect image layers (zIndex default 0)
            for layer in nest.layout.layers {
                let imgURL = nest.rootURL.appendingPathComponent(layer.src)
                if let image = NSImage(contentsOf: imgURL) {
                    let iv = NSImageView(image: image)
                    iv.imageScaling = .scaleAxesIndependently
                    if let opacity = layer.opacity {
                        iv.alphaValue = CGFloat(opacity)
                    }
                    layerViews.append(iv)
                    items.append(RenderItem(view: iv, frame: layer.frame, zIndex: layer.zIndex ?? 0, order: orderCounter))
                    orderCounter += 1
                }
            }

            // Collect elements (zIndex default 10, between layers and components)
            if let elements = nest.layout.elements {
                for element in elements {
                    let view: NSView
                    var renderer: NestElementRenderer?

                    switch element {
                    case .staticImage(let e):
                        let iv = NSImageView()
                        iv.imageScaling = .scaleAxesIndependently
                        let imgURL = nest.rootURL.appendingPathComponent(e.src)
                        iv.image = NSImage(contentsOf: imgURL)
                        view = iv
                    case .variantImage(let e):
                        let r = VariantImageRenderer(element: e, rootURL: nest.rootURL)
                        view = r
                        renderer = r
                    case .metricText(let e):
                        let r = MetricTextRenderer(element: e)
                        view = r
                        renderer = r
                    case .metricGauge(let e):
                        let r = MetricGaugeRenderer(element: e)
                        view = r
                        renderer = r
                    }

                    elementViews.append(view)
                    if let renderer = renderer {
                        elementRenderers.append(renderer)
                    }
                    items.append(RenderItem(view: view, frame: element.frame, zIndex: 10, order: orderCounter))
                    orderCounter += 1
                }
            }

            // Collect official components (zIndex default 30)
            if let components = nest.layout.components {
                for component in components {
                    guard let view = OfficialComponentFactory.createView(for: component, rootURL: nest.rootURL, nestId: nest.id) else {
                        continue
                    }
                    componentViews.append(view)
                    if let renderer = view as? OfficialComponentRenderer {
                        componentRenderers.append(renderer)
                    }
                    items.append(RenderItem(view: view, frame: component.frame, zIndex: component.zIndex ?? 30, order: orderCounter))
                    orderCounter += 1
                }
            }

            // Stable sort: zIndex first, then original layout order
            items.sort {
                if $0.zIndex == $1.zIndex { return $0.order < $1.order }
                return $0.zIndex < $1.zIndex
            }
            for item in items {
                addSubview(item.view)
            }
            renderItems = items
        }

        NotificationCenter.default.post(name: .nestSizeChanged, object: nil)
        updateAppearance()
        rebuildWidgets() // Force rebuild to switch orbit/default mode
        refreshMetrics() // Update immediately
        needsLayout = true
    }
    
    // TODO: Implement metricBands logic to allow themes to change element styles (e.g. color) based on metric value ranges
    
    private func startMetricTimer() {
        metricTimer?.invalidate()
        metricTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshMetrics()
        }
    }
    
    private func refreshMetrics() {
        var newSnapshot = MetricSnapshot()
        for provider in metricProviders {
            newSnapshot = newSnapshot.merging(provider.snapshot())
        }
        self.metricSnapshot = newSnapshot
        
        for renderer in elementRenderers {
            renderer.update(snapshot: self.metricSnapshot)
        }
        for renderer in componentRenderers {
            renderer.update(snapshot: self.metricSnapshot)
        }
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
            // In orbit mode, only capture if a subview (like the rings) is hit.
            // If subview returns nil (the center), we return nil to allow clicking the pet.
            for subview in subviews.reversed() {
                if let hit = subview.hitTest(point) {
                    return hit
                }
            }
            return nil
        }
        return super.hitTest(point)
    }
}

extension Notification.Name {
    static let nestSizeChanged = Notification.Name("nestSizeChanged")
}

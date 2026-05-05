import AppKit

final class NestOverlayWindow: NSPanel, NSWindowDelegate {
    private let renderer: NestRenderer
    private let reader = PetPositionReader()
    private var pollTimer: Timer?
    private var hoverTimer: Timer?
    private var lastVisible = false
    private var modeLabel: NSTextField?

    private let gap: CGFloat = 8
    private var currentSize: NSSize { renderer.currentCanvasSize }

    init() {
        let initialSize = NSSize(width: 220, height: 72)
        let contentView = NSView(frame: NSRect(origin: .zero, size: initialSize))
        renderer = NestRenderer(frame: contentView.bounds)
        renderer.autoresizingMask = [.width, .height]
        contentView.addSubview(renderer)

        let label = NSTextField(labelWithString: "Nest (standalone)")
        label.font = .systemFont(ofSize: 9)
        label.textColor = .white.withAlphaComponent(0.35)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 2, width: initialSize.width, height: 10)
        label.isHidden = true
        contentView.addSubview(label)
        modeLabel = label

        super.init(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        delegate = self
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .normal
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        isMovableByWindowBackground = false

        self.contentView = contentView
        setupObservers()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.poll()
        }
        
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.updateHoverState()
        }
    }

    private func updateHoverState() {
        let activeId = SettingsStore.shared.settings.activeNestId
        guard activeId == NestRenderer.orbitNestId else { return }
        
        let mouseLoc = NSEvent.mouseLocation
        let windowFrame = self.frame
        
        let localX = mouseLoc.x - windowFrame.origin.x
        let localY = mouseLoc.y - windowFrame.origin.y
        
        let center = CGPoint(x: windowFrame.width / 2, y: windowFrame.height / 2)
        let dist = sqrt(pow(localX - center.x, 2) + pow(localY - center.y, 2))
        
        let isHovering = dist >= 40 && dist <= 85
        
        if let orbitView = renderer.subviews.first(where: { $0 is UsageOrbitRenderer }) as? UsageOrbitRenderer {
            orbitView.isHovering = isHovering
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = buildMenu()
        NSMenu.popUpContextMenu(menu, with: event, for: self.contentView!)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "CodexPet Nest")
        let activeId = SettingsStore.shared.settings.activeNestId
        
        let classicItem = NSMenuItem(title: "Use Classic Nest",
                                     action: #selector(MenuActionTarget.activateClassicNest),
                                     keyEquivalent: "")
        classicItem.state = activeId == "default" ? .on : .off
        menu.addItem(classicItem)
        
        let orbitItem = NSMenuItem(title: "Use Capacity Orbit Nest",
                                   action: #selector(MenuActionTarget.activateOrbitNest),
                                   keyEquivalent: "")
        orbitItem.state = activeId == "capacity-orbit-nest" ? .on : .off
        menu.addItem(orbitItem)
        
        menu.addItem(.separator())
        
        menu.addItem(NSMenuItem(title: "Toggle Pomodoro", action: #selector(MenuActionTarget.togglePomodoro), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Set Countdown", action: #selector(MenuActionTarget.setCountdown), keyEquivalent: ""))
        
        let usageEnabled = SettingsStore.shared.widgetEnabled("usage")
        let usageTitle = usageEnabled ? "Hide Usage Indicator" : "Show Usage Indicator"
        menu.addItem(NSMenuItem(title: usageTitle, action: #selector(MenuActionTarget.toggleUsage), keyEquivalent: ""))
        
        menu.addItem(.separator())
        
        menu.addItem(NSMenuItem(title: "Browse Pets", action: #selector(MenuActionTarget.browsePets), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Browse Nests", action: #selector(MenuActionTarget.browseNests), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(MenuActionTarget.openSettings), keyEquivalent: ""))
        
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit CodexPet Nest", action: #selector(NSApplication.terminate), keyEquivalent: "q"))
        
        // Only set target for items intended for MenuActionTarget
        for item in menu.items {
            if item.action != #selector(NSApplication.terminate) {
                item.target = MenuActionTarget.shared
            }
        }
        return menu
    }

    private func poll() {
        let result = reader.read()

        switch result {
        case .unavailable, .closed:
            if lastVisible {
                orderOut(nil)
            }
            lastVisible = false

        case .open(let petBounds):
            showFollowing(petBounds: petBounds)
        }
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: .toggleNestVisibility, object: nil, queue: .main) { [weak self] note in
            let show = note.object as? Bool ?? true
            if show {
                self?.orderFront(nil)
            } else {
                self?.orderOut(nil)
            }
        }
        NotificationCenter.default.addObserver(forName: .nestSizeChanged, object: nil, queue: .main) { [weak self] _ in
            self?.updateSizeAndPosition()
        }
    }

    private func updateSizeAndPosition() {
        print("[NestOverlayWindow] updateSizeAndPosition called. currentSize: \(currentSize)")
        contentView?.frame = NSRect(origin: .zero, size: currentSize)
        modeLabel?.frame = NSRect(x: 0, y: 2, width: currentSize.width, height: 10)
        poll()
    }


    private func showFollowing(petBounds: PetBounds) {
        modeLabel?.isHidden = true

        let petTl = NSRect(x: petBounds.x, y: petBounds.y,
                           width: petBounds.width, height: petBounds.height)

        guard let screen = screenForTopLeftRect(petTl) else {
            lastVisible = true
            return
        }

        let petAk = appKitRectFromTopLeft(petTl, screen: screen)
        let nestFrame = computeNestFrame(petFrame: petAk, screen: screen)
        // Stay behind/at normal level. Hover is handled by global polling.
        self.level = .normal
        self.ignoresMouseEvents = false
        
        #if DEBUG
        print("[NestOverlayWindow] petTl: \(petTl), petAk: \(petAk), nestFrame: \(nestFrame), level: \(level.rawValue)")
        #endif
        
        setFrame(nestFrame, display: true)

        if !isVisible || !lastVisible {
            orderFront(nil)
        }
        lastVisible = true
    }

    private func computeNestFrame(petFrame: NSRect, screen: NSScreen) -> NSRect {
        let activeId = SettingsStore.shared.settings.activeNestId
        if activeId == NestRenderer.orbitNestId {
            let size = currentSize
            // Center the orbit nest on the pet
            return NSRect(x: petFrame.midX - size.width / 2,
                          y: petFrame.midY - size.height / 2,
                          width: size.width, height: size.height)
        }

        let pos = SettingsStore.shared.settings.nestPosition
        let sf = screen.visibleFrame
        let size = currentSize

        func rectFor(_ candidate: String) -> NSRect {
            switch candidate {
            case "bottom":
                return NSRect(x: petFrame.midX - size.width / 2,
                              y: petFrame.minY - size.height - gap,
                              width: size.width, height: size.height)
            case "right":
                return NSRect(x: petFrame.maxX + gap,
                              y: petFrame.midY - size.height / 2,
                              width: size.width, height: size.height)
            case "left":
                return NSRect(x: petFrame.minX - size.width - gap,
                              y: petFrame.midY - size.height / 2,
                              width: size.width, height: size.height)
            case "top":
                return NSRect(x: petFrame.midX - size.width / 2,
                              y: petFrame.maxY + gap,
                              width: size.width, height: size.height)
            default:
                return rectFor("bottom")
            }
        }

        func clamp(_ r: NSRect) -> NSRect {
            var r = r
            let margin: CGFloat = 8
            if r.minX < sf.minX + margin { r.origin.x = sf.minX + margin }
            if r.maxX > sf.maxX - margin { r.origin.x = sf.maxX - margin - r.width }
            if r.minY < sf.minY + margin { r.origin.y = sf.minY + margin }
            if r.maxY > sf.maxY - margin { r.origin.y = sf.maxY - margin - r.height }
            return r
        }

        func visibleRatio(_ r: NSRect) -> CGFloat {
            let inter = r.intersection(sf)
            guard inter.width > 0, inter.height > 0 else { return 0 }
            return (inter.width * inter.height) / (r.width * r.height)
        }

        if pos == "auto" {
            let candidates = ["bottom", "right", "left", "top"]
            var best: String?
            var bestScore: CGFloat = -.infinity
            for c in candidates {
                let r = rectFor(c)
                let vr = visibleRatio(r)
                let overflow = max(0, sf.minX - r.minX) + max(0, r.maxX - sf.maxX)
                    + max(0, sf.minY - r.minY) + max(0, r.maxY - sf.maxY)
                let edge = (r.intersection(petFrame).width * r.intersection(petFrame).height > 0) ? 1.0 : 0.0
                let score = vr - overflow * 0.01 - edge
                if score > bestScore {
                    bestScore = score
                    best = c
                }
                if vr >= 0.95 && edge == 0 {
                    break
                }
            }
            return clamp(rectFor(best ?? "bottom"))
        }

        return clamp(rectFor(pos))
    }
}

extension Notification.Name {
    static let togglePomodoro = Notification.Name("CodexPetNest.togglePomodoro")
    static let setCountdown = Notification.Name("CodexPetNest.setCountdown")
    static let openSettings = Notification.Name("CodexPetNest.openSettings")
}

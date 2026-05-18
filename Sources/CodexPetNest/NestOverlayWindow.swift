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
        
        let showHideTitle = SettingsStore.shared.settings.showNest ? l("menu.hide_nest") : l("menu.show_nest")
        menu.addItem(NSMenuItem(title: showHideTitle, action: #selector(MenuActionTarget.toggleShowNest), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem(title: l("context.manage_nests"), action: #selector(MenuActionTarget.manageLocalNests), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: l("context.manage_pets"), action: #selector(MenuActionTarget.manageLocalPets), keyEquivalent: ""))
        

        
        // Only set target for items intended for MenuActionTarget
        for item in menu.items {
            if item.action != #selector(NSApplication.terminate) {
                item.target = MenuActionTarget.shared
            }
        }
        return menu
    }

    private func poll() {
        guard SettingsStore.shared.settings.showNest else {
            if isVisible {
                orderOut(nil)
            }
            return
        }

        let result = reader.read()

        switch result {
        case .unavailable, .closed:
            if lastVisible {
                orderOut(nil)
            }
            lastVisible = false

        case .open(let petBounds):
            let activeId = SettingsStore.shared.settings.activeNestId
            if SettingsStore.shared.settings.hoverOnlyNestIds.contains(activeId) {
                guard let screen = screenForTopLeftRect(NSRect(x: petBounds.x, y: petBounds.y, width: petBounds.width, height: petBounds.height)) else {
                    if lastVisible { orderOut(nil) }
                    lastVisible = false
                    return
                }
                let mouseLoc = NSEvent.mouseLocation
                let petAkY = screen.frame.height - petBounds.y - petBounds.height
                let margin: CGFloat = 60
                let petHitRect = NSRect(x: petBounds.x - margin, y: petAkY - margin, width: petBounds.width + margin * 2, height: petBounds.height + margin * 2)
                let overPet = petHitRect.contains(mouseLoc)
                let overNest = isVisible ? self.frame.contains(mouseLoc) : false
                if !overPet && !overNest {
                    if lastVisible { orderOut(nil) }
                    lastVisible = false
                    return
                }
            }
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
        let size = currentSize
        let sf = screen.visibleFrame

        func clamp(_ r: NSRect) -> NSRect {
            var r = r
            let margin: CGFloat = 8
            if r.minX < sf.minX + margin { r.origin.x = sf.minX + margin }
            if r.maxX > sf.maxX - margin { r.origin.x = sf.maxX - margin - r.width }
            if r.minY < sf.minY + margin { r.origin.y = sf.minY + margin }
            if r.maxY > sf.maxY - margin { r.origin.y = sf.maxY - margin - r.height }
            return r
        }

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

        func visibleRatio(_ r: NSRect) -> CGFloat {
            let inter = r.intersection(sf)
            guard inter.width > 0, inter.height > 0 else { return 0 }
            return (inter.width * inter.height) / (r.width * r.height)
        }

        // 1. Orbit Nest logic
        if activeId == NestRenderer.orbitNestId {
            // Center the orbit nest on the pet
            return NSRect(x: petFrame.midX - size.width / 2,
                          y: petFrame.midY - size.height / 2,
                          width: size.width, height: size.height)
        }

        // 2. V1.1 petSlot logic (check top-level petSlot first, fallback to canvas.petSlot)
        if let activeNest = LocalNestManager.shared.getActiveNest() {
            let petSlotRect: NestRect?
            if let topPetSlot = activeNest.layout.petSlot {
                petSlotRect = topPetSlot.frame
            } else if let canvasPetSlot = activeNest.layout.canvas.petSlot {
                petSlotRect = canvasPetSlot
            } else {
                petSlotRect = nil
            }

            if let petSlot = petSlotRect {
                let slotCenterX = petSlot.x + petSlot.width / 2
                let slotCenterYFromTop = petSlot.y + petSlot.height / 2
                let slotCenterYFromBottom = size.height - slotCenterYFromTop

                let originX = petFrame.midX - CGFloat(slotCenterX)
                let originY = petFrame.midY - CGFloat(slotCenterYFromBottom)

                return NSRect(x: originX, y: originY, width: size.width, height: size.height)
            }
        }

        // 3. Standard positional logic
        let pos = SettingsStore.shared.settings.nestPosition
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
                if vr >= 0.95 && edge == 0 { break }
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

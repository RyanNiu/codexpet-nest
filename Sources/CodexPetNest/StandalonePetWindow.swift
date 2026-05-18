import AppKit

private final class PetInteractionView: NSView {
    weak var petWindow: StandalonePetWindow?

    override var acceptsFirstResponder: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        petWindow?.handleMouseDown(event)
    }

    override func mouseDragged(with event: NSEvent) {
        petWindow?.handleMouseDragged(event)
    }

    override func mouseUp(with event: NSEvent) {
        petWindow?.handleMouseUp(event)
    }

    override func mouseEntered(with event: NSEvent) {
        petWindow?.handleMouseEntered(event)
    }

    override func mouseExited(with event: NSEvent) {
        petWindow?.handleMouseExited(event)
    }

    override func mouseMoved(with event: NSEvent) {
        petWindow?.handleMouseMoved(event)
    }

    override func rightMouseDown(with event: NSEvent) {
        petWindow?.handleRightMouseDown(event)
    }
}

/// Transparent floating window that displays an independent desktop pet.
final class StandalonePetWindow: NSPanel {
    private let animationPlayer = PetAnimationPlayer()
    private var petId: String
    private var dragStartGlobal: NSPoint?
    private var dragOrigin: NSPoint?
    private var behaviorEngine: PetBehaviorEngine?
    private var isDragging = false
    private var isHovering = false
    private var previousMouseInside = false
    private var didDragDuringMouseDown = false
    private var hoverTrackingArea: NSTrackingArea?

    private let defaultSize = NSSize(width: 128, height: 128)

    init(petId: String) {
        self.petId = petId
        let contentView = PetInteractionView(frame: NSRect(origin: .zero, size: defaultSize))
        animationPlayer.view.frame = contentView.bounds
        animationPlayer.view.autoresizingMask = [.width, .height]
        contentView.addSubview(animationPlayer.view)

        let initialOrigin = StandalonePetWindow.restoreOrDefaultOrigin(for: petId)
        super.init(
            contentRect: NSRect(origin: initialOrigin, size: defaultSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        ignoresMouseEvents = SettingsStore.shared.settings.petClickThrough
        isMovableByWindowBackground = false
        acceptsMouseMovedEvents = true

        self.contentView = contentView
        contentView.petWindow = self

        setupHoverTracking()
        applyPet(petId)
        applyBehavior()
    }

    private func setupHoverTracking() {
        if let existing = hoverTrackingArea {
            contentView?.removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect]
        hoverTrackingArea = NSTrackingArea(rect: contentView?.bounds ?? .zero, options: options, owner: contentView, userInfo: nil)
        if let area = hoverTrackingArea {
            contentView?.addTrackingArea(area)
        }
    }

    // MARK: - Pet loading

    private func applyPet(_ petId: String) {
        guard let pet = LocalPetManager.shared.pets.first(where: { $0.id == petId })
                ?? LocalPetManager.shared.pets.first else {
            return
        }
        self.petId = pet.id

        let spritesheetURL = URL(fileURLWithPath: pet.path).appendingPathComponent(pet.spritesheetPath)
        guard let image = NSImage(contentsOf: spritesheetURL) else { return }

        animationPlayer.loadSpritesheet(image, petId: pet.id, manifest: pet.manifest)

        animationPlayer.play(action: "idle")
    }

    private func applyBehavior() {
        if SettingsStore.shared.settings.randomBehaviorEnabled {
            if behaviorEngine == nil {
                behaviorEngine = PetBehaviorEngine(player: animationPlayer, window: self)
            }
            behaviorEngine?.start()
        } else {
            behaviorEngine?.stop()
            behaviorEngine = nil
        }
    }

    // MARK: - Position persistence

    private static func restoreOrDefaultOrigin(for petId: String) -> NSPoint {
        if let saved = SettingsStore.shared.settings.standalonePetFrame {
            let point = NSPoint(x: saved.x, y: saved.y)
            if let screen = screenForPoint(point) {
                let sf = screen.visibleFrame
                let clamped = NSPoint(
                    x: max(sf.minX + 8, min(point.x, sf.maxX - saved.width - 8)),
                    y: max(sf.minY + 8, min(point.y, sf.maxY - saved.height - 8))
                )
                return clamped
            }
        }
        // Default: bottom-right corner of primary screen
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return NSPoint(x: 800, y: 300)
        }
        let sf = screen.visibleFrame
        return NSPoint(x: sf.maxX - 140, y: sf.minY + 200)
    }

    private static func screenForPoint(_ point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            let sf = screen.visibleFrame
            return sf.insetBy(dx: -10, dy: -10).contains(point)
        }
    }

    private func saveCurrentFrame() {
        let f = frame
        SettingsStore.shared.settings.standalonePetFrame = SavedRect(
            x: f.origin.x,
            y: f.origin.y,
            width: f.width,
            height: f.height
        )
        SettingsStore.shared.save()
    }

    // MARK: - Mouse events

    func handleMouseDown(_ event: NSEvent) {
        dragStartGlobal = NSEvent.mouseLocation
        dragOrigin = frame.origin
        isDragging = true
        didDragDuringMouseDown = false
        behaviorEngine?.pause()
        behaviorEngine?.markUserInteraction()
        animationPlayer.play(action: "idle")
    }

    func handleMouseDragged(_ event: NSEvent) {
        guard let dragStartGlobal, let dragOrigin else { return }
        let currentMouse = NSEvent.mouseLocation
        let delta = NSPoint(
            x: currentMouse.x - dragStartGlobal.x,
            y: currentMouse.y - dragStartGlobal.y
        )
        if hypot(delta.x, delta.y) > 2 {
            didDragDuringMouseDown = true
        }
        if delta.x > 2 {
            animationPlayer.play(action: "walk-right")
        } else if delta.x < -2 {
            animationPlayer.play(action: "walk-left")
        }
        var newOrigin = NSPoint(
            x: dragOrigin.x + delta.x,
            y: dragOrigin.y + delta.y
        )
        if let screen = StandalonePetWindow.screenForPoint(newOrigin) {
            let sf = screen.visibleFrame
            newOrigin.x = max(sf.minX + 8, min(newOrigin.x, sf.maxX - frame.width - 8))
            newOrigin.y = max(sf.minY + 8, min(newOrigin.y, sf.maxY - frame.height - 8))
        }
        setFrameOrigin(newOrigin)
    }

    func handleMouseUp(_ event: NSEvent) {
        isDragging = false
        let shouldResumeHover = didDragDuringMouseDown && isMouseInsideContent()
        dragStartGlobal = nil
        dragOrigin = nil
        didDragDuringMouseDown = false
        saveCurrentFrame()
        behaviorEngine?.resume()
        animationPlayer.play(action: shouldResumeHover ? "hover" : "idle")
    }

    func handleMouseEntered(_ event: NSEvent) {
        isHovering = true
        behaviorEngine?.pause()
        behaviorEngine?.markUserInteraction()
        guard !isDragging else { return }
        animationPlayer.play(action: "hover")
    }

    func handleMouseExited(_ event: NSEvent) {
        isHovering = false
        previousMouseInside = false
        behaviorEngine?.resume()
        guard !isDragging else { return }
        animationPlayer.play(action: "idle")
    }

    func handleMouseMoved(_ event: NSEvent) {
        if !previousMouseInside {
            previousMouseInside = true
            behaviorEngine?.pause()
            if !isDragging {
                animationPlayer.play(action: "hover")
            }
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    private func isMouseInsideContent() -> Bool {
        guard let contentView else { return false }
        let windowPoint = convertPoint(fromScreen: NSEvent.mouseLocation)
        let local = contentView.convert(windowPoint, from: nil)
        return contentView.bounds.contains(local)
    }

    // MARK: - Right-click menu

    func handleRightMouseDown(_ event: NSEvent) {
        let menu = buildContextMenu()
        NSMenu.popUpContextMenu(menu, with: event, for: contentView!)
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu(title: "CodexPet Nest")
        let codexAvailable = PetRuntimeCoordinator.shared.isCodexAvailable()
        let isStandalone = PetRuntimeCoordinator.shared.activeMode == .standalone

        // Show/Hide nest
        let showNest = SettingsStore.shared.settings.showNest
        let nestTitle = showNest ? l("menu.hide_nest") : l("menu.show_nest")
        menu.addItem(actionItem(title: nestTitle, action: #selector(MenuActionTarget.toggleShowNest)))

        // Show/Hide pet
        if isStandalone {
            let showPet = SettingsStore.shared.settings.showStandalonePet
            let petTitle = showPet ? "隐藏宠物" : "显示宠物"
            menu.addItem(actionItem(title: petTitle, action: #selector(MenuActionTarget.toggleShowStandalonePet)))
        } else {
            let disabledItem = NSMenuItem(title: "显示/隐藏宠物", action: nil, keyEquivalent: "")
            disabledItem.isEnabled = false
            menu.addItem(disabledItem)
        }

        menu.addItem(.separator())

        // Pet mode submenu
        let modeItem = NSMenuItem(title: "宠物模式", action: nil, keyEquivalent: "")
        let modeMenu = NSMenu(title: "")
        let codexItem = NSMenuItem(
            title: "跟随 Codex 宠物",
            action: #selector(MenuActionTarget.switchToCodexFollow),
            keyEquivalent: ""
        )
        codexItem.state = isStandalone ? .off : .on
        codexItem.isEnabled = codexAvailable
        if !codexAvailable {
            codexItem.title = "跟随 Codex 宠物（Codex 未运行）"
        }
        modeMenu.addItem(codexItem)

        let standaloneItem = NSMenuItem(
            title: "独立桌面宠物",
            action: #selector(MenuActionTarget.switchToStandalone),
            keyEquivalent: ""
        )
        standaloneItem.state = isStandalone ? .on : .off
        modeMenu.addItem(standaloneItem)
        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        // Free roam
        let roamItem = NSMenuItem(
            title: "自由活动",
            action: #selector(MenuActionTarget.toggleFreeRoam),
            keyEquivalent: ""
        )
        roamItem.state = SettingsStore.shared.settings.freeRoamEnabled ? .on : .off
        roamItem.isEnabled = isStandalone
        menu.addItem(roamItem)

        // Always on top
        let topItem = NSMenuItem(
            title: "总在最前",
            action: #selector(MenuActionTarget.togglePetAlwaysOnTop),
            keyEquivalent: ""
        )
        topItem.state = SettingsStore.shared.settings.petAlwaysOnTop ? .on : .off
        menu.addItem(topItem)

        // Click through
        let clickItem = NSMenuItem(
            title: "点击穿透",
            action: #selector(MenuActionTarget.togglePetClickThrough),
            keyEquivalent: ""
        )
        clickItem.state = SettingsStore.shared.settings.petClickThrough ? .on : .off
        menu.addItem(clickItem)

        menu.addItem(.separator())

        menu.addItem(actionItem(title: l("context.manage_pets"), action: #selector(MenuActionTarget.manageLocalPets)))
        menu.addItem(actionItem(title: l("context.manage_nests"), action: #selector(MenuActionTarget.manageLocalNests)))

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: l("menu.quit"), action: #selector(NSApplication.terminate), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        assignActionTargets(in: menu)
        return menu
    }

    private func actionItem(title: String, action: Selector) -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: "")
    }

    private func assignActionTargets(in menu: NSMenu) {
        for item in menu.items {
            if let submenu = item.submenu {
                assignActionTargets(in: submenu)
            }
            if item.action != nil && item.action != #selector(NSApplication.terminate) {
                item.target = MenuActionTarget.shared
            }
        }
    }

    // MARK: - Public API

    func reloadPet(_ newPetId: String? = nil) {
        if let newPetId {
            self.petId = newPetId
        }
        applyPet(self.petId)
    }

    func reloadBehavior() {
        applyBehavior()
    }

    func reloadSettings() {
        ignoresMouseEvents = SettingsStore.shared.settings.petClickThrough
        level = .floating
        applyBehavior()
    }

    override func orderFront(_ sender: Any?) {
        super.orderFront(sender)
        animationPlayer.resume()
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        animationPlayer.pause()
    }

    /// Show a temporary floating tip above the pet window, auto-dismiss after 3 seconds.
    func showModeTip(_ message: String) {
        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.wantsLayer = true
        label.layer?.cornerRadius = 8
        label.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        label.sizeToFit()
        let paddedSize = NSSize(width: label.frame.width + 24, height: 28)
        label.frame = NSRect(origin: NSPoint(x: 12, y: 4), size: label.frame.size)

        let overlay = NSView(frame: NSRect(origin: .zero, size: paddedSize))
        overlay.wantsLayer = true
        overlay.layer?.cornerRadius = 8
        overlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        overlay.addSubview(label)

        let tipWindow = NSPanel(
            contentRect: NSRect(origin: .zero, size: paddedSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        tipWindow.isOpaque = false
        tipWindow.backgroundColor = .clear
        tipWindow.hasShadow = false
        tipWindow.level = level
        tipWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        tipWindow.ignoresMouseEvents = true
        tipWindow.contentView = overlay

        let tipOrigin = NSPoint(x: frame.midX - paddedSize.width / 2, y: frame.maxY + 8)
        tipWindow.setFrameOrigin(tipOrigin)
        tipWindow.orderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                tipWindow.animator().alphaValue = 0
            } completionHandler: {
                tipWindow.orderOut(nil)
            }
        }
    }
}

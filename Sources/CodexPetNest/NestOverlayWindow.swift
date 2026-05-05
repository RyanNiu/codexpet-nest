import AppKit

final class NestOverlayWindow: NSPanel, NSWindowDelegate {
    private let renderer: NestRenderer
    private let reader = PetPositionReader()
    private var pollTimer: Timer?
    private var lastVisible = false
    private var modeLabel: NSTextField?

    private static let nestSize = NSSize(width: 220, height: 72)
    private let gap: CGFloat = 8

    init() {
        let contentView = NSView(frame: NSRect(origin: .zero, size: Self.nestSize))
        renderer = NestRenderer(frame: contentView.bounds)
        renderer.autoresizingMask = [.width, .height]
        contentView.addSubview(renderer)

        let label = NSTextField(labelWithString: "Nest (standalone)")
        label.font = .systemFont(ofSize: 9)
        label.textColor = .white.withAlphaComponent(0.35)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 2, width: Self.nestSize.width, height: 10)
        label.isHidden = true
        contentView.addSubview(label)
        modeLabel = label

        super.init(
            contentRect: NSRect(origin: .zero, size: Self.nestSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        delegate = self
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        isMovableByWindowBackground = false

        self.contentView = contentView
        setupObservers()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = buildMenu()
        let loc = NSPoint(x: frame.minX + event.locationInWindow.x,
                          y: frame.minY + event.locationInWindow.y)
        menu.popUp(positioning: nil, at: loc, in: nil)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "CodexPet Nest")

        menu.addItem(NSMenuItem(title: "Open Nest",
                                 action: #selector(MenuActionTarget.openNest), keyEquivalent: ""))
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Toggle Pomodoro",
                                       action: #selector(MenuActionTarget.togglePomodoro), keyEquivalent: ""))

        menu.addItem(NSMenuItem(title: "Set Countdown",
                                 action: #selector(MenuActionTarget.setCountdown), keyEquivalent: ""))
        
        let usageEnabled = SettingsStore.shared.widgetEnabled("usage")
        let usageTitle = usageEnabled ? "Hide Usage Indicator" : "Show Usage Indicator"
        menu.addItem(NSMenuItem(title: usageTitle,
                                 action: #selector(MenuActionTarget.toggleUsage), keyEquivalent: ""))
        
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Browse Pets",
                                 action: #selector(MenuActionTarget.browsePets), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Browse Nests",
                                 action: #selector(MenuActionTarget.browseNests), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Upload Pet",
                                 action: #selector(MenuActionTarget.uploadPet), keyEquivalent: ""))
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Hide Nest",
                                 action: #selector(MenuActionTarget.hideNest), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings",
                                 action: #selector(MenuActionTarget.openSettings), keyEquivalent: ""))

        menu.items.forEach { $0.target = MenuActionTarget.shared }
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
    }


    private func showFollowing(petBounds: PetBounds) {
        modeLabel?.isHidden = true

        let petTl = NSRect(x: petBounds.x, y: petBounds.y,
                           width: petBounds.width, height: petBounds.height)

        guard let screen = screenForTopLeftRect(petTl) else {
            lastVisible = true
            return
        }

        let tlFrame = topLeftFrame(for: screen)
        let petAk = appKitRectFromTopLeft(petTl, screen: screen)
        let nestFrame = computeNestFrame(petFrame: petAk, screen: screen)
        
        #if DEBUG
        print("[NestOverlay] raw top-left pet rect: \(petTl)")
        print("[NestOverlay] selected screen.frame: \(screen.frame)")
        print("[NestOverlay] selected topLeftFrame: \(tlFrame)")
        print("[NestOverlay] converted AppKit pet rect: \(petAk)")
        print("[NestOverlay] final nest frame: \(nestFrame)")
        #endif
        
        setFrame(nestFrame, display: true)

        if !isVisible || !lastVisible {
            orderFront(nil)
        }
        lastVisible = true
    }

    private func computeNestFrame(petFrame: NSRect, screen: NSScreen) -> NSRect {
        let pos = SettingsStore.shared.settings.nestPosition
        let sf = screen.visibleFrame
        let size = Self.nestSize

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

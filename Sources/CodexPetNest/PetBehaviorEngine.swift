import AppKit

/// Simple state machine for standalone pet autonomous behavior.
///
/// States: idle -> randomAction -> idle
///         idle -> walking -> idle
///         dragging -> idle
///         hovering -> idle
///
/// Free roam is paused during drag/hover and decays frequency when the user is idle.
final class PetBehaviorEngine {
    private weak var player: PetAnimationPlayer?
    private weak var window: StandalonePetWindow?

    private var timer: Timer?
    private var state: BehaviorState = .idle
    private var walkTimer: Timer?
    private var walkDestination: NSPoint?
    private var isPaused = false

    // Idle-tracking for frequency decay
    private var lastUserInteractionTime = Date()
    private var idleTimer: Timer?
    private var activityLevel: ActivityLevel = .active

    private enum BehaviorState {
        case idle
        case randomAction
        case walking
    }

    private enum ActivityLevel {
        case active       // user interacted within last 30s
        case light        // 30s – 2min
        case idle         // 2min – 10min
        case deepIdle     // > 10min — no walking
    }

    init(player: PetAnimationPlayer, window: StandalonePetWindow) {
        self.player = player
        self.window = window
    }

    func start() {
        lastUserInteractionTime = Date()
        startIdleTracking()
        scheduleNext()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        walkTimer?.invalidate()
        walkTimer = nil
        idleTimer?.invalidate()
        idleTimer = nil
        state = .idle
        isPaused = false
        player?.play(action: "idle")
    }

    func pause() {
        guard !isPaused else { return }
        isPaused = true
        timer?.invalidate()
        timer = nil
        walkTimer?.invalidate()
        walkTimer = nil
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        if state == .walking || state == .randomAction {
            state = .idle
            player?.play(action: "idle")
        }
        scheduleNext()
    }

    /// Call when the user interacts (drag, hover) to reset idle tracking.
    func markUserInteraction() {
        lastUserInteractionTime = Date()
        if activityLevel == .deepIdle {
            activityLevel = .idle
            if state == .idle && !isPaused {
                scheduleNext()
            }
        }
    }

    // MARK: - Idle tracking

    private func startIdleTracking() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateActivityLevel()
        }
    }

    private func updateActivityLevel() {
        let elapsed = Date().timeIntervalSince(lastUserInteractionTime)

        let newLevel: ActivityLevel
        if elapsed < 30 {
            newLevel = .active
        } else if elapsed < 120 {
            newLevel = .light
        } else if elapsed < 600 {
            newLevel = .idle
        } else {
            newLevel = .deepIdle
        }

        guard newLevel != activityLevel else { return }
        activityLevel = newLevel

        // Stop walking if entering deep idle
        if newLevel == .deepIdle && state == .walking {
            walkTimer?.invalidate()
            walkTimer = nil
            state = .idle
            player?.play(action: "idle")
            scheduleNext()
        }

        // Restart scheduling with updated frequency
        if state == .idle && !isPaused {
            scheduleNext()
        }
    }

    // MARK: - Scheduling

    private func scheduleNext() {
        guard !isPaused else { return }
        timer?.invalidate()

        let baseMin = 4.0
        let baseMax = 12.0

        let levelMultiplier: Double
        switch activityLevel {
        case .active:   levelMultiplier = 1.0
        case .light:    levelMultiplier = 2.0
        case .idle:     levelMultiplier = 4.0
        case .deepIdle: levelMultiplier = 8.0
        }

        let intensity = SettingsStore.shared.settings.randomBehaviorIntensity
        let intensityFactor: Double = intensity == "high" ? 0.5 : (intensity == "low" ? 2.0 : 1.0)

        let factor = levelMultiplier * intensityFactor
        let delay = Double.random(in: baseMin * factor ... baseMax * factor)

        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.triggerBehavior()
        }
    }

    private func triggerBehavior() {
        guard !isPaused, state == .idle else {
            scheduleNext()
            return
        }

        let walkChance: Double
        switch activityLevel {
        case .active:   walkChance = 0.5
        case .light:    walkChance = 0.3
        case .idle:     walkChance = 0.15
        case .deepIdle: walkChance = 0.0
        }

        let shouldWalk = SettingsStore.shared.settings.freeRoamEnabled
            && activityLevel != .deepIdle
            && Double.random(in: 0...1) < walkChance

        if shouldWalk {
            startWalking()
        } else {
            playRandomAction()
        }
    }

    // MARK: - Actions

    private func playRandomAction() {
        guard state == .idle else { return }
        state = .randomAction
        player?.play(action: "special")
        let duration = 2.0
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.state == .randomAction else { return }
            self.state = .idle
            self.player?.play(action: "idle")
            self.scheduleNext()
        }
    }

    private func startWalking() {
        guard state == .idle, let window else { return }
        state = .walking

        guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            state = .idle
            scheduleNext()
            return
        }

        let sf = screen.visibleFrame
        let currentOrigin = window.frame.origin
        let petSize = window.frame.size

        let targetX = Double.random(in: sf.minX + 20 ... sf.maxX - petSize.width - 20)
        let targetY = Double.random(in: sf.minY + 20 ... sf.maxY - petSize.height - 20)
        let destination = NSPoint(x: targetX, y: targetY)

        let moveSpeed = 55.0
        let distance = hypot(destination.x - currentOrigin.x, destination.y - currentOrigin.y)
        let duration = max(0.4, distance / moveSpeed)

        let isMovingRight = destination.x >= currentOrigin.x
        player?.play(action: isMovingRight ? "walk-right" : "walk-left")

        let stepCount = max(1, Int(duration / 0.05))
        var step = 0
        let deltaX = (destination.x - currentOrigin.x) / Double(stepCount)
        let deltaY = (destination.y - currentOrigin.y) / Double(stepCount)

        walkTimer?.invalidate()
        walkTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] t in
            guard let self, self.state == .walking, let window = self.window else {
                t.invalidate()
                return
            }
            step += 1
            if step >= stepCount {
                window.setFrameOrigin(destination)
                t.invalidate()
                self.walkTimer = nil
                self.state = .idle
                self.player?.play(action: "idle")
                self.saveWindowPosition(window)
                self.scheduleNext()
            } else {
                var newOrigin = NSPoint(
                    x: window.frame.origin.x + deltaX,
                    y: window.frame.origin.y + deltaY
                )
                // Clamp to current screen bounds during each step
                if let currentScreen = window.screen ?? NSScreen.main {
                    let sf = currentScreen.visibleFrame
                    newOrigin.x = max(sf.minX + 8, min(newOrigin.x, sf.maxX - window.frame.width - 8))
                    newOrigin.y = max(sf.minY + 8, min(newOrigin.y, sf.maxY - window.frame.height - 8))
                }
                window.setFrameOrigin(newOrigin)
            }
        }
    }

    private func saveWindowPosition(_ window: StandalonePetWindow) {
        let f = window.frame
        SettingsStore.shared.settings.standalonePetFrame = SavedRect(
            x: f.origin.x,
            y: f.origin.y,
            width: f.width,
            height: f.height
        )
        SettingsStore.shared.save()
    }
}

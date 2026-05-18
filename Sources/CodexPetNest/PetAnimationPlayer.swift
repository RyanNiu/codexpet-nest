import AppKit

/// Lightweight runtime animation player for standalone pet window.
/// Loads spritesheet frames on-demand and plays action-based animations.
final class PetAnimationPlayer {
    let view = NSImageView()

    private var spritesheet: NSImage?
    private var descriptor = SpriteSheetDescriptor(
        frameWidth: 128, frameHeight: 128, columns: 8, rows: 9, animations: nil
    )
    private var frameCache: [String: [NSImage]] = [:]
    private var currentAction: String = "idle"
    private var currentFrameIndex = 0
    private var timer: Timer?
    private var isPaused = false
    private var petId: String?
    private let playbackSpeedMultiplier = 0.65

    init() {
        view.imageScaling = .scaleProportionallyUpOrDown
        view.wantsLayer = true
        view.layer?.magnificationFilter = .nearest
    }

    var availableActions: [String] {
        if let anims = descriptor.animations, !anims.isEmpty {
            return Array(anims.keys).sorted()
        }
        return (0..<descriptor.rows).map { "row_\($0)" }
    }

    // MARK: - Loading

    func loadSpritesheet(_ image: NSImage, petId: String? = nil, manifest: PetManifest? = nil) {
        self.petId = petId
        spritesheet = image
        frameCache.removeAll()

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }

        var manifestDict: [String: Any]?
        if let manifest {
            manifestDict = makeManifestDict(from: manifest)
        }

        descriptor = PetSpriteSheetRenderer.shared.detectDescriptor(cgImage: cgImage, manifest: manifestDict)

        if let petId {
            PetSpriteSheetRenderer.shared.debugExportContactSheet(cgImage: cgImage, desc: descriptor, petId: petId)
        }
    }

    private func makeManifestDict(from manifest: PetManifest) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let fw = manifest.frameWidth { dict["frameWidth"] = fw }
        if let fh = manifest.frameHeight { dict["frameHeight"] = fh }
        if let fs = manifest.frameSize { dict["frameSize"] = fs }
        if let cols = manifest.columns { dict["columns"] = cols }
        if let rows = manifest.rows { dict["rows"] = rows }
        if let anims = manifest.animations {
            var animDict: [String: [String: Any]] = [:]
            for (key, config) in anims {
                var cfg: [String: Any] = ["row": config.row, "frames": config.frames]
                if let fps = config.fps { cfg["fps"] = fps }
                animDict[key] = cfg
            }
            dict["animations"] = animDict
        }
        return dict
    }

    // MARK: - Playback

    func play(action: String) {
        let resolvedAction = resolveAction(action)
        if resolvedAction == currentAction && !isPaused && timer != nil { return }
        stopTimer()

        let frames = cachedFrames(for: resolvedAction)

        if !frames.isEmpty {
            currentAction = resolvedAction
            currentFrameIndex = 0
            view.image = frames[0]

            let fps = animationFPS(for: resolvedAction)
            if frames.count > 1 && !isPaused {
                startTimer(fps: fps, frameCount: frames.count)
            }
        } else if let first = availableActions.first, first != resolvedAction {
            play(action: first)
        }
    }

    func pause() {
        isPaused = true
        stopTimer()
    }

    func resume() {
        isPaused = false
        guard timer == nil else { return }
        let frames = cachedFrames(for: currentAction)
        if frames.count > 1 {
            let fps = animationFPS(for: currentAction)
            startTimer(fps: fps, frameCount: frames.count)
        }
    }

    // MARK: - Internals

    private func resolveAction(_ action: String) -> String {
        let anims = descriptor.animations ?? [:]
        if anims[action] != nil { return action }

        let aliases: [String: [String]] = [
            "idle": ["waiting", "row_0"],
            "hover": ["hovering", "happy", "idle", "row_0"],
            "drag": ["dragging", "held", "picked-up", "idle", "row_0"],
            "walk-right": ["running-right", "run-right", "right", "walk", "running", "row_1", "idle", "row_0"],
            "walk-left": ["running-left", "run-left", "left", "walk", "running", "row_2", "idle", "row_0"],
            "special": ["waving", "wave", "happy", "jumping", "review", "idle", "row_0"]
        ]

        if let candidates = aliases[action] {
            for candidate in candidates {
                if anims[candidate] != nil { return candidate }
            }
        }

        if anims.isEmpty {
            switch action {
            case "walk-right": return descriptor.rows > 1 ? "row_1" : "row_0"
            case "walk-left": return descriptor.rows > 2 ? "row_2" : (descriptor.rows > 1 ? "row_1" : "row_0")
            case "hover": return descriptor.rows > 3 ? "row_3" : "row_0"
            case "drag": return descriptor.rows > 4 ? "row_4" : "row_0"
            case "special": return descriptor.rows > 5 ? "row_5" : "row_0"
            default: return "row_0"
            }
        }

        // Fallback chain
        if action == "hover" && anims["idle"] != nil { return "idle" }
        if action == "drag" {
            if anims["idle"] != nil { return "idle" }
            for key in ["walk-right", "walk-left", "running-right", "running-left"] {
                if anims[key] != nil { return key }
            }
        }
        return anims["idle"] != nil ? "idle" : (availableActions.first ?? action)
    }

    private func cachedFrames(for action: String) -> [NSImage] {
        if let existing = frameCache[action] { return existing }

        guard spritesheet?.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil else {
            return []
        }

        let animConfig = descriptor.animations?[action]
        let row = animConfig?.row ?? rowIndex(for: action)
        let frameCount = animConfig?.frames ?? descriptor.columns

        let previewAction = PetPreviewAction(
            id: action, label: action, row: row,
            frames: frameCount, fps: animConfig?.fps
        )

        let frames = PetSpriteSheetRenderer.shared.extractAnimationFrames(
            from: spritesheet!, action: previewAction, desc: descriptor
        )

        frameCache[action] = frames
        return frames
    }

    private func rowIndex(for action: String) -> Int {
        if action.hasPrefix("row_"),
           let idx = Int(action.dropFirst("row_".count)),
           idx >= 0,
           idx < descriptor.rows {
            return idx
        }
        return 0
    }

    private func animationFPS(for action: String) -> Double {
        let baseFPS = descriptor.animations?[action]?.fps ?? 8.0
        if action == "idle" || action == "waiting" || action == "row_0" {
            return baseFPS * 0.1
        }
        return baseFPS
    }

    private func startTimer(fps: Double, frameCount: Int) {
        stopTimer()
        let effectiveFPS = min(max(fps * playbackSpeedMultiplier, 1.0), 8.0)
        let interval = 1.0 / effectiveFPS
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self, !self.isPaused else { return }
            let frames = self.frameCache[self.currentAction] ?? []
            guard !frames.isEmpty else { return }
            self.currentFrameIndex = (self.currentFrameIndex + 1) % frames.count
            self.view.image = frames[self.currentFrameIndex]
        }
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopTimer()
    }
}

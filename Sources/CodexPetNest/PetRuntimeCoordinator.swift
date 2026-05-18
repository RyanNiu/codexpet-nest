import AppKit

/// Notification posted when the active pet runtime mode changes.
extension Notification.Name {
    static let petRuntimeModeChanged = Notification.Name("CodexPetNest.petRuntimeModeChanged")
    static let petRuntimeStandalonePetChanged = Notification.Name("CodexPetNest.petRuntimeStandalonePetChanged")
    static let petRuntimeModeDegraded = Notification.Name("CodexPetNest.petRuntimeModeDegraded")
    static let petRuntimeModeRestored = Notification.Name("CodexPetNest.petRuntimeModeRestored")
}

final class PetRuntimeCoordinator {
    static let shared = PetRuntimeCoordinator()

    private let positionReader = PetPositionReader()
    private(set) var standalonePetWindow: StandalonePetWindow?

    private var pollTimer: Timer?

    private(set) var activeMode: PetRuntimeMode = .codexFollow

    /// True when standalone mode was entered via automatic degradation (Codex unavailable),
    /// not via manual user choice. Controls whether auto-restore is allowed.
    private var standaloneWasAutoDegraded = false

    var currentPositionProvider: PetPositionProvider {
        switch activeMode {
        case .codexFollow:
            return CodexPetPositionProvider(reader: positionReader)
        case .standalone:
            if let w = standalonePetWindow, w.isVisible {
                return StandalonePetPositionProvider(window: w)
            }
            return CodexPetPositionProvider(reader: positionReader)
        }
    }

    private init() {
        standaloneWasAutoDegraded = SettingsStore.shared.settings.standaloneWasAutoDegraded
        resolveActiveMode()
        startCodexAvailabilityPolling()

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSettingsChanged),
            name: .settingsChanged, object: nil
        )

        NotificationCenter.default.addObserver(
            forName: .petRuntimeModeDegraded, object: nil, queue: .main
        ) { [weak self] note in
            guard let message = note.object as? String else { return }
            self?.standalonePetWindow?.showModeTip(message)
        }

        NotificationCenter.default.addObserver(
            forName: .petRuntimeModeRestored, object: nil, queue: .main
        ) { [weak self] note in
            guard let message = note.object as? String else { return }
            self?.standalonePetWindow?.showModeTip(message)
        }
    }

    // MARK: - Mode resolution

    private func resolveActiveMode() {
        let preferred = SettingsStore.shared.settings.preferredPetRuntimeMode

        if let preferred {
            if preferred == .codexFollow && !isCodexAvailable() {
                activeMode = .standalone
            } else {
                activeMode = preferred
            }
        } else {
            activeMode = isCodexAvailable() ? .codexFollow : .standalone
        }
    }

    func isCodexAvailable() -> Bool {
        switch positionReader.read() {
        case .open:
            return true
        case .closed, .unavailable:
            return false
        }
    }

    // MARK: - Mode switching

    func switchToCodexFollow() {
        guard isCodexAvailable() else { return }
        clearAutoDegradeFlag()
        SettingsStore.shared.settings.preferredPetRuntimeMode = .codexFollow
        SettingsStore.shared.save()
        applyMode(.codexFollow)
    }

    func switchToStandalone() {
        clearAutoDegradeFlag()
        SettingsStore.shared.settings.preferredPetRuntimeMode = .standalone
        SettingsStore.shared.settings.showStandalonePet = true
        SettingsStore.shared.settings.petClickThrough = false
        SettingsStore.shared.save()
        applyMode(.standalone)
    }

    func clearPreference() {
        clearAutoDegradeFlag()
        SettingsStore.shared.settings.preferredPetRuntimeMode = nil
        SettingsStore.shared.save()
        resolveActiveMode()
        applyMode(activeMode)
    }

    private func clearAutoDegradeFlag() {
        standaloneWasAutoDegraded = false
        SettingsStore.shared.settings.standaloneWasAutoDegraded = false
        SettingsStore.shared.save()
    }

    private func applyMode(_ mode: PetRuntimeMode) {
        if activeMode == mode {
            enforceModeSideEffects(for: mode)
            return
        }
        activeMode = mode

        enforceModeSideEffects(for: mode)

        NotificationCenter.default.post(name: .petRuntimeModeChanged, object: mode)
    }

    func activateCurrentMode() {
        enforceModeSideEffects(for: activeMode)
        NotificationCenter.default.post(name: .petRuntimeModeChanged, object: activeMode)
    }

    private func enforceModeSideEffects(for mode: PetRuntimeMode) {
        switch mode {
        case .codexFollow:
            hideStandalonePet()
        case .standalone:
            showStandalonePet()
        }
    }

    // MARK: - Standalone pet management

    func showStandalonePet() {
        guard SettingsStore.shared.settings.showStandalonePet else { return }

        if standalonePetWindow == nil {
            let petId = currentStandalonePetId()
            standalonePetWindow = StandalonePetWindow(petId: petId)
        }

        standalonePetWindow?.reloadSettings()
        standalonePetWindow?.orderFront(nil)
    }

    func hideStandalonePet() {
        standalonePetWindow?.orderOut(nil)
    }

    private func currentStandalonePetId() -> String {
        if let id = SettingsStore.shared.settings.activeStandalonePetId {
            return id
        }
        if let first = LocalPetManager.shared.pets.first {
            return first.id
        }
        return "builtin-default"
    }

    func setStandalonePetId(_ petId: String) {
        SettingsStore.shared.settings.activeStandalonePetId = petId
        SettingsStore.shared.save()

        if activeMode == .standalone {
            standalonePetWindow?.orderOut(nil)
            standalonePetWindow = StandalonePetWindow(petId: petId)
            standalonePetWindow?.orderFront(nil)
        }

        NotificationCenter.default.post(name: .petRuntimeStandalonePetChanged, object: petId)
    }

    // MARK: - Codex availability polling

    private var lastCodexAvailable = false

    private func startCodexAvailabilityPolling() {
        lastCodexAvailable = isCodexAvailable()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkCodexAvailability()
        }
    }

    private func checkCodexAvailability() {
        let nowAvailable = isCodexAvailable()
        defer { lastCodexAvailable = nowAvailable }

        let preferred = SettingsStore.shared.settings.preferredPetRuntimeMode

        if nowAvailable && !lastCodexAvailable {
            // Codex just became available — auto-restore only if auto-degraded
            if preferred == .codexFollow
                && activeMode != .codexFollow
                && standaloneWasAutoDegraded
            {
                standaloneWasAutoDegraded = false
                SettingsStore.shared.settings.standaloneWasAutoDegraded = false
                SettingsStore.shared.save()
                applyMode(.codexFollow)
                NotificationCenter.default.post(
                    name: .petRuntimeModeRestored,
                    object: "Codex 已恢复，已切回跟随 Codex 宠物模式"
                )
            }
        } else if !nowAvailable && lastCodexAvailable {
            // Codex just became unavailable — auto-degrade
            if activeMode == .codexFollow {
                standaloneWasAutoDegraded = true
                SettingsStore.shared.settings.standaloneWasAutoDegraded = true
                SettingsStore.shared.save()
                applyMode(.standalone)
                NotificationCenter.default.post(
                    name: .petRuntimeModeDegraded,
                    object: "Codex 当前不可用，已切换为独立桌面宠物"
                )
            }
        }
    }

    @objc private func handleSettingsChanged() {
        // Refresh standalone pet visibility based on settings
        if activeMode == .standalone {
            if SettingsStore.shared.settings.showStandalonePet {
                showStandalonePet()
            } else {
                hideStandalonePet()
            }
        }
    }
}

import AppKit

final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!

    override init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = ""
            if let img = NSImage(named: "MenuBarIconTemplate") {
                img.isTemplate = true
                button.image = img
            } else if let img = NSImage(systemSymbolName: "bird", accessibilityDescription: "Nest") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "N"
            }
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu(title: "CodexPet Nest")
        menu.delegate = self
        let codexAvailable = PetRuntimeCoordinator.shared.isCodexAvailable()
        let isStandalone = PetRuntimeCoordinator.shared.activeMode == .standalone

        // Show/Hide nest
        let showHideTitle = SettingsStore.shared.settings.showNest
            ? l("menu.hide_nest")
            : l("menu.show_nest")
        menu.addItem(NSMenuItem(title: showHideTitle,
                                 action: #selector(MenuActionTarget.toggleShowNest),
                                 keyEquivalent: ""))

        // Show/Hide pet
        if isStandalone {
            let showPet = SettingsStore.shared.settings.showStandalonePet
            let petTitle = showPet ? "隐藏宠物" : "显示宠物"
            menu.addItem(NSMenuItem(title: petTitle,
                                     action: #selector(MenuActionTarget.toggleShowStandalonePet),
                                     keyEquivalent: ""))
        } else {
            let item = NSMenuItem(title: "显示/隐藏宠物", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // Pet mode submenu
        let modeItem = NSMenuItem(title: "宠物模式", action: nil, keyEquivalent: "")
        let modeMenu = NSMenu(title: "")
        let codexItem = NSMenuItem(
            title: codexAvailable ? "跟随 Codex 宠物" : "跟随 Codex 宠物（Codex 未运行）",
            action: codexAvailable ? #selector(MenuActionTarget.switchToCodexFollow) : nil,
            keyEquivalent: ""
        )
        codexItem.state = isStandalone ? .off : .on
        codexItem.isEnabled = codexAvailable
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
            action: isStandalone ? #selector(MenuActionTarget.toggleFreeRoam) : nil,
            keyEquivalent: ""
        )
        roamItem.state = SettingsStore.shared.settings.freeRoamEnabled ? .on : .off
        roamItem.isEnabled = isStandalone
        menu.addItem(roamItem)

        menu.addItem(.separator())

        menu.addItem(withTitle: l("menu.manage_pets"), action: #selector(MenuActionTarget.manageLocalPets), keyEquivalent: "m")
        menu.addItem(withTitle: l("menu.manage_nests"), action: #selector(MenuActionTarget.manageLocalNests), keyEquivalent: "")

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: l("menu.open_marketplace"),
                                 action: #selector(MenuActionTarget.browsePets),
                                 keyEquivalent: ","))

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: l("menu.open_website"),
                                 action: #selector(MenuActionTarget.openWebsite),
                                 keyEquivalent: ""))
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: l("menu.check_updates"),
                                 action: #selector(MenuActionTarget.checkForUpdates),
                                 keyEquivalent: ""))
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: l("menu.quit"),
                                 action: #selector(NSApplication.terminate(_:)),
                                 keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        assignActionTargets(in: menu)
        statusItem.menu = menu
    }

    private func assignActionTargets(in menu: NSMenu) {
        for item in menu.items {
            if let submenu = item.submenu {
                assignActionTargets(in: submenu)
            }
            if item.action != nil && item.action != #selector(NSApplication.terminate(_:)) {
                item.target = MenuActionTarget.shared
            }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
}

@objc final class MenuActionTarget: NSObject {
    static let shared = MenuActionTarget()
}

extension MenuActionTarget {
    @objc func toggleShowNest() {
        let newState = !SettingsStore.shared.settings.showNest
        SettingsStore.shared.settings.showNest = newState
        SettingsStore.shared.save()
        
        NotificationCenter.default.post(name: .toggleNestVisibility, object: newState)
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }

    @objc func checkForUpdates() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.checkForUpdatesManually(nil)
        }
    }

    @MainActor
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc func manageLocalPets() {
        MainWindowController.shared.show()
        NotificationCenter.default.post(name: .sidebarSelectionChanged, object: nil, userInfo: ["item": SidebarItem(id: "myPets", title: l("menu.manage_pets"), iconName: "pawprint", isCategory: false)])
    }

    @objc func manageLocalNests() {
        MainWindowController.shared.show()
        NotificationCenter.default.post(name: .sidebarSelectionChanged, object: nil, userInfo: ["item": SidebarItem(id: "nestManager", title: l("menu.manage_nests"), iconName: "house", isCategory: false)])
    }

    @objc func browsePets() {
        MainWindowController.shared.show()
        NotificationCenter.default.post(name: .sidebarSelectionChanged, object: nil, userInfo: ["item": SidebarItem(id: "marketplace", title: l("menu.open_marketplace"), iconName: "bag", isCategory: false)])
    }

    @objc func browseNests() {
        OnlineNestMarketplaceWindowController.shared.show()
    }

    @objc func uploadPet() {
        NSWorkspace.shared.open(URL(string: "https://codexpet.xyz/submit")!)
    }

    @objc func openWebsite() {
        NSWorkspace.shared.open(URL(string: "https://codexpet.xyz")!)
    }

    @objc func toggleUsage() {
        let id = "usage"
        if SettingsStore.shared.settings.enabledWidgets.contains(id) {
            SettingsStore.shared.settings.enabledWidgets.removeAll { $0 == id }
        } else {
            SettingsStore.shared.settings.enabledWidgets.append(id)
        }
        SettingsStore.shared.save()
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }

    @objc func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    @objc func openNest() {
        if let window = NSApp.windows.first(where: { $0 is NestOverlayWindow }) {
            window.orderFront(nil)
        }
    }

    @objc func togglePomodoro() {
        NotificationCenter.default.post(name: .togglePomodoro, object: nil)
    }

    @objc func setCountdown() {
        NotificationCenter.default.post(name: .setCountdown, object: nil)
    }

    @objc func hideNest() {
        SettingsStore.shared.settings.showNest = false
        SettingsStore.shared.save()
        for window in NSApp.windows where window is NestOverlayWindow {
            window.orderOut(nil)
        }
    }

    @objc func activateClassicNest() {
        print("[MenuActionTarget] activateClassicNest called")
        SettingsStore.shared.settings.activeNestId = "default"
        SettingsStore.shared.save()
        
        NotificationCenter.default.post(name: .activeNestChanged, object: nil)
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
        NotificationCenter.default.post(name: .nestSizeChanged, object: nil)
    }

    @objc func configureQuickActions() {
        guard let nest = LocalNestManager.shared.getActiveNest() else { return }
        QuickActionsConfigWindowController.shared.show(for: nest.id)
    }

    @objc func activateOrbitNest() {
        print("[MenuActionTarget] activateOrbitNest called")
        SettingsStore.shared.settings.activeNestId = "capacity-orbit-nest"
        SettingsStore.shared.settings.showNest = true
        SettingsStore.shared.save()

        NotificationCenter.default.post(name: .activeNestChanged, object: nil)
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
        NotificationCenter.default.post(name: .nestSizeChanged, object: nil)

        if !SettingsStore.shared.settings.showNest {
            for w in NSApp.windows where w is NestOverlayWindow { w.orderFront(nil) }
        }
    }

    // MARK: - Pet runtime mode actions

    @objc func switchToCodexFollow() {
        PetRuntimeCoordinator.shared.switchToCodexFollow()
        refreshAllMenus()
    }

    @objc func switchToStandalone() {
        PetRuntimeCoordinator.shared.switchToStandalone()
        refreshAllMenus()
    }

    @objc func toggleFreeRoam() {
        let newValue = !SettingsStore.shared.settings.freeRoamEnabled
        SettingsStore.shared.settings.freeRoamEnabled = newValue
        SettingsStore.shared.save()

        // Refresh standalone pet window behavior
        for w in NSApp.windows where w is StandalonePetWindow {
            (w as? StandalonePetWindow)?.reloadBehavior()
        }

        NotificationCenter.default.post(name: .settingsChanged, object: nil)
        refreshAllMenus()
    }

    @objc func toggleShowStandalonePet() {
        let newValue = !SettingsStore.shared.settings.showStandalonePet
        SettingsStore.shared.settings.showStandalonePet = newValue
        SettingsStore.shared.save()

        if newValue {
            PetRuntimeCoordinator.shared.showStandalonePet()
        } else {
            PetRuntimeCoordinator.shared.hideStandalonePet()
        }

        NotificationCenter.default.post(name: .settingsChanged, object: nil)
        refreshAllMenus()
    }

    @objc func togglePetAlwaysOnTop() {
        let newValue = !SettingsStore.shared.settings.petAlwaysOnTop
        SettingsStore.shared.settings.petAlwaysOnTop = newValue
        SettingsStore.shared.save()

        for w in NSApp.windows where w is StandalonePetWindow {
            (w as? StandalonePetWindow)?.reloadSettings()
        }

        NotificationCenter.default.post(name: .settingsChanged, object: nil)
        refreshAllMenus()
    }

    @objc func togglePetClickThrough() {
        let newValue = !SettingsStore.shared.settings.petClickThrough
        SettingsStore.shared.settings.petClickThrough = newValue
        SettingsStore.shared.save()

        for w in NSApp.windows where w is StandalonePetWindow {
            (w as? StandalonePetWindow)?.reloadSettings()
        }

        NotificationCenter.default.post(name: .settingsChanged, object: nil)
        refreshAllMenus()
    }

    private func refreshAllMenus() {
        (NSApp.delegate as? AppDelegate)?.rebuildMenuBarMenu()
    }
}

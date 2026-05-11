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

        let showHideTitle = SettingsStore.shared.settings.showNest
            ? "Hide Nest"
            : "Show Nest"
        menu.addItem(NSMenuItem(title: showHideTitle,
                                 action: #selector(MenuActionTarget.toggleShowNest),
                                 keyEquivalent: ""))
        menu.addItem(withTitle: "Manage Pets...", action: #selector(MenuActionTarget.manageLocalPets), keyEquivalent: "m")
        menu.addItem(withTitle: "Manage Nests...", action: #selector(MenuActionTarget.manageLocalNests), keyEquivalent: "")

        if QuickActionConfigStore.shared.activeNestHasComponent() {
            menu.addItem(withTitle: "Configure Quick Actions...", action: #selector(MenuActionTarget.configureQuickActions), keyEquivalent: "")
        }
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Open Pets Marketplace...",
                                 action: #selector(MenuActionTarget.browsePets),
                                 keyEquivalent: ","))
        
        // let nestMarketItem = NSMenuItem(title: "Online Nest Marketplace (Coming Soon)",
        //                                  action: #selector(MenuActionTarget.browseNests),
        //                                  keyEquivalent: "")
        // nestMarketItem.isEnabled = false
        // menu.addItem(nestMarketItem)

        menu.addItem(.separator())
        
        menu.addItem(NSMenuItem(title: "Open codexpet.xyz",
                                 action: #selector(MenuActionTarget.openWebsite),
                                 keyEquivalent: ""))
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Check for Updates...",
                                 action: #selector(MenuActionTarget.checkForUpdates),
                                 keyEquivalent: ""))
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit CodexPet Nest",
                                 action: #selector(NSApplication.terminate(_:)),
                                 keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        menu.items.forEach { 
            if $0.action != #selector(NSApplication.terminate(_:)) {
                $0.target = MenuActionTarget.shared 
            }
        }
        statusItem.menu = menu
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
        let current = "0.1.0"
        Task {
            do {
                let version = try await CodexPetAPI.shared.getVersion()
                guard version.latestVersion != current else {
                    await showAlert(title: "Up to Date", message: "CodexPet Nest \(current) is the latest version.")
                    return
                }
                await showAlert(
                    title: "Update Available",
                    message: "Version \(version.latestVersion) is available.\n\nDownload from:\n\(version.downloadUrl ?? "https://codexpet.xyz")"
                )
            } catch {
                await showAlert(title: "Update Check Failed", message: error.localizedDescription)
            }
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
        LocalPetManagerWindowController.shared.show()
    }

    @objc func manageLocalNests() {
        LocalNestManagerWindowController.shared.show()
    }

    @objc func browsePets() {
        OnlinePetMarketplaceWindowController.shared.show()
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
}

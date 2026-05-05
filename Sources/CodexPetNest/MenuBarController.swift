import AppKit

final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!

    override init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = ""
            if let img = NSImage(systemSymbolName: "bird", accessibilityDescription: "Nest") {
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
            ? NSLocalizedString("menu.hideNest", comment: "")
            : NSLocalizedString("menu.showNest", comment: "")
        menu.addItem(NSMenuItem(title: showHideTitle,
                                 action: #selector(MenuActionTarget.shared.toggleShowNest),
                                 keyEquivalent: ""))
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.petMarket", comment: ""),
                                 action: #selector(MenuActionTarget.shared.browsePets),
                                 keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.nestMarket", comment: ""),
                                 action: #selector(MenuActionTarget.shared.browseNests),
                                 keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.uploadPet", comment: ""),
                                 action: #selector(MenuActionTarget.shared.uploadPet),
                                 keyEquivalent: ""))
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.settings", comment: ""),
                                 action: #selector(MenuActionTarget.shared.openSettings),
                                 keyEquivalent: ","))
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.quit", comment: ""),
                                 action: #selector(NSApplication.terminate(_:)),
                                 keyEquivalent: "q"))

        menu.items.forEach { $0.target = MenuActionTarget.shared }
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
}

extension MenuActionTarget {
    @objc func toggleShowNest() {
        if SettingsStore.shared.settings.showNest {
            SettingsStore.shared.settings.showNest = false
            SettingsStore.shared.save()
            for w in NSApp.windows where w is NestOverlayWindow { w.orderOut(nil) }
        } else {
            SettingsStore.shared.settings.showNest = true
            SettingsStore.shared.save()
            for w in NSApp.windows where w is NestOverlayWindow { w.orderFront(nil) }
        }
    }
}

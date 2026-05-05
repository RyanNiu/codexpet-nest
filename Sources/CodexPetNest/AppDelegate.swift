import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController!
    private var nestWindow: NestOverlayWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        menuBarController = MenuBarController()
        nestWindow = NestOverlayWindow()

        if SettingsStore.shared.settings.showNest {
            nestWindow.orderFront(nil)
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleOpenSettings),
            name: .openSettings, object: nil
        )

        // Task { await checkVersionOnLaunch() }
    }

    private func checkVersionOnLaunch() async {
        let current = "0.1.0"
        do {
            let version = try await CodexPetAPI.shared.getVersion()
            guard version.latestVersion != current else { return }

            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = "Update Available"
                alert.informativeText = "CodexPet Nest \(version.latestVersion) is available (you have \(current)).\n\nDownload from:\n\(version.downloadUrl ?? "https://codexpet.xyz")"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Open Download")
                alert.addButton(withTitle: "Later")
                if alert.runModal() == .alertFirstButtonReturn {
                    if let urlStr = version.downloadUrl, let url = URL(string: urlStr) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } catch {
            // Silently ignore version check failures on launch
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func handleOpenSettings() {
        SettingsWindowController.shared.show()
    }
}

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let vc = SettingsViewController()
        let window = NSWindow(contentViewController: vc)
        window.title = "CodexPet Nest Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 360, height: 320))
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class SettingsViewController: NSViewController {
    private let showNestCheck = NSButton(checkboxWithTitle: "Show nest", target: nil, action: nil)
    private let positionPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let themePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let focusField = NSTextField(frame: .zero)
    private let breakField = NSTextField(frame: .zero)

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 320))

        let yStart: CGFloat = 280
        let rowH: CGFloat = 32

        func label(_ text: String, y: CGFloat) {
            let l = NSTextField(labelWithString: text)
            l.frame = NSRect(x: 20, y: y, width: 140, height: 20)
            view.addSubview(l)
        }

        label("Show Nest", y: yStart)
        showNestCheck.state = SettingsStore.shared.settings.showNest ? .on : .off
        showNestCheck.frame = NSRect(x: 170, y: yStart, width: 160, height: 20)
        showNestCheck.target = self
        showNestCheck.action = #selector(saveSettings)
        view.addSubview(showNestCheck)

        label("Nest Position", y: yStart - rowH)
        positionPopup.frame = NSRect(x: 170, y: yStart - rowH - 2, width: 160, height: 22)
        positionPopup.addItems(withTitles: ["bottom", "left", "right", "auto"])
        positionPopup.selectItem(withTitle: SettingsStore.shared.settings.nestPosition)
        positionPopup.target = self
        positionPopup.action = #selector(saveSettings)
        view.addSubview(positionPopup)

        label("Theme", y: yStart - rowH * 2)
        themePopup.frame = NSRect(x: 170, y: yStart - rowH * 2 - 2, width: 160, height: 22)
        themePopup.addItems(withTitles: ["default"])
        themePopup.target = self
        themePopup.action = #selector(saveSettings)
        view.addSubview(themePopup)

        label("Focus (min)", y: yStart - rowH * 3)
        focusField.frame = NSRect(x: 170, y: yStart - rowH * 3, width: 80, height: 22)
        focusField.stringValue = String(SettingsStore.shared.settings.pomodoro.focusMinutes)
        focusField.target = self
        focusField.action = #selector(saveSettings)
        view.addSubview(focusField)

        label("Break (min)", y: yStart - rowH * 4)
        breakField.frame = NSRect(x: 170, y: yStart - rowH * 4, width: 80, height: 22)
        breakField.stringValue = String(SettingsStore.shared.settings.pomodoro.breakMinutes)
        breakField.target = self
        breakField.action = #selector(saveSettings)
        view.addSubview(breakField)
    }

    @objc private func saveSettings() {
        let p = SettingsStore.shared.settings.pomodoro
        let showWasOn = SettingsStore.shared.settings.showNest
        let showIsOn = showNestCheck.state == .on
        
        SettingsStore.shared.settings.showNest = showIsOn
        SettingsStore.shared.settings.nestPosition = positionPopup.selectedItem?.title ?? "bottom"
        SettingsStore.shared.settings.pomodoro.focusMinutes = Int(focusField.stringValue) ?? p.focusMinutes
        SettingsStore.shared.settings.pomodoro.breakMinutes = Int(breakField.stringValue) ?? p.breakMinutes
        SettingsStore.shared.save()
        
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
        
        if showWasOn != showIsOn {
            NotificationCenter.default.post(name: .toggleNestVisibility, object: showIsOn)
        }
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("CodexPetNest.settingsChanged")
    static let toggleNestVisibility = Notification.Name("CodexPetNest.toggleNestVisibility")
}

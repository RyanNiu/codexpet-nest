import AppKit
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController!
    private var nestWindow: NestOverlayWindow!
    private var mainWindowController: MainWindowController!
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if ProcessInfo.processInfo.environment["CODEXPET_VALIDATE_NESTS_V11"] == "1" {
            Task {
                let defaultPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent("docs/test-fixtures/nests-v1.1")
                let pathStr = ProcessInfo.processInfo.environment["CODEXPET_NEST_FIXTURES_DIR"] ?? defaultPath.path
                let fixturesDir = URL(fileURLWithPath: pathStr)

                let success = await DevNestPackageValidator.runValidation(fixturesDir: fixturesDir)
                exit(success ? 0 : 1)
            }
            return
        }
        #endif

        disableAutomaticUpdates()

        NSApp.setActivationPolicy(.accessory)

        menuBarController = MenuBarController()
        nestWindow = NestOverlayWindow()
        mainWindowController = MainWindowController.shared

        // Install/Sync built-in nests
        BuiltInNestInstaller.shared.installIfNeeded()

        if SettingsStore.shared.settings.showNest {
            nestWindow.orderFront(nil)
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleOpenSettings),
            name: .openSettings, object: nil
        )

        // Register custom URL scheme handler
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        if let installURL = ProcessInfo.processInfo.environment["CODEXPET_INSTALL_URL"],
           let url = URL(string: installURL) {
            handleInstallURL(url)
        }

        #if !DEBUG
        AppAnalytics.shared.trackLaunch()
        #endif
    }

    func checkForUpdatesManually(_ sender: Any?) {
        if updaterController == nil {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        }

        guard let updaterController else { return }
        updaterController.updater.automaticallyChecksForUpdates = false
        updaterController.updater.automaticallyDownloadsUpdates = false
        updaterController.checkForUpdates(sender)
    }

    private func disableAutomaticUpdates() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "SUEnableAutomaticChecks")
        defaults.set(false, forKey: "SUAutomaticallyUpdate")
        defaults.set(false, forKey: "SUAllowsAutomaticUpdates")
        defaults.synchronize()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleInstallURL(url)
        }
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            return
        }
        handleInstallURL(url)
    }

    private func handleInstallURL(_ url: URL) {
        guard url.scheme == "codexpetnest" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        let action = components.queryItems?.first(where: { $0.name == "action" })?.value

        guard let action else {
            // No ?action= — backward compat: delegate to token-based nest install flow
            Task {
                await NestInstallService.shared.handleInstallURL(url)
            }
            return
        }

        switch action {
        case "open":
            Task { await handleOpenAction() }
        case "install-pet":
            Task { await handleInstallPetAction(components) }
        case "open-nest":
            Task { await handleOpenNestAction(components) }
        default:
            Task { @MainActor in showUnknownActionAlert(action) }
        }
    }

    // MARK: - Action Handlers

    private func handleOpenAction() async {
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
            SettingsStore.shared.settings.showNest = true
            SettingsStore.shared.save()
            NotificationCenter.default.post(name: .toggleNestVisibility, object: true)
            
            if let window = NSApp.windows.first(where: { $0 is NestOverlayWindow }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func handleInstallPetAction(_ components: URLComponents) async {
        let params = components.queryItems ?? []

        guard let slug = params.first(where: { $0.name == "slug" })?.value, !slug.isEmpty else {
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = "Invalid Link"
                alert.informativeText = "The install link is missing the pet id."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return
        }

        do {
            let prepared = try await PackageManager.shared.preparePetInstall(id: slug)
            let name = params.first(where: { $0.name == "name" })?.value
                ?? prepared.manifest.name

            if PackageManager.shared.isPetInstalled(id: prepared.manifest.id) {
                let overwrite = await MainActor.run {
                    PackageUI.showOverwritePrompt(name: prepared.manifest.name, id: prepared.manifest.id)
                }
                guard overwrite else { return }
            }

            try await PackageManager.shared.installPreparedPet(prepared)
            await MainActor.run {
                PackageUI.showInstallSuccess(name: name)
            }
        } catch {
            await MainActor.run {
                PackageUI.showInstallError(error)
            }
        }
    }

    private func handleOpenNestAction(_ components: URLComponents) async {
        let params = components.queryItems ?? []

        guard let id = params.first(where: { $0.name == "id" })?.value, !id.isEmpty else {
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = "Invalid Link"
                alert.informativeText = "The nest link is missing the id parameter."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return
        }

        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
            LocalNestManager.shared.applyNest(id: id)
            if let window = NSApp.windows.first(where: { $0 is NestOverlayWindow }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    @MainActor
    private func showUnknownActionAlert(_ action: String) {
        let alert = NSAlert()
        alert.messageText = "Unknown Action"
        alert.informativeText = "The link action \"\(action)\" is not recognized."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // Manual check logic is now handled by Sparkle
    @available(*, deprecated, message: "Use Sparkle updaterController instead")
    private func checkVersionOnLaunch() async {
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func handleOpenSettings() {
        SettingsWindowController.shared.show()
    }

    var nestOverlayWindow: NestOverlayWindow? {
        NSApp.windows.first(where: { $0 is NestOverlayWindow }) as? NestOverlayWindow
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

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshUI), name: .settingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshUI), name: .toggleNestVisibility, object: nil)
    }

    @objc private func refreshUI() {
        showNestCheck.state = SettingsStore.shared.settings.showNest ? .on : .off
        positionPopup.selectItem(withTitle: SettingsStore.shared.settings.nestPosition)
        focusField.stringValue = String(SettingsStore.shared.settings.pomodoro.focusMinutes)
        breakField.stringValue = String(SettingsStore.shared.settings.pomodoro.breakMinutes)
    }

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

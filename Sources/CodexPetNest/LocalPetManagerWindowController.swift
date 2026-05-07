import AppKit
import Combine

final class LocalPetManagerWindowController: NSWindowController {
    static let shared = LocalPetManagerWindowController()

    private init() {
        let vc = LocalPetManagerViewController()
        let window = NSWindow(contentViewController: vc)
        window.title = "Manage Pets"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 420))
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        (contentViewController as? LocalPetManagerViewController)?.refresh()
    }
}

final class LocalPetManagerViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let detailView = NSView()
    private let emptyLabel = NSTextField(labelWithString: "No pets found in ~/.codex/pets/")
    
    private let nameLabel = NSTextField(labelWithString: "")
    private let idLabel = NSTextField(labelWithString: "")
    private let descLabel = NSTextField(wrappingLabelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let previewImage = NSImageView()
    
    private let openFinderBtn = NSButton(title: "Open in Finder", target: nil, action: nil)
    private let uninstallBtn = NSButton(title: "Delete Pet", target: nil, action: nil)
    private let browseMarketplaceBtn = NSButton(title: "Add / Browse Pets", target: nil, action: nil)
    private let installBtn = NSButton(title: "Install Local Pet ZIP...", target: nil, action: nil)
    private let openCodexSettingsBtn = NSButton(title: "Open Codex Settings", target: nil, action: nil)
    
    private var pets: [LocalPet] = []
    private var cancellables = Set<AnyCancellable>()
    
    private let previewView = AnimatedSpritePreviewView()
    private let actionSwitcher = NSSegmentedControl()
    private var spritesheetImage: NSImage?
    private var spriteDescriptor: SpriteSheetDescriptor?


    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 420))
        
        scrollView.frame = NSRect(x: 0, y: 70, width: 220, height: 350)
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.height]
        
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("PetColumn")))
        
        scrollView.documentView = tableView
        view.addSubview(scrollView)
        
        detailView.frame = NSRect(x: 220, y: 70, width: 380, height: 350)
        detailView.autoresizingMask = [.width, .height]
        view.addSubview(detailView)
        
        setupDetailView()
        
        let bottomBar = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 70))
        bottomBar.autoresizingMask = [.width]
        view.addSubview(bottomBar)
        
        browseMarketplaceBtn.frame = NSRect(x: 20, y: 35, width: 180, height: 25)
        browseMarketplaceBtn.target = self
        browseMarketplaceBtn.action = #selector(openMarketplace)
        browseMarketplaceBtn.bezelStyle = .rounded
        browseMarketplaceBtn.contentTintColor = .systemBlue
        bottomBar.addSubview(browseMarketplaceBtn)

        installBtn.frame = NSRect(x: 20, y: 10, width: 180, height: 25)
        installBtn.target = self
        installBtn.action = #selector(installLocalZip)
        bottomBar.addSubview(installBtn)
        
        openCodexSettingsBtn.frame = NSRect(x: 400, y: 10, width: 180, height: 50)
        openCodexSettingsBtn.target = self
        openCodexSettingsBtn.action = #selector(openCodexSettings)
        openCodexSettingsBtn.bezelStyle = .rounded
        bottomBar.addSubview(openCodexSettingsBtn)
        
        emptyLabel.frame = NSRect(x: 20, y: 200, width: 180, height: 40)
        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)
        
        LocalPetManager.shared.$pets
            .receive(on: RunLoop.main)
            .sink { [weak self] newPets in
                self?.pets = newPets
                self?.tableView.reloadData()
                self?.emptyLabel.isHidden = !newPets.isEmpty
                if self?.tableView.selectedRow == -1 && !newPets.isEmpty {
                    self?.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                }
                self?.updateDetail()
            }
            .store(in: &cancellables)
    }

    private func setupDetailView() {
        nameLabel.font = .boldSystemFont(ofSize: 18)
        nameLabel.frame = NSRect(x: 20, y: 310, width: 340, height: 25)
        detailView.addSubview(nameLabel)
        
        idLabel.font = .systemFont(ofSize: 12)
        idLabel.textColor = .secondaryLabelColor
        idLabel.frame = NSRect(x: 20, y: 290, width: 340, height: 15)
        detailView.addSubview(idLabel)
        
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.frame = NSRect(x: 20, y: 270, width: 340, height: 15)
        detailView.addSubview(statusLabel)
        
        previewView.frame = NSRect(x: 20, y: 140, width: 200, height: 200)
        previewView.wantsLayer = true
        previewView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        previewView.layer?.cornerRadius = 8
        detailView.addSubview(previewView)
        
        actionSwitcher.segmentCount = 4
        actionSwitcher.setLabel("Idle", forSegment: 0)
        actionSwitcher.setLabel("Walk", forSegment: 1)
        actionSwitcher.setLabel("Sleep", forSegment: 2)
        actionSwitcher.setLabel("Action", forSegment: 3)
        actionSwitcher.selectedSegment = 0
        actionSwitcher.target = self
        actionSwitcher.action = #selector(actionChanged)
        actionSwitcher.frame = NSRect(x: 20, y: 110, width: 340, height: 25)
        detailView.addSubview(actionSwitcher)
        
        descLabel.frame = NSRect(x: 20, y: 55, width: 340, height: 50)
        detailView.addSubview(descLabel)

        
        openFinderBtn.frame = NSRect(x: 20, y: 20, width: 120, height: 30)
        openFinderBtn.target = self
        openFinderBtn.action = #selector(openInFinder)
        detailView.addSubview(openFinderBtn)
        
        uninstallBtn.frame = NSRect(x: 150, y: 20, width: 100, height: 30)
        uninstallBtn.target = self
        uninstallBtn.action = #selector(uninstallPet)
        detailView.addSubview(uninstallBtn)
    }

    func refresh() {
        LocalPetManager.shared.refresh()
    }

    private func updateDetail() {
        let row = tableView.selectedRow
        guard row >= 0, row < pets.count else {
            detailView.isHidden = true
            return
        }
        detailView.isHidden = false
        let pet = pets[row]
        
        nameLabel.stringValue = pet.displayName
        idLabel.stringValue = "ID: \(pet.id)"
        descLabel.stringValue = pet.description
        
        if pet.isCurrent {
            statusLabel.stringValue = "● Currently active in Codex"
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.stringValue = "Inactive"
            statusLabel.textColor = .secondaryLabelColor
        }
        
        // Load preview
        spritesheetImage = nil
        spriteDescriptor = nil
        
        let sheetPath = URL(fileURLWithPath: pet.path).appendingPathComponent(pet.spritesheetPath).path
        if let img = NSImage(contentsOfFile: sheetPath) {
            self.spritesheetImage = img
            if let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                // Convert manifest to [String: Any] for detectDescriptor
                var manifestDict: [String: Any] = [:]
                if let m = pet.manifest {
                    if let fw = m.frameWidth { manifestDict["frameWidth"] = fw }
                    if let fh = m.frameHeight { manifestDict["frameHeight"] = fh }
                    if let fs = m.frameSize { manifestDict["frameSize"] = fs }
                    if let c = m.columns { manifestDict["columns"] = c }
                    if let r = m.rows { manifestDict["rows"] = r }
                }
                self.spriteDescriptor = PetSpriteSheetRenderer.shared.detectDescriptor(cgImage: cg, manifest: manifestDict)
                PetSpriteSheetRenderer.shared.debugExportContactSheet(cgImage: cg, desc: self.spriteDescriptor!, petId: pet.id)
            }
            updateAnimation()
        } else {
            previewView.setFrames([])
        }
        
        uninstallBtn.title = pet.isAppManaged ? "Delete Pet" : "Remove Folder"
    }
    
    @objc private func actionChanged() {
        updateAnimation()
    }
    
    private func updateAnimation() {
        guard let image = spritesheetImage, let desc = spriteDescriptor else { return }
        let row = tableView.selectedRow
        if row < 0 || row >= pets.count { return }
        let pet = pets[row]
        
        let actions = ["idle", "walk", "sleep", "action"]
        let seg = actionSwitcher.selectedSegment
        let actionName = seg < actions.count ? actions[seg] : "idle"
        
        if let cached = PetImageCache.shared.getAnimation(for: pet.id, action: actionName) {
            previewView.setFrames(cached)
            return
        }
        
        let frames = PetSpriteSheetRenderer.shared.extractAnimationFrames(from: image, action: actionName, desc: desc)
        if !frames.isEmpty {
            PetImageCache.shared.setAnimation(frames, for: pet.id, action: actionName)
        }
        previewView.setFrames(frames)
    }


    // MARK: - Actions

    @objc private func openMarketplace() {
        OnlinePetMarketplaceWindowController.shared.show()
    }

    @objc private func openInFinder() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        LocalPetManager.shared.openInFinder(pet: pets[row])
    }

    @objc private func uninstallPet() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        let pet = pets[row]
        
        if pet.isCurrent {
            let alert = NSAlert()
            alert.messageText = "Cannot Uninstall Active Pet"
            alert.informativeText = "'\(pet.displayName)' is currently active in Codex. Codex opened Settings, please manually go to Appearance / Personalization / Pets and switch to another pet first."
            alert.addButton(withTitle: "Open Codex Settings")
            alert.addButton(withTitle: "OK")
            if alert.runModal() == .alertFirstButtonReturn {
                openCodexSettings()
            }
            return
        }

        let alert = NSAlert()
        alert.messageText = "Uninstall Pet?"
        alert.informativeText = "Are you sure you want to remove '\(pet.displayName)' (\(pet.id))?\n\nPath: \(pet.path)"
        if !pet.isAppManaged {
            alert.messageText = "Confirm Deleting Local Pet"
            alert.informativeText += "\n\nWarning: This pet was NOT installed by CodexPet Nest. Deleting it will permanently remove the folder from your system."
        }
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try LocalPetManager.shared.uninstallPet(pet)
            } catch {
                let errAlert = NSAlert(error: error)
                errAlert.runModal()
            }
        }
    }

    @objc private func installLocalZip() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            
            Task {
                do {
                    try await PackageManager.shared.installLocalPet(zipURL: url)
                    await MainActor.run {
                        let successAlert = NSAlert()
                        successAlert.messageText = "Pet Installed"
                        successAlert.informativeText = "Pet installed. Codex opened Settings. Please choose Appearance / Personalization / Pets and choose this pet."
                        successAlert.addButton(withTitle: "Open Codex Settings")
                        successAlert.addButton(withTitle: "OK")
                        if successAlert.runModal() == .alertFirstButtonReturn {
                            self?.openCodexSettings()
                        }
                    }
                } catch {
                    await MainActor.run {
                        let errAlert = NSAlert(error: error)
                        errAlert.runModal()
                    }
                }
            }
        }
    }

    @objc private func openCodexSettings() {
        // Try priority routes
        let routes = [
            "codex://settings/personalization",
            "codex://settings/general-settings"
        ]
        
        for route in routes {
            if let url = URL(string: route), NSWorkspace.shared.open(url) {
                return
            }
        }
        
        // Fallback to app itself
        let appPath = "/Applications/Codex.app"
        if FileManager.default.fileExists(atPath: appPath) {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: appPath), configuration: NSWorkspace.OpenConfiguration())
        } else {
            let alert = NSAlert()
            alert.messageText = "Could not open Codex"
            alert.informativeText = "Codex.app was not found in /Applications."
            alert.runModal()
        }
    }

    // MARK: - NSTableView

    func numberOfRows(in tableView: NSTableView) -> Int {
        pets.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let pet = pets[row]
        let identifier = NSUserInterfaceItemIdentifier("PetCell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier
            
            let imgView = NSImageView()
            imgView.imageScaling = .scaleProportionallyUpOrDown
            imgView.frame = NSRect(x: 5, y: 2, width: 40, height: 40)
            imgView.wantsLayer = true
            imgView.layer?.cornerRadius = 4
            imgView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.05).cgColor
            cell?.addSubview(imgView)
            cell?.imageView = imgView
            
            let textField = NSTextField(labelWithString: "")
            textField.font = .systemFont(ofSize: 13, weight: .medium)
            textField.frame = NSRect(x: 50, y: 12, width: 160, height: 20)
            cell?.addSubview(textField)
            cell?.textField = textField
        }
        
        var display = pet.displayName
        if pet.isCurrent { display += " (Active)" }
        cell?.textField?.stringValue = display
        cell?.textField?.textColor = pet.isCurrent ? .systemGreen : .labelColor
        
        // Thumbnail
        cell?.imageView?.image = nil
        if let cached = PetImageCache.shared.getThumbnail(for: pet.id) {
            cell?.imageView?.image = cached
        } else {
            let sheetPath = URL(fileURLWithPath: pet.path).appendingPathComponent(pet.spritesheetPath).path
            if let img = NSImage(contentsOfFile: sheetPath) {
                if let thumb = PetSpriteSheetRenderer.shared.extractFirstFrame(from: img, petId: pet.id) {
                    PetImageCache.shared.setThumbnail(thumb, for: pet.id)
                    cell?.imageView?.image = thumb
                }
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 44
    }


    func tableViewSelectionDidChange(_ notification: Notification) {
        updateDetail()
    }
}

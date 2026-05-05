import AppKit
import Combine

final class LocalPetManagerWindowController: NSWindowController {
    static let shared = LocalPetManagerWindowController()

    private init() {
        let vc = LocalPetManagerViewController()
        let window = NSWindow(contentViewController: vc)
        window.title = "Manage Local Pets"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 400))
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
    private let uninstallBtn = NSButton(title: "Uninstall", target: nil, action: nil)
    private let installBtn = NSButton(title: "Install Local Pet ZIP...", target: nil, action: nil)
    private let openCodexSettingsBtn = NSButton(title: "Open Codex Settings", target: nil, action: nil)
    
    private var pets: [LocalPet] = []
    private var cancellables = Set<AnyCancellable>()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        
        scrollView.frame = NSRect(x: 0, y: 50, width: 220, height: 350)
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.height]
        
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("PetColumn")))
        
        scrollView.documentView = tableView
        view.addSubview(scrollView)
        
        detailView.frame = NSRect(x: 220, y: 50, width: 380, height: 350)
        detailView.autoresizingMask = [.width, .height]
        view.addSubview(detailView)
        
        setupDetailView()
        
        let bottomBar = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 50))
        bottomBar.autoresizingMask = [.width]
        view.addSubview(bottomBar)
        
        installBtn.frame = NSRect(x: 20, y: 10, width: 180, height: 30)
        installBtn.target = self
        installBtn.action = #selector(installLocalZip)
        bottomBar.addSubview(installBtn)
        
        openCodexSettingsBtn.frame = NSRect(x: 400, y: 10, width: 180, height: 30)
        openCodexSettingsBtn.target = self
        openCodexSettingsBtn.action = #selector(openCodexSettings)
        openCodexSettingsBtn.bezelStyle = .rounded
        openCodexSettingsBtn.contentTintColor = .systemBlue
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
        
        previewImage.frame = NSRect(x: 20, y: 140, width: 120, height: 120)
        previewImage.imageScaling = .scaleProportionallyUpOrDown
        previewImage.wantsLayer = true
        previewImage.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        previewImage.layer?.cornerRadius = 8
        detailView.addSubview(previewImage)
        
        descLabel.frame = NSRect(x: 20, y: 60, width: 340, height: 70)
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
        if let preview = pet.preview {
            let imgURL = URL(fileURLWithPath: pet.path).appendingPathComponent(preview)
            previewImage.image = NSImage(contentsOf: imgURL)
        } else {
            previewImage.image = NSImage(systemSymbolName: "Questionmark.square", accessibilityDescription: nil)
        }
        
        uninstallBtn.title = pet.isAppManaged ? "Uninstall" : "Remove Folder"
    }

    // MARK: - Actions

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
            alert.informativeText = "'\(pet.displayName)' is currently active in Codex. Please switch to another pet in Codex Settings first, then try uninstalling again."
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
                        successAlert.informativeText = "Pet installed. In Codex, open Settings -> Appearance and choose this pet."
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
        let url = URL(string: "codex://settings/general-settings")!
        if NSWorkspace.shared.open(url) {
            // Success
        } else {
            // Fallback to /Applications/Codex.app
            let appPath = "/Applications/Codex.app"
            if FileManager.default.fileExists(atPath: appPath) {
                NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
            } else {
                let alert = NSAlert()
                alert.messageText = "Could not open Codex"
                alert.informativeText = "Codex.app was not found in /Applications."
                alert.runModal()
            }
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
            let textField = NSTextField(labelWithString: "")
            textField.identifier = NSUserInterfaceItemIdentifier("TextField")
            cell?.addSubview(textField)
            cell?.textField = textField
            textField.frame = NSRect(x: 5, y: 5, width: 210, height: 20)
        }
        
        var display = pet.displayName
        if pet.isCurrent { display += " (Active)" }
        cell?.textField?.stringValue = display
        cell?.textField?.textColor = pet.isCurrent ? .systemGreen : .labelColor
        
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateDetail()
    }
}

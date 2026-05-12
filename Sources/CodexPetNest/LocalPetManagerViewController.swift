import AppKit
import Combine

final class LocalPetManagerViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    static let shared = LocalPetManagerViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        refresh()
    }

    // Merged into LocalPetManagerViewController
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let detailView = NSView()
    private let emptyLabel = NSTextField(labelWithString: l("manage.no_pets_found"))
    
    private let nameLabel = NSTextField(labelWithString: "")
    private let idLabel = NSTextField(labelWithString: "")
    private let descLabel = NSTextField(wrappingLabelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let previewImage = NSImageView()
    
    private let openFinderBtn = NSButton(title: l("manage.open_in_finder"), target: nil, action: nil)
    private let uninstallBtn = NSButton(title: l("manage.delete_pet"), target: nil, action: nil)
    private let browseMarketplaceBtn = NSButton(title: l("manage.add_browse_pets"), target: nil, action: nil)
    private let installBtn = NSButton(title: l("manage.install_local_pet"), target: nil, action: nil)
    private let openCodexSettingsBtn = NSButton(title: l("manage.open_codex_settings"), target: nil, action: nil)
    
    private var pets: [LocalPet] = []
    private var cancellables = Set<AnyCancellable>()
    
    private let previewView = AnimatedSpritePreviewView()
    private let actionPopup = NSPopUpButton()
    private let statusBadge = NestUI.badge("", color: .secondaryLabelColor)
    private let sourceBadge = NestUI.badge("", color: .systemBlue)
    private var previewActions: [PetPreviewAction] = []
    private var spritesheetImage: NSImage?
    private var spriteDescriptor: SpriteSheetDescriptor?


    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 520))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        NestUI.panel(scrollView)
        
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 58
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.selectionHighlightStyle = .regular
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("PetColumn")))
        
        scrollView.documentView = tableView
        view.addSubview(scrollView)
        
        detailView.translatesAutoresizingMaskIntoConstraints = false
        NestUI.panel(detailView, color: .controlBackgroundColor)
        view.addSubview(detailView)
        
        setupDetailView()
        
        let bottomBar = NSStackView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 10
        bottomBar.alignment = .centerY

        browseMarketplaceBtn.target = self
        browseMarketplaceBtn.action = #selector(openMarketplace)
        NestUI.styleSecondaryButton(browseMarketplaceBtn)
        browseMarketplaceBtn.contentTintColor = .systemTeal
        bottomBar.addArrangedSubview(browseMarketplaceBtn)

        installBtn.target = self
        installBtn.action = #selector(installLocalZip)
        NestUI.stylePrimaryButton(installBtn)
        bottomBar.addArrangedSubview(installBtn)

        let spacer = NSView()
        bottomBar.addArrangedSubview(spacer)
        
        openCodexSettingsBtn.target = self
        openCodexSettingsBtn.action = #selector(openCodexSettings)
        NestUI.styleSecondaryButton(openCodexSettingsBtn)
        bottomBar.addArrangedSubview(openCodexSettingsBtn)
        view.addSubview(bottomBar)
        
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -14),
            scrollView.widthAnchor.constraint(equalToConstant: 250),

            detailView.leadingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: 16),
            detailView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            detailView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            detailView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -14),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
            bottomBar.heightAnchor.constraint(equalToConstant: 32),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            emptyLabel.widthAnchor.constraint(lessThanOrEqualTo: scrollView.widthAnchor, constant: -24)
        ])
        
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
        [nameLabel, idLabel, statusLabel, previewView, actionPopup, descLabel, openFinderBtn, uninstallBtn, statusBadge, sourceBadge].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NestUI.configureLabel(nameLabel, size: 20, weight: .bold)
        detailView.addSubview(nameLabel)
        
        NestUI.configureLabel(idLabel, size: 12, color: .secondaryLabelColor)
        detailView.addSubview(idLabel)
        
        NestUI.configureLabel(statusLabel, size: 12, color: .secondaryLabelColor)
        detailView.addSubview(statusLabel)
        detailView.addSubview(statusBadge)
        detailView.addSubview(sourceBadge)
        
        NestUI.previewSurface(previewView)
        detailView.addSubview(previewView)
        
        actionPopup.target = self
        actionPopup.action = #selector(actionChanged)
        detailView.addSubview(actionPopup)
        
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .labelColor
        descLabel.maximumNumberOfLines = 3
        detailView.addSubview(descLabel)

        openFinderBtn.target = self
        openFinderBtn.action = #selector(openInFinder)
        NestUI.styleSecondaryButton(openFinderBtn)
        detailView.addSubview(openFinderBtn)
        
        uninstallBtn.target = self
        uninstallBtn.action = #selector(uninstallPet)
        NestUI.styleSecondaryButton(uninstallBtn)
        uninstallBtn.contentTintColor = .systemRed
        detailView.addSubview(uninstallBtn)

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: detailView.topAnchor, constant: 18),
            previewView.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: 18),
            previewView.trailingAnchor.constraint(equalTo: detailView.trailingAnchor, constant: -18),
            previewView.heightAnchor.constraint(greaterThanOrEqualToConstant: 210),
            previewView.heightAnchor.constraint(equalTo: detailView.heightAnchor, multiplier: 0.48),

            actionPopup.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 10),
            actionPopup.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            actionPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),

            nameLabel.topAnchor.constraint(equalTo: actionPopup.bottomAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: 18),
            nameLabel.trailingAnchor.constraint(equalTo: detailView.trailingAnchor, constant: -18),

            idLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            idLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            idLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            statusBadge.topAnchor.constraint(equalTo: idLabel.bottomAnchor, constant: 10),
            statusBadge.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            statusBadge.heightAnchor.constraint(equalToConstant: 22),
            statusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 58),

            sourceBadge.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor),
            sourceBadge.leadingAnchor.constraint(equalTo: statusBadge.trailingAnchor, constant: 8),
            sourceBadge.heightAnchor.constraint(equalToConstant: 22),
            sourceBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 58),

            statusLabel.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: sourceBadge.trailingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            descLabel.topAnchor.constraint(equalTo: statusBadge.bottomAnchor, constant: 12),
            descLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            openFinderBtn.bottomAnchor.constraint(equalTo: detailView.bottomAnchor, constant: -18),
            openFinderBtn.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),

            uninstallBtn.centerYAnchor.constraint(equalTo: openFinderBtn.centerYAnchor),
            uninstallBtn.leadingAnchor.constraint(equalTo: openFinderBtn.trailingAnchor, constant: 10)
        ])
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
            statusLabel.stringValue = l("manage.currently_active")
            statusLabel.textColor = .systemGreen
            statusBadge.stringValue = l("manage.active")
            statusBadge.textColor = .systemGreen
            statusBadge.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.12).cgColor
        } else {
            statusLabel.stringValue = l("manage.inactive")
            statusLabel.textColor = .secondaryLabelColor
            statusBadge.stringValue = l("manage.inactive")
            statusBadge.textColor = .secondaryLabelColor
            statusBadge.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.10).cgColor
        }
        sourceBadge.stringValue = pet.isAppManaged ? "Nest" : "Local"
        sourceBadge.textColor = pet.isAppManaged ? .systemTeal : .systemBlue
        sourceBadge.layer?.backgroundColor = (sourceBadge.textColor ?? .systemBlue).withAlphaComponent(0.12).cgColor
        
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
                self.previewActions = PetSpriteSheetRenderer.shared.previewActions(for: self.spriteDescriptor!)
                
                // Rebuild popup
                actionPopup.removeAllItems()
                for action in self.previewActions {
                    actionPopup.addItem(withTitle: action.label)
                }
                actionPopup.selectItem(at: 0)
                
                PetSpriteSheetRenderer.shared.debugExportContactSheet(cgImage: cg, desc: self.spriteDescriptor!, petId: pet.id)
            }
            updateAnimation()
        } else {
            self.previewActions = []
            actionPopup.removeAllItems()
            previewView.setFrames([])
        }
        
        uninstallBtn.title = pet.isAppManaged ? l("manage.delete_pet") : l("manage.remove_folder")
    }
    
    @objc private func actionChanged() {
        updateAnimation()
    }
    
    private func updateAnimation() {
        guard let image = spritesheetImage, let desc = spriteDescriptor else { return }
        let row = tableView.selectedRow
        if row < 0 || row >= pets.count { return }
        let pet = pets[row]
        
        let index = actionPopup.indexOfSelectedItem
        guard index >= 0, index < previewActions.count else { return }
        let action = previewActions[index]
        
        if let cached = PetImageCache.shared.getAnimation(for: pet.id, action: action.id) {
            previewView.setFrames(cached)
            return
        }
        
        let frames = PetSpriteSheetRenderer.shared.extractAnimationFrames(from: image, action: action, desc: desc)
        if !frames.isEmpty {
            PetImageCache.shared.setAnimation(frames, for: pet.id, action: action.id)
        }
        previewView.setFrames(frames)
    }


    // MARK: - Actions

    @objc private func openMarketplace() {
        NotificationCenter.default.post(name: .sidebarSelectionChanged, object: nil, userInfo: ["item": SidebarItem(id: "marketplace", title: l("menu.open_marketplace"), iconName: "bag", isCategory: false)])
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
            alert.messageText = l("manage.cannot_uninstall_active_title")
            alert.informativeText = l("manage.cannot_uninstall_active_message", pet.displayName)
            alert.addButton(withTitle: l("manage.open_codex_settings"))
            alert.addButton(withTitle: l("ok"))
            if alert.runModal() == .alertFirstButtonReturn {
                openCodexSettings()
            }
            return
        }

        let alert = NSAlert()
        alert.messageText = l("manage.uninstall_pet_title")
        alert.informativeText = l("manage.uninstall_pet_message", pet.displayName, pet.id, pet.path)
        if !pet.isAppManaged {
            alert.informativeText += l("manage.uninstall_pet_local_warning")
        }
        alert.addButton(withTitle: l("manage.uninstall"))
        alert.addButton(withTitle: l("cancel"))
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
                        successAlert.messageText = l("manage.pet_installed_title")
                        successAlert.informativeText = l("manage.pet_installed_message")
                        successAlert.addButton(withTitle: l("manage.open_codex_settings"))
                        successAlert.addButton(withTitle: l("ok"))
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
            alert.messageText = l("manage.could_not_open_codex")
            alert.informativeText = l("manage.codex_not_found")
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
            imgView.translatesAutoresizingMaskIntoConstraints = false
            imgView.wantsLayer = true
            imgView.layer?.cornerRadius = 6
            imgView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            cell?.addSubview(imgView)
            cell?.imageView = imgView
            
            let textField = NSTextField(labelWithString: "")
            textField.font = .systemFont(ofSize: 13, weight: .medium)
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(textField)
            cell?.textField = textField

            let subField = NSTextField(labelWithString: "")
            subField.font = .systemFont(ofSize: 11)
            subField.textColor = .secondaryLabelColor
            subField.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(subField)

            NSLayoutConstraint.activate([
                imgView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 10),
                imgView.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                imgView.widthAnchor.constraint(equalToConstant: 42),
                imgView.heightAnchor.constraint(equalToConstant: 42),
                textField.topAnchor.constraint(equalTo: cell!.topAnchor, constant: 10),
                textField.leadingAnchor.constraint(equalTo: imgView.trailingAnchor, constant: 10),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -10),
                subField.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 2),
                subField.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
                subField.trailingAnchor.constraint(equalTo: textField.trailingAnchor)
            ])
        }
        
        var display = pet.displayName
        if pet.isCurrent { display += l("manage.active_suffix") }
        cell?.textField?.stringValue = display
        cell?.textField?.textColor = pet.isCurrent ? .systemGreen : .labelColor
        if let subField = cell?.subviews.compactMap({ $0 as? NSTextField }).last {
            subField.stringValue = pet.isAppManaged ? "Nest" : "Local"
        }
        
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
        return 58
    }


    func tableViewSelectionDidChange(_ notification: Notification) {
        updateDetail()
    }
}

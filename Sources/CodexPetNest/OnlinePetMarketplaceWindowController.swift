import Foundation
import AppKit

final class OnlinePetMarketplaceWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {
    
    static let shared = OnlinePetMarketplaceWindowController()
    
    private var pets: [PetItem] = []
    private var selectedPet: PetDetail?
    private var isInstalling: Bool = false
    private var isLoading: Bool = false
    private var currentPage: Int = 1
    private var totalItems: Int = 0
    private var pageSize: Int = 10
    
    private var listTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?
    
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let searchField = NSSearchField()
    private let loadingIndicator = NSProgressIndicator()
    
    private let paginationBar = NSStackView()
    private let prevButton = NSButton()
    private let nextButton = NSButton()
    private let pageLabel = NSTextField(labelWithString: "Page 1")
    
    
    private let detailContainer = NSView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let authorLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(wrappingLabelWithString: "")
    private let metaLabel = NSTextField(labelWithString: "")
    private let tagsLabel = NSTextField(labelWithString: "")
    private let previewView = AnimatedSpritePreviewView()
    private let actionSwitcher = NSSegmentedControl()
    private let installButton = NSButton()
    private let settingsButton = NSButton()
    private let statusLabel = NSTextField(labelWithString: "")
    private let websiteButton = NSButton()
    
    private var currentAnimationFrames: [NSImage] = []
    private var spritesheetImage: NSImage?
    private var petSpriteConfig: PetSpriteConfig?


    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if pets.isEmpty { loadData() }
    }
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pet Marketplace"
        window.center()
        self.init(window: window)
        setupUI()
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        // Search Bar
        searchField.placeholderString = "Search online pets..."
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchField)
        
        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .small
        loadingIndicator.isDisplayedWhenStopped = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loadingIndicator)

        websiteButton.title = "Open codexpet.xyz"
        websiteButton.bezelStyle = .inline
        websiteButton.target = self
        websiteButton.action = #selector(openWebsite)
        websiteButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(websiteButton)
        
        // Split View (Manual)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        contentView.addSubview(scrollView)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowHeight = 64 // Taller rows for thumbnails
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("PetColumn"))
        tableView.addTableColumn(column)
        scrollView.documentView = tableView
        
        // Pagination Bar
        paginationBar.orientation = .horizontal
        paginationBar.spacing = 8
        paginationBar.alignment = .centerY
        paginationBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(paginationBar)
        
        prevButton.title = "Prev"
        prevButton.bezelStyle = .rounded
        prevButton.target = self
        prevButton.action = #selector(prevPage)
        paginationBar.addArrangedSubview(prevButton)
        
        pageLabel.font = .systemFont(ofSize: 12)
        paginationBar.addArrangedSubview(pageLabel)
        
        nextButton.title = "Next"
        nextButton.bezelStyle = .rounded
        nextButton.target = self
        nextButton.action = #selector(nextPage)
        paginationBar.addArrangedSubview(nextButton)
        
        detailContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(detailContainer)
        
        // Detail View Layout
        previewView.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(previewView)
        
        actionSwitcher.segmentCount = 4
        actionSwitcher.setLabel("Idle", forSegment: 0)
        actionSwitcher.setLabel("Walk", forSegment: 1)
        actionSwitcher.setLabel("Sleep", forSegment: 2)
        actionSwitcher.setLabel("Action", forSegment: 3)
        actionSwitcher.selectedSegment = 0
        actionSwitcher.target = self
        actionSwitcher.action = #selector(actionChanged)
        actionSwitcher.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(actionSwitcher)
        
        nameLabel.font = .boldSystemFont(ofSize: 22)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(nameLabel)
        
        authorLabel.textColor = .secondaryLabelColor
        authorLabel.font = .systemFont(ofSize: 13)
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(authorLabel)
        
        descriptionLabel.font = .systemFont(ofSize: 13)
        descriptionLabel.textColor = .labelColor
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(descriptionLabel)
        
        metaLabel.textColor = .secondaryLabelColor
        metaLabel.font = .systemFont(ofSize: 11)
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(metaLabel)
        
        tagsLabel.textColor = .systemBlue
        tagsLabel.font = .systemFont(ofSize: 11, weight: .medium)
        tagsLabel.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(tagsLabel)
        
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(statusLabel)
        
        installButton.title = "Install"
        installButton.bezelStyle = .rounded
        installButton.target = self
        installButton.action = #selector(installClicked)
        installButton.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(installButton)
        
        settingsButton.title = "Open Codex Settings"
        settingsButton.bezelStyle = .rounded
        settingsButton.target = self
        settingsButton.action = #selector(openCodexSettings)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(settingsButton)
        
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchField.widthAnchor.constraint(equalToConstant: 280),
            
            loadingIndicator.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            loadingIndicator.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 8),

            websiteButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            websiteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.bottomAnchor.constraint(equalTo: paginationBar.topAnchor, constant: -8),
            scrollView.widthAnchor.constraint(equalToConstant: 280),
            
            paginationBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            paginationBar.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            paginationBar.heightAnchor.constraint(equalToConstant: 32),
            
            
            detailContainer.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            detailContainer.leadingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: 16),
            detailContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            detailContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            previewView.topAnchor.constraint(equalTo: detailContainer.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
            previewView.heightAnchor.constraint(equalToConstant: 280),
            
            actionSwitcher.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 12),
            actionSwitcher.centerXAnchor.constraint(equalTo: detailContainer.centerXAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: actionSwitcher.bottomAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
            
            authorLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            authorLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            
            descriptionLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
            
            metaLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            metaLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            
            tagsLabel.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 6),
            tagsLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            tagsLabel.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
            
            statusLabel.bottomAnchor.constraint(equalTo: installButton.topAnchor, constant: -12),
            statusLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            
            installButton.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor),
            installButton.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            installButton.widthAnchor.constraint(equalToConstant: 120),
            
            settingsButton.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor),
            settingsButton.leadingAnchor.constraint(equalTo: installButton.trailingAnchor, constant: 12)
        ])
        
        detailContainer.isHidden = true
    }
    
    private func loadData(search: String? = nil, page: Int = 1) {
        listTask?.cancel()
        isLoading = true
        loadingIndicator.startAnimation(nil)
        self.currentPage = page
        
        listTask = Task {
            do {
                let response = try await CodexPetAPI.shared.listPets(search: search, page: page, limit: pageSize)
                if Task.isCancelled { return }
                
                await MainActor.run {
                    self.pets = response.items
                    self.totalItems = response.total
                    self.pageSize = response.pageSize
                    self.updatePaginationUI()
                    self.tableView.reloadData()
                    self.isLoading = false
                    self.loadingIndicator.stopAnimation(nil)
                    // Select first if any
                    if !self.pets.isEmpty && self.tableView.selectedRow == -1 {
                        self.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                    }
                }
            } catch {
                if Task.isCancelled { return }
                print("Failed to load pets: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.loadingIndicator.stopAnimation(nil)
                    self.showErrorAlert(message: "Failed to load pets: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func updatePaginationUI() {
        let totalPages = max(1, Int(ceil(Double(totalItems) / Double(pageSize))))
        pageLabel.stringValue = "\(currentPage) / \(totalPages)"
        prevButton.isEnabled = currentPage > 1
        nextButton.isEnabled = currentPage < totalPages
    }
    
    @objc private func prevPage() {
        if currentPage > 1 {
            loadData(search: searchField.stringValue, page: currentPage - 1)
        }
    }
    
    @objc private func nextPage() {
        let totalPages = max(1, Int(ceil(Double(totalItems) / Double(pageSize))))
        if currentPage < totalPages {
            loadData(search: searchField.stringValue, page: currentPage + 1)
        }
    }
    
    @MainActor
    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Network Error"
        alert.informativeText = message
        alert.addButton(withTitle: "Retry")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            loadData(search: searchField.stringValue)
        }
    }
    
    @objc private func searchChanged() {
        loadData(search: searchField.stringValue)
    }
    
    @objc private func installClicked() {
        guard let pet = selectedPet else { return }
        
        isInstalling = true
        installButton.isEnabled = false
        installButton.title = "Installing..."
        
        Task {
            do {
                try await PackageManager.shared.installPet(id: pet.id)
                await MainActor.run {
                    self.isInstalling = false
                    self.updateDetailUI()
                    
                    let alert = NSAlert()
                    alert.messageText = "Pet Installed"
                    alert.informativeText = "Pet '\(pet.name)' installed successfully. In Codex, open Settings -> Appearance and choose this pet."
                    alert.addButton(withTitle: "Open Codex Settings")
                    alert.addButton(withTitle: "OK")
                    if alert.runModal() == .alertFirstButtonReturn {
                        self.openCodexSettings()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isInstalling = false
                    self.installButton.isEnabled = true
                    self.installButton.title = "Install"
                    
                    let alert = NSAlert()
                    alert.messageText = "Installation Failed"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
    }
    
    @objc private func openWebsite() {
        NSWorkspace.shared.open(URL(string: "https://codexpet.xyz")!)
    }
    
    @objc private func actionChanged() {
        updateAnimation()
    }

    
    @objc private func openCodexSettings() {
        let codexSettingsURL = URL(string: "codex://settings/general-settings")!
        if NSWorkspace.shared.open(codexSettingsURL) {
            return
        }
        
        // Fallback
        let appPath = "/Applications/Codex.app"
        if FileManager.default.fileExists(atPath: appPath) {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: appPath), configuration: NSWorkspace.OpenConfiguration())
        }
    }
    
    private func updateDetailUI() {
        guard let pet = selectedPet else {
            detailContainer.isHidden = true
            return
        }
        
        detailContainer.isHidden = false
        nameLabel.stringValue = pet.name
        authorLabel.stringValue = "by \(pet.author)"
        descriptionLabel.stringValue = pet.description
        
        let dateStr = pet.updatedAt.prefix(10)
        metaLabel.stringValue = "License: \(pet.license) | Updated: \(dateStr)"
        tagsLabel.stringValue = pet.tags.map { "#\($0)" }.joined(separator: " ")
        
        let isInstalled = PackageManager.shared.isPetInstalled(id: pet.id)
        installButton.title = isInstalled ? "Reinstall" : "Install"
        installButton.isEnabled = !isInstalling
        
        statusLabel.stringValue = "ID: \(pet.id) | Version: \(pet.version) | Downloads: \(pet.downloads)"
        
        // Load Preview
        detailTask?.cancel()
        detailTask = Task {
            if let url = URL(string: pet.previewUrl) {
                if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
                    await MainActor.run {
                        if self.selectedPet?.id == pet.id {
                            self.spritesheetImage = image
                            self.actionSwitcher.selectedSegment = 0
                            self.updateAnimation()
                        }
                    }
                }
            }
        }
    }
    
    private func updateAnimation() {
        guard let image = spritesheetImage else { return }
        
        let row = actionSwitcher.selectedSegment
        let frames: [NSImage]
        
        if let config = petSpriteConfig {
            let actions = ["idle", "walk", "sleep", "action"]
            let actionName = row < actions.count ? actions[row] : "idle"
            frames = PetSpriteSheetRenderer.shared.extractAnimationFrames(from: image, action: actionName, config: config)
        } else {
            // Fallback to heuristic
            frames = PetSpriteSheetRenderer.shared.extractFallbackAnimation(from: image, row: row)
        }
        
        previewView.setFrames(frames)
    }

    
    // MARK: - TableView
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return pets.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let pet = pets[row]
        let identifier = NSUserInterfaceItemIdentifier("PetCell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView(frame: .zero)
            cell?.identifier = identifier
            
            let imgView = NSImageView()
            imgView.imageScaling = .scaleProportionallyUpOrDown
            imgView.translatesAutoresizingMaskIntoConstraints = false
            imgView.wantsLayer = true
            imgView.layer?.cornerRadius = 4
            imgView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.05).cgColor
            cell?.addSubview(imgView)
            cell?.imageView = imgView
            
            let nameField = NSTextField(labelWithString: "")
            nameField.font = .systemFont(ofSize: 13, weight: .medium)
            nameField.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(nameField)
            cell?.textField = nameField
            
            let authorField = NSTextField(labelWithString: "")
            authorField.font = .systemFont(ofSize: 11)
            authorField.textColor = .secondaryLabelColor
            authorField.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(authorField)
            
            NSLayoutConstraint.activate([
                imgView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                imgView.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                imgView.widthAnchor.constraint(equalToConstant: 48),
                imgView.heightAnchor.constraint(equalToConstant: 48),
                
                nameField.topAnchor.constraint(equalTo: cell!.topAnchor, constant: 12),
                nameField.leadingAnchor.constraint(equalTo: imgView.trailingAnchor, constant: 8),
                nameField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                
                authorField.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 2),
                authorField.leadingAnchor.constraint(equalTo: imgView.trailingAnchor, constant: 8),
                authorField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4)
            ])
        }
        
        cell?.textField?.stringValue = pet.name
        if let authorField = cell?.subviews.compactMap({ $0 as? NSTextField }).last {
            authorField.stringValue = pet.author
        }
        
        // Async load thumbnail
        cell?.imageView?.image = nil
        Task {
            if let url = URL(string: pet.previewUrl) {
                if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
                    let thumbnail = PetSpriteSheetRenderer.shared.extractFirstFrame(from: image)
                    await MainActor.run {
                        // Check if row is still visible
                        let currentRow = self.tableView.row(for: cell!)
                        if currentRow == row {
                            cell?.imageView?.image = thumbnail
                        }
                    }
                }
            }
        }
        
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 else {
            selectedPet = nil
            updateDetailUI()
            return
        }
        
        let petSummary = pets[row]
        detailTask?.cancel()
        
        detailTask = Task {
            do {
                let detail = try await CodexPetAPI.shared.getPet(id: petSummary.id)
                if Task.isCancelled { return }
                
                await MainActor.run {
                    self.selectedPet = detail
                    self.updateDetailUI()
                }
            } catch {
                if Task.isCancelled { return }
                print("Failed to get pet detail: \(error)")
            }
        }
    }
}

extension NSImage {
    func firstFrame() -> NSImage {
        let w = size.width
        let h = size.height
        if w == 0 || h == 0 { return self }
        
        // Heuristic: If it's a strip, take the square. 
        // If it's 1:1, return self.
        // If it's a grid (e.g. 400x400 with 80x80 frames), it's hard without meta.
        // But most "previews" for pets are either 1:1 or horizontal strips.
        let frameSize = min(w, h)
        if w == h { return self }
        
        let rect = NSRect(x: 0, y: h - frameSize, width: frameSize, height: frameSize)
        let target = NSImage(size: NSSize(width: frameSize, height: frameSize))
        target.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: target.size), from: rect, operation: .copy, fraction: 1.0)
        target.unlockFocus()
        return target
    }
}


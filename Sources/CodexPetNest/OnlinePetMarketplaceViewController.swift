import Foundation
import AppKit

final class OnlinePetMarketplaceViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    static let shared = OnlinePetMarketplaceViewController()
    
    private var pets: [PetItem] = []
    private var selectedPet: PetDetail?
    private var isInstalling: Bool = false
    private var isLoading: Bool = false
    private var currentPage: Int = 1
    private var totalItems: Int = 0
    private var pageSize: Int = 10
    
    private var listTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?
    private var searchTimer: Timer?

    
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let searchField = NSSearchField()
    private let loadingIndicator = NSProgressIndicator()
    
    private let paginationBar = NSStackView()
    private let prevButton = NSButton()
    private let nextButton = NSButton()
    private let pageLabel = NSTextField(labelWithString: l("market.page", 1))
    
    
    private let detailContainer = NSView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let authorLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(wrappingLabelWithString: "")
    private let metaLabel = NSTextField(labelWithString: "")
    private let tagsLabel = NSTextField(labelWithString: "")
    private let previewView = AnimatedSpritePreviewView()
    private let actionPopup = NSPopUpButton()
    private var previewActions: [PetPreviewAction] = []
    private let installButton = NSButton()
    private let settingsButton = NSButton()
    private let statusLabel = NSTextField(labelWithString: "")
    private let websiteButton = NSButton()
    
    private var currentAnimationFrames: [NSImage] = []
    private var spritesheetImage: NSImage?
    private var spriteDescriptor: SpriteSheetDescriptor?



    
    override func viewDidLoad() {
        super.viewDidLoad()
        if pets.isEmpty { loadData() }
    }
    
    override func loadView() {
        self.view = NSView()
        setupUI()
    }
    
    private func setupUI() {
        let contentView = self.view
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NestUI.contentBackground.cgColor


        
        // Search Bar
        searchField.placeholderString = l("market.search_placeholder")
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchField)
        
        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .small
        loadingIndicator.isDisplayedWhenStopped = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loadingIndicator)

        websiteButton.title = l("menu.open_website")
        NestUI.styleSecondaryButton(websiteButton)
        websiteButton.target = self
        websiteButton.action = #selector(openWebsite)
        websiteButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(websiteButton)
        
        // Split View (Manual)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        contentView.addSubview(scrollView)

        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowHeight = 58
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.selectionHighlightStyle = .regular
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("PetColumn"))
        tableView.addTableColumn(column)
        scrollView.documentView = tableView
        
        // Pagination Bar
        paginationBar.orientation = .horizontal
        paginationBar.spacing = 8
        paginationBar.alignment = .centerY
        paginationBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(paginationBar)
        
        prevButton.title = l("market.prev")
        NestUI.styleSecondaryButton(prevButton)
        prevButton.target = self
        prevButton.action = #selector(prevPage)
        paginationBar.addArrangedSubview(prevButton)
        
        pageLabel.font = .systemFont(ofSize: 12)
        paginationBar.addArrangedSubview(pageLabel)
        
        nextButton.title = l("market.next")
        NestUI.styleSecondaryButton(nextButton)
        nextButton.target = self
        nextButton.action = #selector(nextPage)
        paginationBar.addArrangedSubview(nextButton)
        
        detailContainer.translatesAutoresizingMaskIntoConstraints = false
        NestUI.panel(detailContainer, color: NestUI.panelBackground)
        contentView.addSubview(detailContainer)

        
        // Detail View Layout
        previewView.translatesAutoresizingMaskIntoConstraints = false
        NestUI.previewSurface(previewView)
        detailContainer.addSubview(previewView)
        
        actionPopup.target = self
        actionPopup.action = #selector(actionChanged)
        actionPopup.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(actionPopup)
        
        nameLabel.font = .systemFont(ofSize: 22, weight: .bold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(nameLabel)

        
        authorLabel.textColor = .secondaryLabelColor
        authorLabel.font = .systemFont(ofSize: 13)
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(authorLabel)
        
        descriptionLabel.font = .systemFont(ofSize: 13)
        descriptionLabel.textColor = .labelColor
        descriptionLabel.maximumNumberOfLines = 4
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(descriptionLabel)
        
        metaLabel.textColor = .secondaryLabelColor
        metaLabel.font = .systemFont(ofSize: 11)
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(metaLabel)
        
        tagsLabel.textColor = NestUI.accent
        tagsLabel.font = .systemFont(ofSize: 11, weight: .medium)
        tagsLabel.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(tagsLabel)

        
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(statusLabel)
        
        installButton.title = l("market.install")
        NestUI.stylePrimaryButton(installButton)
        installButton.target = self
        installButton.action = #selector(installClicked)
        installButton.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(installButton)
        
        settingsButton.title = l("manage.open_codex_settings")
        NestUI.styleSecondaryButton(settingsButton)
        settingsButton.target = self
        settingsButton.action = #selector(openCodexSettings)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(settingsButton)
        
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            searchField.widthAnchor.constraint(equalToConstant: 300),
            
            loadingIndicator.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            loadingIndicator.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 8),

            websiteButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            websiteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            scrollView.bottomAnchor.constraint(equalTo: paginationBar.topAnchor, constant: -8),
            scrollView.widthAnchor.constraint(equalToConstant: 310),
            
            paginationBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            paginationBar.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            paginationBar.heightAnchor.constraint(equalToConstant: 32),
            
            
            detailContainer.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 14),
            detailContainer.leadingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: 12),
            detailContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            detailContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            
            previewView.topAnchor.constraint(equalTo: detailContainer.topAnchor, constant: 20),
            previewView.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor, constant: 20),
            previewView.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor, constant: -20),
            previewView.heightAnchor.constraint(equalTo: detailContainer.heightAnchor, multiplier: 0.45),
            previewView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
            
            actionPopup.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 14),
            actionPopup.centerXAnchor.constraint(equalTo: detailContainer.centerXAnchor),
            actionPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            
            nameLabel.topAnchor.constraint(equalTo: actionPopup.bottomAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor, constant: 24),
            nameLabel.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor, constant: -24),
            
            authorLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            authorLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            
            tagsLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 10),
            tagsLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            tagsLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: tagsLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            
            metaLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            metaLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            
            statusLabel.bottomAnchor.constraint(equalTo: installButton.topAnchor, constant: -14),
            statusLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            
            installButton.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor, constant: -20),
            installButton.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            installButton.widthAnchor.constraint(equalToConstant: 130),
            installButton.heightAnchor.constraint(equalToConstant: 34),
            
            settingsButton.centerYAnchor.constraint(equalTo: installButton.centerYAnchor),
            settingsButton.leadingAnchor.constraint(equalTo: installButton.trailingAnchor, constant: 10),
            settingsButton.heightAnchor.constraint(equalToConstant: 34)
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
                    self.showErrorAlert(message: l("market.failed_load", error.localizedDescription))
                }
            }
        }
    }
    
    private func updatePaginationUI() {
        let totalPages = max(1, Int(ceil(Double(totalItems) / Double(pageSize))))
        pageLabel.stringValue = l("market.page", currentPage) + " / \(totalPages)"
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
        alert.messageText = l("market.network_error")
        alert.informativeText = message
        alert.addButton(withTitle: l("market.retry"))
        alert.addButton(withTitle: l("ok"))
        if alert.runModal() == .alertFirstButtonReturn {
            loadData(search: searchField.stringValue)
        }
    }
    
    @objc private func searchChanged() {
        searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.loadData(search: self?.searchField.stringValue)
        }
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
                    alert.messageText = l("market.install_success_title")
                    alert.informativeText = l("market.install_success_message", pet.name)
                    alert.addButton(withTitle: l("manage.open_codex_settings"))
                    alert.addButton(withTitle: l("ok"))
                    if alert.runModal() == .alertFirstButtonReturn {
                        self.openCodexSettings()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isInstalling = false
                    self.installButton.isEnabled = true
                    self.installButton.title = l("market.install")
                    
                    let alert = NSAlert()
                    alert.messageText = l("market.install_failed_title")
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
    }
    
    @objc private func openWebsite() {
        NSWorkspace.shared.open(URL(string: "https://codexpet.xyz")!)
    }

    @objc private func openSelectedPetWebsite() {
        guard let pet = selectedPet else { return }
        let urlStr = !pet.detailUrl.isEmpty ? pet.detailUrl : "https://codexpet.xyz/share/\(pet.id)"
        if let url = URL(string: urlStr) {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func actionChanged() {
        updateAnimation()
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
        }
    }
    
    private func updateDetailUI() {
        guard let pet = selectedPet else {
            detailContainer.isHidden = true
            websiteButton.title = l("menu.open_website")
            websiteButton.action = #selector(openWebsite)
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
        installButton.title = isInstalled ? l("market.reinstall") : l("market.install")
        installButton.isEnabled = !isInstalling
        
        websiteButton.title = l("market.view_on_website")
        websiteButton.action = #selector(openSelectedPetWebsite)
        
        statusLabel.stringValue = "ID: \(pet.id) | Version: \(pet.version) | Downloads: \(pet.downloads)"
        
        // Load Preview
        detailTask?.cancel()
        detailTask = Task {
            if let url = URL(string: pet.previewUrl) {
                let image: NSImage?
                if let cached = PetImageCache.shared.getSpritesheet(for: pet.previewUrl) {
                    image = cached
                } else {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        image = NSImage(data: data)
                        if let img = image {
                            PetImageCache.shared.setSpritesheet(img, for: pet.previewUrl)
                        }
                    } catch {
                        print("Failed to download spritesheet: \(error)")
                        image = nil
                    }
                }
                
                if let img = image, !Task.isCancelled {
                    await MainActor.run {
                        if self.selectedPet?.id == pet.id {
                            self.spritesheetImage = img
                            
                            guard let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
                            
                            // Create manifest dict for animations if available
                            var manifestDict: [String: Any] = [:]
                            if let anims = pet.animations {
                                // Convert to [String: [String: Any]] for detectDescriptor
                                var animsDict: [String: [String: Any]] = [:]
                                for (key, cfg) in anims {
                                    var cfgDict: [String: Any] = ["row": cfg.row, "frames": cfg.frames]
                                    if let fps = cfg.fps { cfgDict["fps"] = fps }
                                    animsDict[key] = cfgDict
                                }
                                manifestDict["animations"] = animsDict
                            }
                            
                            self.spriteDescriptor = PetSpriteSheetRenderer.shared.detectDescriptor(cgImage: cg, manifest: manifestDict)
                            self.previewActions = PetSpriteSheetRenderer.shared.previewActions(for: self.spriteDescriptor!)
                            
                            // Rebuild popup
                            self.actionPopup.removeAllItems()
                            for action in self.previewActions {
                                self.actionPopup.addItem(withTitle: action.label)
                            }
                            self.actionPopup.selectItem(at: 0)
                            
                            self.updateAnimation()
                        }
                    }
                }
            }
        }
    }
    
    private func updateAnimation() {
        guard let image = spritesheetImage, let desc = spriteDescriptor else { return }
        
        let index = actionPopup.indexOfSelectedItem
        guard index >= 0, index < previewActions.count else { return }
        let action = previewActions[index]
        
        let petId = selectedPet?.id ?? ""
        if let cached = PetImageCache.shared.getAnimation(for: petId, action: action.id) {
            previewView.setFrames(cached)
            return
        }
        
        let frames = PetSpriteSheetRenderer.shared.extractAnimationFrames(from: image, action: action, desc: desc)
        if !frames.isEmpty {
            PetImageCache.shared.setAnimation(frames, for: petId, action: action.id)
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
            imgView.layer?.cornerRadius = 6
            imgView.layer?.backgroundColor = NestUI.previewBackground.cgColor
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

            let metaField = NSTextField(labelWithString: "")
            metaField.font = .systemFont(ofSize: 10)
            metaField.textColor = .tertiaryLabelColor
            metaField.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(metaField)
            
            NSLayoutConstraint.activate([
                imgView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 10),
                imgView.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                imgView.widthAnchor.constraint(equalToConstant: 44),
                imgView.heightAnchor.constraint(equalToConstant: 44),
                
                nameField.topAnchor.constraint(equalTo: cell!.topAnchor, constant: 8),
                nameField.leadingAnchor.constraint(equalTo: imgView.trailingAnchor, constant: 10),
                nameField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -10),
                
                authorField.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 2),
                authorField.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
                authorField.trailingAnchor.constraint(equalTo: nameField.trailingAnchor),

                metaField.topAnchor.constraint(equalTo: authorField.bottomAnchor, constant: 1),
                metaField.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
                metaField.trailingAnchor.constraint(equalTo: nameField.trailingAnchor)
            ])
        }
        
        cell?.textField?.stringValue = pet.name
        let labels = cell?.subviews.compactMap({ $0 as? NSTextField }) ?? []
        if labels.count > 1 {
            labels[1].stringValue = pet.author
        }
        if labels.count > 2 {
            labels[2].stringValue = "v\(pet.version)"
        }
        
        // Async load thumbnail with caching
        cell?.imageView?.image = nil
        
        if let cached = PetImageCache.shared.getThumbnail(for: pet.id) {
            cell?.imageView?.image = cached
            return cell
        }
        
        Task {
            if let url = URL(string: pet.previewUrl) {
                do {
                    let image: NSImage?
                    if let cachedSheet = PetImageCache.shared.getSpritesheet(for: pet.previewUrl) {
                        image = cachedSheet
                    } else {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        image = NSImage(data: data)
                        if let img = image {
                            PetImageCache.shared.setSpritesheet(img, for: pet.previewUrl)
                        }
                    }
                    
                    if let img = image {
                        let thumbnail = PetSpriteSheetRenderer.shared.extractFirstFrame(from: img, petId: pet.id)
                        if let thumb = thumbnail {
                            PetImageCache.shared.setThumbnail(thumb, for: pet.id)
                            await MainActor.run {
                                let currentRow = self.tableView.row(for: cell!)
                                if currentRow == row {
                                    cell?.imageView?.image = thumb
                                }
                            }
                        }
                    }

                } catch {
                    print("Thumbnail load failed: \(error)")
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

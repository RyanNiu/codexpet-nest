import Foundation
import AppKit

final class OnlinePetMarketplaceWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {
    
    static let shared = OnlinePetMarketplaceWindowController()
    
    private var pets: [PetItem] = []
    private var selectedPet: PetDetail?
    private var isInstalling: Bool = false
    private var isLoading: Bool = false
    
    private var listTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?
    
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let searchField = NSSearchField()
    private let loadingIndicator = NSProgressIndicator()
    
    private let detailContainer = NSView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let authorLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(wrappingLabelWithString: "")
    private let metaLabel = NSTextField(labelWithString: "")
    private let tagsLabel = NSTextField(labelWithString: "")
    private let previewImageView = NSImageView()
    private let installButton = NSButton()
    private let settingsButton = NSButton()
    private let statusLabel = NSTextField(labelWithString: "")
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if pets.isEmpty { loadData() }
    }
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 850, height: 580),
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
        
        // Split View (Manual)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        contentView.addSubview(scrollView)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("PetColumn"))
        tableView.addTableColumn(column)
        scrollView.documentView = tableView
        
        detailContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(detailContainer)
        
        // Detail View Layout
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(previewImageView)
        
        nameLabel.font = .boldSystemFont(ofSize: 24)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(nameLabel)
        
        authorLabel.textColor = .secondaryLabelColor
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(authorLabel)
        
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
        statusLabel.font = .systemFont(ofSize: 12)
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
            
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            scrollView.widthAnchor.constraint(equalToConstant: 280),
            
            detailContainer.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            detailContainer.leadingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: 16),
            detailContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            detailContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            previewImageView.topAnchor.constraint(equalTo: detailContainer.topAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
            previewImageView.heightAnchor.constraint(equalToConstant: 200),
            
            nameLabel.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
            
            authorLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            authorLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            
            metaLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 4),
            metaLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            
            tagsLabel.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 8),
            tagsLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            tagsLabel.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
            
            descriptionLabel.topAnchor.constraint(equalTo: tagsLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
            
            statusLabel.bottomAnchor.constraint(equalTo: installButton.topAnchor, constant: -8),
            statusLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            
            installButton.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor),
            installButton.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            installButton.widthAnchor.constraint(equalToConstant: 120),
            
            settingsButton.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor),
            settingsButton.leadingAnchor.constraint(equalTo: installButton.trailingAnchor, constant: 12)
        ])
        
        detailContainer.isHidden = true
    }
    
    private func loadData(search: String? = nil) {
        listTask?.cancel()
        isLoading = true
        loadingIndicator.startAnimation(nil)
        
        listTask = Task {
            do {
                let response = try await CodexPetAPI.shared.listPets(search: search)
                if Task.isCancelled { return }
                
                await MainActor.run {
                    self.pets = response.items
                    self.tableView.reloadData()
                    self.isLoading = false
                    self.loadingIndicator.stopAnimation(nil)
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
        Task {
            if let url = URL(string: pet.previewUrl) {
                if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
                    await MainActor.run {
                        if self.selectedPet?.id == pet.id {
                            self.previewImageView.image = image
                        }
                    }
                }
            }
        }
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
                nameField.topAnchor.constraint(equalTo: cell!.topAnchor, constant: 4),
                nameField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                nameField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                
                authorField.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 2),
                authorField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                authorField.bottomAnchor.constraint(equalTo: cell!.bottomAnchor, constant: -4)
            ])
        }
        
        cell?.textField?.stringValue = pet.name
        if let authorField = cell?.subviews.compactMap({ $0 as? NSTextField }).last {
            authorField.stringValue = pet.author
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

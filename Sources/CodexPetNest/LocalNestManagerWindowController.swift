import AppKit

final class LocalNestManagerWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    static let shared = LocalNestManagerWindowController()
    
    private var tableView: NSTableView!
    private var nests: [InstalledNest] = []
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Manage Nests"
        window.center()
        super.init(window: window)
        setupUI()
        refreshData()
        
        NotificationCenter.default.addObserver(self, selector: #selector(refreshData), name: .installedNestsChanged, object: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshData()
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 74
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.selectionHighlightStyle = .regular
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NestColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        
        let bottomBar = NSStackView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 10
        bottomBar.alignment = .centerY
        
        let installBtn = NSButton(title: "Install Local Nest ZIP...", target: self, action: #selector(installLocalNest))
        let refreshBtn = NSButton(title: "Refresh", target: self, action: #selector(refreshData))
        
        bottomBar.addArrangedSubview(installBtn)
        bottomBar.addArrangedSubview(refreshBtn)
        bottomBar.addArrangedSubview(NSView()) // Spacer
        
        contentView.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),

            bottomBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            bottomBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            bottomBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            bottomBar.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    @objc private func refreshData() {
        self.nests = LocalNestManager.shared.installedNests
        tableView.reloadData()
    }
    
    // MARK: - TableView
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return nests.count + 1 // +1 for "Capacity Orbit"
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let view = NSTableCellView()
        view.identifier = NSUserInterfaceItemIdentifier("NestCell")

        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 4
        iconView.layer?.masksToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconView)
        
        let infoStack = NSStackView()
        infoStack.orientation = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 4
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoStack)
        
        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        infoStack.addArrangedSubview(titleLabel)
        
        let authorLabel = NSTextField(labelWithString: "")
        authorLabel.font = NSFont.systemFont(ofSize: 11)
        authorLabel.textColor = .secondaryLabelColor
        authorLabel.lineBreakMode = .byTruncatingTail
        authorLabel.maximumNumberOfLines = 2
        infoStack.addArrangedSubview(authorLabel)

        let activeLabel = NSTextField(labelWithString: "Active")
        activeLabel.font = NSFont.boldSystemFont(ofSize: 11)
        activeLabel.textColor = .systemGreen
        activeLabel.isHidden = true
        activeLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activeLabel)
        
        let useBtn = NSButton(title: "Use", target: self, action: #selector(useNest(_:)))
        useBtn.bezelStyle = .rounded
        useBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(useBtn)
        
        let menuBtn = NSButton(image: NSImage(named: NSImage.actionTemplateName)!, target: self, action: #selector(showMenu(_:)))
        menuBtn.bezelStyle = .recessed
        menuBtn.isBordered = false
        menuBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuBtn)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 60),
            iconView.heightAnchor.constraint(equalToConstant: 45),

            infoStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            infoStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            infoStack.trailingAnchor.constraint(lessThanOrEqualTo: activeLabel.leadingAnchor, constant: -12),

            activeLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            activeLabel.trailingAnchor.constraint(equalTo: useBtn.leadingAnchor, constant: -12),

            useBtn.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            useBtn.widthAnchor.constraint(equalToConstant: 72),
            useBtn.trailingAnchor.constraint(equalTo: menuBtn.leadingAnchor, constant: -8),

            menuBtn.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            menuBtn.widthAnchor.constraint(equalToConstant: 28),
            menuBtn.heightAnchor.constraint(equalToConstant: 28),
            menuBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
        let currentNestId = SettingsStore.shared.settings.activeNestId
        
        if row == 0 {
            titleLabel.stringValue = "Capacity Orbit"
            authorLabel.stringValue = "Built-in • Shows live usage rings around your pet"
            iconView.image = NSImage(named: NSImage.networkName)
            useBtn.tag = -2
            menuBtn.tag = -2
            menuBtn.isEnabled = false
            if currentNestId == "capacity-orbit-nest" {
                activeLabel.isHidden = false
                useBtn.isEnabled = false
            }
        } else {
            let nest = nests[row - 1]
            titleLabel.stringValue = nest.name
            authorLabel.stringValue = "v\(nest.version) by \(nest.author)"
            if let pURL = nest.previewURL {
                iconView.image = NSImage(contentsOf: pURL)
            } else {
                iconView.image = NSImage(named: NSImage.networkName)
            }
            useBtn.tag = row - 1
            menuBtn.tag = row - 1
            if currentNestId == nest.id {
                activeLabel.isHidden = false
                useBtn.isEnabled = false
            }
        }
        
        return view
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 74
    }
    
    // MARK: - Actions
    
    @objc private func useNest(_ sender: NSButton) {
        let id: String
        if sender.tag == -2 {
            id = "capacity-orbit-nest"
        } else {
            id = nests[sender.tag].id
        }
        LocalNestManager.shared.applyNest(id: id)
        tableView.reloadData()
    }
    
    @objc private func showMenu(_ sender: NSButton) {
        guard sender.tag >= 0 else { return }
        let nest = nests[sender.tag]
        
        let menu = NSMenu()
        menu.addItem(withTitle: "Open in Finder", action: #selector(openInFinder(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Uninstall", action: #selector(uninstallNest(_:)), keyEquivalent: "").target = self
        
        menu.item(at: 0)?.representedObject = nest
        menu.item(at: 1)?.representedObject = nest
        
        let point = NSPoint(x: 0, y: sender.bounds.height)
        menu.popUp(positioning: nil, at: point, in: sender)
    }
    
    @objc private func openInFinder(_ sender: NSMenuItem) {
        guard let nest = sender.representedObject as? InstalledNest else { return }
        LocalNestManager.shared.openNestFolder(id: nest.id)
    }
    
    @objc private func uninstallNest(_ sender: NSMenuItem) {
        guard let nest = sender.representedObject as? InstalledNest else { return }
        
        let alert = NSAlert()
        alert.messageText = "Uninstall Nest Skin?"
        alert.informativeText = "Are you sure you want to remove '\(nest.name)'? This cannot be undone."
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try LocalNestManager.shared.uninstallNest(id: nest.id)
            } catch {
                let errAlert = NSAlert(error: error)
                errAlert.runModal()
            }
        }
    }
    
    @objc private func installLocalNest() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                do {
                    try await PackageManager.shared.installLocalNest(zipURL: url)
                    await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = "Nest Installed"
                        alert.informativeText = "The nest skin has been installed successfully. Would you like to use it now?"
                        alert.addButton(withTitle: "Apply Now")
                        alert.addButton(withTitle: "Later")
                        if alert.runModal() == .alertFirstButtonReturn {
                            // Find the newly installed nest
                            LocalNestManager.shared.refresh()
                            if let newNest = LocalNestManager.shared.installedNests.last {
                                LocalNestManager.shared.applyNest(id: newNest.id)
                            }
                        }
                        self.refreshData()
                    }
                } catch {
                    await MainActor.run {
                        let alert = NSAlert(error: error)
                        alert.runModal()
                    }
                }
            }
        }
    }
}
